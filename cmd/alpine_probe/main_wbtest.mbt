///|
test "post-init command step budget defaults and parses positive override" {
  let args = ["alpine_probe", "xlong", "--post-init-command-step-budget", "42"]
  assert_eq(
    parse_positive_int_arg(
      args, "--post-init-command-step-budget", default_post_init_command_step_budget,
    ),
    42,
  )
  assert_eq(
    parse_positive_int_arg(
      ["alpine_probe", "xlong"],
      "--post-init-command-step-budget",
      default_post_init_command_step_budget,
    ),
    default_post_init_command_step_budget,
  )
}

///|
test "interactive command step budget defaults and parses positive override" {
  let args = [
    "alpine_probe", "xlong", "--interactive-command-step-budget", "77",
  ]
  assert_eq(
    parse_positive_int_arg(
      args, "--interactive-command-step-budget", default_interactive_command_step_budget,
    ),
    77,
  )
  assert_eq(
    parse_positive_int_arg(
      ["alpine_probe", "xlong"],
      "--interactive-command-step-budget",
      default_interactive_command_step_budget,
    ),
    default_interactive_command_step_budget,
  )
}

///|
test "console line trimming preserves shell command body" {
  assert_eq(trim_console_line("ps\n"), "ps")
  assert_eq(trim_console_line("cat /proc/mounts\r\n"), "cat /proc/mounts")
  assert_eq(
    trim_console_line("echo keep trailing spaces  \n"),
    "echo keep trailing spaces  ",
  )
}

///|
test "argument value parser keeps flag-specific routing simple" {
  let args = ["alpine_probe", "xlong", "--dtb", "custom.dtb", "--expect", "ok"]
  match parse_arg_value(args, "--dtb") {
    Some(value) => assert_eq(value, "custom.dtb")
    None => abort("expected --dtb value")
  }
  match parse_arg_value(args, "--missing") {
    Some(_) => abort("unexpected --missing value")
    None => ()
  }
}

///|
test "post-init command trace reports per-command durations" {
  assert_eq(
    format_post_init_command_trace([10, 25], [20]),
    "cmd1:start=10,marker=20,duration=10; cmd2:start=25,marker=?,duration=?",
  )
  assert_eq(format_post_init_command_trace([], []), "")
}

///|
test "iputils loopback smoke keeps commands and markers aligned" {
  let commands = alpine_post_init_iputils_loopback_commands()
  let markers = alpine_post_init_iputils_loopback_markers()
  assert_eq(commands.length(), 4)
  assert_eq(markers.length(), 4)
  assert_true(commands[1].contains("add iputils"))
  assert_true(commands[2].contains("ifconfig lo up"))
  assert_true(commands[3].contains("/bin/ping -c 1 -W 1 127.0.0.1"))
  assert_eq(markers[3], "post-init-iputils-loopback-ok")
}

///|
test "apk persistence read smoke runs installed ping after reboot" {
  let command = alpine_post_init_apk_persistence_read_command()
  assert_true(command.contains("/sbin/apk info -e iputils-ping"))
  assert_true(command.contains("ifconfig lo up"))
  assert_true(command.contains("/bin/ping -c 1 -W 1 127.0.0.1"))
  assert_true(command.contains("printf"))
}

///|
test "service smoke keeps init.d-style start and stop aligned" {
  let commands = alpine_post_init_service_commands()
  let markers = alpine_post_init_service_markers()
  assert_eq(commands.length(), 3)
  assert_eq(markers.length(), 3)
  assert_true(commands[0].contains("/etc/init.d/riscv-mbt-service"))
  assert_true(commands[1].contains("riscv-mbt-service start"))
  assert_true(commands[1].contains("riscv-mbt-service status"))
  assert_true(commands[2].contains("riscv-mbt-service stop"))
  assert_eq(markers[2], "post-init-service-ok")
}

///|
test "service persistence smoke writes and reruns service script" {
  let write_commands = alpine_post_init_service_persistence_write_commands()
  let write_markers = alpine_post_init_service_persistence_write_markers()
  assert_eq(write_commands.length(), 2)
  assert_eq(write_markers.length(), 2)
  assert_true(write_commands[0].contains("/etc/init.d/riscv-mbt-service"))
  assert_true(write_commands[1].contains("sync"))
  let read_command = alpine_post_init_service_persistence_read_command()
  assert_true(read_command.contains("test -x /etc/init.d/riscv-mbt-service"))
  assert_true(read_command.contains("riscv-mbt-service start"))
  assert_true(read_command.contains("riscv-mbt-service stop"))
  assert_true(read_command.contains("printf"))
}

