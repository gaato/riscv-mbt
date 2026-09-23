# Task 0040: `F` Scalar Bring-Up

## Background

`RV64 Linux Profile v1` needs scalar floating-point before the repo can claim broader post-Linux software compatibility. The first step is a constrained `F` bring-up that makes floating-point architectural state, `fcsr`, and a practical scalar subset independently testable.

## Work

- Add a floating-point register bank alongside the integer architectural state
- Add modeled `fflags`, `frm`, and `fcsr` CSR surface
- Extend legality gating so floating-point instructions are checked against the enabled extension set instead of XLEN alone
- Implement the first scalar `F` subset:
  - `FLW`
  - `FSW`
  - `FMV.X.W`
  - `FMV.W.X`
  - `FADD.S`
  - `FSUB.S`
  - `FMUL.S`
  - `FDIV.S`
  - `FSQRT.S`
  - `FMIN.S`
  - `FMAX.S`
- Keep the first implementation constrained:
  - host IEEE arithmetic for value computation
  - only default rounding mode support
  - `fflags` visible as state but not yet fully updated from arithmetic exceptions

## Acceptance Criteria

- Floating-point state can be read and written independently of integer state
- `fcsr`, `frm`, and `fflags` are visible through the CSR path
- The initial scalar `F` subset decodes and executes with targeted regressions
- Unsupported rounding modes trap or are otherwise handled exactly as documented

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0018](0018-extensions-a-fd-v-h.md)

## Status

- `done`

## Progress Notes

- This is the first concrete slice under the post-Linux extension milestone
- The implementation strategy is host IEEE arithmetic with explicit limitations recorded in docs and tests
- The initial scalar `F` subset is now implemented with:
  - raw FP register state
  - `fcsr` / `frm` / `fflags` CSR visibility
  - `FLW` / `FSW`
  - `FMV.X.W` / `FMV.W.X`
  - `FADD.S` / `FSUB.S` / `FMUL.S` / `FDIV.S` / `FSQRT.S`
  - `FMIN.S` / `FMAX.S`
