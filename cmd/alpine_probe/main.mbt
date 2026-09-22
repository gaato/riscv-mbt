// Native Alpine boot probe. This command is a host-side integration harness
// for checking Linux/OpenSBI/Alpine progress without involving the browser UI.

///|
let opensbi_path = "_build/opensbi-riscv64-fw_dynamic.bin"

///|
// Kernel, DTB, and initrd paths intentionally point at generated `_build`
// artifacts. The probe is an integration harness; artifact freshness is a
// caller/build-script responsibility, not something hidden inside this binary.
let kernel_path = "_build/linux-kernel-riscv64"

///|
let dtb_path = "_build/minimal-alpine.dtb"

///|
let virtio_dtb_path = "_build/minimal-alpine-virtio.dtb"

///|
let auto_root_virtio_dtb_path = "_build/minimal-alpine-virtio-auto-root.dtb"

///|
let initrd_path = "_build/alpine-initramfs-riscv64.cpio"

///|
let auto_root_initrd_path = "_build/alpine-initramfs-riscv64-auto-root.cpio"

///|
let rootfs_image_path = "_build/alpine-rootfs-riscv64.ext4"

///|
// The initrd address must stay in sync with scripts/build-alpine-initramfs.sh
// so the DTB's linux,initrd-start/end values describe the bytes loaded below.
let initrd_addr : UInt64 = 0x84000000U.to_uint64()

///|
// OpenSBI fw_dynamic reads its next-stage handoff structure from this address;
// the runner helper writes the structure after firmware/kernel loading.
let fw_dynamic_info_addr : UInt64 = 0x80100000U.to_uint64()

///|
// Alpine's riscv64 Linux Image is loaded at the standard 2 MiB-aligned virt
// kernel address expected by the RISC-V Linux boot ABI.
let kernel_entry_addr : UInt64 = 0x80200000U.to_uint64()

///|
let alpine_marker = "riscv-mbt Alpine initramfs ready"

///|
let alpine_shell_marker = "riscv-mbt Alpine shell alive"

///|
let alpine_shell_prompt_marker = "/ #"

///|
let alpine_post_init_marker = "post-init-ready"

///|
let alpine_auto_root_marker = "riscv-mbt Alpine auto-root ready"

///|
let initramfs_unpack_marker_old = "Trying to unpack rootfs image as initramfs"

///|
let initramfs_unpack_marker_new = "Unpacking initramfs..."

///|
let run_init_marker = "Run /init as init process"

///|
let free_initmem_marker = "Freeing unused kernel image"

///|
let free_initrd_marker = "Freeing initrd memory"

///|
let rootfs_marker = "rootfs"

///|
let default_max_steps = 300000000

///|
// UART polling is deliberately coarse because full-rootfs boot dominates probe
// time. Every marker is also checked against the final full buffer before exit.
let drain_interval = 1000000

///|
// Once a rootfs-side command has been injected, a missing marker is usually a
// command/runtime problem rather than more boot progress. Break earlier so
// exploratory diagnostics do not burn the full `xlong` budget. The CLI can
// override this default for deliberately tiny failure probes.
let default_post_init_command_step_budget = 150000000

///|
// Interactive console commands run after auto-root handoff, so a timeout here
// means "this shell command did not settle" rather than "Linux did not boot".
let default_interactive_command_step_budget = 30000000

///|
let csr_sstatus = 0x100

///|
let csr_sie = 0x104

///|
let csr_sepc = 0x141

///|
let csr_scause = 0x142

///|
let csr_stval = 0x143

///|
let csr_sip = 0x144

///|
let csr_satp = 0x180

///|
fn hex(value : UInt64) -> String {
  "0x" + value.to_string(radix=16)
}

///|
fn privilege_name(mode : @riscv.PrivilegeMode) -> String {
  match mode {
    User => "User"
    Supervisor => "Supervisor"
    Machine => "Machine"
  }
}

///|
async fn read_binary(path : String) -> Bytes {
  @fs.read_file(path).binary() catch {
    _ => abort("missing artifact: " + path)
  }
}

///|
async fn write_binary(path : String, bytes : Bytes) -> Unit {
  // Used by persistence probes to materialize the virtio-blk backing image
  // after guest writes. write_at avoids depending on stream cursor state.
  let file = @fs.create(path, permission=0o644)
  defer file.close()
  file.write_at(bytes[:], position=0L)
}

///|
fn parse_max_steps(args : Array[String]) -> Int {
  // Keep named budgets stable so task docs can cite runs reproducibly. `xlong`
  // is the current full-rootfs budget; `xxlong` is retained for older docs.
  if args.length() >= 2 {
    match args[1] {
      "short" => 19000000
      "medium" => 100000000
      "long" => default_max_steps
      "xxlong" => 600000000
      "xlong" => 1000000000
      _ => default_max_steps
    }
  } else {
    default_max_steps
  }
}

///|
fn parse_arg_value(args : Array[String], flag : String) -> String? {
  if args.length() < 2 {
    return None
  }
  for index in 0..<(args.length() - 1) {
    if args[index] == flag {
      return Some(args[index + 1])
    }
  }
  None
}

///|
fn parse_positive_int_arg(
  args : Array[String],
  flag : String,
  default_value : Int,
) -> Int {
  match parse_arg_value(args, flag) {
    Some(text) => {
      let parsed = @string.parse_int(text) catch {
        _ => abort(flag + " must be a positive integer")
      }
      if parsed <= 0 {
        abort(flag + " must be a positive integer")
      }
      parsed
    }
    None => default_value
  }
}

///|
fn parse_flag(args : Array[String], flag : String) -> Bool {
  args.any(fn(arg) { arg == flag })
}

///|
fn trim_console_line(line : String) -> String {
  line.trim_end(chars="\n").trim_end(chars="\r").to_owned()
}

///|
fn format_runner_stats(runner : @riscv.Runner, steps : Int) -> String {
  "[riscv-mbt stats] steps=\{steps} pc=\{hex(runner.pc_u64())} privilege=\{privilege_name(runner.privilege_mode())} " +
  "decode=\{runner.decode_cache_hit_count()}/\{runner.decode_cache_miss_count()} translate=\{runner.translate_cache_hit_count()}/\{runner.translate_cache_miss_count()} " +
  "virtio=\{runner.virtio_blk_read_request_count()}r/\{runner.virtio_blk_write_request_count()}w"
}

///|
fn format_post_init_command_trace(
  start_steps : Array[Int],
  marker_steps : Array[Int],
) -> String {
  if start_steps.length() == 0 {
    return ""
  }
  let mut trace = ""
  for index in 0..<start_steps.length() {
    if index > 0 {
      trace = trace + "; "
    }
    trace = trace +
      "cmd" +
      (index + 1).to_string() +
      ":start=" +
      start_steps[index].to_string()
    if index < marker_steps.length() {
      let marker_step = marker_steps[index]
      trace = trace +
        ",marker=" +
        marker_step.to_string() +
        ",duration=" +
        (marker_step - start_steps[index]).to_string()
    } else {
      trace = trace + ",marker=?,duration=?"
    }
  }
  trace
}

///|
struct InteractiveConsoleResult {
  steps : Int
  last_output_steps : Int
  outcome : String
  trapped : Bool
  output : String
}

///|
async fn run_interactive_console(
  runner : @riscv.Runner,
  start_steps : Int,
  initial_output : String,
  command_step_budget : Int,
) -> InteractiveConsoleResult {
  let mut steps = start_steps
  let mut last_output_steps = start_steps
  let mut outcome = "interactive-console"
  let mut output = initial_output
  @stdio.stdout.write(
    "\n[riscv-mbt] interactive console ready. Type shell commands, :stats, or :quit.\n",
  )
  @stdio.stdout.write(format_runner_stats(runner, steps) + "\n")
  @stdio.stdout.write("riscv-mbt> ")
  while @stdio.stdin.read_until("\n") is Some(line) {
    let command = trim_console_line(line)
    if command == ":quit" || command == ":q" {
      outcome = "interactive-console-quit"
      break
    }
    if command == ":stats" {
      @stdio.stdout.write(format_runner_stats(runner, steps) + "\n")
      @stdio.stdout.write("riscv-mbt> ")
      continue
    }
    runner.uart_push_input(command + "\r\n")
    let command_start_steps = steps
    let mut saw_output = false
    let mut quiet_drains = 0
    for ;; {
      if steps - command_start_steps >= command_step_budget {
        outcome = "interactive-command-timeout"
        @stdio.stdout.write(
          "\n[riscv-mbt] command step budget reached after \{command_step_budget} steps\n",
        )
        break
      }
      match runner.step() {
        Running => {
          steps = steps + 1
          if steps % drain_interval == 0 {
            let partial = runner.uart_drain()
            if partial.length() > 0 {
              output = output + partial
              last_output_steps = steps
              saw_output = true
              quiet_drains = 0
              @stdio.stdout.write(partial)
            } else if saw_output {
              quiet_drains += 1
              if quiet_drains >= 2 {
                break
              }
            }
          }
        }
        Trap(info) => {
          outcome = "trap pc=" +
            info.faulting_pc.to_string() +
            " tval=" +
            info.trap_value.to_string()
          @stdio.stdout.write("\n[riscv-mbt] " + outcome + "\n")
          return { steps, last_output_steps, outcome, trapped: true, output, }
        }
      }
    }
    @stdio.stdout.write("\n" + format_runner_stats(runner, steps) + "\n")
    @stdio.stdout.write("riscv-mbt> ")
  }
  let tail = runner.uart_drain()
  if tail.length() > 0 {
    output = output + tail
    last_output_steps = steps
    @stdio.stdout.write(tail)
  }
  { steps, last_output_steps, outcome, trapped: false, output, }
}