///|
test "openrc install smoke keeps package and command checks aligned" {
  let commands = alpine_post_init_openrc_install_commands()
  let markers = alpine_post_init_openrc_install_markers()
  assert_eq(commands.length(), 4)
  assert_eq(markers.length(), 4)
  assert_true(commands[0].contains("openrc-*.apk"))
  assert_true(commands[1].contains("add openrc"))
  assert_true(commands[2].contains("/sbin/openrc --version"))
  assert_true(commands[2].contains("/bin/rc-status"))
  assert_true(commands[3].contains("/sbin/rc-update show"))
  assert_eq(markers[2], "openrc-commands-ok")
  assert_eq(markers[3], "post-init-openrc-ok")
}

///|
test "openrc surface smoke avoids package reinstall" {
  let commands = alpine_post_init_openrc_surface_commands()
  let markers = alpine_post_init_openrc_surface_markers()
  assert_eq(commands.length(), 3)
  assert_eq(markers.length(), 3)
  assert_true(commands[0].contains("/sbin/openrc"))
  assert_true(commands[0].contains("/bin/rc-status"))
  assert_true(commands[0].contains("/etc/init.d"))
  assert_true(commands[1].contains("/sbin/openrc --version"))
  assert_true(!commands[1].contains("apk"))
  assert_true(commands[2].contains("/sbin/rc-update show"))
  assert_eq(markers[2], "post-init-openrc-surface-ok")
}

///|
test "openrc service smoke exercises rc-update registration" {
  let commands = alpine_post_init_openrc_service_commands()
  let markers = alpine_post_init_openrc_service_markers()
  assert_eq(commands.length(), 3)
  assert_eq(markers.length(), 3)
  assert_true(commands[0].contains("#!/sbin/openrc-run"))
  assert_true(commands[0].contains("/run/openrc/softlevel"))
  assert_true(commands[1].contains("/sbin/rc-update add"))
  assert_true(commands[2].contains("/sbin/rc-update del"))
  assert_eq(markers[1], "openrc-service-register-ok")
  assert_eq(markers[2], "post-init-openrc-service-ok")
}

///|
test "openrc action smoke exercises rc-service actions" {
  let commands = alpine_post_init_openrc_action_commands()
  let markers = alpine_post_init_openrc_action_markers()
  assert_eq(commands.length(), 3)
  assert_eq(markers.length(), 3)
  assert_true(commands[0].contains("#!/sbin/openrc-run"))
  assert_true(commands[1].contains("/sbin/rc-service --nodeps"))
  assert_true(commands[1].contains(" start"))
  assert_true(commands[1].contains(" status"))
  assert_true(commands[2].contains(" stop"))
  assert_eq(markers[1], "openrc-action-start-ok")
  assert_eq(markers[2], "post-init-openrc-action-ok")
}

///|
test "auto-root handoff selects auto-root artifacts by default" {
  let args = ["alpine_probe", "xlong", "--auto-root-handoff"]
  assert_eq(select_dtb_path(args, true, true), auto_root_virtio_dtb_path)
  assert_eq(select_initrd_path(args, true), auto_root_initrd_path)
  assert_eq(
    select_dtb_path(
      ["alpine_probe", "xlong", "--auto-root-handoff", "--dtb", "custom.dtb"],
      true,
      true,
    ),
    "custom.dtb",
  )
  assert_eq(
    select_initrd_path(
      [
        "alpine_probe", "xlong", "--auto-root-handoff", "--initrd", "custom.cpio",
      ],
      true,
    ),
    "custom.cpio",
  )
}

///|
test "interactive console selects auto-root virtio artifacts by default" {
  let args = ["alpine_probe", "xlong", "--interactive-console"]
  assert_eq(select_dtb_path(args, true, true), auto_root_virtio_dtb_path)
  assert_eq(select_initrd_path(args, true), auto_root_initrd_path)
}

///|
test "non-auto-root virtio probes keep the standard virtio artifacts" {
  let args = ["alpine_probe", "xlong", "--post-init-system-smoke"]
  assert_eq(select_dtb_path(args, false, true), virtio_dtb_path)
  assert_eq(select_initrd_path(args, false), initrd_path)
}
