# Task 0011: Stabilize The Practical RV64 Core

## Background

Before Linux bring-up, the RV64 CPU core should be stable on its own. This stage exists to keep core instruction bugs separate from privileged and MMU bugs.

## Work

- Carry forward `M`, `C`, `Zicsr`, and `Zifencei` onto the RV64 path
- Finish RV64 integer-width and mixed-width instruction coverage
- Keep Linux-specific platform work out of this task

## Acceptance Criteria

- RV64 practical-core regressions pass without relying on MMU or SBI
- Integer-core failures can still be isolated from system-integration failures

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0010](0010-rv64-transition.md)

## Status

- `doing`
