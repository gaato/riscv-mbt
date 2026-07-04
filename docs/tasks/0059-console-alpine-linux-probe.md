# Task 0059: Console Alpine Linux Probe

## Background

The browser Alpine proof is useful, but the active workflow now prefers console/native Linux evidence for routine implementation slices. The existing `cmd/alpine_probe` could boot to a BusyBox prompt, but it could not inject guest console input and verify command output.

## Work

- Extend the native Alpine probe with optional UART command injection after the BusyBox prompt
- Verify an expected shell output marker without involving the browser
- Keep the probe deterministic enough for regression evidence

## Acceptance Criteria

- The probe still reports the existing Linux boot markers
- A command can be sent after `/ #` appears
- The probe can stop only after a caller-specified expected output appears
- The probe can run the standard functional smoke used for Linux usability
  checks without involving the browser

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0058](0058-alpine-rootfs-browser-boot.md)

## Status

- `done`

## Progress Notes

- Added `--command` and `--expect` support to `cmd/alpine_probe`. After the probe sees the BusyBox `/ #` prompt, it feeds the command through `Runner::uart_push_input`, keeps executing the guest, and reports `outcome=console-command` only once the expected marker appears in UART output.
- Validation passed with `moon fmt`, `moon check`, `moon info`, and the console/native Alpine command probe:
  `moon run --target native cmd/alpine_probe xxlong --command "printf '\\143\\157\\156\\163\\157\\154\\145\\055\\162\\165\\156\\055\\157\\153\\012'" --expect console-run-ok`.
  The probe reached `outcome=console-command`, `steps=361000000`, `shell_command_sent=true`, `shell_expect_seen=true`, `contains_linux_version=true`, `contains_run_init=true`, and `contains_alpine_shell_prompt=true`.
- Added `--functional-smoke`, which sends the same practical command sequence
  as the browser functional smoke after the BusyBox prompt and expects
  `linux-functional-ok`.
- Validation passed with
  `moon run --target native cmd/alpine_probe xxlong --functional-smoke`.
  The probe reached `outcome=console-command`, `steps=362000000`,
  `functional_smoke=true`, `shell_command_sent=true`, and
  `shell_expect_seen=true`.
