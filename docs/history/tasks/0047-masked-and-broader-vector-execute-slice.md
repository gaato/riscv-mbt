# Task 0047: Masked And Broader Vector Execute Slice

## Background

The first narrow vector arithmetic and memory slices are now in place. The next step is to broaden `V` execution semantics without jumping directly to a much larger subset.

## Work

- Add the first masked vector execute path on top of the existing `vl`/`vtype`/vector register helpers
- Keep the scope narrow enough that masking, tail behavior, and legality stay understandable
- Continue to defer strided/indexed memory, `LMUL>1`, and broader policy semantics unless a small masked subset proves stable

## Initial Scope

- masked integer vector arithmetic first
- preserve the current `LMUL=1` and `SEW={8,16,32,64}` boundary unless explicitly widened
- keep `vstart!=0` as unsupported unless a dedicated restart slice is introduced
- defer strided/indexed vector memory and broader vector arithmetic families

## Implemented Scope

- masked `vadd.vv`
- masked `vadd.vx`
- masked `vadd.vi`
- `v0` bit-mask interpretation only
- masked-off active lanes remain undisturbed
- preserve the current `LMUL=1` and `SEW={8,16,32,64}` boundary
- keep `vstart!=0` unsupported
- continue to defer masked memory, strided/indexed memory, and `LMUL>1`

## Acceptance Criteria

- The first masked vector execute subset has dedicated decode/execute regressions
- The implementation reuses the current vector config, element-access, and unit-stride memory helpers
- Existing scalar, CSR, `vsetvl*`, arithmetic-slice, and first vector-memory regressions remain green

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0046](0046-first-vector-memory-slice.md)

## Status

- `done`

## Progress Notes

- This is the next narrow `V` slice after the first vector memory subset
- The main open `V` gaps are now masking, broader execute semantics, and wider memory/addressing forms
- The current repo contract now includes the first masked vector arithmetic subset:
  - masked `vadd.vv`
  - masked `vadd.vx`
  - masked `vadd.vi`
- The current masked-execute boundary is intentionally narrow:
  - `v0` bit-mask only
  - masked-off lanes remain undisturbed
  - `LMUL=1` only
  - `SEW={8,16,32,64}` only
  - `vstart!=0` remains unsupported
- The next step is broader vector memory/addressing and wider execution semantics, not a jump to full `V`
