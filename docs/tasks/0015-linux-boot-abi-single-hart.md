# Task 0015: Meet The Linux Boot ABI On One Hart

## Background

A large class of early Linux boot failures are not MMU bugs but boot-state mismatches such as wrong register conventions or a bad initial `satp` state.

## Work

- Meet the expected `a0`, `a1`, and `satp = 0` boot conditions
- Respect image placement and alignment constraints that matter on the chosen path
- Bring up Linux on a single hart first

## Linux Entry Contract

Use the upstream Linux RISC-V boot requirements as the normative source for this task: <https://docs.kernel.org/arch/riscv/boot.html>.

For the current direct devicetree, RV64, OpenSBI handoff path:

- `a0` contains the current hart id at kernel entry
- `a1` contains the guest physical address of the devicetree
- `satp = 0` at kernel entry, so the kernel starts with the MMU disabled
- the kernel Image is placed at an RV64 PMD boundary, which is 2 MiB aligned
- resident firmware or protected memory must be described through devicetree `/reserved-memory` or an equivalent firmware memory map before the platform relies on such regions
- one-hart boot remains the baseline; SMP work should follow the ordered booting model with SBI HSM when hart lifecycle support is in scope

## Acceptance Criteria

- Linux boot logs appear on one hart
- Boot assumptions are documented separately from MMU correctness
- The documented boot assumptions map back to the upstream Linux RISC-V boot requirements

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0014](0014-opensbi-and-virt-platform.md)

## Progress

- ✅ Minimal DTB generator (`tools/build_minimal_dtb.py`) replaces QEMU virt DTB dependency
- ✅ S-mode entry stub (`tools/c-samples/smode-entry/smode_entry.S`) built at 0x80200000
- ✅ Test "Task 0015: S-mode entry stub via OpenSBI handoff" — OpenSBI boots fully, delegates to S-mode stub, stub prints "Linux ABI: S-mode entry OK" via UART after 4M steps
- ✅ `a0` (hart_id) and `a1` (dtb_addr) correctly delivered by OpenSBI; initial `satp = 0` boot state confirmed
- ✅ Load real Debian riscv64 Linux kernel at 0x80200000
- ✅ Kernel placement uses the RV64 2 MiB PMD boundary required by the Linux boot contract
- ✅ Implement M-mode interrupt delivery (`take_pending_interrupt()`)
- ✅ Fix satp WARL: reject unsupported paging modes (Sv57/mode=10 → mode=0) so kernel
  falls back to Sv39 instead of using an unimplemented 5-level page table scheme
- ✅ Kernel prints `[    0.000000] Linux version 6.12.73+deb13-riscv64` at ~19M steps

## Status

- `done`
