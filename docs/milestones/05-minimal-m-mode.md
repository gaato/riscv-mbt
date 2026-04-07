# Milestone 05: Minimal M-mode

## Purpose

Cross the boundary from CPU implementation into system implementation by adding the smallest coherent machine-mode environment.

## Target Instructions / Features

- Reset-to-M-mode behavior
- `mtvec`, `mstatus`, `mepc`, `mcause`, `mie`, `mip`
- Trap entry and return skeleton
- Explicit machine-level invariants

## Non-Goals

- Full supervisor mode
- MMU
- Linux boot

## Exit Criteria

- Trap entry and return tests pass
- Reset assumptions and machine-mode behavior are explicit in docs and tests

## Required Tests

- Trap routing tests
- CSR-state transition tests around trap entry and exit

## Prerequisites For Next Milestone

- Stable machine-mode control flow
