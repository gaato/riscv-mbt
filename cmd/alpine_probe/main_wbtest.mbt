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
test "non-auto-root virtio probes keep the standard virtio artifacts" {
  let args = ["alpine_probe", "xlong", "--post-init-system-smoke"]
  assert_eq(select_dtb_path(args, false, true), virtio_dtb_path)
  assert_eq(select_initrd_path(args, false), initrd_path)
}
