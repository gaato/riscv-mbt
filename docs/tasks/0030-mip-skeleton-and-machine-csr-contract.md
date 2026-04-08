# Task 0030: Mip Skeleton And Machine CSR Contract

## Background

This slice completes the first `Minimal M-mode` checkpoint by adding `mip`
as explicit machine state and documenting which CSRs are modeled vs
compatibility-only storage.

## Work

- Add `CSR_MIP` as readable/writable machine-state storage
- Keep interrupt delivery out of scope; this is a skeleton only
- Document the machine CSR contract:
  - modeled now: `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mtval`, `misa`, `mhartid`
  - compatibility-only storage: `medeleg`, `mideleg`, `stvec`, `satp`, `pmpcfg0`, `pmpaddr0`, `mnstatus`
  - read-only: `misa`, `mhartid`
- Keep official `env/p` compatibility while making the contract explicit

## Acceptance Criteria

- `mip` exists and can be read/written via CSR instructions
- No interrupt-delivery side effects are introduced in this slice
- The machine CSR contract is explicit in docs and tests
- Existing official `rv32ui` / `rv32um` / `rv32uc` survey paths stay green

## Related Milestone

- `Minimal M-mode`

## Dependencies

- [Task 0029](0029-machine-return-and-mstatus.md)

## Completion Notes

- `CSR_MIP` is now part of the modeled machine CSR set.
- `mip` is readable and writable through the existing checked CSR path.
- `mip` is storage only in this slice; no interrupt-delivery behavior is attached.
- The machine CSR contract is explicit in code and tests:
  - modeled now: `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mtval`, `misa`, `mhartid`
  - compatibility-only storage: `medeleg`, `mideleg`, `stvec`, `satp`, `pmpcfg0`, `pmpaddr0`, `mnstatus`
  - read-only: `misa`, `mhartid`

## Status

- `done`
