# Task 0015: Meet The Linux Boot ABI On One Hart

## Background

A large class of early Linux boot failures are not MMU bugs but boot-state mismatches such as wrong register conventions or a bad initial `satp` state.

## Work

- Meet the expected `a0`, `a1`, and `satp = 0` boot conditions
- Respect image placement and alignment constraints that matter on the chosen path
- Bring up Linux on a single hart first

## Acceptance Criteria

- Linux boot logs appear on one hart
- Boot assumptions are documented separately from MMU correctness

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0014](0014-opensbi-and-virt-platform.md)

## Status

- `todo`
