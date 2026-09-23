# Task 0057: MoonBit Refactoring Before The Next Vector Slice

## Background

After the browser Linux boot and cache-performance slices, the root package had enough working behavior but `riscv_execute.mbt` was carrying integer, floating-point, vector, CSR, interrupt, and decode-cache execution concerns in one file.

Before Task 0048 expands vector memory/addressing and starts `LMUL>1`, the vector execution surface should be easier to edit without mixing unrelated FP or integer execution code.

## Work

- Split focused MoonBit files inside the existing root package without changing public emulator behavior.
- Move floating-point helpers and `F/D` execution into a dedicated file.
- Move vector CSR/config/register/memory helpers and first-slice vector execution into a dedicated file.
- Keep `Runner::step` as the central instruction dispatcher for now.
- Replace simple mutable index loops with range loops where the loop has no algorithmic state beyond the index.
- Remove avoidable MoonBit deprecation warnings exposed by the current toolchain.
- Keep black-box Sv39 translation tests on the existing public `sv39_translate` surface.

## Acceptance Criteria

- `moon check` passes without warnings.
- Full `moon test` remains green.
- Browser Wasm smoke still passes.
- `riscv_execute.mbt` is below the 2k-line file-size guideline.
- Docs record the new file split and the remaining execution-boundary follow-up work.

## Related Milestone

- `Verification, Debug, And Performance`
- `Extensions: A, F/D, V, H`

## Dependencies

- [Task 0056](0056-simmerv-inspired-cache-performance.md)
- [Task 0048](0048-broader-vector-memory-and-lmul-slice.md)

## Status

- `done`

## Progress Notes

- Added `riscv_fp.mbt` for floating-point register helpers, FCSR helpers, and `F/D` execution.
- Added `riscv_vector.mbt` for vector CSR helpers, `vtype`/`vl` handling, element access, mask handling, unit-stride memory helpers, `vsetvl*`, and the first vector execute/memory slices.
- Reduced `riscv_execute.mbt` to the central dispatcher plus integer, load/store, CSR/system, AMO, interrupt, decode-cache, and run/demo helpers.
- Converted simple index-only loops in Bus byte writes, SMP runner construction, cache flushes, vector element loops, superpage PPN loops, `Runner::run`, and `words_to_bytes` to range loops.
- Replaced deprecated StringView `to_string()` use with `to_owned()` in manifest parsing helpers.
- Replaced deprecated `@queue.new()` with `@queue.Queue([])`.
- `PhyTarget` is now private; `sv39_translate`, `AccessType`, and `TranslateResult` stay public because black-box Sv39 tests use them as a verification surface.
- Verification: `moon check`, full `moon test` (`151` passed), `./scripts/build-browser-demo.sh`, and the existing browser Wasm smoke script all passed.