///|
fn select_dtb_path(
  args : Array[String],
  uses_auto_root_artifacts : Bool,
  uses_virtio_rootfs : Bool,
) -> String {
  match parse_arg_value(args, "--dtb") {
    Some(path) => path
    None =>
      if uses_auto_root_artifacts {
        auto_root_virtio_dtb_path
      } else if uses_virtio_rootfs {
        virtio_dtb_path
      } else {
        dtb_path
      }
  }
}

///|
fn select_initrd_path(
  args : Array[String],
  uses_auto_root_artifacts : Bool,
) -> String {
  match parse_arg_value(args, "--initrd") {
    Some(path) => path
    None =>
      if uses_auto_root_artifacts {
        auto_root_initrd_path
      } else {
        initrd_path
      }
  }
}

///|
fn alpine_functional_smoke_command() -> String {
  // Keep this close to the browser functional smoke so console/native and
  // browser evidence prove the same early-userspace behavior.
  "mount -t proc proc /proc && " +
  "mount -t sysfs sysfs /sys && " +
  "echo file-ok > /tmp/riscv-mbt-file && " +
  "cat /tmp/riscv-mbt-file && " +
  "mkdir -p /tmp/riscv-mbt-dir && " +
  "/bin/sh -c 'echo pipe-ok' | grep pipe-ok && " +
  "uname -m && " +
  "cat /proc/cpuinfo > /tmp/riscv-mbt-cpuinfo && " +
  "printf '\\154\\151\\156\\165\\170\\055\\146\\165\\156\\143\\164\\151\\157\\156\\141\\154\\055\\157\\153\\012'"
}

///|
fn alpine_rootfs_smoke_command() -> String {
  "modprobe virtio_mmio && " +
  "modprobe virtio_blk && " +
  "modprobe ext4 && " +
  "mount -t proc proc /proc && " +
  "mount -t sysfs sysfs /sys && " +
  "mount -t devtmpfs devtmpfs /dev && " +
  "mkdir -p /mnt/root && " +
  "mount -t ext4 -o ro /dev/vda /mnt/root && " +
  "test -x /mnt/root/bin/busybox && " +
  "/mnt/root/bin/busybox printf '\\162\\157\\157\\164\\146\\163\\055\\155\\157\\165\\156\\164\\055\\157\\153\\012'"
}

///|
fn alpine_switch_root_smoke_command() -> String {
  "modprobe virtio_mmio && " +
  "modprobe virtio_blk && " +
  "modprobe ext4 && " +
  "mount -t devtmpfs devtmpfs /dev && " +
  "mkdir -p /mnt/root && " +
  "mount -t ext4 -o ro /dev/vda /mnt/root && " +
  "mount -t proc proc /mnt/root/proc && " +
  "mount -t sysfs sysfs /mnt/root/sys && " +
  "mount -t devtmpfs devtmpfs /mnt/root/dev && " +
  "exec switch_root /mnt/root /bin/busybox sh -c " +
  "\"printf '\\163\\167\\151\\164\\143\\150\\055\\162\\157\\157\\164\\055\\157\\153\\012'; exec /bin/sh\""
}

///|
fn alpine_init_smoke_command() -> String {
  "modprobe virtio_mmio && " +
  "modprobe virtio_blk && " +
  "modprobe ext4 && " +
  "mount -t devtmpfs devtmpfs /dev && " +
  "mkdir -p /mnt/root && " +
  "mount -t ext4 /dev/vda /mnt/root && " +
  "mount -t proc proc /mnt/root/proc && " +
  "mount -t sysfs sysfs /mnt/root/sys && " +
  "mount -t devtmpfs devtmpfs /mnt/root/dev && " +
  "mount -t tmpfs tmpfs /mnt/root/run && " +
  "mount -t tmpfs tmpfs /mnt/root/tmp && " +
  "exec switch_root /mnt/root /sbin/init"
}

///|
fn alpine_post_init_smoke_command() -> String {
  "(mount -t proc proc /proc 2>/dev/null || true) && " +
  "(mount -t sysfs sysfs /sys 2>/dev/null || true) && " +
  "echo post-file-ok > /tmp/riscv-mbt-post-file && " +
  "cat /tmp/riscv-mbt-post-file && " +
  "echo rootfs-write-ok > /root/riscv-mbt-rootfs-write && " +
  "cat /root/riscv-mbt-rootfs-write && " +
  "sync && " +
  "uname -m && " +
  "test -r /proc/mounts && " +
  "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\146\\165\\156\\143\\164\\151\\157\\156\\141\\154\\055\\157\\153\\012'"
}

