# Task 0032: RV64I Sign Extension And Word Ops

## Background

The first RV64-specific correctness checkpoint is preserving the sign-extension invariant for 32-bit values living in 64-bit registers, plus the dedicated `*W` and wider load/store semantics that depend on it.

## Work

- Add RV64I-specific decode and execute coverage
- Preserve sign-extension invariants for 32-bit results in 64-bit registers
- Add `LWU`, `LD`, `SD`, and RV64 shift-width behavior
- Add `ADDIW`, `SLLIW`, `SRLIW`, `SRAIW`, `ADDW`, `SUBW`, `SLLW`, `SRLW`, `SRAW`

## Acceptance Criteria

- RV64 sign-extension rules are tested explicitly
- RV64 load/store width behavior is covered by execute tests
- `*W` instruction semantics are validated independently from broader Linux work

## Status

- `done`

## Completion Notes

- Added RV64I decode coverage for `LWU`, `LD`, `SD`, and `OP-IMM-32` / `OP-32`
- Added writeback helpers that distinguish full-width writes from sign-extended word writes
- Added RV64 execute regressions for `LW` vs `LWU`, `LD` / `SD`, and `*W` arithmetic and shifts
