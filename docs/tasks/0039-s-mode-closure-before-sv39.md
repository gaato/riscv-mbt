# Task 0039: S-mode Closure Before `Sv39`

## Background

After supervisor trap entry and delegation are both present, the repo should close the standalone `S`-mode checkpoint before taking on address translation.

## Work

- Consolidate machine/supervisor trap-flow regressions
- Close the `0012` umbrella once the supervisor path is independently testable
- Advance repo docs so `Sv39` becomes the next active task

## Acceptance Criteria

- The supervisor path is documented as a standalone checkpoint before `Sv39`
- `docs/current.md` and the active milestone doc point to `Sv39` as the next task after closure
- No MMU or platform assumptions are mixed into the S-mode closure step

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0038](0038-delegation-routing-and-sret.md)

## Status

- `todo`
