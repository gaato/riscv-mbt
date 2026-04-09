# Task 0034: RV64 Carry-Forward Of `C`, `Zicsr`, And `Zifencei`

## Background

The widened RV64 state from `0010` is only useful if the already-supported practical CPU features still behave correctly on that path.

## Work

- Keep the legality gate as the first RV32/RV64 instruction-support boundary
- Add RV64 regressions for the current compressed subset
- Keep `C.JAL` illegal on RV64 while preserving the current RV32C behavior
- Add RV64 regressions for carried-forward CSR and `FENCE.I` behavior

## Acceptance Criteria

- RV64 execute and compressed regressions cover the current `C + Zicsr + Zifencei` surface
- `C.JAL` traps as `IllegalInstruction` on RV64
- No MMU, SBI, or platform work is mixed into this step

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0010](0010-rv64-transition.md)

## Status

- `done`

## Completion Notes

- The legality gate now rejects RV64-only instructions on RV32 and `C.JAL` on RV64
- RV64 compressed mixed-width regressions now cover the current supported subset
- RV64 execute tests explicitly cover carried-forward CSR and `FENCE.I` behavior
