# Task 0008: Add Minimal M-mode

## Background

Minimal machine mode is the point where the project shifts from "CPU core" to "system substrate".
This task is an umbrella that tracks the staged implementation slices below.

## Work

- Keep `Minimal M-mode` work as small, testable slices
- Complete [Task 0028](0028-machine-reset-and-trap-entry.md): reset + trap-entry invariants
- Complete [Task 0029](0029-machine-return-and-mstatus.md): `MRET` + `mstatus` transition semantics
- Complete [Task 0030](0030-mip-skeleton-and-machine-csr-contract.md): `mip` skeleton + machine CSR contract

## Acceptance Criteria

- Tasks `0028`, `0029`, and `0030` are all `done`
- Trap entry, trap return, and machine-state invariants are explicit in tests
- The docs describe the machine CSR contract and `mip` skeleton behavior clearly

## Related Milestone

- `Minimal M-mode`

## Dependencies

- [Task 0007](0007-rv32imc-zicsr-zifencei.md)

## Completion Notes

- [Task 0028](0028-machine-reset-and-trap-entry.md) made reset and trap-entry invariants explicit.
- [Task 0029](0029-machine-return-and-mstatus.md) hardened `MRET` and `mstatus` transition semantics.
- [Task 0030](0030-mip-skeleton-and-machine-csr-contract.md) added `mip` as machine-state storage and made the machine CSR contract explicit.
- `Minimal M-mode` is now the first coherent machine-mode checkpoint for the project.

## Status

- `done`
