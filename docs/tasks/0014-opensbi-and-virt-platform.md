# Task 0014: Integrate OpenSBI And A Virt-Like Platform

## Background

The fastest route to Linux boot is not a bespoke board model. It is a platform close enough to `QEMU virt` that observability, timers, interrupts, and device-tree expectations line up.

## Work

- Use OpenSBI as the early SBI path instead of inventing a fully custom SBI first
- Add a `virt`-like machine model with UART, timer, interrupt plumbing, and DTB expectations
- Make Linux bring-up observable through serial output as early as possible

## Acceptance Criteria

- The platform is documented in terms of its Linux/OpenSBI assumptions
- Serial output and timer/interrupt basics exist before full Linux boot succeeds

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0013](0013-sv39-and-sfence-vma.md)

## Status

- `todo`
