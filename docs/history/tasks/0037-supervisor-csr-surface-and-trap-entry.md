# Task 0037: Supervisor CSR Surface And Trap Entry

## Background

Before delegation and `SRET` semantics land, the emulator needs an explicit supervisor trap surface. This step exists to make `S`-mode trap state independently testable before `Sv39` work begins.

## Work

- Add the minimum supervisor CSR surface:
  - `sstatus`
  - `stvec`
  - `sscratch`
  - `sepc`
  - `scause`
  - `stval`
- Generalize trap-target selection so it is no longer hard-coded to `mtvec`
- Add a supervisor trap-entry helper alongside the existing machine trap-entry helper
- Keep trap-vector semantics direct-mode only for both `mtvec` and `stvec`
- Preserve the current machine-only runtime routing while preparing the supervisor path for delegation work

## Acceptance Criteria

- Supervisor trap state is writable and readable through the CSR path
- Supervisor trap entry is independently testable without Linux in the loop
- Direct `stvec` target masking is explicit and regression-tested
- Existing machine trap behavior remains unchanged

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0011](0011-rv64-practical-core.md)

## Status

- `done`

## Completion Notes

- Added minimum supervisor CSR surface (`sstatus`, `stvec`, `sscratch`, `sepc`, `scause`, `stval`) on the checked CSR path
- Generalized trap target selection so supervisor and machine trap vectors share direct-mode target logic
- Added supervisor trap-entry state update path and regression tests for delegated user trap entry and `stvec` low-bit masking
