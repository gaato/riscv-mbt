# Task 0016: Add SMP After Single-Hart Boot

## Background

SMP multiplies the number of moving parts. It should be introduced only after one-hart Linux boot is stable.

## Work

- Refactored `Runner` to use shareable `Array` fields (`mtime`, `clint_msip`, `all_mtimecmp`, `plic_regs`) so multiple harts can share a single bus and device state
- Added `make_smp_runners(config, num_harts)` factory that creates N runners sharing all platform state
- Extended CLINT to support per-hart MSIP (offset `4*hartid`) and per-hart mtimecmp (offset `0x4000+8*hartid`) for up to 2 harts
- `update_timer()` now reflects CLINT MSIP into `MIP.MSIP` (bit 3) each step
- Added `tools/minimal-smp.dts` (2-hart DTS) and `_build/minimal-smp.dtb`
- Added Task 0016 SMP test: two harts run alternately; verified that the kernel boots and produces `Linux version` output with a 2-hart DTB at ~42M total steps

## Acceptance Criteria

- One-hart boot remains stable ✓ (Task 0015 test unchanged, 107/108 original tests pass)
- Secondary-hart bring-up is testable and documented separately ✓ (Task 0016 test added, 108/108 pass total)

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0015](0015-linux-boot-abi-single-hart.md)

## Status

- `done`
