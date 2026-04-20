# Task 0017: Define The Post-Linux Compatibility Target

## Background

After Linux boots, the project should stop being “whatever extension comes next” and become “which compatibility target are we honoring”.

## Work

- Decide whether the default target is `RV64G`, `RV64GC`, or a profile-driven compatibility set
- Record the target in docs and ADRs
- Align future extension work to that target

## Acceptance Criteria

- The compatibility target is explicit and versioned in repo docs
- Future extension work no longer depends on chat memory

## Related Milestone

- `Post-Linux compatibility target`

## Dependencies

- [Task 0016](0016-smp-after-single-hart.md)

## Status

- `doing`

## Progress Notes

- This task is now the active mainline decision point after Linux boot and browser delivery are complete
- The remaining work is to choose and document the compatibility target that future extension work should follow
