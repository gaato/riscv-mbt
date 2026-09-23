# Task 0056: Simmerv-Inspired Cache Performance Slice

## Background

`simmerv` demonstrates several performance techniques that fit an interpreter-based RISC-V emulator: predecoded block/uop caching, split translation caches, fast paths for common instructions, and visible performance counters.

`riscv-mbt` should take the parts that fit its current MoonBit architecture without collapsing fetch, decode, translation, trap, and device boundaries.

## Work

- Add a small decode cache inspired by `simmerv`'s predecoded uop cache direction
- Add a Sv39 translation cache inspired by `simmerv`'s split TLB direction
- Expose cache counters to tests and the browser UI
- Keep invalidation explicit at `FENCE.I`, `satp`, `SFENCE.VMA`, and host-side memory image writes
- Preserve current execute semantics and avoid a broad basic-block executor refactor in this slice
- Record native and browser Linux boot observations

## Acceptance Criteria

- Decode cache hit/miss behavior has focused regression coverage
- Sv39 translation cache hit/miss and flush behavior has focused regression coverage
- Native Linux boot still reaches `Linux version`
- Browser smoke and browser Linux boot proofs still pass
- Docs record measured cache counters, timing observations, and deferred follow-up work

## Related Milestone

- `Verification, Debug, And Performance`

## Dependencies

- [Task 0055](0055-browser-plain-wasm-backend.md)

## Status

- `done`

## Progress Notes

- Added a 4096-entry direct-mapped decode cache keyed by physical fetch address, raw instruction, instruction length, and XLEN.
- `FENCE.I`, `load_program*`, and `write_memory_bytes` flush the decode cache.
- Added a 4096-entry direct-mapped Sv39 translation cache keyed by virtual page, `satp`, access type, effective privilege, `SUM`, and `MXR`.
- `satp` writes, `SFENCE.VMA`, `load_program*`, and `write_memory_bytes` flush the translation cache.
- Browser status now reports decode and translation cache hit/miss counters.
- Native Linux boot observation after this slice: `19,000,000` steps in `29.30s`, with `18,941,994` decode hits / `58,005` decode misses and `16,991,713` translation hits / `1,677,284` translation misses.
- Browser Linux boot proof after this slice reached `Linux version`, `earlycon`, and `Kernel command line` in `349.33s`; the previous plain-Wasm proof before this slice recorded `609.38s`.
- Browser DOM observation after this slice: `624,005,546` decode hits / `113,116,343` decode misses and `826,051,582` translation hits / `46,300,763` translation misses.
- Full basic-block/uop cache and a rewritten common-instruction fast executor remain deferred because they would require a larger `Runner::step` boundary split.
