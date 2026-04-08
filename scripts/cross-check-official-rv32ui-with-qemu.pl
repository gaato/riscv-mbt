#!/usr/bin/env perl

use v5.36;

use Carp qw(croak);
use File::Spec::Functions qw(catdir catfile);
use File::Temp qw(tempdir);
use FindBin qw($RealBin);
use IO::Socket::UNIX;
use POSIX qw(WNOHANG);
use Socket qw(SOCK_STREAM SHUT_WR);

sub repo_root () {
  state $root = catdir($RealBin, '..');
  return $root;
}

sub repo_path (@parts) {
  return @parts ? catfile(repo_root(), @parts) : repo_root();
}

sub command_exists ($command) {
  return -x $command if $command =~ m{/};

  for my $dir (split /:/, ($ENV{PATH} // q{})) {
    my $candidate = catfile($dir, $command);
    return 1 if -f $candidate && -x _;
  }

  return 0;
}

sub require_tool ($command) {
  croak "missing required tool: $command" if !command_exists($command);
  return $command;
}

sub detect_command ($env_name, @candidates) {
  my $configured = $ENV{$env_name};
  if (defined($configured) && $configured ne q{}) {
    require_tool($configured);
    return $configured;
  }

  for my $candidate (@candidates) {
    return $candidate if command_exists($candidate);
  }

  croak(
    "missing supported command for $env_name; tried " .
      join(', ', @candidates),
  );
}

sub capture_cmd (@command) {
  open my $fh, '-|', @command or croak "failed to start command: @command: $!";
  my $output = do {
    local $/;
    <$fh> // q{};
  };
  close $fh or croak "command failed ($?): @command";
  return $output;
}

sub manifest_rows ($path) {
  open my $fh, '<', $path or croak "failed to open $path: $!";

  my @rows;
  while (my $line = <$fh>) {
    chomp $line;
    $line =~ s/\r$//;
    next if $line =~ /^\s*(?:#|$)/;
    push @rows, [split /\t/, $line, -1];
  }

  close $fh or croak "failed to close $path: $!";
  return @rows;
}

my $src_dir = $ENV{RISCV_TESTS_DIR} // repo_path('_build', 'riscv-tests-src');
my $isa_dir = catdir($src_dir, 'isa');
my $manifest_file = repo_path('tools', 'riscv-tests-manifest.tsv');
my $qemu_bin = $ENV{QEMU_BIN} // 'qemu-system-riscv32';
my $readelf_bin = detect_command(
  'READELF_BIN',
  qw(riscv64-unknown-elf-readelf riscv64-elf-readelf),
);

my $poll_attempts = $ENV{QEMU_POLL_ATTEMPTS} // 200;
my $poll_interval = $ENV{QEMU_POLL_INTERVAL_SEC} // 0.05;
my $socket_attempts = $ENV{QEMU_SOCKET_ATTEMPTS} // 100;

require_tool($qemu_bin);
require_tool($readelf_bin);

if (!-d $isa_dir) {
  die <<"EOF";
missing official riscv-tests build output under $isa_dir
run ./scripts/build-riscv-tests-official.sh first
EOF
}

sub strip_monitor_output ($text) {
  $text =~ s/\e\[[0-9;]*[A-Za-z]//gr;
}

sub slurp_file ($path) {
  open my $fh, '<', $path or return q{};
  my $content = do {
    local $/;
    <$fh> // q{};
  };
  close $fh;
  return $content;
}

sub send_monitor_command ($socket_path, $command) {
  my $socket = IO::Socket::UNIX->new(
    Type => SOCK_STREAM,
    Peer => $socket_path,
  ) or die "failed to connect to QEMU monitor socket $socket_path: $!";

  print {$socket} "$command\n" or die "failed to write monitor command: $!";
  shutdown($socket, SHUT_WR) or die "failed to close monitor write side: $!";

  my $response = do {
    local $/;
    <$socket> // q{};
  };
  close $socket or die "failed to close monitor socket $socket_path: $!";
  return strip_monitor_output($response);
}

sub read_symbol_addr ($elf, $symbol) {
  my $output = capture_cmd($readelf_bin, '-sW', $elf);
  for my $line (split /\n/, $output) {
    my @fields = split ' ', $line;
    next if @fields < 8;
    return lc $fields[1] if $fields[7] eq $symbol;
  }
  return undef;
}

sub read_hmp_u32 ($monitor_socket, $address_hex) {
  my $raw = send_monitor_command($monitor_socket, "xp/1wx 0x$address_hex");
  for my $line (split /\n/, $raw) {
    return lc $1 if $line =~ /:\s+0x([0-9a-fA-F]+)/;
  }
  return undef;
}

sub read_register_snapshot ($monitor_socket) {
  return send_monitor_command($monitor_socket, 'info registers');
}

sub normalize_test_name ($input) {
  return $1 if $input =~ /^rv32ui-p-(.+)$/;
  return $input;
}

sub load_default_tests () {
  my @tests;
  for my $row (manifest_rows($manifest_file)) {
    my ($suite, $name, $arch, $tier) = @$row;
    next if !defined $tier;
    push @tests, $name if $suite eq 'rv32ui' && $tier eq 'gating';
  }
  return @tests;
}

sub child_alive ($pid) {
  return waitpid($pid, WNOHANG) == 0;
}

sub short_sleep ($seconds) {
  select undef, undef, undef, $seconds;
}

sub run_one ($short_name) {
  my $elf = catfile($isa_dir, "rv32ui-p-$short_name");
  die "missing official test binary: $elf\n" if !-f $elf;

  my $tohost = read_symbol_addr($elf, 'tohost')
    // die "failed to locate tohost in $elf\n";

  my $temp_dir = tempdir(CLEANUP => 1);
  my $monitor_socket = catfile($temp_dir, 'monitor.sock');
  my $qemu_stdout = catfile($temp_dir, 'qemu.stdout');
  my $qemu_stderr = catfile($temp_dir, 'qemu.stderr');

  open my $stdout_fh, '>', $qemu_stdout
    or die "failed to open $qemu_stdout: $!";
  open my $stderr_fh, '>', $qemu_stderr
    or die "failed to open $qemu_stderr: $!";

  my $qemu_pid = fork();
  die "failed to fork for $qemu_bin: $!" if !defined $qemu_pid;

  if ($qemu_pid == 0) {
    open STDOUT, '>&', $stdout_fh or die "failed to redirect stdout: $!";
    open STDERR, '>&', $stderr_fh or die "failed to redirect stderr: $!";
    exec(
      $qemu_bin,
      '-machine',
      'virt',
      '-bios',
      'none',
      '-nographic',
      '-kernel',
      $elf,
      '-monitor',
      "unix:$monitor_socket,server,nowait",
      '-serial',
      'none',
      '-display',
      'none',
    );
    die "failed to exec $qemu_bin: $!";
  }

  close $stdout_fh;
  close $stderr_fh;

  my $cleanup = sub {
    if (kill 0, $qemu_pid) {
      kill 'TERM', $qemu_pid;
    }
    waitpid($qemu_pid, 0);
  };

  my $ok = eval {
    my $socket_ready = 0;
    for (1 .. $socket_attempts) {
      if (-S $monitor_socket) {
        $socket_ready = 1;
        last;
      }
      last if !child_alive($qemu_pid);
      short_sleep($poll_interval);
    }

    if (!$socket_ready) {
      die "qemu monitor socket was not ready for rv32ui-p-$short_name\n" .
        slurp_file($qemu_stderr);
    }

    my $tohost_value = '0x00000000';
    for (1 .. $poll_attempts) {
      if (!child_alive($qemu_pid)) {
        die "qemu exited early while running rv32ui-p-$short_name\n" .
          slurp_file($qemu_stderr);
      }

      my $raw_value = read_hmp_u32($monitor_socket, $tohost);
      if (defined $raw_value) {
        $tohost_value = "0x$raw_value";
      }
      last if $tohost_value ne '0x00000000';
      short_sleep($poll_interval);
    }

    if ($tohost_value eq '0x00000000') {
      die "timeout waiting for tohost in rv32ui-p-$short_name\n" .
        read_register_snapshot($monitor_socket) .
        slurp_file($qemu_stderr);
    }

    if ($tohost_value ne '0x00000001') {
      die "rv32ui-p-$short_name reported failure through tohost=$tohost_value\n" .
        read_register_snapshot($monitor_socket);
    }

    say "PASS rv32ui-p-$short_name (tohost=$tohost_value)";
    return 1;
  };
  my $error = $@;

  $cleanup->();
  die $error if !$ok;
}

my @tests = @ARGV
  ? map { normalize_test_name($_) } @ARGV
  : load_default_tests();

die "no tests selected\n" if !@tests;

run_one($_) for @tests;
