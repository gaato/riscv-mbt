# Task 0041: `D` Extension Bring-Up

## Background

Once scalar `F` is stable, the next extension step is `D`. This task carries the floating-point path from single-precision to double-precision without mixing in vector or hypervisor work.

## Work

- Add `D` architectural state semantics on top of the existing FP register bank
- Implement `FLD` / `FSD`
- Implement `D` scalar arithmetic and bit-move instructions
- Add `F`/`D` conversion paths needed for practical software compatibility

## Acceptance Criteria

- `D` state is independently testable
- `FLD` / `FSD` and core scalar `D` operations have targeted decode and execute regressions
- `F` behavior remains stable while `D` is added

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0040](0040-f-scalar-bring-up.md)

## Status

- `done`

## Progress Notes

- `D` now rides on the same FP register bank, FCSR helpers, and extension-aware legality gate introduced for scalar `F`
- `FLD` / `FSD`, raw 64-bit moves, core scalar `D` arithmetic, and `F`/`D` conversions all have targeted decode and execute regressions
- `moon check` and `moon test` pass with the `D` path enabled and the existing non-FP regressions unchanged
