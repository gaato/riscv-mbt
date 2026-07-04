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

- `doing`

## Progress Notes

- This is the next narrow `V` slice after the first masked arithmetic subset
- The main open `V` gaps are now broader vector memory/addressing forms, `LMUL>1`, and wider execution semantics
- Browser Wasm Linux boot is now complete, so this task is the next normal post-Linux extension slice
- Task 0057 split vector helpers and first-slice execution into `riscv_vector.mbt`; Task 0048 should extend that file instead of growing unrelated dispatcher or FP code.
- The mainline priority has resumed here after the Alpine browser boot proof. Continue with RISC-V spec-aligned `V` extension coverage first; use browser Alpine probes as integration gates and performance measurements as guardrails, not as the primary work queue.
- Added the first `LMUL>1` execute path for vector unit-stride memory: `LMUL=2` `vle32.v` and `vse32.v` now map element indices across the aligned vector register group (`v2-v3` in the regression). Misaligned `LMUL=2` groups such as `vd=1` still trap as illegal. Validation passed with `moon check`, vector memory tests, full `moon test` (160 passed), `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:51.90`.
- Added the first strided vector memory slice: unmasked `vlse32.v` and `vsse32.v` now decode and execute with `mop=10`, `rs1` as base, and `rs2` as byte stride. The implementation reuses the vector memory legality helper, LMUL register-group element mapping, and no-partial-commit load/store structure. Validation passed with `moon check`, targeted decode/vector-memory tests, full `moon test` (161 passed), `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:51.62`.
- Added the first indexed-unordered vector memory slice: unmasked `vluxei32.v` and `vsuxei32.v` now decode and execute with `mop=01`, `rs1` as base, and `vs2` as a vector of zero-extended 32-bit byte offsets. This slice is intentionally limited to data `SEW=32` and index `EEW=32`, so index EMUL matches the current LMUL. Validation passed with `moon check`, targeted decode/vector-memory tests, full `moon test` (162 passed), `moon bench`, `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:52.04`.
- Added the first indexed-ordered vector memory slice: unmasked `vloxei32.v` and `vsoxei32.v` now decode and execute with `mop=11`, sharing the indexed `e32` legality and address path while committing stores in element order. A regression covers repeated ordered-store offsets so the final value comes from the later element. Validation passed with `moon check`, targeted decode/vector-memory tests, full `moon test` (163 passed), `moon bench`, `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:52.50`.
- Added vector mask load/store: `vlm.v` and `vsm.v` now decode through the `lumop/sumop=01011` unit-stride memory encodings and transfer `ceil(vl/8)` bytes to or from the mask register representation. Validation passed with `moon check`, targeted decode/vector-memory tests, full `moon test` (164 passed), `moon bench`, `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:51.88`.
- Added the first `LMUL=2` vector arithmetic slice: `vmv.v.i`, `vmv.v.x`, `vmv.x.s`, `vadd.vv`, `vadd.vx`, and `vadd.vi` now use aligned register-group element access, so `e32,m2` operations span groups such as `v2-v3`. Misaligned arithmetic groups, such as a base `v3` under `m2`, trap as illegal. This is still scalar MoonBit execution of guest vector semantics; host Wasm SIMD / `v128` is not enabled. Validation passed with `moon check`, targeted vector arithmetic tests, full `moon test` (165 passed), `moon fmt`, `moon info`, `moon bench`, `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:51.95`.
- Added `vector_add_lmul2_loop_100k_steps` to `moon bench` so future MoonBit `V128`/host-SIMD experiments have a direct scalar baseline for the first `LMUL=2` arithmetic path before changing runtime semantics. This follows the current measurement-first tuning guidance from the MoonBit optimization article and the MoonBit 0.10 release note that `V128` is still experimental. The initial baseline measured `31.18 ms +/- 304.25 us`; validation passed with `moon check`, `moon bench`, and full `moon test` (165 passed).
- Added the first vector subtract slice: `vsub.vv` and `vsub.vx` now decode and execute through the same vector config, mask, and aligned register-group path as the existing add/move arithmetic slice. A regression covers `e32,m2` group mapping and per-lane modulo wrap (`2 - 7 == 0xfffffffb`). Validation passed with `moon check`, targeted decode/vector arithmetic tests, full `moon test` (165 passed), `moon bench`, `moon fmt`, `moon info`, `./scripts/build-browser-demo.sh`, and browser Alpine functional smoke at `wall=0:52.04`.
- Added the first vector bitwise logical slice from the RISC-V V integer arithmetic encodings: `vand.vv/vx/vi`, `vor.vv/vx/vi`, and `vxor.vv/vx/vi` now decode and execute. The execute path shares one private binary-op helper with `vadd` and `vsub`, so the same active `vl`, mask, SEW wrapping, and aligned `LMUL=2` register-group rules apply. The regression covers every new decode form, full `e32,m2` group mapping across both 64-bit words in each destination register, and `vxor.vi -1` as the architectural `vnot.v` pseudoinstruction shape. Validation passed with `moon fmt`, `moon check`, targeted decode/vector logical/vector arithmetic tests, full `moon test` (166 passed), `moon bench`, and `moon info`. Browser smoke was intentionally not run for this slice because the active goal now makes browser testing optional unless the browser Linux integration surface is changed.
- Added the first vector min/max slice from the RISC-V V integer arithmetic encodings: `vminu.vv/vx`, `vmin.vv/vx`, `vmaxu.vv/vx`, and `vmax.vv/vx` now decode and execute. The existing private binary-op helper now carries the active SEW into signed comparisons, so e32 lanes such as `0xffffffff` are compared as `-1` for signed forms while unsigned forms keep raw lane ordering. The regression covers every new decode form, signed-vs-unsigned e32 behavior, scalar `vx` comparisons, and full `e32,m2` group mapping. Validation passed with `moon fmt`, `moon check`, targeted decode/vector min-max tests, full `moon test` (167 passed), `moon bench`, `moon info`, and the console/native Alpine probe `moon run --target native cmd/alpine_probe xxlong`, which reached `outcome=alpine-shell-prompt` at 357,000,000 guest steps.
- Added the first vector shift slice from the RISC-V V single-width bit shift encodings: `vsll.vv/vx/vi`, `vsrl.vv/vx/vi`, and `vsra.vv/vx/vi` now decode and execute. Shift amounts use only the low `lg2(SEW)` bits as required by the spec, and `vsra` sign-extends each lane at the active SEW before arithmetic right shift. The regression covers every new decode form, `e32,m2` group mapping, vector/scalar/immediate shift sources, shift counts larger than the e32 width, and logical-vs-arithmetic right shift behavior. Validation passed with `moon fmt`, `moon check`, targeted decode/vector shift tests, full `moon test` (168 passed), `moon bench`, `moon info`, and the console/native Alpine command probe `moon run --target native cmd/alpine_probe xxlong --command "printf '\\143\\157\\156\\163\\157\\154\\145\\055\\163\\150\\151\\146\\164\\055\\157\\153\\012'" --expect console-shift-ok`, which reached `outcome=console-command` at 361,000,000 guest steps.
