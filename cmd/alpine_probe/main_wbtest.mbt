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
