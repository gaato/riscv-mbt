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
- ✅ MIP.MTIP injection when `mtime >= mtimecmp`
- ✅ CSR_SIE/CSR_SIP constants and M→S masking
- ✅ PLIC minimum (source-enable, priority, threshold, claim/complete registers)
- ✅ DTB blob loading at `dtb_addr`, `a1` boot ABI via `setup_boot_abi()`
- ✅ WFI instruction (NOP behavior for single-hart)
- ✅ A extension: LR/SC always succeed single-hart, all AMO ops (AMOSWAP/ADD/XOR/AND/OR/MIN/MAX/MINU/MAXU) for W and D widths
- ✅ Updated misa to 0x141105 (IMACSU)
- ✅ RV64C extensions: C.LD, C.SD, C.LDSP, C.SDSP, C.ADDIW, C.SUBW, C.ADDW
- ✅ Fixed C.SRLI/C.SRAI decode to allow 6-bit shift amounts (shamt ≥ 32) in RV64
- ✅ Expanded CSR surface: mscratch, mvendorid, marchid, mimpid, mcounteren, scounteren, menvcfg, senvcfg
- ✅ OpenSBI `fw_dynamic` smoke test: loads real binary + DTB, observes banner via `uart_drain()`
- ✅ OpenSBI v1.7 banner verified: "OpenSBI v1.7" printed (315 chars) after 10M steps (105 tests, 0 failed)

### Remaining

- (none — smoke test passes)

## Acceptance Criteria

- The platform is documented in terms of its Linux/OpenSBI assumptions
- Serial output and timer/interrupt basics exist before full Linux boot succeeds

## Related Milestone

- `Linux boot platform integration`

## Dependencies

- [Task 0013](0013-sv39-and-sfence-vma.md)

## Status

- `done`