///|
fn alpine_post_init_session_commands() -> Array[String] {
  [
    "printf 'alpha\\n' > /root/riscv-mbt-session && " +
    "cat /root/riscv-mbt-session && " +
    "printf '\\163\\145\\163\\163\\151\\157\\156\\055\\163\\164\\145\\160\\061\\055\\157\\153\\012'",
    "printf 'beta\\n' >> /root/riscv-mbt-session && " +
    "grep beta /root/riscv-mbt-session && " +
    "wc -l /root/riscv-mbt-session && " +
    "printf '\\163\\145\\163\\163\\151\\157\\156\\055\\163\\164\\145\\160\\062\\055\\157\\153\\012'",
    "mkdir -p /root/riscv-mbt-session-dir && " +
    "cp /root/riscv-mbt-session /root/riscv-mbt-session-dir/copy && " +
    "ls /root/riscv-mbt-session-dir | grep copy && " +
    "sync && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\163\\145\\163\\163\\151\\157\\156\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_session_markers() -> Array[String] {
  ["session-step1-ok", "session-step2-ok", "post-init-session-ok"]
}

///|
fn alpine_post_init_busybox_commands() -> Array[String] {
  [
    "busybox --list > /root/riscv-mbt-applets && " +
    "grep -x awk /root/riscv-mbt-applets && " +
    "grep -x sed /root/riscv-mbt-applets && " +
    "grep -x sort /root/riscv-mbt-applets && " +
    "grep -x xargs /root/riscv-mbt-applets && " +
    "wc -l /root/riscv-mbt-applets && " +
    "printf '\\142\\165\\163\\171\\142\\157\\170\\055\\154\\151\\163\\164\\055\\157\\153\\012'",
    "printf 'z:3\\na:1\\na:1\\n' > /root/riscv-mbt-text && " +
    "sort /root/riscv-mbt-text | uniq > /root/riscv-mbt-sorted && " +
    "sed -n '1p' /root/riscv-mbt-sorted | cut -d: -f1 | tr a-z A-Z && " +
    "awk -F: '{s += $2} END {print s}' /root/riscv-mbt-sorted && " +
    "printf '\\142\\165\\163\\171\\142\\157\\170\\055\\164\\145\\170\\164\\055\\157\\153\\012'",
    "touch /root/riscv-mbt-touch && " +
    "chmod 755 /root/riscv-mbt-touch && " +
    "test -x /root/riscv-mbt-touch && " +
    "ln -sf /root/riscv-mbt-touch /root/riscv-mbt-link && " +
    "readlink /root/riscv-mbt-link | grep riscv-mbt-touch && " +
    "find /root -name riscv-mbt-touch | grep riscv-mbt-touch && " +
    "printf '\\142\\165\\163\\171\\142\\157\\170\\055\\146\\163\\055\\157\\153\\012'",
    "dd if=/root/riscv-mbt-text of=/root/riscv-mbt-dd bs=1 count=8 && " +
    "head -n 1 /root/riscv-mbt-text && " +
    "tail -n 1 /root/riscv-mbt-text && " +
    "printf 'riscv-mbt-xargs\\n' | xargs echo && " +
    "env | grep PATH && " +
    "ps | head -n 1 && " +
    "date >/root/riscv-mbt-date && " +
    "sleep 0 && " +
    "sync && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\142\\165\\163\\171\\142\\157\\170\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_busybox_markers() -> Array[String] {
  [
    "busybox-list-ok", "busybox-text-ok", "busybox-fs-ok", "post-init-busybox-ok",
  ]
}

///|
fn alpine_post_init_apk_commands() -> Array[String] {
  // Dynamic apk diagnostic. The generated rootfs may route normal `/sbin/apk`
  // use through apk.static for practical usability, while keeping Alpine's
  // dynamic binary as `/sbin/apk.dynamic` for loader/library-read work.
  [
    "test -x /sbin/apk.dynamic && " +
    "test -x /lib/ld-musl-riscv64.so.1 && " +
    "test -x /usr/lib/libapk.so.3.0.0 && " +
    "test -e /usr/lib/libz.so.1 && " +
    "test -r /lib/apk/db/installed && " +
    "printf '\\141\\160\\153\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/lib/ld-musl-riscv64.so.1 --list /sbin/apk.dynamic && " +
    "printf '\\141\\160\\153\\055\\154\\157\\141\\144\\145\\162\\055\\157\\153\\012'",
    "test -x /sbin/apk.dynamic && " +
    "/sbin/apk.dynamic --version && " +
    "printf '\\141\\160\\153\\055\\166\\145\\162\\163\\151\\157\\156\\055\\157\\153\\012'",
    "/sbin/apk.dynamic info -e busybox && " +
    "/sbin/apk.dynamic info | head -n 5 && " +
    "/sbin/apk.dynamic info | grep '^busybox$' && " +
    "printf '\\141\\160\\153\\055\\144\\142\\055\\157\\153\\012'",
    "/sbin/apk.dynamic info -L busybox | grep '/bin/busybox' && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\141\\160\\153\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_markers() -> Array[String] {
  [
    "apk-files-ok", "apk-loader-ok", "apk-version-ok", "apk-db-ok", "post-init-apk-ok",
  ]
}

///|
fn alpine_post_init_apk_static_commands() -> Array[String] {
  // Static apk is the practical package-database smoke. It also checks the
  // standard `/sbin/apk` command when the generated rootfs maps it to the
  // static apk copy.
  [
    "test -x /sbin/apk && " +
    "test -x /sbin/apk.static && " +
    "test -r /lib/apk/db/installed && " +
    "printf '\\141\\160\\153\\055\\163\\164\\141\\164\\151\\143\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --version && " +
    "/sbin/apk.static --version && " +
    "printf '\\141\\160\\153\\055\\163\\164\\141\\164\\151\\143\\055\\166\\145\\162\\163\\151\\157\\156\\055\\157\\153\\012'",
    "/sbin/apk info -e busybox && " +
    "/sbin/apk info | head -n 5 && " +
    "/sbin/apk info | grep '^busybox$' && " +
    "printf '\\141\\160\\153\\055\\163\\164\\141\\164\\151\\143\\055\\144\\142\\055\\157\\153\\012'",
    "/sbin/apk info -L busybox | grep '^bin/busybox$' && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\141\\160\\153\\055\\163\\164\\141\\164\\151\\143\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_static_markers() -> Array[String] {
  [
    "apk-static-files-ok", "apk-static-version-ok", "apk-static-db-ok", "post-init-apk-static-ok",
  ]
}

///|
fn alpine_post_init_apk_install_commands() -> Array[String] {
  // Offline package installation proof. The rootfs builder places `ddate.apk`
  // under `/root/riscv-mbt-apks`; installing that local file avoids depending
  // on virtio-net while still exercising apk's add path and rootfs mutation.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/ddate.apk && " +
    "! test -x /usr/bin/ddate && " +
    "printf '\\141\\160\\153\\055\\151\\156\\163\\164\\141\\154\\154\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --force-non-repository add /root/riscv-mbt-apks/ddate.apk && " +
    "printf '\\141\\160\\153\\055\\151\\156\\163\\164\\141\\154\\154\\055\\141\\144\\144\\055\\157\\153\\012'",
    "/sbin/apk info -e ddate && " +
    "test -x /usr/bin/ddate && " +
    "ddate > /root/riscv-mbt-ddate && " +
    "test -s /root/riscv-mbt-ddate && " +
    "cat /root/riscv-mbt-ddate && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\141\\160\\153\\055\\151\\156\\163\\164\\141\\154\\154\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_install_markers() -> Array[String] {
  ["apk-install-files-ok", "apk-install-add-ok", "post-init-apk-install-ok"]
}

///|
fn alpine_post_init_apk_local_repo_commands() -> Array[String] {
  // Local repository proof. This is closer to `apk add <name>` than the file
  // path smoke: apk resolves `ddate` through the rootfs-side APKINDEX while
  // staying offline and using the package file copied into the same directory.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/APKINDEX.tar.gz && " +
    "test -r /root/riscv-mbt-apks/ddate.apk && " +
    "! test -x /usr/bin/ddate && " +
    "printf '\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\162\\145\\160\\157\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --repository /root/riscv-mbt-apks add ddate && " +
    "printf '\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\162\\145\\160\\157\\055\\141\\144\\144\\055\\157\\153\\012'",
    "/sbin/apk info -e ddate && " +
    "test -x /usr/bin/ddate && " +
    "ddate > /root/riscv-mbt-local-repo-ddate && " +
    "test -s /root/riscv-mbt-local-repo-ddate && " +
    "cat /root/riscv-mbt-local-repo-ddate && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\162\\145\\160\\157\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_local_repo_markers() -> Array[String] {
  [
    "apk-local-repo-files-ok", "apk-local-repo-add-ok", "post-init-apk-local-repo-ok",
  ]
}

///|
fn alpine_post_init_apk_local_deps_commands() -> Array[String] {
  // Dependency-resolution proof. The rootfs builder includes `iputils` plus
  // the packages that satisfy its APKINDEX dependencies, so apk must resolve a
  // normal package name and install subpackages/libraries from the local repo.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/APKINDEX.tar.gz && " +
    "ls /root/riscv-mbt-apks/iputils-*.apk && " +
    "ls /root/riscv-mbt-apks/iputils-ping-*.apk && " +
    "ls /root/riscv-mbt-apks/libcap2-*.apk && " +
    "! /sbin/apk info -e iputils && " +
    "! /sbin/apk info -e iputils-ping && " +
    "printf '\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\144\\145\\160\\163\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --repository /root/riscv-mbt-apks add iputils && " +
    "printf '\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\144\\145\\160\\163\\055\\141\\144\\144\\055\\157\\153\\012'",
    "/sbin/apk info -e iputils && " +
    "/sbin/apk info -e iputils-ping && " +
    "/sbin/apk info -e libcap2 && " +
    "/sbin/apk info -L iputils-ping | grep '^bin/ping$' && " +
    "/bin/ping -V && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\141\\160\\153\\055\\154\\157\\143\\141\\154\\055\\144\\145\\160\\163\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_local_deps_markers() -> Array[String] {
  [
    "apk-local-deps-files-ok", "apk-local-deps-add-ok", "post-init-apk-local-deps-ok",
  ]
}

///|
fn alpine_post_init_iputils_loopback_commands() -> Array[String] {
  // Package-runtime proof. Dependency resolution alone only proves that apk can
  // install files; this command sequence proves an installed iputils binary can
  // exercise the guest kernel's loopback network path.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/APKINDEX.tar.gz && " +
    "ls /root/riscv-mbt-apks/iputils-*.apk && " +
    "ls /root/riscv-mbt-apks/iputils-ping-*.apk && " +
    "printf '\\151\\160\\165\\164\\151\\154\\163\\055\\154\\157\\157\\160\\142\\141\\143\\153\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --repository /root/riscv-mbt-apks add iputils && " +
    "/sbin/apk info -e iputils-ping && " +
    "test -x /bin/ping && " +
    "printf '\\151\\160\\165\\164\\151\\154\\163\\055\\154\\157\\157\\160\\142\\141\\143\\153\\055\\141\\144\\144\\055\\157\\153\\012'",
    "ifconfig lo up && " +
    "ifconfig lo | grep '127.0.0.1' && " +
    "printf '\\151\\160\\165\\164\\151\\154\\163\\055\\154\\157\\157\\160\\142\\141\\143\\153\\055\\154\\157\\055\\157\\153\\012'",
    "/bin/ping -c 1 -W 1 127.0.0.1 && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\151\\160\\165\\164\\151\\154\\163\\055\\154\\157\\157\\160\\142\\141\\143\\153\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_iputils_loopback_markers() -> Array[String] {
  [
    "iputils-loopback-files-ok", "iputils-loopback-add-ok", "iputils-loopback-lo-ok",
    "post-init-iputils-loopback-ok",
  ]
}

///|
fn alpine_post_init_shell_commands() -> Array[String] {
  // This is intentionally about shell behavior rather than individual applets:
  // script execution from the rootfs, env/argv propagation, background jobs,
  // wait, exit-status control flow, subshells, and redirection.
  [
    "printf '#!/bin/sh\\nset -e\\necho script-arg:$1\\necho script-env:$RISCV_MBT_SHELL\\nprintf \"script-output\\\\n\" > /root/riscv-mbt-script-output\\n' > /root/riscv-mbt-script && " +
    "chmod 755 /root/riscv-mbt-script && " +
    "RISCV_MBT_SHELL=ok /root/riscv-mbt-script arg1 | tee /root/riscv-mbt-script-log && " +
    "grep script-arg:arg1 /root/riscv-mbt-script-log && " +
    "grep script-env:ok /root/riscv-mbt-script-log && " +
    "grep script-output /root/riscv-mbt-script-output && " +
    "printf '\\163\\150\\145\\154\\154\\055\\163\\143\\162\\151\\160\\164\\055\\157\\153\\012'",
    "(sleep 0; printf 'background-ok\\n' > /root/riscv-mbt-bg) & " +
    "pid=$! && wait $pid && " +
    "cat /root/riscv-mbt-bg && " +
    "false || printf 'exit-status-ok\\n' && " +
    "printf '\\163\\150\\145\\154\\154\\055\\152\\157\\142\\055\\157\\153\\012'",
    "(printf 'subshell-ok\\n') > /root/riscv-mbt-shell-redir && " +
    "printf 'append-ok\\n' >> /root/riscv-mbt-shell-redir && " +
    "grep subshell-ok /root/riscv-mbt-shell-redir && " +
    "grep append-ok /root/riscv-mbt-shell-redir && " +
    "sync && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\163\\150\\145\\154\\154\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_shell_markers() -> Array[String] {
  ["shell-script-ok", "shell-job-ok", "post-init-shell-ok"]
}

///|
fn alpine_post_init_system_commands() -> Array[String] {
  // This smoke exercises ordinary process and filesystem administration
  // surfaces that are broader than shell syntax but narrower than package
  // management: /proc visibility, PID 1, identity, working directories,
  // permissions, and create/move/remove behavior on the rootfs.
  [
    // PID 1 and identity: prove the switched root has a procfs view and that
    // we are still driving the root-owned validation shell.
    "test -d /proc/1 && " +
    "readlink /proc/1/exe | grep busybox && " +
    "ps | grep '[i]nit' && " +
    "id && " +
    "id -u | grep '^0$' && " +
    "printf '\\163\\171\\163\\164\\145\\155\\055\\160\\162\\157\\143\\055\\157\\153\\012'",
    // Rootfs file management: create nested directories, move a file, and read
    // the moved content back before cleanup.
    "pwd && " +
    "cd /root && " +
    "mkdir -p riscv-mbt-system/a && " +
    "printf 'system-file\\n' > riscv-mbt-system/a/source && " +
    "mv riscv-mbt-system/a/source riscv-mbt-system/a/moved && " +
    "test -f riscv-mbt-system/a/moved && " +
    "grep system-file riscv-mbt-system/a/moved && " +
    "printf '\\163\\171\\163\\164\\145\\155\\055\\146\\163\\055\\157\\153\\012'",
    // Permission and cleanup: umask should affect rootfs file mode, and rm/rmdir
    // should leave no validation directory behind.
    "umask 077 && " +
    "printf 'secret\\n' > /root/riscv-mbt-system/secret && " +
    "ls -l /root/riscv-mbt-system/secret | grep '^-rw-------' && " +
    "rm /root/riscv-mbt-system/secret && " +
    "rm /root/riscv-mbt-system/a/moved && " +
    "rmdir /root/riscv-mbt-system/a && " +
    "rmdir /root/riscv-mbt-system && " +
    "sync && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\163\\171\\163\\164\\145\\155\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_system_markers() -> Array[String] {
  ["system-proc-ok", "system-fs-ok", "post-init-system-ok"]
}

///|
fn alpine_post_init_service_commands() -> Array[String] {
  // Service-style workflow for the current BusyBox-init rootfs. This does not
  // pretend OpenRC is present; it proves the known-good rootfs can create,
  // start, observe, and stop a simple init.d-shaped service script.
  [
    "mkdir -p /etc/init.d /run && " +
    "printf '#!/bin/sh\\ncase \"$1\" in\\nstart)\\n  printf service-started\\\\n > /run/riscv-mbt-service.log\\n  sleep 1000 &\\n  echo $! > /run/riscv-mbt-service.pid\\n  ;;\\nstatus)\\n  test -s /run/riscv-mbt-service.pid && kill -0 $(cat /run/riscv-mbt-service.pid)\\n  ;;\\nstop)\\n  if test -s /run/riscv-mbt-service.pid; then kill $(cat /run/riscv-mbt-service.pid); fi\\n  rm -f /run/riscv-mbt-service.pid\\n  ;;\\n*) exit 2 ;;\\nesac\\n' > /etc/init.d/riscv-mbt-service && " +
    "chmod 755 /etc/init.d/riscv-mbt-service && " +
    "test -x /etc/init.d/riscv-mbt-service && " +
    "printf '\\163\\145\\162\\166\\151\\143\\145\\055\\163\\143\\162\\151\\160\\164\\055\\157\\153\\012'",
    "/etc/init.d/riscv-mbt-service start && " +
    "test -s /run/riscv-mbt-service.pid && " +
    "/etc/init.d/riscv-mbt-service status && " +
    "test -s /run/riscv-mbt-service.log && " +
    "grep service-started /run/riscv-mbt-service.log && " +
    "printf '\\163\\145\\162\\166\\151\\143\\145\\055\\163\\164\\141\\162\\164\\055\\157\\153\\012'",
    "/etc/init.d/riscv-mbt-service stop && " +
    "! test -e /run/riscv-mbt-service.pid && " +
    "rm -f /etc/init.d/riscv-mbt-service /run/riscv-mbt-service.log && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\163\\145\\162\\166\\151\\143\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_service_markers() -> Array[String] {
  ["service-script-ok", "service-start-ok", "post-init-service-ok"]
}

///|
fn alpine_post_init_service_persistence_write_commands() -> Array[String] {
  // First half of service persistence: put an init.d-shaped script on the
  // rootfs, sync it, then let the host save the mutated virtio-blk image.
  [
    "mkdir -p /etc/init.d /run && " +
    "printf '#!/bin/sh\\ncase \"$1\" in\\nstart)\\n  printf service-started\\\\n > /run/riscv-mbt-service.log\\n  sleep 1000 &\\n  echo $! > /run/riscv-mbt-service.pid\\n  ;;\\nstatus)\\n  test -s /run/riscv-mbt-service.pid && kill -0 $(cat /run/riscv-mbt-service.pid)\\n  ;;\\nstop)\\n  if test -s /run/riscv-mbt-service.pid; then kill $(cat /run/riscv-mbt-service.pid); fi\\n  rm -f /run/riscv-mbt-service.pid\\n  ;;\\n*) exit 2 ;;\\nesac\\n' > /etc/init.d/riscv-mbt-service && " +
    "chmod 755 /etc/init.d/riscv-mbt-service && " +
    "test -x /etc/init.d/riscv-mbt-service && " +
    "printf '\\163\\145\\162\\166\\151\\143\\145\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "grep service-started /etc/init.d/riscv-mbt-service && " +
    "sync && " +
    "printf '\\163\\145\\162\\166\\151\\143\\145\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\167\\162\\151\\164\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_service_persistence_write_markers() -> Array[String] {
  ["service-persistence-files-ok", "service-persistence-write-ok"]
}

///|
fn alpine_post_init_service_persistence_read_command() -> String {
  // Second half: boot from the host-saved image and run the persisted service
  // script without recreating it in this emulator run.
  "test -x /etc/init.d/riscv-mbt-service && " +
  "grep service-started /etc/init.d/riscv-mbt-service && " +
  "/etc/init.d/riscv-mbt-service start && " +
  "test -s /run/riscv-mbt-service.pid && " +
  "/etc/init.d/riscv-mbt-service status && " +
  "test -s /run/riscv-mbt-service.log && " +
  "grep service-started /run/riscv-mbt-service.log && " +
  "/etc/init.d/riscv-mbt-service stop && " +
  "! test -e /run/riscv-mbt-service.pid && " +
  "rm -f /run/riscv-mbt-service.log && " +
  "printf '\\163\\145\\162\\166\\151\\143\\145\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\162\\145\\141\\144\\055\\157\\153\\012'"
}

///|
fn alpine_post_init_openrc_install_commands() -> Array[String] {
  // OpenRC is not the default boot path. This smoke proves an explicitly built
  // local repository can install OpenRC userspace without changing the known
  // good BusyBox-init baseline.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/APKINDEX.tar.gz && " +
    "ls /root/riscv-mbt-apks/openrc-*.apk && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --repository /root/riscv-mbt-apks add openrc && " +
    "/sbin/apk info -e openrc && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\141\\144\\144\\055\\157\\153\\012'",
    "test -x /sbin/openrc && " +
    "test -x /bin/rc-status && " +
    "test -x /sbin/rc-update && " +
    "/sbin/openrc --version && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\143\\157\\155\\155\\141\\156\\144\\163\\055\\157\\153\\012'",
    "/sbin/rc-update show && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\157\\160\\145\\156\\162\\143\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_openrc_install_markers() -> Array[String] {
  [
    "openrc-files-ok", "openrc-add-ok", "openrc-commands-ok", "post-init-openrc-ok",
  ]
}

///|
fn alpine_post_init_openrc_surface_commands() -> Array[String] {
  // For images where the OpenRC package payload was prepared by the rootfs
  // builder. This keeps runtime probes focused on OpenRC usability instead of
  // spending each run reinstalling service-manager packages.
  [
    "test -x /sbin/openrc && " +
    "test -x /bin/rc-status && " +
    "test -x /sbin/rc-update && " +
    "test -d /etc/init.d && " +
    "test -r /etc/rc.conf && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\163\\165\\162\\146\\141\\143\\145\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/openrc --version && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\163\\165\\162\\146\\141\\143\\145\\055\\166\\145\\162\\163\\151\\157\\156\\055\\157\\153\\012'",
    "/sbin/rc-update show && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\157\\160\\145\\156\\162\\143\\055\\163\\165\\162\\146\\141\\143\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_openrc_surface_markers() -> Array[String] {
  [
    "openrc-surface-files-ok", "openrc-surface-version-ok", "post-init-openrc-surface-ok",
  ]
}

///|
fn alpine_post_init_openrc_service_commands() -> Array[String] {
  // Exercise OpenRC's service command surface on a prepared image. This does
  // not claim OpenRC is PID 1; it proves the installed OpenRC tooling can
  // manage an openrc-run service script from the current BusyBox-init shell.
  [
    "mkdir -p /run/openrc /etc/init.d && " +
    "touch /run/openrc/softlevel && " +
    "printf '#!/sbin/openrc-run\\ndescription=\"riscv-mbt OpenRC smoke\"\\npidfile=\"/run/riscv-mbt-openrc-service.pid\"\\nstart() { sleep 1000 & echo $! > \"$pidfile\"; }\\nstatus() { test -s \"$pidfile\" && kill -0 $(cat \"$pidfile\"); }\\nstop() { if test -s \"$pidfile\"; then kill $(cat \"$pidfile\"); fi; rm -f \"$pidfile\"; }\\n' > /etc/init.d/riscv-mbt-openrc-service && " +
    "chmod 755 /etc/init.d/riscv-mbt-openrc-service && " +
    "test -x /etc/init.d/riscv-mbt-openrc-service && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\163\\145\\162\\166\\151\\143\\145\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/rc-update add riscv-mbt-openrc-service default && " +
    "/sbin/rc-update show default | grep riscv-mbt-openrc-service && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\163\\145\\162\\166\\151\\143\\145\\055\\162\\145\\147\\151\\163\\164\\145\\162\\055\\157\\153\\012'",
    "/sbin/rc-update del riscv-mbt-openrc-service default && " +
    "! /sbin/rc-update show default | grep riscv-mbt-openrc-service && " +
    "rm -f /etc/init.d/riscv-mbt-openrc-service && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\157\\160\\145\\156\\162\\143\\055\\163\\145\\162\\166\\151\\143\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_openrc_service_markers() -> Array[String] {
  [
    "openrc-service-files-ok", "openrc-service-register-ok", "post-init-openrc-service-ok",
  ]
}

///|
fn alpine_post_init_openrc_action_commands() -> Array[String] {
  // Narrower than daemon supervision: prove rc-service can dispatch
  // openrc-run start/status/stop actions in this BusyBox-init environment.
  [
    "mkdir -p /run/openrc /etc/init.d && " +
    "touch /run/openrc/softlevel && " +
    "printf '#!/sbin/openrc-run\\ndescription=\"riscv-mbt OpenRC action smoke\"\\nstart() { touch /run/riscv-mbt-openrc-action.started; }\\nstatus() { test -e /run/riscv-mbt-openrc-action.started; }\\nstop() { rm -f /run/riscv-mbt-openrc-action.started; }\\n' > /etc/init.d/riscv-mbt-openrc-action && " +
    "chmod 755 /etc/init.d/riscv-mbt-openrc-action && " +
    "test -x /etc/init.d/riscv-mbt-openrc-action && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\141\\143\\164\\151\\157\\156\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/rc-service --nodeps riscv-mbt-openrc-action start && " +
    "test -e /run/riscv-mbt-openrc-action.started && " +
    "/sbin/rc-service --nodeps riscv-mbt-openrc-action status && " +
    "printf '\\157\\160\\145\\156\\162\\143\\055\\141\\143\\164\\151\\157\\156\\055\\163\\164\\141\\162\\164\\055\\157\\153\\012'",
    "/sbin/rc-service --nodeps riscv-mbt-openrc-action stop && " +
    "! test -e /run/riscv-mbt-openrc-action.started && " +
    "rm -f /etc/init.d/riscv-mbt-openrc-action && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\157\\160\\145\\156\\162\\143\\055\\141\\143\\164\\151\\157\\156\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_openrc_action_markers() -> Array[String] {
  [
    "openrc-action-files-ok", "openrc-action-start-ok", "post-init-openrc-action-ok",
  ]
}

///|
fn alpine_post_init_storage_commands() -> Array[String] {
  // This smoke is about the block-backed rootfs path, not applet breadth:
  // write a file, force writeback, then read and compare it through a second
  // file so virtio-blk read/write paths both stay in the Linux proof loop.
  [
    "mkdir -p /root/riscv-mbt-storage && " +
    "dd if=/dev/zero of=/root/riscv-mbt-storage/blob bs=1024 count=16 && " +
    "printf 'storage-tail\\n' >> /root/riscv-mbt-storage/blob && " +
    "sync && " +
    "wc -c /root/riscv-mbt-storage/blob && " +
    "printf '\\163\\164\\157\\162\\141\\147\\145\\055\\167\\162\\151\\164\\145\\055\\157\\153\\012'",
    "(echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true) && " +
    "dd if=/root/riscv-mbt-storage/blob of=/root/riscv-mbt-storage/copy bs=4096 && " +
    "cmp /root/riscv-mbt-storage/blob /root/riscv-mbt-storage/copy && " +
    "tail -n 1 /root/riscv-mbt-storage/copy | grep storage-tail && " +
    "sync && " +
    "printf '\\160\\157\\163\\164\\055\\151\\156\\151\\164\\055\\163\\164\\157\\162\\141\\147\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_storage_markers() -> Array[String] {
  ["storage-write-ok", "post-init-storage-ok"]
}

///|
fn alpine_post_init_persistence_write_command() -> String {
  // First half of the persistence proof: create a rootfs file from ordinary
  // Alpine userspace, then let the host-side probe save the mutated disk image.
  "printf 'persisted-through-host-image\\n' > /root/riscv-mbt-persist && " +
  "sync && " +
  "cat /root/riscv-mbt-persist && " +
  "printf '\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\167\\162\\151\\164\\145\\055\\157\\153\\012'"
}

///|
fn alpine_post_init_persistence_read_command() -> String {
  // Second half of the persistence proof: boot from the saved image and read
  // the file without recreating it in this emulator run.
  "cat /root/riscv-mbt-persist | grep persisted-through-host-image && " +
  "printf '\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\162\\145\\141\\144\\055\\157\\153\\012'"
}

///|
fn alpine_post_init_apk_persistence_write_commands() -> Array[String] {
  // First half of the package persistence proof: install a dependency-bearing
  // package set, sync it, and let the host write back the mutated disk image.
  [
    "test -x /sbin/apk && " +
    "test -r /root/riscv-mbt-apks/APKINDEX.tar.gz && " +
    "! /sbin/apk info -e iputils && " +
    "! /sbin/apk info -e iputils-ping && " +
    "printf '\\141\\160\\153\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\146\\151\\154\\145\\163\\055\\157\\153\\012'",
    "/sbin/apk --no-network --allow-untrusted --repository /root/riscv-mbt-apks add iputils && " +
    "sync && " +
    "printf '\\141\\160\\153\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\167\\162\\151\\164\\145\\055\\157\\153\\012'",
  ]
}

///|
fn alpine_post_init_apk_persistence_write_markers() -> Array[String] {
  ["apk-persistence-files-ok", "apk-persistence-write-ok"]
}

///|
fn alpine_post_init_apk_persistence_read_command() -> String {
  // Second half: boot from the host-saved image and prove the installed
  // packages are still present and runnable without running `apk add` again.
  "/sbin/apk info -e iputils && " +
  "/sbin/apk info -e iputils-ping && " +
  "/sbin/apk info -e libcap2 && " +
  "/sbin/apk info -L iputils-ping | grep '^bin/ping$' && " +
  "ifconfig lo up && " +
  "ifconfig lo | grep '127.0.0.1' && " +
  "/bin/ping -c 1 -W 1 127.0.0.1 && " +
  "printf '\\141\\160\\153\\055\\160\\145\\162\\163\\151\\163\\164\\145\\156\\143\\145\\055\\162\\145\\141\\144\\055\\157\\153\\012'"
}

///|
async fn main {
  let args = @env.args()
  let max_steps = parse_max_steps(args)
  let post_init_command_step_budget = parse_positive_int_arg(
    args, "--post-init-command-step-budget", default_post_init_command_step_budget,
  )
  let interactive_command_step_budget = parse_positive_int_arg(
    args, "--interactive-command-step-budget", default_interactive_command_step_budget,
  )
  let interactive_console = parse_flag(args, "--interactive-console")
  let functional_smoke = parse_flag(args, "--functional-smoke")
  let rootfs_smoke = parse_flag(args, "--rootfs-smoke")
  let switch_root_smoke = parse_flag(args, "--switch-root-smoke")
  let init_smoke = parse_flag(args, "--init-smoke")
  let auto_root_smoke = parse_flag(args, "--auto-root-smoke")
  let auto_root_handoff = parse_flag(args, "--auto-root-handoff")
  let auto_root_post_init_smoke = parse_flag(
    args, "--auto-root-post-init-smoke",
  )
  let post_init_smoke = parse_flag(args, "--post-init-smoke")
  let post_init_session_smoke = parse_flag(args, "--post-init-session-smoke")
  let post_init_busybox_smoke = parse_flag(args, "--post-init-busybox-smoke")
  let post_init_apk_smoke = parse_flag(args, "--post-init-apk-smoke")
  let post_init_apk_static_smoke = parse_flag(
    args, "--post-init-apk-static-smoke",
  )
  let post_init_apk_install_smoke = parse_flag(
    args, "--post-init-apk-install-smoke",
  )
  let post_init_apk_local_repo_smoke = parse_flag(
    args, "--post-init-apk-local-repo-smoke",
  )
  let post_init_apk_local_deps_smoke = parse_flag(
    args, "--post-init-apk-local-deps-smoke",
  )
  let post_init_iputils_loopback_smoke = parse_flag(
    args, "--post-init-iputils-loopback-smoke",
  )
  let post_init_shell_smoke = parse_flag(args, "--post-init-shell-smoke")
  let post_init_system_smoke = parse_flag(args, "--post-init-system-smoke")
  let post_init_service_smoke = parse_flag(args, "--post-init-service-smoke")
  let post_init_service_persistence_write_smoke = parse_flag(
    args, "--post-init-service-persistence-write-smoke",
  )
  let post_init_service_persistence_read_smoke = parse_flag(
    args, "--post-init-service-persistence-read-smoke",
  )
  let post_init_openrc_install_smoke = parse_flag(
    args, "--post-init-openrc-install-smoke",
  )
  let post_init_openrc_surface_smoke = parse_flag(
    args, "--post-init-openrc-surface-smoke",
  )
  let post_init_openrc_service_smoke = parse_flag(
    args, "--post-init-openrc-service-smoke",
  )
  let post_init_openrc_action_smoke = parse_flag(
    args, "--post-init-openrc-action-smoke",
  )
  let post_init_storage_smoke = parse_flag(args, "--post-init-storage-smoke")
  let post_init_persistence_write_smoke = parse_flag(
    args, "--post-init-persistence-write-smoke",
  )
  let post_init_persistence_read_smoke = parse_flag(
    args, "--post-init-persistence-read-smoke",
  )
  let post_init_apk_persistence_write_smoke = parse_flag(
    args, "--post-init-apk-persistence-write-smoke",
  )
  let post_init_apk_persistence_read_smoke = parse_flag(
    args, "--post-init-apk-persistence-read-smoke",
  )
  let write_back_virtio_blk_disk = parse_flag(
    args, "--write-back-virtio-blk-disk",
  )
  let post_init_custom_command = parse_arg_value(args, "--post-init-command")
  let post_init_custom_expect = match post_init_custom_command {
    Some(_) =>
      match parse_arg_value(args, "--post-init-expect") {
        Some(marker) => Some(marker)
        None => abort("--post-init-expect is required with --post-init-command")
      }
    None => None
  }
  let has_post_init_custom_command = post_init_custom_command is Some(_)
  let has_post_init_probe = post_init_smoke ||
    post_init_session_smoke ||
    post_init_busybox_smoke ||
    post_init_apk_smoke ||
    post_init_apk_static_smoke ||
    post_init_apk_install_smoke ||
    post_init_apk_local_repo_smoke ||
    post_init_apk_local_deps_smoke ||
    post_init_iputils_loopback_smoke ||
    post_init_shell_smoke ||
    post_init_system_smoke ||
    post_init_service_smoke ||
    post_init_service_persistence_write_smoke ||
    post_init_service_persistence_read_smoke ||
    post_init_openrc_install_smoke ||
    post_init_openrc_surface_smoke ||
    post_init_openrc_service_smoke ||
    post_init_openrc_action_smoke ||
    post_init_storage_smoke ||
    post_init_persistence_write_smoke ||
    post_init_persistence_read_smoke ||
    post_init_apk_persistence_write_smoke ||
    post_init_apk_persistence_read_smoke ||
    has_post_init_custom_command
  let uses_auto_root_artifacts = auto_root_smoke ||
    auto_root_handoff ||
    auto_root_post_init_smoke ||
    interactive_console
  // Any smoke beyond the tiny initramfs prompt needs the virtio DTB and rootfs
  // disk image. Keep that routing centralized so adding a new post-init proof
  // does not accidentally boot the no-block-device platform.
  let uses_virtio_rootfs = rootfs_smoke ||
    switch_root_smoke ||
    init_smoke ||
    auto_root_smoke ||
    auto_root_handoff ||
    auto_root_post_init_smoke ||
    interactive_console ||
    has_post_init_probe
  let selected_dtb_path = select_dtb_path(
    args, uses_auto_root_artifacts, uses_virtio_rootfs,
  )
  let selected_initrd_path = select_initrd_path(args, uses_auto_root_artifacts)
  let virtio_blk_disk_path = match parse_arg_value(args, "--virtio-blk-disk") {
    Some(path) => Some(path)
    None => if uses_virtio_rootfs { Some(rootfs_image_path) } else { None }
  }
  let selected_virtio_blk_disk_path = match virtio_blk_disk_path {
    Some(path) => path
    None => ""
  }
  let command = if functional_smoke {
    Some(alpine_functional_smoke_command())
  } else if rootfs_smoke {
    Some(alpine_rootfs_smoke_command())
  } else if switch_root_smoke {
    Some(alpine_switch_root_smoke_command())
  } else if init_smoke {
    Some(alpine_init_smoke_command())
  } else if auto_root_smoke {
    None
  } else if auto_root_handoff {
    None
  } else if auto_root_post_init_smoke {
    None
  } else if interactive_console {
    None
  } else if has_post_init_probe {
    // Post-init probes first run the standard root handoff command. The
    // per-proof commands are injected only after rootfs-side init emits
    // `post-init-ready`.
    Some(alpine_init_smoke_command())
  } else {
    parse_arg_value(args, "--command")
  }
  let expect = if functional_smoke {
    Some("linux-functional-ok")
  } else if rootfs_smoke {
    Some("rootfs-mount-ok")
  } else if switch_root_smoke {
    Some("switch-root-ok")
  } else if init_smoke {
    Some(alpine_post_init_marker)
  } else if auto_root_smoke {
    Some(alpine_post_init_marker)
  } else if auto_root_handoff && !has_post_init_probe {
    Some(alpine_post_init_marker)
  } else if interactive_console {
    Some(alpine_post_init_marker)
  } else if auto_root_post_init_smoke {
    Some("post-init-functional-ok")
  } else if post_init_smoke {
    Some("post-init-functional-ok")
  } else if post_init_session_smoke {
    Some("post-init-session-ok")
  } else if post_init_busybox_smoke {
    Some("post-init-busybox-ok")
  } else if post_init_apk_smoke {
    Some("post-init-apk-ok")
  } else if post_init_apk_static_smoke {
    Some("post-init-apk-static-ok")
  } else if post_init_apk_install_smoke {
    Some("post-init-apk-install-ok")
  } else if post_init_apk_local_repo_smoke {
    Some("post-init-apk-local-repo-ok")
  } else if post_init_apk_local_deps_smoke {
    Some("post-init-apk-local-deps-ok")
  } else if post_init_iputils_loopback_smoke {
    Some("post-init-iputils-loopback-ok")
  } else if post_init_shell_smoke {
    Some("post-init-shell-ok")
  } else if post_init_system_smoke {
    Some("post-init-system-ok")
  } else if post_init_service_smoke {
    Some("post-init-service-ok")
  } else if post_init_service_persistence_write_smoke {
    Some("service-persistence-write-ok")
  } else if post_init_service_persistence_read_smoke {
    Some("service-persistence-read-ok")
  } else if post_init_openrc_install_smoke {
    Some("post-init-openrc-ok")
  } else if post_init_openrc_surface_smoke {
    Some("post-init-openrc-surface-ok")
  } else if post_init_openrc_service_smoke {
    Some("post-init-openrc-service-ok")
  } else if post_init_openrc_action_smoke {
    Some("post-init-openrc-action-ok")
  } else if post_init_storage_smoke {
    Some("post-init-storage-ok")
  } else if post_init_persistence_write_smoke {
    Some("persistence-write-ok")
  } else if post_init_persistence_read_smoke {
    Some("persistence-read-ok")
  } else if post_init_apk_persistence_write_smoke {
    Some("apk-persistence-write-ok")
  } else if post_init_apk_persistence_read_smoke {
    Some("apk-persistence-read-ok")
  } else if post_init_custom_expect is Some(marker) {
    Some(marker)
  } else {
    parse_arg_value(args, "--expect")
  }
  let post_init_commands = if post_init_custom_command is Some(text) {
    [text]
  } else if post_init_busybox_smoke {
    alpine_post_init_busybox_commands()
  } else if post_init_apk_smoke {
    alpine_post_init_apk_commands()
  } else if post_init_apk_static_smoke {
    alpine_post_init_apk_static_commands()
  } else if post_init_apk_install_smoke {
    alpine_post_init_apk_install_commands()
  } else if post_init_apk_local_repo_smoke {
    alpine_post_init_apk_local_repo_commands()
  } else if post_init_apk_local_deps_smoke {
    alpine_post_init_apk_local_deps_commands()
  } else if post_init_iputils_loopback_smoke {
    alpine_post_init_iputils_loopback_commands()
  } else if post_init_shell_smoke {
    alpine_post_init_shell_commands()
  } else if post_init_system_smoke {
    alpine_post_init_system_commands()
  } else if post_init_service_smoke {
    alpine_post_init_service_commands()
  } else if post_init_service_persistence_write_smoke {
    alpine_post_init_service_persistence_write_commands()
  } else if post_init_service_persistence_read_smoke {
    [alpine_post_init_service_persistence_read_command()]
  } else if post_init_openrc_install_smoke {
    alpine_post_init_openrc_install_commands()
  } else if post_init_openrc_surface_smoke {
    alpine_post_init_openrc_surface_commands()
  } else if post_init_openrc_service_smoke {
    alpine_post_init_openrc_service_commands()
  } else if post_init_openrc_action_smoke {
    alpine_post_init_openrc_action_commands()
  } else if post_init_storage_smoke {
    alpine_post_init_storage_commands()
  } else if post_init_persistence_write_smoke {
    [alpine_post_init_persistence_write_command()]
  } else if post_init_persistence_read_smoke {
    [alpine_post_init_persistence_read_command()]
  } else if post_init_apk_persistence_write_smoke {
    alpine_post_init_apk_persistence_write_commands()
  } else if post_init_apk_persistence_read_smoke {
    [alpine_post_init_apk_persistence_read_command()]
  } else if auto_root_post_init_smoke {
    [alpine_post_init_smoke_command()]
  } else if post_init_session_smoke {
    alpine_post_init_session_commands()
  } else if post_init_smoke {
    [alpine_post_init_smoke_command()]
  } else {
    []
  }
  let post_init_markers = if post_init_custom_expect is Some(marker) {
    [marker]
  } else if post_init_busybox_smoke {
    alpine_post_init_busybox_markers()
  } else if post_init_apk_smoke {
    alpine_post_init_apk_markers()
  } else if post_init_apk_static_smoke {
    alpine_post_init_apk_static_markers()
  } else if post_init_apk_install_smoke {
    alpine_post_init_apk_install_markers()
  } else if post_init_apk_local_repo_smoke {
    alpine_post_init_apk_local_repo_markers()
  } else if post_init_apk_local_deps_smoke {
    alpine_post_init_apk_local_deps_markers()
  } else if post_init_iputils_loopback_smoke {
    alpine_post_init_iputils_loopback_markers()
  } else if post_init_shell_smoke {
    alpine_post_init_shell_markers()
  } else if post_init_system_smoke {
    alpine_post_init_system_markers()
  } else if post_init_service_smoke {
    alpine_post_init_service_markers()
  } else if post_init_service_persistence_write_smoke {
    alpine_post_init_service_persistence_write_markers()
  } else if post_init_service_persistence_read_smoke {
    ["service-persistence-read-ok"]
  } else if post_init_openrc_install_smoke {
    alpine_post_init_openrc_install_markers()
  } else if post_init_openrc_surface_smoke {
    alpine_post_init_openrc_surface_markers()
  } else if post_init_openrc_service_smoke {
    alpine_post_init_openrc_service_markers()
  } else if post_init_openrc_action_smoke {
    alpine_post_init_openrc_action_markers()
  } else if post_init_storage_smoke {
    alpine_post_init_storage_markers()
  } else if post_init_persistence_write_smoke {
    ["persistence-write-ok"]
  } else if post_init_persistence_read_smoke {
    ["persistence-read-ok"]
  } else if post_init_apk_persistence_write_smoke {
    alpine_post_init_apk_persistence_write_markers()
  } else if post_init_apk_persistence_read_smoke {
    ["apk-persistence-read-ok"]
  } else if auto_root_post_init_smoke {
    ["post-init-functional-ok"]
  } else if post_init_session_smoke {
    alpine_post_init_session_markers()
  } else if post_init_smoke {
    ["post-init-functional-ok"]
  } else {
    []
  }
  let fw_bytes = read_binary(opensbi_path)
  let kernel_bytes = read_binary(kernel_path)
  let dtb_bytes = read_binary(selected_dtb_path)
  let initrd_bytes = read_binary(selected_initrd_path)
  let virtio_blk_disk_bytes = match virtio_blk_disk_path {
    Some(path) => Some(read_binary(path))
    None => None
  }

  let runner = @riscv.make_runner(
    if virtio_blk_disk_bytes is Some(_) {
      @riscv.virtio_blk_machine_config()
    } else {
      @riscv.virt_machine_config()
    },
  )
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  runner.write_memory_bytes(kernel_entry_addr, kernel_bytes)
  runner.load_dtb(dtb_bytes)
  runner.write_memory_bytes(initrd_addr, initrd_bytes)
  match virtio_blk_disk_bytes {
    Some(bytes) => runner.load_virtio_blk_disk(bytes)
    None => ()
  }
  runner.setup_fw_dynamic_handoff(
    fw_dynamic_info_addr,
    kernel_entry_addr,
    1U.to_uint64(),
  )

  let mut steps = 0
  let mut output = ""
  let mut outcome = "timeout"
  let mut trapped = false
  let mut last_output_steps = 0
  let mut shell_command_sent = false
  let mut post_init_command_sent = false
  let mut post_init_command_index = 0
  let mut post_init_command_steps = -1
  let post_init_command_start_steps : Array[Int] = []
  let post_init_command_marker_steps : Array[Int] = []
  let mut post_init_command_start_read_requests = 0U.to_uint64()
  let mut post_init_command_start_read_bytes = 0U.to_uint64()
  let mut post_init_command_start_write_requests = 0U.to_uint64()
  let mut post_init_command_start_write_bytes = 0U.to_uint64()
  let mut post_init_command_start_sequential_reads = 0U.to_uint64()
  let mut post_init_command_start_forward_gap_reads = 0U.to_uint64()
  let mut post_init_command_start_backward_reads = 0U.to_uint64()
  let mut shell_expect_seen = false
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        if steps % drain_interval == 0 {
          let partial = runner.uart_drain()
          if partial.length() > 0 {
            output = output + partial
            last_output_steps = steps
            if output.contains(alpine_shell_prompt_marker) {
              outcome = "alpine-shell-prompt"
              match command {
                Some(text) =>
                  if !shell_command_sent {
                    // Feed the command through the same UART input path that
                    // the browser host uses. This keeps the console probe
                    // grounded in guest-visible serial input instead of
                    // treating prompt reachability as the whole Linux proof.
                    runner.uart_push_input(text + "\r\n")
                    shell_command_sent = true
                  }
                None => break
              }
            } else if output.contains(alpine_shell_marker) {
              outcome = "alpine-shell"
            } else if output.contains(alpine_marker) {
              outcome = "alpine-marker"
            }
            match expect {
              Some(marker) =>
                if (shell_command_sent || post_init_command_sent) &&
                  output.contains(marker) {
                  shell_expect_seen = true
                  outcome = "console-command"
                  if post_init_command_sent &&
                    post_init_command_marker_steps.length() <
                    post_init_command_index {
                    post_init_command_marker_steps.push(steps)
                  }
                  break
                }
              None => if outcome == "alpine-shell-prompt" { break }
            }
            if interactive_console && output.contains(alpine_post_init_marker) {
              shell_expect_seen = true
              outcome = "interactive-ready"
              break
            }
            if auto_root_smoke && output.contains(alpine_post_init_marker) {
              shell_expect_seen = true
              outcome = "console-command"
              break
            }
            if post_init_commands.length() > 0 &&
              (
                shell_command_sent ||
                auto_root_handoff ||
                auto_root_post_init_smoke
              ) &&
              post_init_command_index == 0 &&
              output.contains(alpine_post_init_marker) {
              // Rootfs-side autoshell is alive. Start the first post-init
              // command only now, otherwise initramfs shell success could be
              // mistaken for mounted-rootfs usability.
              runner.uart_push_input(post_init_commands[0] + "\r\n")
              post_init_command_sent = true
              post_init_command_index = 1
              post_init_command_steps = steps
              post_init_command_start_steps.push(steps)
              post_init_command_start_read_requests = runner.virtio_blk_read_request_count()
              post_init_command_start_read_bytes = runner.virtio_blk_read_byte_count()
              post_init_command_start_write_requests = runner.virtio_blk_write_request_count()
              post_init_command_start_write_bytes = runner.virtio_blk_write_byte_count()
              post_init_command_start_sequential_reads = runner.virtio_blk_read_sequential_request_count()
              post_init_command_start_forward_gap_reads = runner.virtio_blk_read_forward_gap_request_count()
              post_init_command_start_backward_reads = runner.virtio_blk_read_backward_request_count()
            } else if post_init_command_index > 0 &&
              post_init_command_index < post_init_commands.length() &&
              output.contains(post_init_markers[post_init_command_index - 1]) {
              // Multi-command proofs advance by marker, not by prompt count:
              // command echo and shell prompts are noisy under serial console.
              post_init_command_marker_steps.push(steps)
              runner.uart_push_input(
                post_init_commands[post_init_command_index] + "\r\n",
              )
              post_init_command_index += 1
              post_init_command_steps = steps
              post_init_command_start_steps.push(steps)
              post_init_command_start_read_requests = runner.virtio_blk_read_request_count()
              post_init_command_start_read_bytes = runner.virtio_blk_read_byte_count()
              post_init_command_start_write_requests = runner.virtio_blk_write_request_count()
              post_init_command_start_write_bytes = runner.virtio_blk_write_byte_count()
              post_init_command_start_sequential_reads = runner.virtio_blk_read_sequential_request_count()
              post_init_command_start_forward_gap_reads = runner.virtio_blk_read_forward_gap_request_count()
              post_init_command_start_backward_reads = runner.virtio_blk_read_backward_request_count()
            }
          }
          if post_init_command_sent &&
            !shell_expect_seen &&
            post_init_command_steps >= 0 &&
            steps - post_init_command_steps >= post_init_command_step_budget {
            // This timeout is measured from command injection, not from boot
            // start. It keeps exploratory rootfs commands from hiding behind
            // the already-expensive Linux/OpenSBI/Alpine startup cost.
            outcome = "post-init-command-timeout"
            break
          }
        }
      }
      Trap(info) => {
        trapped = true
        outcome = "trap pc=" +
          info.faulting_pc.to_string() +
          " tval=" +
          info.trap_value.to_string()
        break
      }
    }
  }
  let tail = runner.uart_drain()
  if tail.length() > 0 {
    output = output + tail
  }
  if interactive_console && outcome == "interactive-ready" {
    let interactive_result = run_interactive_console(
      runner, steps, output, interactive_command_step_budget,
    )
    steps = interactive_result.steps
    last_output_steps = interactive_result.last_output_steps
    output = interactive_result.output
    outcome = interactive_result.outcome
    trapped = interactive_result.trapped
  }
  if outcome == "timeout" {
    // Preserve the strongest boot milestone visible in the final UART buffer
    // when the run otherwise timed out. Do not downgrade specific outcomes
    // such as post-init command timeout or traps just because a prompt was
    // visible earlier in the buffer.
    if output.contains(alpine_shell_prompt_marker) {
      outcome = "alpine-shell-prompt"
    } else if output.contains(alpine_shell_marker) {
      outcome = "alpine-shell"
    } else if output.contains(alpine_marker) {
      outcome = "alpine-marker"
    }
  }
  match expect {
    Some(marker) => {
      if (shell_command_sent || post_init_command_sent) &&
        output.contains(marker) {
        // Final full-buffer check catches markers emitted after the last
        // periodic drain, especially near the step budget boundary.
        shell_expect_seen = true
        outcome = "console-command"
        if post_init_command_sent &&
          post_init_command_marker_steps.length() < post_init_command_index {
          post_init_command_marker_steps.push(steps)
        }
      }
      if auto_root_smoke && output.contains(marker) {
        shell_expect_seen = true
        outcome = "console-command"
      }
      if auto_root_handoff && !has_post_init_probe && output.contains(marker) {
        shell_expect_seen = true
        outcome = "console-command"
      }
      if interactive_console && output.contains(marker) {
        shell_expect_seen = true
      }
    }
    None => ()
  }
  if write_back_virtio_blk_disk &&
    shell_expect_seen &&
    virtio_blk_disk_path is Some(path) {
    // This is intentionally after marker evaluation: only guest-visible Linux
    // behavior decides success, then the host persists the resulting disk.
    write_binary(path, runner.virtio_blk_disk_bytes())
  }
  println("Alpine native probe")
  println("outcome=" + outcome)
  println("steps=" + steps.to_string())
  println("last_output_steps=" + last_output_steps.to_string())
  println("trapped=" + trapped.to_string())
  println("shell_command_sent=" + shell_command_sent.to_string())
  println("post_init_command_sent=" + post_init_command_sent.to_string())
  println("shell_expect_seen=" + shell_expect_seen.to_string())
  println("functional_smoke=" + functional_smoke.to_string())
  println("rootfs_smoke=" + rootfs_smoke.to_string())
  println("switch_root_smoke=" + switch_root_smoke.to_string())
  println("init_smoke=" + init_smoke.to_string())
  println("auto_root_smoke=" + auto_root_smoke.to_string())
  println("auto_root_handoff=" + auto_root_handoff.to_string())
  println("auto_root_post_init_smoke=" + auto_root_post_init_smoke.to_string())
  println("interactive_console=" + interactive_console.to_string())
  println("post_init_smoke=" + post_init_smoke.to_string())
  println("post_init_session_smoke=" + post_init_session_smoke.to_string())
  println("post_init_busybox_smoke=" + post_init_busybox_smoke.to_string())
  println("post_init_apk_smoke=" + post_init_apk_smoke.to_string())
  println(
    "post_init_apk_static_smoke=" + post_init_apk_static_smoke.to_string(),
  )
  println(
    "post_init_apk_install_smoke=" + post_init_apk_install_smoke.to_string(),
  )
  println(
    "post_init_apk_local_repo_smoke=" +
    post_init_apk_local_repo_smoke.to_string(),
  )
  println(
    "post_init_apk_local_deps_smoke=" +
    post_init_apk_local_deps_smoke.to_string(),
  )
  println(
    "post_init_iputils_loopback_smoke=" +
    post_init_iputils_loopback_smoke.to_string(),
  )
  println("post_init_shell_smoke=" + post_init_shell_smoke.to_string())
  println("post_init_system_smoke=" + post_init_system_smoke.to_string())
  println("post_init_service_smoke=" + post_init_service_smoke.to_string())
  println(
    "post_init_service_persistence_write_smoke=" +
    post_init_service_persistence_write_smoke.to_string(),
  )
  println(
    "post_init_service_persistence_read_smoke=" +
    post_init_service_persistence_read_smoke.to_string(),
  )
  println(
    "post_init_openrc_install_smoke=" +
    post_init_openrc_install_smoke.to_string(),
  )
  println(
    "post_init_openrc_surface_smoke=" +
    post_init_openrc_surface_smoke.to_string(),
  )
  println(
    "post_init_openrc_service_smoke=" +
    post_init_openrc_service_smoke.to_string(),
  )
  println(
    "post_init_openrc_action_smoke=" + post_init_openrc_action_smoke.to_string(),
  )
  println("post_init_storage_smoke=" + post_init_storage_smoke.to_string())
  println(
    "post_init_persistence_write_smoke=" +
    post_init_persistence_write_smoke.to_string(),
  )
  println(
    "post_init_persistence_read_smoke=" +
    post_init_persistence_read_smoke.to_string(),
  )
  println(
    "post_init_apk_persistence_write_smoke=" +
    post_init_apk_persistence_write_smoke.to_string(),
  )
  println(
    "post_init_apk_persistence_read_smoke=" +
    post_init_apk_persistence_read_smoke.to_string(),
  )
  println(
    "write_back_virtio_blk_disk=" + write_back_virtio_blk_disk.to_string(),
  )
  println(
    "post_init_custom_command=" + has_post_init_custom_command.to_string(),
  )
  println("post_init_command_index=" + post_init_command_index.to_string())
  println("post_init_command_steps=" + post_init_command_steps.to_string())
  println(
    "post_init_command_trace=" +
    format_post_init_command_trace(
      post_init_command_start_steps, post_init_command_marker_steps,
    ),
  )
  println(
    "post_init_command_step_budget=" + post_init_command_step_budget.to_string(),
  )
  println(
    "interactive_command_step_budget=" +
    interactive_command_step_budget.to_string(),
  )
  println("dtb_path=" + selected_dtb_path)
  println("initrd_path=" + selected_initrd_path)
  println("virtio_blk_disk=" + selected_virtio_blk_disk_path)
  println("final_pc=" + hex(runner.pc_u64()))
  println("final_privilege=" + privilege_name(runner.privilege_mode()))
  println("csr_sstatus=" + hex(runner.read_csr_u64(csr_sstatus)))
  println("csr_sie=" + hex(runner.read_csr_u64(csr_sie)))
  println("csr_sip=" + hex(runner.read_csr_u64(csr_sip)))
  println("csr_sepc=" + hex(runner.read_csr_u64(csr_sepc)))
  println("csr_scause=" + hex(runner.read_csr_u64(csr_scause)))
  println("csr_stval=" + hex(runner.read_csr_u64(csr_stval)))
  println("csr_satp=" + hex(runner.read_csr_u64(csr_satp)))
  println(
    "decode_cache=\{runner.decode_cache_hit_count()} hits/\{runner.decode_cache_miss_count()} misses",
  )
  println(
    "translate_cache=\{runner.translate_cache_hit_count()} hits/\{runner.translate_cache_miss_count()} misses",
  )
  println(
    "virtio_blk=\{runner.virtio_blk_read_request_count()} read-req/\{runner.virtio_blk_read_byte_count()} read-bytes " +
    "\{runner.virtio_blk_write_request_count()} write-req/\{runner.virtio_blk_write_byte_count()} write-bytes",
  )
  println(
    "virtio_blk_read_cache=\{runner.virtio_blk_read_cache_hit_count()} hits/\{runner.virtio_blk_read_cache_miss_count()} misses",
  )
  println(
    "virtio_blk_read_window=first=\{hex(runner.virtio_blk_read_first_offset())} min=\{hex(runner.virtio_blk_read_min_offset())} max_end=\{hex(runner.virtio_blk_read_max_end())} last=\{hex(runner.virtio_blk_read_last_offset())} last_end=\{hex(runner.virtio_blk_read_last_end())}",
  )
  println(
    "virtio_blk_read_pattern=\{runner.virtio_blk_read_sequential_request_count()} sequential " +
    "\{runner.virtio_blk_read_forward_gap_request_count()} forward-gap " +
    "\{runner.virtio_blk_read_backward_request_count()} backward",
  )
  println(
    "post_init_command_virtio_delta=\{runner.virtio_blk_read_request_count() - post_init_command_start_read_requests} read-req/" +
    "\{runner.virtio_blk_read_byte_count() - post_init_command_start_read_bytes} read-bytes " +
    "\{runner.virtio_blk_write_request_count() - post_init_command_start_write_requests} write-req/" +
    "\{runner.virtio_blk_write_byte_count() - post_init_command_start_write_bytes} write-bytes",
  )
  println(
    "post_init_command_read_pattern_delta=\{runner.virtio_blk_read_sequential_request_count() - post_init_command_start_sequential_reads} sequential " +
    "\{runner.virtio_blk_read_forward_gap_request_count() - post_init_command_start_forward_gap_reads} forward-gap " +
    "\{runner.virtio_blk_read_backward_request_count() - post_init_command_start_backward_reads} backward",
  )
  println("output_chars=" + output.length().to_string())
  println(
    "contains_linux_version=" + output.contains("Linux version").to_string(),
  )
  println(
    "contains_initramfs_unpack=" +
    (output.contains(initramfs_unpack_marker_old) ||
    output.contains(initramfs_unpack_marker_new)).to_string(),
  )
  println(
    "contains_free_initmem=" + output.contains(free_initmem_marker).to_string(),
  )
  println(
    "contains_free_initrd=" + output.contains(free_initrd_marker).to_string(),
  )
  println("contains_run_init=" + output.contains(run_init_marker).to_string())
  println("contains_rootfs=" + output.contains(rootfs_marker).to_string())
  println("contains_virtio_blk=" + output.contains("virtio_blk").to_string())
  println("contains_vda=" + output.contains("vda").to_string())
  println(
    "contains_alpine_marker=" + output.contains(alpine_marker).to_string(),
  )
  println(
    "contains_alpine_shell=" + output.contains(alpine_shell_marker).to_string(),
  )
  println(
    "contains_alpine_shell_prompt=" +
    output.contains(alpine_shell_prompt_marker).to_string(),
  )
  println(
    "contains_post_init_marker=" +
    output.contains(alpine_post_init_marker).to_string(),
  )
  println(
    "contains_auto_root_marker=" +
    output.contains(alpine_auto_root_marker).to_string(),
  )
  let tail_start = if output.length() > 5000 {
    output.length() - 5000
  } else {
    0
  }
  println("tail:")
  println(output[tail_start:].to_owned())
}
