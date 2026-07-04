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
