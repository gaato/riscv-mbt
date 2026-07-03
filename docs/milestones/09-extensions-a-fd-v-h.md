# Milestone 09: Extensions In Priority Order

## Purpose

Extend the post-Linux emulator in software-value order rather than simply by spec adjacency.

## Target Instructions / Features

- `F`, then `D`
- Any remaining compatibility gaps required by the chosen profile
- `V`
- `H`

## Non-Goals

- Treating every extension as equally urgent

## Exit Criteria

- Extension work follows an explicit order tied to the chosen compatibility target
- Each extension family arrives with dedicated tests and documentation updates

## Required Tests

- Extension-specific conformance and regression tests for each family as it lands

## Prerequisites For Next Milestone

- Stronger verification and observability infrastructure

## Current Checkpoint

- This is now the active mainline milestone
- The chosen baseline is `RV64 Linux Profile v1`
- The extension phase is now staged as:
  1. scalar `F`
  2. `D`
  3. post-`F/D` closure and next-family handoff
  4. `V` state/CSR-only bring-up
  5. `vsetvl*` and the first execute-level `V` slice
  6. first vector arithmetic slice
  7. first vector memory slice
  8. masked and broader vector execute semantics
  9. broader vector memory/addressing and the first `LMUL>1` path
  10. `H` only after `V`
- Scalar `F` and `D` are now both in place with the current constrained host-IEEE implementation
- No additional required compatibility gaps are currently open for `RV64 Linux Profile v1`
- The first `V` state/CSR slice is now in place
- `vsetvli`, `vsetivli`, and `vsetvl` now execute with the current fixed boundary of `VLEN=128`, `SEW={8,16,32,64}`, and `LMUL={1,2,4,8}`
- The first narrow integer vector arithmetic slice is now in place with:
  - `vmv.v.i`
  - `vmv.v.x`
  - `vmv.x.s`
  - `vadd.vv`
  - `vadd.vx`
  - `vadd.vi`
- The first narrow vector memory slice is now in place with:
  - `vle8.v`
  - `vle16.v`
  - `vle32.v`
  - `vle64.v`
  - `vse8.v`
  - `vse16.v`
  - `vse32.v`
  - `vse64.v`
- The current `V` execution boundary is still intentionally narrow:
  - `LMUL=1` only
  - unit-stride integer memory only
  - width/`SEW` match required for vector memory
  - no partial commit on vector memory faults
- The first masked vector arithmetic subset is now in place with:
  - masked `vadd.vv`
  - masked `vadd.vx`
  - masked `vadd.vi`
- The current masked-execute boundary is still intentionally narrow:
  - `v0` bit-mask only
  - masked-off lanes remain undisturbed
  - `LMUL=1` only
  - `vstart!=0` remains unsupported
- The browser Wasm Linux boot goal is now complete, so the remaining extension sequence resumes at `0048`, the first broader vector memory/addressing + `LMUL>1` slice
