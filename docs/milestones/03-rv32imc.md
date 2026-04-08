# Milestone 03: RV32IMC

## Purpose

Introduce compressed instructions after the 32-bit integer core is stable.

## Target Instructions / Features

- 16-bit instruction fetch and length detection
- Compressed decode path and expansion strategy
- `RV32IMC` execution compatibility

## Non-Goals

- 64-bit widening
- Privileged mode

## Exit Criteria

- Mixed 16/32-bit programs run correctly
- `pc` updates remain correct across instruction widths
- Built upstream `*-p-*` survey results show `rv32ui`, `rv32um`, and the current `rv32uc` coverage passing

## Required Tests

- Instruction-length tests
- Integration tests that jump across compressed and non-compressed instructions

## Prerequisites For Next Milestone

- Fetch/decode abstraction clean enough to add `RV64I`
- `RV32IMC` docs and survey status explicitly closed before CSR/FENCE.I hardening
