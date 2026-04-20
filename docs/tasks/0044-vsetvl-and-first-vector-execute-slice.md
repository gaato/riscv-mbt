# Task 0044: `vsetvl*` And The First Vector Execute Slice

## Background

The first `V` slice is now in place as state/CSR-only bring-up. The next step is to make vector configuration state executable by adding the `vsetvli` family and the minimum legality/runtime plumbing needed before any arithmetic or vector memory instructions land.

## Work

- Add decode and execute support for:
  - `vsetvli`
  - `vsetivli`
  - `vsetvl`
- Replace the reset-only `vl`/`vtype` placeholders with runtime-updated vector configuration state
- Define the repo's first concrete `SEW`/`LMUL` acceptance boundary
- Keep vector arithmetic and vector load/store out of scope for this slice

## Acceptance Criteria

- `vsetvli`/`vsetivli`/`vsetvl` decode and execute with dedicated tests
- `vl` and `vtype` are updated by the `vsetvl*` path rather than remaining reset-only state
- Unsupported or out-of-scope `SEW`/`LMUL` combinations fail in a documented way
- No vector arithmetic, masking, or vector memory instructions are added yet

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0043](0043-vector-extension-evaluation.md)

## Status

- `doing`

## Progress Notes

- This is the first execute-level `V` slice after state/CSR bring-up
- The immediate goal is to make vector configuration state executable before widening into arithmetic or vector memory
