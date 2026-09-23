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

- `done`

## Progress Notes

- This task is now the active mainline decision point after Linux boot and browser delivery are complete
- The repo now uses a profile-driven target instead of claiming `RV64G` or `RV64GC` directly
- The chosen target is `RV64 Linux Profile v1`
- Future extension prioritization is anchored to that profile, with `F`/`D` as the first required compatibility family to add
