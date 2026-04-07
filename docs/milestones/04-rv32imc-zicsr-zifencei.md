# Milestone 04: RV32IMC + Zicsr + Zifencei

## Purpose

Turn the compressed 32-bit core into the first practical standalone CPU target for system-facing experiments.

## Target Instructions / Features

- The six `Zicsr` instructions
- `FENCE.I` from `Zifencei`
- A documented minimum CSR surface before privileged mode

## Non-Goals

- Full privileged architecture
- MMU and devices
- Linux boot

## Exit Criteria

- CSR instruction tests pass
- `FENCE.I` has at least one behavior-focused regression test
- Docs describe this stage as the first practical standalone CPU checkpoint

## Required Tests

- CSR read/write and side-effect tests
- Fetch synchronization tests or equivalent self-modifying-code micro-tests

## Prerequisites For Next Milestone

- Stable CSR semantics to carry into machine mode
