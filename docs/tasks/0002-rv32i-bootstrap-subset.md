# Task 0002: Implement The RV32I Bootstrap Subset

## Background

The first code checkpoint should prove that the MoonBit project shape, public interfaces, and test harness can support real CPU work.

## Work

- Create `CpuState`, `Bus`, `Instruction`, `StepResult`, `Runner`, and `MachineConfig`
- Support a bootstrap subset of `RV32I`
- Add decode, execute, and integration tests
- Wire a simple CLI demo

## Acceptance Criteria

- `moon test` passes
- A small hand-assembled program can run through the CLI demo
- Unsupported instructions trap instead of silently misbehaving

## Related Milestone

- `RV32I`

## Dependencies

- [Task 0001](0001-bootstrap-operating-system.md)

## Status

- `done`
