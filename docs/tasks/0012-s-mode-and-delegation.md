# Task 0012: Add S-mode And Delegation

## Background

Linux boot wants supervisor-mode execution, not an indefinitely M-mode-centric design. Delegation should become explicit before MMU and SBI work deepen.

## Work

- Add supervisor trap state such as `stvec`, `sepc`, `scause`, and `stval`
- Add `medeleg` and `mideleg`
- Make the S-mode path independent enough that everything does not route through M-mode by default

## Acceptance Criteria

- Supervisor trap flow is testable on its own
- Delegated exceptions and interrupts can be reasoned about without Linux in the loop

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0011](0011-rv64-practical-core.md)

## Status

- `todo`
