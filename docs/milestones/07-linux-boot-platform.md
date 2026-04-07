# Milestone 07: Linux Boot Platform Integration

## Purpose

Treat Linux boot as a system-integration milestone that proves the platform hangs together, not merely as proof of ISA coverage.

## Target Instructions / Features

- Privileged execution sufficient for Linux boot
- MMU implementation on the chosen Linux path
- Boot ABI requirements such as `a0`, `a1`, and `satp = 0`
- SBI-compatible boot flow, ideally through OpenSBI
- `QEMU virt`-style platform assumptions where practical

## Non-Goals

- Full post-Linux compatibility coverage
- Rich front-end hosting

## Exit Criteria

- Linux emits boot logs through the emulated serial path
- The boot flow is documented and reproducible
- Platform assumptions are explicit in repo docs

## Required Tests

- Focused MMU and privileged tests
- Boot-path smoke tests
- Device-access smoke tests for the minimum Linux path

## Prerequisites For Next Milestone

- A successful and repeatable Linux boot
