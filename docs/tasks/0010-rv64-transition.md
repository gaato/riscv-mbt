# Task 0010: Establish RV64 Sign-Extension Invariants

## Background

For Linux and broad software compatibility, the roadmap should pivot to RV64 before going too deep into MMU and device work. The most dangerous failure mode is treating RV64 as “RV32 with wider registers” and breaking the sign-extension invariants that compilers and ABIs expect.

## Work

- Widen the core to `RV64`
- Preserve the invariant that 32-bit values living in 64-bit registers are sign-extended
- Add `*W` instruction coverage and RV64-specific shift-rule tests
- Keep the widening work separate from MMU and Linux platform work

## Acceptance Criteria

- RV64 width and sign-extension edge cases are tested explicitly
- `*W` instruction semantics are validated independently from broader Linux bring-up
- RV32 correctness stays understandable and testable

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0008](0008-minimal-m-mode.md)

## Status

- `todo`
