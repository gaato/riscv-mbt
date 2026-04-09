# Task 0035: ELF64 Loader And RV64 Official Plumbing

## Background

Practical RV64 stabilization needs an official regression path, which means the loader and test harness must ingest `ELF64` binaries and route them to an RV64-configured runner.

## Work

- Extend `Runner.load_elf(...)` to support both `ELF32` and `ELF64`
- Add `ELF64` loader unit tests with linked-address segment loading and symbol discovery
- Add an XLEN-aware official machine-config helper
- Split official `riscv-tests` build output into RV32 and RV64 roots
- Make the test harness and survey command choose build dir and runner config from manifest `arch`

## Acceptance Criteria

- `ELF64` binaries load successfully through the same runner API
- RV32 loader and official test paths remain unchanged
- Official harness plumbing can route `rv64*` cases without manual config edits

## Related Milestone

- `RV64 transition`

## Dependencies

- [Task 0034](0034-rv64-carry-forward-of-c-zicsr-zifencei.md)

## Status

- `done`

## Completion Notes

- `Runner.load_elf(...)` now handles both `ELF32` and `ELF64` little-endian RISC-V files
- Official build roots are split into `_build/riscv-tests-src/isa` and `_build/riscv-tests-src-rv64/isa`
- The official harness chooses runner config and artifact path from manifest `arch`
