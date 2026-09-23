# Task 0045: First Vector Arithmetic Slice

## Background

The vector state/CSR surface and `vsetvl*` configuration path are now in place. The next step is to add the first narrow execute-level vector arithmetic subset without widening immediately into full vector memory, masking, or the broader `V` ISA.

## Work

- Add the first minimal vector arithmetic subset on top of the existing `vl`/`vtype` machinery
- Keep the scope narrow enough that `SEW`/`LMUL` handling, legality, and raw vector register layout stay understandable
- Continue to defer vector memory, masking policy, and wider vector execution coverage unless a small arithmetic subset proves stable
- Fix the execute boundary for this slice to:
  - unmasked instructions only
  - `LMUL=1` only
  - `SEW={8,16,32,64}`
  - tail elements remain undisturbed
  - `vill` or `vstart!=0` traps as `IllegalInstruction`

## Implemented Subset

- `vmv.v.i`
- `vmv.v.x`
- `vmv.x.s`
- `vadd.vv`
- `vadd.vx`
- `vadd.vi`

## Acceptance Criteria

- The first vector arithmetic subset has dedicated decode/execute regressions
- The implementation uses the existing `vl`/`vtype` helper path rather than duplicating vector config logic
- Existing scalar, CSR, and `vsetvl*` regressions remain green
- The implemented subset is explicitly documented as the first narrow arithmetic slice, not as general vector execution

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0044](0044-vsetvl-and-first-vector-execute-slice.md)

## Status

- `done`

## Progress Notes

- This is the first post-configuration `V` execution task
- The goal is to validate the vector execution shape with a narrow arithmetic subset before adding vector memory or broader policy semantics
- The current repo contract now includes the first narrow integer vector execute subset:
  - `vmv.v.i`
  - `vmv.v.x`
  - `vmv.x.s`
  - `vadd.vv`
  - `vadd.vx`
  - `vadd.vi`
- The execute boundary is intentionally narrow:
  - unmasked only
  - `LMUL=1` only
  - tail-undisturbed only
  - `vill` and `vstart!=0` trap as `IllegalInstruction`
- The next step is vector memory, not broader arithmetic policy
