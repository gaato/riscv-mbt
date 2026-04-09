# Task 0014: Integrate OpenSBI And A Virt-Like Platform

## Background

The fastest route to Linux boot is not a bespoke board model. It is a platform close enough to `QEMU virt` that observability, timers, interrupts, and device-tree expectations line up.

## Work

- Use OpenSBI as the early SBI path instead of inventing a fully custom SBI first
- Add a `virt`-like machine model with UART, timer, interrupt plumbing, and DTB expectations
- Make Linux bring-up observable through serial output as early as possible

### Completed sub-tasks

- ✅ Extended `MachineConfig` with `uart0_base`, `clint_base`, `plic_base`, `dtb_addr` fields
- ✅ Added `virt_machine_config()` with QEMU virt-like addresses
- ✅ Added MMIO physical access layer: `phy_contains`, `phy_load_u8/u16/u32/u64`, `phy_store_u8/u16/u32/u64`
- ✅ UART 16550A minimum: THR write (offset 0) captured in `uart_output`, LSR read (offset 5) returns 0x60
- ✅ CLINT minimum: `mtime` (offset 0xBFF8) and `mtimecmp[0]` (offset 0x4000) read/write via byte/half/word/dword MMIO
- ✅ Public accessors: `uart_drain()`, `clint_mtime()`, `clint_mtimecmp()`
- ✅ 5 new MMIO tests (91 total, 0 failed)

### Remaining

- Interrupt injection: `MIP.MTIP` when `mtime >= mtimecmp`
- PLIC minimum (claim/complete registers) — needed for external IRQ delivery to S-mode
- DTB blob loading and `a1` boot ABI
- OpenSBI smoke test (binary boot, serial output observed via `uart_drain`)

## Acceptance Criteria

- The platform is documented in terms of its Linux/OpenSBI assumptions
- Serial output and timer/interrupt basics exist before full Linux boot succeeds

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0013](0013-sv39-and-sfence-vma.md)

## Status

- `doing`
