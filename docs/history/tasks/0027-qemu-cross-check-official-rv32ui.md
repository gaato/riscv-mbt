# Task 0027: Cross-Check Official `rv32ui-p-*` With A System Emulator

## Background

When official binaries start running, it helps to separate "the binary is fine"
from "our emulator is wrong". A system emulator such as `qemu-system-riscv32`
is the fastest practical cross-check.

## Work

- Install or document a working `qemu-system-riscv32` path
- Verify that the chosen official `rv32ui-p-*` subset boots and reaches the
  expected pass/fail mechanism outside this emulator
- Keep the cross-check focused on bring-up, not as a permanent dependency for
  every local test run

## Acceptance Criteria

- At least one official `rv32ui-p-*` binary is validated in a reference system emulator
- The repo documents how to use that cross-check during bring-up
- Emulator failures can be compared against a known-good execution path

## Validated Today

- `rv32ui-p-add`
- `rv32ui-p-addi`
- `rv32ui-p-beq`
- `rv32ui-p-bltu`
- `rv32ui-p-lb`
- `rv32ui-p-lhu`
- `rv32ui-p-sw`
- `rv32ui-p-jal`
- `rv32ui-p-jalr`
- `rv32ui-p-lui`
- `rv32ui-p-auipc`

## Notes

- The repo cross-check path uses `qemu-system-riscv32 -machine virt -bios none -kernel rv32ui-p-*`
- Pass/fail is observed by polling the upstream `tohost` symbol over a QEMU monitor socket
- `./scripts/cross-check-official-rv32ui-with-qemu.pl` defaults to the manifest-backed gating subset and accepts individual test names as arguments

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0004](0004-riscv-tests-integration.md)
- [Task 0026](0026-official-rv32ui-runner.md)

## Status

- `done`
