# Task 0028: Machine Reset And Trap Entry

## Background

This is the first concrete slice under `Minimal M-mode`.
It focuses on reset invariants and trap-entry state transitions only.

## Work

- Make reset assumptions explicit for modeled machine CSRs
- Make trap entry write `mepc`, `mcause`, and `mtval` predictably
- Record prior privilege into `mstatus.MPP` on trap entry
- Update trap-entry status bits with `mstatus.MPIE <- MIE` and `mstatus.MIE <- 0`
- Keep `mtvec` handling in direct-mode form (`BASE = mtvec & ~0b11`)

## Acceptance Criteria

- Reset starts in `Machine` and uses `MachineConfig.entry_point`
- Trap entry from `User` and from `Machine` updates `mstatus.MPP` correctly
- Trap entry updates `mstatus.MPIE` and clears `mstatus.MIE`
- `mtvec` trap target masks low two bits and does not use vectored dispatch
- Existing official `rv32ui` / `rv32um` / `rv32uc` survey paths stay green

## Related Milestone

- `Minimal M-mode`

## Dependencies

- [Task 0008](0008-minimal-m-mode.md)

## Completion Notes

- Reset invariants for modeled machine state are explicit in execute tests.
- Trap entry now records prior privilege into `mstatus.MPP`.
- Trap entry now performs `mstatus.MPIE <- MIE` and `mstatus.MIE <- 0`.
- `mtvec` handling remains direct-mode (`BASE = mtvec & ~0b11`) and is covered by tests.

## Status

- `done`
