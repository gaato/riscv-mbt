# Task 0024: Load Official `riscv-tests` Binaries

## Background

The repo can already build official `rv32ui-p-*` binaries with the GNU
toolchain, but the emulator still assumes a simple flat program load at address
`0x00000000`.

Official `riscv-tests` binaries are linked for a machine-style memory layout
and need a loader that can place sections at their linked addresses.

## Work

- Add a minimal ELF loading path for official `riscv-tests` binaries
- Respect section addresses instead of flattening everything to `0x00000000`
- Make entry point and `tohost` / signature-related symbols observable to the runner
- Keep the loader small and specific to current `riscv-tests` bring-up needs

## Acceptance Criteria

- The emulator can ingest an official `rv32ui-p-*` ELF without manual relinking
- Program sections land at the addresses expected by the binary
- The runner can start execution from the ELF entry point

## Related Milestone

- `RV32IM`

## Dependencies

- [Task 0004](0004-riscv-tests-integration.md)

## Status

- `done`
