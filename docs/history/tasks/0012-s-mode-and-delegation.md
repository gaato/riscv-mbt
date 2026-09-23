# Task 0012: Add S-mode And Delegation

## Background

Linux boot wants supervisor-mode execution, not an indefinitely M-mode-centric design. Delegation should become explicit before MMU and SBI work deepen.

## Work

- Use this task as the umbrella for supervisor-mode and delegation work before `Sv39`
- Add the minimum supervisor trap surface and direct trap-entry path
- Add delegation routing and `SRET` without mixing in MMU or platform work

## Subtasks

- [0037 Supervisor CSR surface and trap entry](0037-supervisor-csr-surface-and-trap-entry.md)
- [0038 Delegation routing and `SRET`](0038-delegation-routing-and-sret.md)
- [0039 S-mode closure before `Sv39`](0039-s-mode-closure-before-sv39.md)

## Acceptance Criteria

- Supervisor trap flow is testable on its own
- Delegated exceptions and interrupts can be reasoned about without Linux in the loop
- The supervisor path is explicit enough that `Sv39` work does not have to begin from an M-mode-only trap design

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0011](0011-rv64-practical-core.md)

## Status

- `done`

## Progress Notes

- Supervisor trap entry, delegated exception routing, and `SRET` are now independently testable before `Sv39`
- The next Linux-path task is `Sv39` and `SFENCE.VMA`
