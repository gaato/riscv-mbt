# Task 0008: Add Minimal M-mode

## Background

Minimal machine mode is the point where the project shifts from “CPU core” to “system substrate”.

## Work

- Add the minimum machine-level CSR set
- Implement trap entry, `mepc`, `mcause`, and `mtvec` handling
- Add `mstatus`, `mie`, and `mip` skeleton behavior
- Define reset and trap invariants in tests

## Acceptance Criteria

- Trap-handling tests pass
- Reset-to-M-mode assumptions are explicit
- The roadmap clearly marks this as the system-entry checkpoint

## Related Milestone

- `Minimal M-mode`

## Dependencies

- [Task 0007](0007-rv32imc-zicsr-zifencei.md)

## Status

- `todo`
