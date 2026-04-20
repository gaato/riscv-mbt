# Task 0043: First `V` Slice State And CSR Bring-Up

## Background

With the `F/D` phase closed, the next extension-family decision for the current mainline is `V`. The first `V` slice stays intentionally narrow: bring up vector architectural state, visible CSR surface, and extension gating before any `vsetvli` or vector arithmetic lands.

## Work

- Add vector architectural state storage (`v0..v31`) as raw slots only
- Add the first visible vector CSR surface
  - `vstart`
  - `vxsat`
  - `vxrm`
  - `vcsr`
  - `vl`
  - `vtype`
  - `vlenb`
- Gate vector CSR visibility behind the `V` extension bit
- Keep `vsetvli` and all vector instructions out of scope for this slice
- Record the next follow-up as the first execute-level vector slice

## Acceptance Criteria

- Vector state and visible vector CSR surface exist with dedicated regression tests
- `vlenb` is exposed as a read-only constant and `vl`/`vtype` remain read-only in this slice
- Vector CSR accesses are rejected when `V` is not enabled
- The first `V` scope is documented as state/CSR-only, with `vsetvli` and vector execute deferred

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0042](0042-post-fd-closure.md)

## Status

- `done`

## Progress Notes

- This is the next active slice after post-`F/D` closure
- The first `V` slice is state/CSR-only with raw register storage and visible CSR plumbing
- Assumptions for this slice:
  - `VLEN = 128`
  - vector registers are stored as raw slots
  - `vtype` resets with `vill=1`
  - no `mstatus.VS` modeling yet
  - no `vsetvli` or vector execute path yet
- Implemented:
  - raw vector register storage for `v0..v31`
  - visible vector CSR surface and reset values
  - `V`-gated CSR access checks
  - execute regressions for reset, CSR visibility, read-only enforcement, and no-`V` trapping
