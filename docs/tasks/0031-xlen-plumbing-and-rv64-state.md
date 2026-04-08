# Task 0031: XLEN Plumbing And RV64 State

## Background

Before RV64-specific instruction semantics can be tested cleanly, the core needs widened architectural state and an explicit XLEN switch without breaking the existing RV32 default path.

## Work

- Add an explicit `Xlen` configuration surface
- Widen machine state, CSR storage, and address-bearing fields to RV64-capable internal types
- Keep the public default configuration and official regression path on `RV32`
- Preserve the current ELF32 loader and RV32 official test flow during the transition

## Acceptance Criteria

- `rv64_machine_config()` exists as an explicit RV64 test entry point
- Internal architectural state is widened to support RV64 execution
- Existing RV32 regression remains green

## Status

- `done`

## Completion Notes

- Added `Xlen32 | Xlen64` and threaded XLEN through `MachineConfig`
- Widened internal architectural state, CSR storage, and bus addresses to `UInt64`
- Kept `default_machine_config()` and official RV32 regression on the RV32 path, with compatibility accessors preserved for existing tests and commands
