# Task 0016: Add SMP After Single-Hart Boot

## Background

SMP multiplies the number of moving parts. It should be introduced only after one-hart Linux boot is stable.

## Work

- Add SBI HSM-based hart bring-up after the single-hart path works
- Add the minimum extra synchronization and observability needed for secondary harts
- Keep SMP-specific issues out of the one-hart boot baseline

## Acceptance Criteria

- One-hart boot remains stable
- Secondary-hart bring-up is testable and documented separately

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0015](0015-linux-boot-abi-single-hart.md)

## Status

- `todo`
