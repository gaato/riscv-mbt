# Milestone 05: Minimal M-mode

## Purpose

Cross the boundary from CPU implementation into system implementation by adding the smallest coherent machine-mode environment.

## Target Instructions / Features

- Reset-to-M-mode behavior
- `mtvec`, `mstatus`, `mepc`, `mcause`, `mie`, `mip`
- Trap entry and return skeleton
- Explicit machine-level invariants

## Implementation Order

1. Reset + trap entry ([Task 0028](../tasks/0028-machine-reset-and-trap-entry.md))
2. `MRET` + `mstatus` transitions ([Task 0029](../tasks/0029-machine-return-and-mstatus.md))
3. `mip` + machine CSR contract ([Task 0030](../tasks/0030-mip-skeleton-and-machine-csr-contract.md))

## Non-Goals

- Full supervisor mode
- MMU
- Linux boot

## Exit Criteria

- Trap entry and return tests pass
- Reset assumptions and machine-mode behavior are explicit in docs and tests

## Completion Notes

- Reset, trap-entry, and trap-return invariants are now explicit in execute tests.
- `mip` exists as machine-state storage with no interrupt-delivery behavior attached yet.
- The machine CSR contract is explicit in code and task docs.
- `Minimal M-mode` is complete and the mainline next step is the `RV64 transition`.

## Required Tests

- Trap routing tests
- CSR-state transition tests around trap entry and exit

## Prerequisites For Next Milestone

- Stable machine-mode control flow
