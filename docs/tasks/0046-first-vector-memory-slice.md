# Task 0046: First Vector Memory Slice

## Background

The first narrow vector arithmetic slice is now in place. The next step is to make vector registers useful without immediately widening into masking, widening/narrowing arithmetic, or full policy semantics.

## Work

- Add the first narrow vector memory subset on top of the current `vl`/`vtype` path
- Keep the scope narrow enough that vector element layout, `SEW`, and memory semantics stay understandable
- Reuse the existing vector config and element-access helpers instead of introducing a second vector execution path

## Implemented Scope

- unit-stride integer vector load/store only
- unmasked only
- `LMUL=1` only
- `SEW={8,16,32,64}`
- width/`SEW` match required
- tail elements remain undisturbed
- `vill` or `vstart!=0` traps as `IllegalInstruction`
- faulting vector memory instructions do not partially commit

## Acceptance Criteria

- The first vector memory subset has dedicated decode/execute regressions
- The implementation reuses the current vector config helpers and raw vector slot layout
- Existing scalar, CSR, `vsetvl*`, and first arithmetic-slice regressions remain green

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0045](0045-first-vector-arithmetic-slice.md)

## Status

- `done`

## Progress Notes

- This is the next narrow `V` slice after the first arithmetic subset
- The goal is to bring up vector memory before broader masking or policy semantics
- The current repo contract now includes:
  - `vle8.v`
  - `vle16.v`
  - `vle32.v`
  - `vle64.v`
  - `vse8.v`
  - `vse16.v`
  - `vse32.v`
  - `vse64.v`
- The implementation boundary is intentionally narrow:
  - unit-stride only
  - integer memory only
  - unmasked only
  - `LMUL=1` only
  - `SEW` must match memory width
  - tail-undisturbed
  - no partial commit on fault
- The next step is broader vector execute semantics, starting with masking and non-trivial execution constraints
