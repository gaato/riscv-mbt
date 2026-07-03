# Milestone 07: Linux Boot Platform Integration

## Purpose

Treat Linux boot as a system-integration milestone that proves the platform hangs together, not merely as proof of ISA coverage.

## Target Instructions / Features

- Privileged execution sufficient for Linux boot
- MMU implementation on the chosen Linux path
- Boot ABI requirements from the Linux RISC-V boot contract: `a0` contains the current hart id, `a1` points to the devicetree in guest physical memory, and `satp = 0` at kernel entry
- RV64 kernel Image placement at a 2 MiB PMD boundary
- Firmware/protected-memory description through devicetree reserved-memory or an equivalent firmware memory map when resident firmware regions matter
- SBI-compatible boot flow, ideally through OpenSBI
- `QEMU virt`-style platform assumptions where practical

## Non-Goals

- Full post-Linux compatibility coverage
- Rich front-end hosting

## Exit Criteria

- Linux emits boot logs through the emulated serial path
- The boot flow is documented and reproducible
- Platform assumptions are explicit in repo docs
- Linux boot assumptions cite the upstream kernel boot requirements instead of remaining repo-local folklore

## Required Tests

- Focused MMU and privileged tests
- Boot-path smoke tests
- Device-access smoke tests for the minimum Linux path

## Implementation Order

1. `S`-mode trap surface and supervisor trap entry
2. delegation routing and `SRET`
3. `Sv39` and `SFENCE.VMA`
4. platform and boot ABI integration

## Current Checkpoint

- This milestone is complete
- `S`-mode and delegation, `Sv39` and `SFENCE.VMA`, OpenSBI/platform integration, Linux boot ABI, and SMP follow-through are all closed in repo tasks
- Linux-path assumptions are now recorded in repo docs rather than left implicit
- The Linux boot ABI reference for future changes is <https://docs.kernel.org/arch/riscv/boot.html>

## Prerequisites For Next Milestone

- A successful and repeatable Linux boot
