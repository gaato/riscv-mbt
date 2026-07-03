# Task 0048: Broader Vector Memory And LMUL Slice

## Background

The first vector arithmetic, first unit-stride memory subset, and first masked arithmetic subset are now in place. The next step is to widen `V` execution without jumping directly to a full vector ISA implementation.

## Work

- Broaden vector memory beyond the first unit-stride subset
- Start widening execution beyond `LMUL=1`
- Keep the scope small enough that element layout, legality, and fault behavior remain understandable

## Initial Scope

- first non-trivial vector memory/addressing expansion
- first `LMUL>1` execute path
- preserve the current `SEW={8,16,32,64}` boundary unless explicitly widened
- continue to defer restart semantics, fault-only-first, and full vector policy behavior

## Acceptance Criteria

- The next broader vector slice has dedicated decode/execute regressions
- The implementation reuses the current vector config, element-access, mask, and unit-stride helper layers
- Existing scalar, CSR, `vsetvl*`, arithmetic, memory, and masked regressions remain green

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0047](0047-masked-and-broader-vector-execute-slice.md)

## Status

- `todo`

## Progress Notes

- This is the next narrow `V` slice after the first masked arithmetic subset
- The main open `V` gaps are now broader vector memory/addressing forms, `LMUL>1`, and wider execution semantics
- Browser Wasm Linux boot is now complete, so this task is the next normal post-Linux extension slice
- Task 0057 split vector helpers and first-slice execution into `riscv_vector.mbt`; Task 0048 should extend that file instead of growing unrelated dispatcher or FP code.
