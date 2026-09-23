# Task 0029: Machine Return And Mstatus Semantics

## Background

This slice hardens trap-return behavior after trap-entry invariants are in place.

## Work

- Make `MRET` transitions explicit:
  - next privilege from `mstatus.MPP`
  - `mstatus.MIE <- mstatus.MPIE`
  - `mstatus.MPIE <- 1`
  - `mstatus.MPP <- U`
- Make modeled `mstatus` reset defaults explicit in tests
- Tighten user-mode round-trip tests around `mstatus` transitions

## Acceptance Criteria

- `MRET` privilege and status-bit transitions are covered by focused execute tests
- `mstatus` reset defaults used by trap/return flow are explicit in tests
- Existing official `rv32ui` / `rv32um` / `rv32uc` survey paths stay green

## Related Milestone

- `Minimal M-mode`

## Dependencies

- [Task 0028](0028-machine-reset-and-trap-entry.md)

## Completion Notes

- `MRET` now applies explicit status transitions:
  - `mstatus.MIE <- mstatus.MPIE`
  - `mstatus.MPIE <- 1`
  - `mstatus.MPP <- U`
- `MRET` privilege restoration from `mstatus.MPP` is covered in focused tests.
- User- and machine-side return flows are both covered by execute regressions.
- Modeled `mstatus` reset defaults used by trap/return flow are explicit in tests.

## Status

- `done`
