# Task 0010: Establish RV64 Sign-Extension Invariants

## Background

For Linux and broad software compatibility, the roadmap should pivot to RV64 before going too deep into MMU and device work. The most dangerous failure mode is treating RV64 as “RV32 with wider registers” and breaking the sign-extension invariants that compilers and ABIs expect.

## Work

- Split the RV64 transition into small implementation slices
- Widen the core to `RV64` without disturbing the current RV32 default path
- Preserve the invariant that 32-bit values living in 64-bit registers are sign-extended
- Add `*W` instruction coverage and RV64-specific shift-rule tests
- Keep the widening work separate from MMU and Linux platform work

## Subtasks

- [0031 XLEN plumbing and RV64 state](0031-xlen-plumbing-and-rv64-state.md)
- [0032 RV64I sign extension and word ops](0032-rv64i-sign-extension-and-word-ops.md)
- [0033 RV64M word ops and transition closure](0033-rv64m-word-ops-and-transition-closure.md)

## Acceptance Criteria

- RV64 width and sign-extension edge cases are tested explicitly
- `*W` instruction semantics are validated independently from broader Linux bring-up
- RV32 correctness stays understandable and testable

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0008](0008-minimal-m-mode.md)

## Status

- `done`

## Completion Notes

- Internal architectural state is now RV64-capable while the public default and official regression path remain RV32 during the transition
- RV64I sign-extension invariants, wider load/store semantics, and `*W` instruction coverage are in place
- RV64M `*W` semantics and widened-state `MRET` / trap regressions are covered
- The next active task is [Task 0011](0011-rv64-practical-core.md)
