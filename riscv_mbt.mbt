// Core architectural state, public runner API, memory bus, ELF loading, and
// machine presets. Keep hardware-facing constants here so execution, decode,
// and platform code share one architectural vocabulary.

///|
pub enum Xlen {
  Xlen32
  Xlen64
}

///|
pub fn xlen32() -> Xlen {
  Xlen32
}

///|
pub fn xlen64() -> Xlen {
  Xlen64
}

///|
pub struct MachineConfig {
  // The emulator has one config object rather than scattered global board
  // constants so tests can swap between bare RV32, RV64, virt, and virtio-blk
  // shapes without changing core execution code.
  xlen : Xlen
  extensions : UInt64
  ram_base : UInt64
  ram_size : Int32
  entry_point : UInt64
  hart_id : UInt64
  uart0_base : UInt64
  clint_base : UInt64
  plic_base : UInt64
  virtio_blk_base : UInt64
  dtb_addr : UInt64
}

///|
pub(all) enum PrivilegeMode {
  User
  Supervisor
  Machine
}

///|
pub struct CsrFile {
  registers : Array[UInt64]
}

///|
pub struct CpuState {
  mut pc : UInt64
  registers : Array[UInt64]
  fregisters : Array[UInt64]
  vregisters : Array[UInt64]
  csrs : CsrFile
  mut privilege : PrivilegeMode
}

///|
pub struct Bus {
  /// Guest physical address corresponding to byte offset zero.
  base_addr : UInt64
  /// Little-endian guest RAM packed into host 64-bit words.
  words : FixedArray[UInt64]
  /// Exact guest-visible RAM size in bytes, excluding padding in `words`.
  size : Int32
}

///|
pub struct ElfInfo {
  entry_point : UInt64
  tohost_addr : UInt64?
  fromhost_addr : UInt64?
  begin_signature_addr : UInt64?
  end_signature_addr : UInt64?
}

///|
pub enum LoadElfResult {
  Loaded(ElfInfo)
  LoadError(String)
}

///|
pub enum Instruction {
  // This enum is the decoded internal ISA surface. Keep constructors explicit
  // even when several encodings share execution helpers; tests assert decode
  // shape separately from behavior so Linux failures can be traced precisely.
  Fence
  FenceI
  Lui(Int32, UInt32)
  Auipc(Int32, UInt32)
  Addi(Int32, Int32, Int32)
  Slti(Int32, Int32, Int32)
  Sltiu(Int32, Int32, Int32)
  Xori(Int32, Int32, Int32)
  Ori(Int32, Int32, Int32)
  Andi(Int32, Int32, Int32)
  Addiw(Int32, Int32, Int32)
  Slli(Int32, Int32, Int32)
  Srli(Int32, Int32, Int32)
  Srai(Int32, Int32, Int32)
  Slliw(Int32, Int32, Int32)
  Srliw(Int32, Int32, Int32)
  Sraiw(Int32, Int32, Int32)
  Add(Int32, Int32, Int32)
  Sub(Int32, Int32, Int32)
  Addw(Int32, Int32, Int32)
  Subw(Int32, Int32, Int32)
  Mul(Int32, Int32, Int32)
  Mulw(Int32, Int32, Int32)
  Mulh(Int32, Int32, Int32)
  Mulhsu(Int32, Int32, Int32)
  Mulhu(Int32, Int32, Int32)
  Div(Int32, Int32, Int32)
  Divw(Int32, Int32, Int32)
  Divu(Int32, Int32, Int32)
  Divuw(Int32, Int32, Int32)
  Rem(Int32, Int32, Int32)
  Remw(Int32, Int32, Int32)
  Remu(Int32, Int32, Int32)
  Remuw(Int32, Int32, Int32)
  Sll(Int32, Int32, Int32)
  Sllw(Int32, Int32, Int32)
  Slt(Int32, Int32, Int32)
  Sltu(Int32, Int32, Int32)
  Xor(Int32, Int32, Int32)
  Srl(Int32, Int32, Int32)
  Sra(Int32, Int32, Int32)
  Srlw(Int32, Int32, Int32)
  Sraw(Int32, Int32, Int32)
  Or(Int32, Int32, Int32)
  And(Int32, Int32, Int32)
  Beq(Int32, Int32, Int32)
  Bne(Int32, Int32, Int32)
  Blt(Int32, Int32, Int32)
  Bge(Int32, Int32, Int32)
  Bltu(Int32, Int32, Int32)
  Bgeu(Int32, Int32, Int32)
  Lb(Int32, Int32, Int32)
  Lh(Int32, Int32, Int32)
  Lw(Int32, Int32, Int32)
  Flw(Int32, Int32, Int32)
  Fld(Int32, Int32, Int32)
  Lwu(Int32, Int32, Int32)
  Ld(Int32, Int32, Int32)
  Lbu(Int32, Int32, Int32)
  Lhu(Int32, Int32, Int32)
  Sb(Int32, Int32, Int32)
  Sh(Int32, Int32, Int32)
  Sw(Int32, Int32, Int32)
  Fsw(Int32, Int32, Int32)
  Fsd(Int32, Int32, Int32)
  Sd(Int32, Int32, Int32)
  FMAddS(Int32, Int32, Int32, Int32, UInt32)
  FMSubS(Int32, Int32, Int32, Int32, UInt32)
  FNMSubS(Int32, Int32, Int32, Int32, UInt32)
  FNMAddS(Int32, Int32, Int32, Int32, UInt32)
  FMAddD(Int32, Int32, Int32, Int32, UInt32)
  FMSubD(Int32, Int32, Int32, Int32, UInt32)
  FNMSubD(Int32, Int32, Int32, Int32, UInt32)
  FNMAddD(Int32, Int32, Int32, Int32, UInt32)
  FAddS(Int32, Int32, Int32, UInt32)
  FSubS(Int32, Int32, Int32, UInt32)
  FMulS(Int32, Int32, Int32, UInt32)
  FDivS(Int32, Int32, Int32, UInt32)
  FSqrtS(Int32, Int32, UInt32)
  FMinS(Int32, Int32, Int32)
  FMaxS(Int32, Int32, Int32)
  FSgnjS(Int32, Int32, Int32)
  FSgnjnS(Int32, Int32, Int32)
  FSgnjxS(Int32, Int32, Int32)
  FLeS(Int32, Int32, Int32)
  FLtS(Int32, Int32, Int32)
  FEqS(Int32, Int32, Int32)
  FClassS(Int32, Int32)
  FAddD(Int32, Int32, Int32, UInt32)
  FSubD(Int32, Int32, Int32, UInt32)
  FMulD(Int32, Int32, Int32, UInt32)
  FDivD(Int32, Int32, Int32, UInt32)
  FSgnjD(Int32, Int32, Int32)
  FSgnjnD(Int32, Int32, Int32)
  FSgnjxD(Int32, Int32, Int32)
  FSqrtD(Int32, Int32, UInt32)
  FMinD(Int32, Int32, Int32)
  FMaxD(Int32, Int32, Int32)
  FLeD(Int32, Int32, Int32)
  FLtD(Int32, Int32, Int32)
  FEqD(Int32, Int32, Int32)
  FClassD(Int32, Int32)
  FmvXW(Int32, Int32)
  FmvWX(Int32, Int32)
  FmvXD(Int32, Int32)
  FmvDX(Int32, Int32)
  FCvtSD(Int32, Int32, UInt32)
  FCvtDS(Int32, Int32, UInt32)
  FCvtSW(Int32, Int32, UInt32)
  FCvtSWU(Int32, Int32, UInt32)
  FCvtSL(Int32, Int32, UInt32)
  FCvtSLU(Int32, Int32, UInt32)
  FCvtDW(Int32, Int32, UInt32)
  FCvtDWU(Int32, Int32, UInt32)
  FCvtDL(Int32, Int32, UInt32)
  FCvtDLU(Int32, Int32, UInt32)
  FCvtWS(Int32, Int32, UInt32)
  FCvtWUS(Int32, Int32, UInt32)
  FCvtLS(Int32, Int32, UInt32)
  FCvtLUS(Int32, Int32, UInt32)
  FCvtWD(Int32, Int32, UInt32)
  FCvtWUD(Int32, Int32, UInt32)
  FCvtLD(Int32, Int32, UInt32)
  FCvtLUD(Int32, Int32, UInt32)
  Vsetvli(Int32, Int32, UInt32)
  Vsetivli(Int32, UInt32, UInt32)
  Vsetvl(Int32, Int32, Int32)
  VmvVI(Int32, Int32)
  VmvVX(Int32, Int32)
  VmvVV(Int32, Int32)
  VmvXS(Int32, Int32)
  VmergeVvm(Int32, Int32, Int32)
  VmergeVxm(Int32, Int32, Int32)
  VmergeVim(Int32, Int32, Int32)
  VaddVv(Int32, Int32, Int32)
  VaddVx(Int32, Int32, Int32)
  VaddVi(Int32, Int32, Int32)
  VsubVv(Int32, Int32, Int32)
  VsubVx(Int32, Int32, Int32)
  VrsubVx(Int32, Int32, Int32)
  VrsubVi(Int32, Int32, Int32)
  VwadduVv(Int32, Int32, Int32)
  VwadduVx(Int32, Int32, Int32)
  VwaddVv(Int32, Int32, Int32)
  VwaddVx(Int32, Int32, Int32)
  VwsubuVv(Int32, Int32, Int32)
  VwsubuVx(Int32, Int32, Int32)
  VwsubVv(Int32, Int32, Int32)
  VwsubVx(Int32, Int32, Int32)
  VmulVv(Int32, Int32, Int32)
  VmulVx(Int32, Int32, Int32)
  VmulhuVv(Int32, Int32, Int32)
  VmulhuVx(Int32, Int32, Int32)
  VmulhVv(Int32, Int32, Int32)
  VmulhVx(Int32, Int32, Int32)
  VmulhsuVv(Int32, Int32, Int32)
  VmulhsuVx(Int32, Int32, Int32)
  VdivuVv(Int32, Int32, Int32)
  VdivuVx(Int32, Int32, Int32)
  VdivVv(Int32, Int32, Int32)
  VdivVx(Int32, Int32, Int32)
  VremuVv(Int32, Int32, Int32)
  VremuVx(Int32, Int32, Int32)
  VremVv(Int32, Int32, Int32)
  VremVx(Int32, Int32, Int32)
  VminuVv(Int32, Int32, Int32)
  VminuVx(Int32, Int32, Int32)
  VminVv(Int32, Int32, Int32)
  VminVx(Int32, Int32, Int32)
  VmaxuVv(Int32, Int32, Int32)
  VmaxuVx(Int32, Int32, Int32)
  VmaxVv(Int32, Int32, Int32)
  VmaxVx(Int32, Int32, Int32)
  VmseqVv(Int32, Int32, Int32)
  VmseqVx(Int32, Int32, Int32)
  VmseqVi(Int32, Int32, Int32)
  VmsneVv(Int32, Int32, Int32)
  VmsneVx(Int32, Int32, Int32)
  VmsneVi(Int32, Int32, Int32)
  VmsltuVv(Int32, Int32, Int32)
  VmsltuVx(Int32, Int32, Int32)
  VmsltVv(Int32, Int32, Int32)
  VmsltVx(Int32, Int32, Int32)
  VmsleuVv(Int32, Int32, Int32)
  VmsleuVx(Int32, Int32, Int32)
  VmsleuVi(Int32, Int32, Int32)
  VmsleVv(Int32, Int32, Int32)
  VmsleVx(Int32, Int32, Int32)
  VmsleVi(Int32, Int32, Int32)
  VmsgtuVx(Int32, Int32, Int32)
  VmsgtuVi(Int32, Int32, Int32)
  VmsgtVx(Int32, Int32, Int32)
  VmsgtVi(Int32, Int32, Int32)
  VmandMm(Int32, Int32, Int32)
  VmnandMm(Int32, Int32, Int32)
  VmandnMm(Int32, Int32, Int32)
  VmxorMm(Int32, Int32, Int32)
  VmorMm(Int32, Int32, Int32)
  VmnorMm(Int32, Int32, Int32)
  VmornMm(Int32, Int32, Int32)
  VmxnorMm(Int32, Int32, Int32)
  VcpopM(Int32, Int32)
  VfirstM(Int32, Int32)
  VmsbfM(Int32, Int32)
  VmsofM(Int32, Int32)
  VmsifM(Int32, Int32)
  ViotaM(Int32, Int32)
  VidV(Int32)
  VcompressVm(Int32, Int32, Int32)
  VrgatherVv(Int32, Int32, Int32)
  VrgatherVx(Int32, Int32, Int32)
  VrgatherVi(Int32, Int32, Int32)
  VslideupVx(Int32, Int32, Int32)
  VslideupVi(Int32, Int32, Int32)
  VslidedownVx(Int32, Int32, Int32)
  VslidedownVi(Int32, Int32, Int32)
  Vslide1upVx(Int32, Int32, Int32)
  Vslide1downVx(Int32, Int32, Int32)
  VmvNrR(Int32, Int32, Int32)
  VsllVv(Int32, Int32, Int32)
  VsllVx(Int32, Int32, Int32)
  VsllVi(Int32, Int32, Int32)
  VsrlVv(Int32, Int32, Int32)
  VsrlVx(Int32, Int32, Int32)
  VsrlVi(Int32, Int32, Int32)
  VsraVv(Int32, Int32, Int32)
  VsraVx(Int32, Int32, Int32)
  VsraVi(Int32, Int32, Int32)
  VandVv(Int32, Int32, Int32)
  VandVx(Int32, Int32, Int32)
  VandVi(Int32, Int32, Int32)
  VorVv(Int32, Int32, Int32)
  VorVx(Int32, Int32, Int32)
  VorVi(Int32, Int32, Int32)
  VxorVv(Int32, Int32, Int32)
  VxorVx(Int32, Int32, Int32)
  VxorVi(Int32, Int32, Int32)
  VlmV(Int32, Int32)
  Vle8V(Int32, Int32)
  Vle16V(Int32, Int32)
  Vle32V(Int32, Int32)
  Vle64V(Int32, Int32)
  Vle8ffV(Int32, Int32)
  Vle16ffV(Int32, Int32)
  Vle32ffV(Int32, Int32)
  Vle64ffV(Int32, Int32)
  Vlseg2e32V(Int32, Int32)
  Vluxei32V(Int32, Int32, Int32)
  Vloxei32V(Int32, Int32, Int32)
  Vlse32V(Int32, Int32, Int32)
  VsmV(Int32, Int32)
  Vse8V(Int32, Int32)
  Vse16V(Int32, Int32)
  Vse32V(Int32, Int32)
  Vse64V(Int32, Int32)
  Vsseg2e32V(Int32, Int32)
  Vsuxei32V(Int32, Int32, Int32)
  Vsoxei32V(Int32, Int32, Int32)
  Vsse32V(Int32, Int32, Int32)
  Jal(Int32, Int32)
  Jalr(Int32, Int32, Int32)
  Csrrw(Int32, Int32, Int32)
  Csrrs(Int32, Int32, Int32)
  Csrrc(Int32, Int32, Int32)
  Csrrwi(Int32, Int32, UInt32)
  Csrrsi(Int32, Int32, UInt32)
  Csrrci(Int32, Int32, UInt32)
  SfenceVma(Int32, Int32)
  Wfi
  AmoW(UInt32, UInt32, Int32, Int32, Int32)
  AmoD(UInt32, UInt32, Int32, Int32, Int32)
  Ecall
  Ebreak
  Mret
  Sret
  Unknown(UInt32)
}

///|
pub enum TrapCause {
  // TrapCause is the architectural cause before it is encoded into mcause or
  // scause. Keep it cause-centric, not handler-centric: delegation decides
  // which privilege mode receives the same underlying event.
  InstructionAddressMisaligned
  InstructionAccessFault
  IllegalInstruction
  Breakpoint
  LoadAddressMisaligned
  LoadAccessFault
  StoreAddressMisaligned
  StoreAccessFault
  InstructionPageFault
  LoadPageFault
  StorePageFault
  EnvironmentCallFromUMode
  EnvironmentCallFromSMode
  EnvironmentCallFromMMode
  // Interrupts (bit 63 set in cause register)
  SupervisorSoftwareInterrupt
  MachineSoftwareInterrupt
  SupervisorTimerInterrupt
  MachineTimerInterrupt
  SupervisorExternalInterrupt
  MachineExternalInterrupt
}

///|
pub struct TrapInfo {
  // StepResult returns traps explicitly so tests and probes can inspect the
  // architectural event without having to parse CSR side effects. Real Linux
  // traps are still entered by raise_trap/enter_*_trap before this is observed.
  cause : TrapCause
  faulting_pc : UInt64
  trap_value : UInt64
}

///|
pub enum StepResult {
  Running
  Trap(TrapInfo)
}

///|
/// Sentinel returned by allocation-free translation and memory checks.
/// Any access of width at least one rejects this address as out of range.
let translate_fault_sentinel : UInt64 = 0xffffffffffffffffUL

///|
let decode_cache_sets : Int32 = 4096

///|
let decode_cache_invalid_tag : UInt64 = bit_not(0U.to_uint64())

///|
let translate_cache_sets : Int32 = 4096

///|
let translate_cache_invalid_vpage : UInt64 = bit_not(0U.to_uint64())

///|
let known_page_table_sets : Int32 = 256

///|
let known_page_table_invalid_ppn : UInt64 = bit_not(0U.to_uint64())

///|
pub struct Runner {
  // Runner owns all mutable machine state for one hart plus the currently
  // modeled platform devices. Shared-device arrays are intentionally stored
  // here until SMP exists; single-hart Linux is the baseline contract.
  cpu : CpuState
  bus : Bus
  config : MachineConfig
  uart_output : Array[Byte]
  uart_input : @queue.Queue[Byte]
  uart_ier : Array[Byte]
  uart_lcr : Array[Byte]
  mtime : Array[UInt64] // [0] = current mtime; shared across SMP harts
  // Architectural performance counters are separate from CLINT mtime: time
  // keeps advancing with the platform timer, while mcountinhibit can stop
  // cycle/instret independently.
  mut mcycle : UInt64
  mut minstret : UInt64
  // raise_trap can still return Running when a trap vector exists. Keep a
  // per-step marker so architectural trap entry is not mistaken for a retired
  // guest instruction by Runner::step.
  mut retire_suppressed : Bool
  /// Cause paired with `translate_fault_sentinel` from `translate_pa`.
  mut last_translate_fault : TrapCause
  /// Physical fetch address written only after `fetch_into_scratch` succeeds.
  mut fetch_pa : UInt64
  /// Raw instruction bits written only after `fetch_into_scratch` succeeds.
  mut fetch_raw : UInt32
  /// Instruction byte length written only after `fetch_into_scratch` succeeds.
  mut fetch_length : Int32
  /// Trap result paired with a sentinel or false hot-path helper result.
  mut pending_step_result : StepResult
  clint_msip : Array[Bool] // [hart_id] = MSIP bit; shared across SMP harts
  all_mtimecmp : Array[UInt64] // [hart_id] = mtimecmp; shared across SMP harts
  plic_regs : Array[Byte] // flat PLIC register file (4 MB); shared across SMP harts
  plic_claimed : Array[Bool] // [source] claimed IP bits awaiting completion
  virtio_blk_state : Array[UInt64]
  virtio_blk_disk : Array[Byte]
  mut virtio_blk_read_cache_base : UInt64
  mut virtio_blk_read_cache_bytes : Bytes
  mut virtio_blk_read_cache_hits : UInt64
  mut virtio_blk_read_cache_misses : UInt64
  mut virtio_blk_read_requests : UInt64
  mut virtio_blk_write_requests : UInt64
  mut virtio_blk_read_bytes : UInt64
  mut virtio_blk_write_bytes : UInt64
  mut virtio_blk_read_first_offset : UInt64
  mut virtio_blk_read_min_offset : UInt64
  mut virtio_blk_read_max_end : UInt64
  mut virtio_blk_read_last_offset : UInt64
  mut virtio_blk_read_last_end : UInt64
  mut virtio_blk_read_sequential_requests : UInt64
  mut virtio_blk_read_forward_gap_requests : UInt64
  mut virtio_blk_read_backward_requests : UInt64
  // LR/SC reservations are shared platform state, indexed by hart id and
  // tracked in physical-address space after translation. The RISC-V A
  // extension allows an implementation-defined reservation set; this emulator
  // models that set as the exact accessed byte range, which is conservative
  // enough for Linux lock/futex loops and lets stores from one hart invalidate
  // another hart's pending SC when the physical ranges overlap.
  lr_sc_reserved_pas : Array[UInt64]
  lr_sc_reserved_sizes : Array[Int32]
  // Decode cache keys by physical fetch address plus raw bits. This avoids
  // mixing Sv39 virtual aliases and keeps cache invalidation tied to fence.i.
  decode_cache_tags : Array[UInt64]
  decode_cache_raws : Array[UInt32]
  decode_cache_lengths : Array[Int32]
  decode_cache_xlens : Array[Int32]
  decode_cache_instructions : Array[Instruction]
  mut decode_cache_hits : UInt64
  mut decode_cache_misses : UInt64
  mut decode_cache_fills : UInt64
  mut decode_cache_flushes : UInt64
  // Translation cache records the privilege and mstatus bits that affect
  // access checks. Page table writes are not tracked precisely; Linux paths
  // rely on sfence.vma to flush this cache at architectural boundaries.
  translate_cache_vpages : Array[UInt64]
  translate_cache_satps : Array[UInt64]
  translate_cache_accesses : Array[Int32]
  translate_cache_privileges : Array[Int32]
  translate_cache_sums : Array[Bool]
  translate_cache_mxrs : Array[Bool]
  translate_cache_pa_pages : Array[UInt64]
  known_page_table_ppns : Array[UInt64]
  mut translate_cache_hits : UInt64
  mut translate_cache_misses : UInt64
  mut translate_cache_fills : UInt64
  mut translate_cache_flushes : UInt64
}

///|
pub fn default_machine_config() -> MachineConfig {
  {
    xlen: Xlen32,
    extensions: current_base_extensions(),
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn official_riscv_tests_machine_config_for_xlen(
  xlen : Xlen,
) -> MachineConfig {
  {
    xlen,
    extensions: current_base_extensions(),
    ram_base: 0x80000000U.to_uint64(),
    ram_size: 0x20000,
    entry_point: 0x80000000U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
fn official_riscv_tests_extensions_for_arch(arch : String) -> UInt64 {
  // The manifest arch column names the ISA profile used to build the upstream
  // ELF. Mirror the relevant MISA bits here so official FP/vector binaries are
  // not accidentally surveyed under the integer-only base profile.
  let mut extensions = current_base_extensions()
  if arch.contains("f") {
    extensions = extensions | MISA_EXT_F
  }
  if arch.contains("d") {
    extensions = extensions | MISA_EXT_F | MISA_EXT_D
  }
  if arch.contains("v") {
    extensions = extensions | MISA_EXT_V
  }
  extensions
}

///|
pub fn official_riscv_tests_machine_config_for_arch(
  arch : String,
) -> MachineConfig {
  let xlen = if arch.has_prefix("rv64") { Xlen64 } else { Xlen32 }
  {
    xlen,
    extensions: official_riscv_tests_extensions_for_arch(arch),
    ram_base: 0x80000000U.to_uint64(),
    ram_size: 0x20000,
    entry_point: 0x80000000U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn official_riscv_tests_machine_config() -> MachineConfig {
  official_riscv_tests_machine_config_for_xlen(Xlen32)
}

///|
pub fn rv64_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions(),
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|

///|
pub fn rv64f_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions() | MISA_EXT_F,
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn rv64fd_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions() | MISA_EXT_F | MISA_EXT_D,
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn rv64fdv_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions() | MISA_EXT_F | MISA_EXT_D | MISA_EXT_V,
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0U.to_uint64(),
    clint_base: 0U.to_uint64(),
    plic_base: 0U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn virt_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions() | MISA_EXT_F | MISA_EXT_D,
    ram_base: 0x80000000U.to_uint64(),
    ram_size: 0x08000000,
    entry_point: 0x80000000U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0x10000000U.to_uint64(),
    clint_base: 0x02000000U.to_uint64(),
    plic_base: 0x0C000000U.to_uint64(),
    virtio_blk_base: 0U.to_uint64(),
    dtb_addr: 0x87E00000U.to_uint64(),
  }
}

///|
pub fn virtio_blk_machine_config() -> MachineConfig {
  let config = virt_machine_config()
  {
    xlen: config.xlen,
    extensions: config.extensions,
    ram_base: config.ram_base,
    ram_size: config.ram_size,
    entry_point: config.entry_point,
    hart_id: config.hart_id,
    uart0_base: config.uart0_base,
    clint_base: config.clint_base,
    plic_base: config.plic_base,
    virtio_blk_base: 0x10001000U.to_uint64(),
    dtb_addr: config.dtb_addr,
  }
}

///|
pub fn CsrFile::new() -> CsrFile {
  { registers: Array::make(4096, 0U.to_uint64()), }
}

///|
pub fn CsrFile::read(self : CsrFile, index : Int32) -> UInt64 {
  self.registers[index]
}

///|
pub fn CsrFile::write(self : CsrFile, index : Int32, value : UInt64) -> Unit {
  self.registers[index] = value
}

///|
const CSR_MSTATUS : Int32 = 0x300

///|
const CSR_MISA : Int32 = 0x301

///|
const CSR_FFLAGS : Int32 = 0x001

///|
const CSR_FRM : Int32 = 0x002

///|
const CSR_FCSR : Int32 = 0x003

///|
const CSR_MEDELEG : Int32 = 0x302

///|
const CSR_MIDELEG : Int32 = 0x303

///|
const MEDELEG_WRITABLE_MASK : UInt64 = 0xb3fe

///|
const MIDELEG_WRITABLE_MASK : UInt64 = 0x222

///|
const CSR_MIE : Int32 = 0x304

///|
const MACHINE_INTERRUPT_MASK : UInt64 = 0xaaa

///|
const CSR_MTVEC : Int32 = 0x305

///|
const CSR_SSTATUS : Int32 = 0x100

///|
const CSR_MEPC : Int32 = 0x341

///|
const CSR_MCAUSE : Int32 = 0x342

///|
const CSR_MTVAL : Int32 = 0x343

///|
const CSR_MIP : Int32 = 0x344

///|
const CSR_STVEC : Int32 = 0x105

///|
const CSR_SSCRATCH : Int32 = 0x140

///|
const CSR_SEPC : Int32 = 0x141

///|
const CSR_SCAUSE : Int32 = 0x142

///|
const CSR_STVAL : Int32 = 0x143

///|
const CSR_SIE : Int32 = 0x104

///|
const CSR_SIP : Int32 = 0x144

///|
const CSR_SATP : Int32 = 0x180

///|
const CSR_PMPCFG0 : Int32 = 0x3A0

///|
const CSR_PMPADDR0 : Int32 = 0x3B0

///|
const CSR_MSCRATCH : Int32 = 0x340

///|
const CSR_MCOUNTEREN : Int32 = 0x306

///|
const CSR_SCOUNTEREN : Int32 = 0x106

///|
const COUNTEREN_WRITABLE_MASK : UInt64 = 0x7

///|
const CSR_MCOUNTINHIBIT : Int32 = 0x320

///|
const CSR_MCYCLE : Int32 = 0xB00

///|
const CSR_MINSTRET : Int32 = 0xB02

///|
const CSR_MCYCLEH : Int32 = 0xB80

///|
const CSR_MINSTRETH : Int32 = 0xB82

///|
const CSR_MHPMCOUNTER3H : Int32 = 0xB83

///|
const CSR_MHPMCOUNTER31H : Int32 = 0xB9F

///|
const MCOUNTINHIBIT_CY_BIT : UInt64 = 0x1

///|
const MCOUNTINHIBIT_IR_BIT : UInt64 = 0x4

///|
const MCOUNTINHIBIT_WRITABLE_MASK : UInt64 = MCOUNTINHIBIT_CY_BIT |
  MCOUNTINHIBIT_IR_BIT

///|
const CSR_MHPMEVENT3H : Int32 = 0x723

///|
const CSR_MHPMEVENT31H : Int32 = 0x73F

///|
const CSR_MENVCFG : Int32 = 0x30A

///|
const CSR_SENVCFG : Int32 = 0x10A

///|
const CSR_CYCLE : Int32 = 0xC00

///|
const CSR_TIME : Int32 = 0xC01

///|
const CSR_INSTRET : Int32 = 0xC02

///|
const CSR_CYCLEH : Int32 = 0xC80

///|
const CSR_TIMEH : Int32 = 0xC81

///|
const CSR_INSTRETH : Int32 = 0xC82

///|
const CSR_HPMCOUNTER3H : Int32 = 0xC83

///|
const CSR_HPMCOUNTER31H : Int32 = 0xC9F

///|
const CSR_MHARTID : Int32 = 0xF14

///|
const CSR_MVENDORID : Int32 = 0xF11

///|
const CSR_MARCHID : Int32 = 0xF12

///|
const CSR_MIMPID : Int32 = 0xF13

///|
// Mandatory machine information CSR. A zero value means there is no standard
// configuration data structure and software should use another discovery path
// such as the device tree supplied by the platform.
const CSR_MCONFIGPTR : Int32 = 0xF15

///|
const CSR_VSTART : Int32 = 0x008

///|
const CSR_VXSAT : Int32 = 0x009

///|
const CSR_VXRM : Int32 = 0x00A

///|
const CSR_VCSR : Int32 = 0x00F

///|
const CSR_VL : Int32 = 0xC20

///|
const CSR_VTYPE : Int32 = 0xC21

///|
const CSR_VLENB : Int32 = 0xC22

///|
const XLEN_32 : Int32 = 32

///|
const XLEN_64 : Int32 = 64

///|
const MSTATUS_SIE_BIT : UInt32 = 0x2U

///|
const MSTATUS_SPIE_BIT : UInt32 = 0x20U

///|
const MSTATUS_SPP_BIT : UInt32 = 0x100U

///|
const MSTATUS_MIE_BIT : UInt32 = 0x8U

///|
const MSTATUS_MPIE_BIT : UInt32 = 0x80U

///|
const MSTATUS_MPP_SHIFT : Int32 = 11

///|
const MSTATUS_MPP_MASK : UInt32 = 0x1800U

///|
const MSTATUS_FS_MASK : UInt64 = 0x6000

///|
const MSTATUS_FS_INITIAL : UInt64 = 0x2000

///|
const MSTATUS_FS_DIRTY : UInt64 = 0x6000

///|
const MSTATUS_SD_BIT : UInt64 = 0x8000000000000000UL

///|
const MSTATUS_UXL_MASK : UInt64 = 0x300000000

///|
const MSTATUS_SXL_MASK : UInt64 = 0xc00000000

///|
const MSTATUS_UXL_64 : UInt64 = 0x200000000

///|
const MSTATUS_SXL_64 : UInt64 = 0x800000000

///|
const MSTATUS_UBE_BIT : UInt64 = 0x40

///|
const MSTATUS_SBE_BIT : UInt64 = 0x1000000000UL

///|
const MSTATUS_MBE_BIT : UInt64 = 0x2000000000UL

///|
const MSTATUS_ENDIAN_MASK : UInt64 = MSTATUS_UBE_BIT |
  MSTATUS_SBE_BIT |
  MSTATUS_MBE_BIT

///|
// Implemented mstatus storage for this fixed RV64GC-style privileged profile.
// It keeps S/M interrupt enables, xPIE/xPP return state, FS, MPRV/SUM/MXR,
// TVM/TW/TSR, fixed-width XLEN/endian placeholders, and derived SD. Unsupported
// user-interrupt, VS, XS, and WPRI/reserved bits are masked out at CSR writes.
const MSTATUS_IMPLEMENTED_MASK : UInt64 = 0x8000003f007e79eaUL

///|
const SSTATUS_VISIBLE_MASK : UInt64 = 0xC0122 |
  MSTATUS_FS_MASK |
  MSTATUS_UXL_MASK |
  MSTATUS_UBE_BIT |
  MSTATUS_SD_BIT
// SIP/SIE visible mask: SSIP(bit 1) | STIP(bit 5) | SEIP(bit 9)

///|
const SIP_VISIBLE_MASK : UInt64 = 0x222

///|
const SIP_WRITABLE_MASK : UInt64 = 0x2

///|
const MSTATUS_MPRV_BIT : UInt64 = 0x20000 // bit 17

///|
const MSTATUS_SUM_BIT : UInt64 = 0x40000 // bit 18

///|
const MSTATUS_MXR_BIT : UInt64 = 0x80000 // bit 19

///|
const MSTATUS_TVM_BIT : UInt64 = 0x100000 // bit 20

///|
const MSTATUS_TW_BIT : UInt64 = 0x200000 // bit 21

///|
const MSTATUS_TSR_BIT : UInt64 = 0x400000 // bit 22

///|
const FCSR_FFLAGS_MASK : UInt64 = 0x1f

///|
const FCSR_FRM_SHIFT : Int32 = 5

///|
const FCSR_FRM_MASK : UInt64 = 0xe0

///|
const FCSR_VISIBLE_MASK : UInt64 = 0xff

///|
const VCSR_VXSAT_MASK : UInt64 = 0x1

///|
const VCSR_VXRM_SHIFT : Int32 = 1

///|
const VCSR_VXRM_MASK : UInt64 = 0x6

///|
const VCSR_VISIBLE_MASK : UInt64 = 0x7

///|
const MISA_EXT_A : UInt64 = 0x1

///|
const MISA_EXT_C : UInt64 = 0x4

///|
const MISA_EXT_D : UInt64 = 0x8

///|
const MISA_EXT_F : UInt64 = 0x20

///|
const MISA_EXT_I : UInt64 = 0x100

///|
const MISA_EXT_M : UInt64 = 0x1000

///|
const MISA_EXT_S : UInt64 = 0x40000

///|
const MISA_EXT_U : UInt64 = 0x100000

///|
const MISA_EXT_V : UInt64 = 0x200000

///|
const VREG_COUNT : Int32 = 32

///|
const VREG_WORDS_PER_REG : Int32 = 2

///|
const VLEN_BYTES : Int32 = 16

///|
fn current_base_extensions() -> UInt64 {
  // Base configs advertise the RV64 Linux baseline we actively execute:
  // integer, multiply/divide, atomics, compressed, supervisor, and user.
  // Floating point and vector support are added explicitly by the configs
  // whose tests or Linux probes need them.
  MISA_EXT_A | MISA_EXT_C | MISA_EXT_I | MISA_EXT_M | MISA_EXT_S | MISA_EXT_U
}

///|
fn canonical_machine_extensions(extensions : UInt64) -> UInt64 {
  // Extension dependencies are part of the architectural profile, not just
  // human-readable ISA strings. Normalize internal test configs before
  // exposing misa or executing gates so impossible profiles cannot leak into
  // later profile checks.
  let mut normalized = extensions
  if (normalized & MISA_EXT_F) == 0U.to_uint64() {
    // D depends on F. When a profile requests D while disabling F, the
    // privileged misa dependency rule says the unsupported pair canonicalizes
    // by clearing the dependent feature as well, not by silently enabling F.
    normalized = normalized & bit_not(MISA_EXT_D)
  }
  if (normalized & MISA_EXT_U) == 0U.to_uint64() {
    // The privileged spec treats S-without-U as an unsupported dependency
    // combination. Clearing U therefore clears S as well.
    normalized = normalized & bit_not(MISA_EXT_S)
  }
  normalized
}

///|
fn misa_value(xlen : Xlen, extensions : UInt64) -> UInt64 {
  let extensions = canonical_machine_extensions(extensions)
  match xlen {
    Xlen32 => (1U.to_uint64() << 30) | extensions
    Xlen64 => (2U.to_uint64() << 62) | extensions
  }
}

///|
fn initial_vtype_value(xlen : Xlen) -> UInt64 {
  match xlen {
    Xlen32 => 1U.to_uint64() << 31
    Xlen64 => 1U.to_uint64() << 63
  }
}

///|
fn xlen_mask(xlen : Int32) -> UInt64 {
  match xlen {
    XLEN_32 => 0xffffffffU.to_uint64()
    XLEN_64 => bit_not(0U.to_uint64())
    _ => abort("unsupported xlen mask")
  }
}

///|
pub fn CpuState::new(
  entry_point : UInt64,
  hart_id : UInt64,
  xlen : Xlen,
  extensions : UInt64,
) -> CpuState {
  // Reset state follows the emulator contract rather than a full hardware
  // reset model: start in M-mode at the supplied firmware entry and expose the
  // requested ISA bits through misa so OpenSBI/Linux can self-configure.
  let csrs = CsrFile::new()
  csrs.write(CSR_MISA, misa_value(xlen, extensions))
  csrs.write(CSR_MHARTID, hart_id)
  csrs.write(CSR_VSTART, 0U.to_uint64())
  csrs.write(CSR_VXSAT, 0U.to_uint64())
  csrs.write(CSR_VXRM, 0U.to_uint64())
  csrs.write(CSR_VCSR, 0U.to_uint64())
  csrs.write(CSR_VL, 0U.to_uint64())
  csrs.write(CSR_VTYPE, initial_vtype_value(xlen))
  csrs.write(CSR_VLENB, VLEN_BYTES.to_uint64())
  {
    pc: entry_point,
    registers: Array::make(32, 0U.to_uint64()),
    fregisters: Array::make(32, 0U.to_uint64()),
    vregisters: Array::make(VREG_COUNT * VREG_WORDS_PER_REG, 0U.to_uint64()),
    csrs,
    privilege: Machine,
  }
}

///|
pub fn CpuState::read_reg(self : CpuState, index : Int32) -> UInt64 {
  if index == 0 {
    0U.to_uint64()
  } else {
    self.registers[index]
  }
}

///|
pub fn CpuState::write_reg(
  self : CpuState,
  index : Int32,
  value : UInt64,
) -> Unit {
  if index != 0 {
    self.registers[index] = value
  }
}

///|
pub fn CpuState::read_freg(self : CpuState, index : Int32) -> UInt64 {
  self.fregisters[index]
}

///|
pub fn CpuState::write_freg(
  self : CpuState,
  index : Int32,
  value : UInt64,
) -> Unit {
  self.fregisters[index] = value
}

///|
pub fn CpuState::read_vreg(
  self : CpuState,
  index : Int32,
  word : Int32,
) -> UInt64 {
  self.vregisters[index * VREG_WORDS_PER_REG + word]
}

///|
pub fn CpuState::write_vreg(
  self : CpuState,
  index : Int32,
  word : Int32,
  value : UInt64,
) -> Unit {
  self.vregisters[index * VREG_WORDS_PER_REG + word] = value
}

///|
pub fn CpuState::read_csr(self : CpuState, index : Int32) -> UInt64 {
  self.csrs.read(index)
}

///|
pub fn CpuState::write_csr(
  self : CpuState,
  index : Int32,
  value : UInt64,
) -> Unit {
  self.csrs.write(index, value)
}

///|
pub fn Bus::new(base_addr : UInt64, size : Int32) -> Bus {
  { base_addr, words: FixedArray::make((size + 7) / 8, 0U.to_uint64()), size, }
}

///|
pub fn Bus::size(self : Bus) -> Int32 {
  self.size
}

///|
fn bus_offset_as_int(offset : UInt64) -> Int32 {
  offset.reinterpret_as_int64().to_int()
}

///|
fn Bus::contains_range(self : Bus, addr : UInt64, width : Int32) -> Bool {
  let start = addr - self.base_addr
  let start_index = bus_offset_as_int(start)
  let end_index = start_index + width
  addr >= self.base_addr && start_index >= 0 && end_index <= self.size
}

///|
/// Trigger the same checked-index failure as the old byte array when an access
/// ends past the exact guest-visible RAM size. A negative offset already
/// panics through the word index, so this is a single comparison on the hot
/// path; it exists because the padding word could otherwise hide an access
/// that straddles the end of a RAM whose size is not a multiple of eight.
fn Bus::check_word_range(self : Bus, offset : Int32, width : Int32) -> Unit {
  if offset > self.size - width {
    ignore(self.words[self.words.length()])
  }
}

///|
/// Return a low-bit mask for one supported scalar memory width.
fn bus_word_mask(width : Int32) -> UInt64 {
  match width {
    1 => 0xffU.to_uint64()
    2 => 0xffffU.to_uint64()
    4 => 0xffffffffU.to_uint64()
    _ => 0xffffffffffffffffUL
  }
}

///|
/// Extract a little-endian scalar from one word, or merge two adjacent words
/// when the byte range crosses a word boundary.
fn Bus::load_word_fragment(self : Bus, offset : Int32, width : Int32) -> UInt64 {
  self.check_word_range(offset, width)
  let word_index = offset >> 3
  let shift = (offset & 7) << 3
  let mask = bus_word_mask(width)
  let low = self.words[word_index] >> shift
  if shift + width * 8 <= 64 {
    low & mask
  } else {
    (low | (self.words[word_index + 1] << (64 - shift))) & mask
  }
}

///|
/// Replace a little-endian scalar with read-modify-write, splitting its bits
/// across two adjacent words when it crosses a word boundary.
fn Bus::store_word_fragment(
  self : Bus,
  offset : Int32,
  width : Int32,
  value : UInt64,
) -> Unit {
  self.check_word_range(offset, width)
  let word_index = offset >> 3
  let shift = (offset & 7) << 3
  let mask = bus_word_mask(width)
  let shifted_mask = mask << shift
  self.words[word_index] = (self.words[word_index] & bit_not(shifted_mask)) |
    ((value & mask) << shift)
  if shift + width * 8 > 64 {
    let low_bits = 64 - shift
    let high_mask = mask >> low_bits
    self.words[word_index + 1] = (
        self.words[word_index + 1] & bit_not(high_mask)
      ) |
      ((value & mask) >> low_bits)
  }
}

///|
fn Bus::load_raw_u8(self : Bus, addr : UInt64) -> UInt32 {
  self.load_word_fragment(bus_offset_as_int(addr - self.base_addr), 1).to_uint()
}

///|
fn Bus::load_raw_u16(self : Bus, addr : UInt64) -> UInt32 {
  self.load_word_fragment(bus_offset_as_int(addr - self.base_addr), 2).to_uint()
}

///|
fn Bus::load_raw_u32(self : Bus, addr : UInt64) -> UInt32 {
  self.load_word_fragment(bus_offset_as_int(addr - self.base_addr), 4).to_uint()
}

///|
pub fn Bus::load_u8(self : Bus, addr : UInt64) -> UInt64 {
  self.load_raw_u8(addr).to_uint64()
}

///|
pub fn Bus::load_u16(self : Bus, addr : UInt64) -> UInt64 {
  self.load_raw_u16(addr).to_uint64()
}

///|
pub fn Bus::load_u32(self : Bus, addr : UInt64) -> UInt64 {
  self.load_raw_u32(addr).to_uint64()
}

///|
pub fn Bus::load_u64(self : Bus, addr : UInt64) -> UInt64 {
  self.load_word_fragment(bus_offset_as_int(addr - self.base_addr), 8)
}

///|
pub fn Bus::store_u8(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.store_word_fragment(bus_offset_as_int(addr - self.base_addr), 1, value)
}

///|
pub fn Bus::store_u16(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.store_word_fragment(bus_offset_as_int(addr - self.base_addr), 2, value)
}

///|
pub fn Bus::store_u32(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.store_word_fragment(bus_offset_as_int(addr - self.base_addr), 4, value)
}

///|
pub fn Bus::store_u64(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.store_word_fragment(bus_offset_as_int(addr - self.base_addr), 8, value)
}

///|
pub fn Bus::write_bytes(self : Bus, base_addr : UInt64, bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    self.store_u8(
      base_addr + index.reinterpret_as_uint().to_uint64(),
      bytes[index].to_uint64(),
    )
  }
}

///|
fn Bus::write_bytes_from(
  self : Bus,
  base_addr : UInt64,
  bytes : Bytes,
  source_offset : Int32,
  len : Int32,
) -> Int32 {
  // Device DMA-style copies should validate the guest range once per
  // descriptor, not once per byte. Reads past the source bytes are zero-filled
  // to match the old virtio-blk behavior for sectors past the backing image.
  if len <= 0 || base_addr < self.base_addr {
    return 0
  }
  let start_index = bus_offset_as_int(base_addr - self.base_addr)
  if start_index < 0 || start_index >= self.size {
    return 0
  }
  let available = self.size - start_index
  let copy_len = if len < available { len } else { available }
  let alignment = start_index & 7
  let head_available = if alignment == 0 { 0 } else { 8 - alignment }
  let head_len = if copy_len < head_available {
    copy_len
  } else {
    head_available
  }
  for offset in 0..<head_len {
    let source_index = source_offset + offset
    self.store_word_fragment(
      start_index + offset,
      1,
      if source_index >= 0 && source_index < bytes.length() {
        bytes[source_index].to_uint64()
      } else {
        0U.to_uint64()
      },
    )
  }
  let bulk_source = source_offset + head_len
  let source_available = if bulk_source >= 0 && bulk_source < bytes.length() {
    bytes.length() - bulk_source
  } else {
    0
  }
  let after_head = copy_len - head_len
  let bulk_available = if after_head < source_available {
    after_head
  } else {
    source_available
  }
  let bulk_len = bulk_available / 8 * 8
  for offset in 0..<(bulk_len / 8) {
    let byte_offset = head_len + offset * 8
    self.words[(start_index + byte_offset) >> 3] = Bytes::unsafe_read_uint64_le(
      bytes,
      source_offset + byte_offset,
    )
  }
  for offset in (head_len + bulk_len)..<copy_len {
    let source_index = source_offset + offset
    self.store_word_fragment(
      start_index + offset,
      1,
      if source_index >= 0 && source_index < bytes.length() {
        bytes[source_index].to_uint64()
      } else {
        0U.to_uint64()
      },
    )
  }
  copy_len
}

///|
fn Bus::copy_bytes_to_array(
  self : Bus,
  base_addr : UInt64,
  dest : Array[Byte],
  dest_offset : Int32,
  len : Int32,
) -> Int32 {
  // Virtio write requests copy guest RAM into the disk backing. Bound both
  // sides once per descriptor so package-manager writes do not scan the whole
  // disk image or re-check the guest range byte by byte.
  if len <= 0 ||
    base_addr < self.base_addr ||
    dest_offset < 0 ||
    dest_offset >= dest.length() {
    return 0
  }
  let start_index = bus_offset_as_int(base_addr - self.base_addr)
  if start_index < 0 || start_index >= self.size {
    return 0
  }
  let guest_available = self.size - start_index
  let dest_available = dest.length() - dest_offset
  let guest_copy_len = if len < guest_available { len } else { guest_available }
  let copy_len = if guest_copy_len < dest_available {
    guest_copy_len
  } else {
    dest_available
  }
  for offset in 0..<copy_len {
    let guest_offset = start_index + offset
    dest[dest_offset + offset] = (self.words[guest_offset >> 3] >>
    ((guest_offset & 7) << 3)).to_byte()
  }
  copy_len
}

///|
pub fn Bus::zero_range(self : Bus, base_addr : UInt64, len : Int32) -> Unit {
  for index in 0..<len {
    self.store_u8(
      base_addr + index.reinterpret_as_uint().to_uint64(),
      0U.to_uint64(),
    )
  }
}

///|
fn Bus::fetch_u16(self : Bus, addr : UInt64) -> UInt32 {
  self.load_raw_u16(addr)
}

///|

///|
pub fn make_runner(config : MachineConfig) -> Runner {
  let config = {
    xlen: config.xlen,
    extensions: canonical_machine_extensions(config.extensions),
    ram_base: config.ram_base,
    ram_size: config.ram_size,
    entry_point: config.entry_point,
    hart_id: config.hart_id,
    uart0_base: config.uart0_base,
    clint_base: config.clint_base,
    plic_base: config.plic_base,
    virtio_blk_base: config.virtio_blk_base,
    dtb_addr: config.dtb_addr,
  }
  let runner = {
    cpu: CpuState::new(
      config.entry_point,
      config.hart_id,
      config.xlen,
      config.extensions,
    ),
    bus: Bus::new(config.ram_base, config.ram_size),
    config,
    uart_output: [],
    uart_input: Queue([]),
    uart_ier: [0U.to_byte()],
    uart_lcr: [0U.to_byte()],
    mtime: [0U.to_uint64()],
    mcycle: 0U.to_uint64(),
    minstret: 0U.to_uint64(),
    retire_suppressed: false,
    last_translate_fault: InstructionAccessFault,
    fetch_pa: 0U.to_uint64(),
    fetch_raw: 0U,
    fetch_length: 0,
    pending_step_result: Running,
    clint_msip: Array::make(2, false),
    all_mtimecmp: Array::make(2, bit_not(0U.to_uint64())),
    plic_regs: if config.plic_base != 0U.to_uint64() {
      Array::make(0x400000, 0U.to_byte())
    } else {
      []
    },
    plic_claimed: if config.plic_base != 0U.to_uint64() {
      Array::make(1024, false)
    } else {
      []
    },
    virtio_blk_state: Array::make(16, 0U.to_uint64()),
    virtio_blk_disk: [],
    virtio_blk_read_cache_base: bit_not(0U.to_uint64()),
    virtio_blk_read_cache_bytes: Bytes::from_array([]),
    virtio_blk_read_cache_hits: 0U.to_uint64(),
    virtio_blk_read_cache_misses: 0U.to_uint64(),
    virtio_blk_read_requests: 0U.to_uint64(),
    virtio_blk_write_requests: 0U.to_uint64(),
    virtio_blk_read_bytes: 0U.to_uint64(),
    virtio_blk_write_bytes: 0U.to_uint64(),
    virtio_blk_read_first_offset: 0U.to_uint64(),
    virtio_blk_read_min_offset: 0U.to_uint64(),
    virtio_blk_read_max_end: 0U.to_uint64(),
    virtio_blk_read_last_offset: 0U.to_uint64(),
    virtio_blk_read_last_end: 0U.to_uint64(),
    virtio_blk_read_sequential_requests: 0U.to_uint64(),
    virtio_blk_read_forward_gap_requests: 0U.to_uint64(),
    virtio_blk_read_backward_requests: 0U.to_uint64(),
    lr_sc_reserved_pas: Array::make(2, LR_SC_NO_RESERVATION),
    lr_sc_reserved_sizes: Array::make(2, 0),
    decode_cache_tags: Array::make(decode_cache_sets, decode_cache_invalid_tag),
    decode_cache_raws: Array::make(decode_cache_sets, 0U),
    decode_cache_lengths: Array::make(decode_cache_sets, 0),
    decode_cache_xlens: Array::make(decode_cache_sets, 0),
    decode_cache_instructions: Array::make(decode_cache_sets, Unknown(0U)),
    decode_cache_hits: 0U.to_uint64(),
    decode_cache_misses: 0U.to_uint64(),
    decode_cache_fills: 0U.to_uint64(),
    decode_cache_flushes: 0U.to_uint64(),
    translate_cache_vpages: Array::make(
      translate_cache_sets, translate_cache_invalid_vpage,
    ),
    translate_cache_satps: Array::make(translate_cache_sets, 0U.to_uint64()),
    translate_cache_accesses: Array::make(translate_cache_sets, 0),
    translate_cache_privileges: Array::make(translate_cache_sets, 0),
    translate_cache_sums: Array::make(translate_cache_sets, false),
    translate_cache_mxrs: Array::make(translate_cache_sets, false),
    translate_cache_pa_pages: Array::make(translate_cache_sets, 0U.to_uint64()),
    known_page_table_ppns: Array::make(
      known_page_table_sets, known_page_table_invalid_ppn,
    ),
    translate_cache_hits: 0U.to_uint64(),
    translate_cache_misses: 0U.to_uint64(),
    translate_cache_fills: 0U.to_uint64(),
    translate_cache_flushes: 0U.to_uint64(),
  }
  if (config.extensions & MISA_EXT_F) != 0U.to_uint64() {
    // Reset values for many status fields are platform-defined. For the
    // emulator's FP-capable test and Linux profiles, start with a legal
    // enabled-but-clean FP context; software can still set FS=Off and get the
    // architectural illegal-instruction behavior.
    runner.cpu.write_csr(CSR_MSTATUS, MSTATUS_FS_INITIAL)
  }
  runner
}

///|
/// Create N runners sharing bus, UART, PLIC, CLINT, and mtime for SMP simulation.
/// All harts start at the same entry point (cold/warm boot path is chosen via MHARTID).
pub fn make_smp_runners(
  config : MachineConfig,
  num_harts : Int32,
) -> Array[Runner] {
  let config = {
    xlen: config.xlen,
    extensions: canonical_machine_extensions(config.extensions),
    ram_base: config.ram_base,
    ram_size: config.ram_size,
    entry_point: config.entry_point,
    hart_id: config.hart_id,
    uart0_base: config.uart0_base,
    clint_base: config.clint_base,
    plic_base: config.plic_base,
    virtio_blk_base: config.virtio_blk_base,
    dtb_addr: config.dtb_addr,
  }
  let shared_bus = Bus::new(config.ram_base, config.ram_size)
  let shared_uart : Array[Byte] = []
  let shared_uart_input : @queue.Queue[Byte] = Queue([])
  let shared_uart_ier : Array[Byte] = [0U.to_byte()]
  let shared_uart_lcr : Array[Byte] = [0U.to_byte()]
  let shared_plic : Array[Byte] = if config.plic_base != 0U.to_uint64() {
    Array::make(0x400000, 0U.to_byte())
  } else {
    []
  }
  let shared_plic_claimed : Array[Bool] = if config.plic_base != 0U.to_uint64() {
    Array::make(1024, false)
  } else {
    []
  }
  let shared_mtime : Array[UInt64] = [0U.to_uint64()]
  let shared_msip : Array[Bool] = Array::make(num_harts, false)
  let shared_mtimecmp : Array[UInt64] = Array::make(
    num_harts,
    bit_not(0U.to_uint64()),
  )
  let shared_virtio_blk_state : Array[UInt64] = Array::make(16, 0U.to_uint64())
  let shared_virtio_blk_disk : Array[Byte] = []
  let shared_lr_sc_reserved_pas : Array[UInt64] = Array::make(
    num_harts,
    LR_SC_NO_RESERVATION,
  )
  let shared_lr_sc_reserved_sizes : Array[Int32] = Array::make(num_harts, 0)
  let harts : Array[Runner] = []
  for i in 0..<num_harts {
    let hart_config : MachineConfig = {
      xlen: config.xlen,
      extensions: config.extensions,
      ram_base: config.ram_base,
      ram_size: config.ram_size,
      entry_point: config.entry_point,
      hart_id: i.to_uint64(),
      uart0_base: config.uart0_base,
      clint_base: config.clint_base,
      plic_base: config.plic_base,
      virtio_blk_base: config.virtio_blk_base,
      dtb_addr: config.dtb_addr,
    }
    let runner = {
      cpu: CpuState::new(
        config.entry_point,
        i.to_uint64(),
        config.xlen,
        config.extensions,
      ),
      bus: shared_bus,
      config: hart_config,
      uart_output: shared_uart,
      uart_input: shared_uart_input,
      uart_ier: shared_uart_ier,
      uart_lcr: shared_uart_lcr,
      mtime: shared_mtime,
      mcycle: 0U.to_uint64(),
      minstret: 0U.to_uint64(),
      retire_suppressed: false,
      last_translate_fault: InstructionAccessFault,
      fetch_pa: 0U.to_uint64(),
      fetch_raw: 0U,
      fetch_length: 0,
      pending_step_result: Running,
      clint_msip: shared_msip,
      all_mtimecmp: shared_mtimecmp,
      plic_regs: shared_plic,
      plic_claimed: shared_plic_claimed,
      virtio_blk_state: shared_virtio_blk_state,
      virtio_blk_disk: shared_virtio_blk_disk,
      virtio_blk_read_cache_base: bit_not(0U.to_uint64()),
      virtio_blk_read_cache_bytes: Bytes::from_array([]),
      virtio_blk_read_cache_hits: 0U.to_uint64(),
      virtio_blk_read_cache_misses: 0U.to_uint64(),
      virtio_blk_read_requests: 0U.to_uint64(),
      virtio_blk_write_requests: 0U.to_uint64(),
      virtio_blk_read_bytes: 0U.to_uint64(),
      virtio_blk_write_bytes: 0U.to_uint64(),
      virtio_blk_read_first_offset: 0U.to_uint64(),
      virtio_blk_read_min_offset: 0U.to_uint64(),
      virtio_blk_read_max_end: 0U.to_uint64(),
      virtio_blk_read_last_offset: 0U.to_uint64(),
      virtio_blk_read_last_end: 0U.to_uint64(),
      virtio_blk_read_sequential_requests: 0U.to_uint64(),
      virtio_blk_read_forward_gap_requests: 0U.to_uint64(),
      virtio_blk_read_backward_requests: 0U.to_uint64(),
      lr_sc_reserved_pas: shared_lr_sc_reserved_pas,
      lr_sc_reserved_sizes: shared_lr_sc_reserved_sizes,
      decode_cache_tags: Array::make(
        decode_cache_sets, decode_cache_invalid_tag,
      ),
      decode_cache_raws: Array::make(decode_cache_sets, 0U),
      decode_cache_lengths: Array::make(decode_cache_sets, 0),
      decode_cache_xlens: Array::make(decode_cache_sets, 0),
      decode_cache_instructions: Array::make(decode_cache_sets, Unknown(0U)),
      decode_cache_hits: 0U.to_uint64(),
      decode_cache_misses: 0U.to_uint64(),
      decode_cache_fills: 0U.to_uint64(),
      decode_cache_flushes: 0U.to_uint64(),
      translate_cache_vpages: Array::make(
        translate_cache_sets, translate_cache_invalid_vpage,
      ),
      translate_cache_satps: Array::make(translate_cache_sets, 0U.to_uint64()),
      translate_cache_accesses: Array::make(translate_cache_sets, 0),
      translate_cache_privileges: Array::make(translate_cache_sets, 0),
      translate_cache_sums: Array::make(translate_cache_sets, false),
      translate_cache_mxrs: Array::make(translate_cache_sets, false),
      translate_cache_pa_pages: Array::make(
        translate_cache_sets,
        0U.to_uint64(),
      ),
      known_page_table_ppns: Array::make(
        known_page_table_sets, known_page_table_invalid_ppn,
      ),
      translate_cache_hits: 0U.to_uint64(),
      translate_cache_misses: 0U.to_uint64(),
      translate_cache_fills: 0U.to_uint64(),
      translate_cache_flushes: 0U.to_uint64(),
    }
    if (config.extensions & MISA_EXT_F) != 0U.to_uint64() {
      // Keep SMP hart reset policy aligned with make_runner: FP-capable harts
      // begin with FS enabled, while explicit FS=Off still traps in execute.
      runner.cpu.write_csr(CSR_MSTATUS, MSTATUS_FS_INITIAL)
    }
    harts.push(runner)
  }
  harts
}

///|
pub fn Runner::config(self : Runner) -> MachineConfig {
  self.config
}

///|
pub fn Runner::pc(self : Runner) -> UInt32 {
  self.cpu.pc.to_uint()
}

///|
pub fn Runner::pc_u64(self : Runner) -> UInt64 {
  self.cpu.pc
}

///|
pub fn Runner::read_reg(self : Runner, index : Int32) -> UInt32 {
  self.cpu.read_reg(index).to_uint()
}

///|
pub fn Runner::read_reg_u64(self : Runner, index : Int32) -> UInt64 {
  self.cpu.read_reg(index)
}

///|
pub fn Runner::read_freg_u64(self : Runner, index : Int32) -> UInt64 {
  self.cpu.read_freg(index)
}

///|
pub fn Runner::read_vreg_u64(
  self : Runner,
  index : Int32,
  word : Int32,
) -> UInt64 {
  self.cpu.read_vreg(index, word)
}

///|
pub fn Runner::read_csr(self : Runner, index : Int32) -> UInt32 {
  self.read_csr_visible(index).to_uint()
}

///|
pub fn Runner::read_csr_u64(self : Runner, index : Int32) -> UInt64 {
  self.read_csr_visible(index)
}

///|
pub fn Runner::privilege_mode(self : Runner) -> PrivilegeMode {
  self.cpu.privilege
}

///|
pub fn Runner::load_u32(self : Runner, addr : UInt32) -> UInt32 {
  self.bus.load_u32(addr.to_uint64()).to_uint()
}

///|
pub fn Runner::load_u32_u64(self : Runner, addr : UInt64) -> UInt64 {
  self.bus.load_u32(addr)
}

///|
pub fn Runner::load_program(
  self : Runner,
  bytes : Bytes,
  base_addr : UInt32,
) -> Unit {
  self.load_program_u64(bytes, base_addr.to_uint64())
}

///|
pub fn Runner::load_program_u64(
  self : Runner,
  bytes : Bytes,
  base_addr : UInt64,
) -> Unit {
  self.bus.write_bytes(base_addr, bytes)
  self.cpu.pc = base_addr
  self.flush_decode_cache()
  self.flush_translate_cache()
}

///|
pub fn Runner::write_memory_bytes(
  self : Runner,
  base_addr : UInt64,
  bytes : Bytes,
) -> Unit {
  self.bus.write_bytes(base_addr, bytes)
  self.flush_decode_cache()
  self.flush_translate_cache()
}

///|
pub fn Runner::decode_cache_hit_count(self : Runner) -> UInt64 {
  self.decode_cache_hits
}

///|
pub fn Runner::decode_cache_miss_count(self : Runner) -> UInt64 {
  self.decode_cache_misses
}

///|
pub fn Runner::decode_cache_fill_count(self : Runner) -> UInt64 {
  self.decode_cache_fills
}

///|
pub fn Runner::decode_cache_flush_count(self : Runner) -> UInt64 {
  self.decode_cache_flushes
}

///|
pub fn Runner::translate_cache_hit_count(self : Runner) -> UInt64 {
  self.translate_cache_hits
}

///|
pub fn Runner::translate_cache_miss_count(self : Runner) -> UInt64 {
  self.translate_cache_misses
}

///|
pub fn Runner::translate_cache_fill_count(self : Runner) -> UInt64 {
  self.translate_cache_fills
}

///|
pub fn Runner::translate_cache_flush_count(self : Runner) -> UInt64 {
  self.translate_cache_flushes
}

///|
/// Load a DTB blob into RAM at config.dtb_addr.
pub fn Runner::load_dtb(self : Runner, dtb : Bytes) -> Unit {
  self.bus.write_bytes(self.config.dtb_addr, dtb)
}

///|
pub fn Runner::load_virtio_blk_disk(self : Runner, disk : Bytes) -> Unit {
  self.virtio_blk_disk.clear()
  for byte in disk {
    self.virtio_blk_disk.push(byte)
  }
  self.virtio_blk_invalidate_read_cache()
  self.virtio_blk_reset_read_pattern_counters()
}

///|
pub fn Runner::virtio_blk_disk_bytes(self : Runner) -> Bytes {
  // Expose the current backing image for host-side persistence probes. The
  // emulator still owns request processing; callers should treat this as a
  // snapshot taken after Linux has issued writes and syncs.
  Bytes::from_array(self.virtio_blk_disk)
}

///|
pub fn Runner::virtio_blk_read_request_count(self : Runner) -> UInt64 {
  self.virtio_blk_read_requests
}

///|
pub fn Runner::virtio_blk_write_request_count(self : Runner) -> UInt64 {
  self.virtio_blk_write_requests
}

///|
pub fn Runner::virtio_blk_read_byte_count(self : Runner) -> UInt64 {
  self.virtio_blk_read_bytes
}

///|
pub fn Runner::virtio_blk_write_byte_count(self : Runner) -> UInt64 {
  self.virtio_blk_write_bytes
}

///|
pub fn Runner::virtio_blk_read_cache_hit_count(self : Runner) -> UInt64 {
  self.virtio_blk_read_cache_hits
}

///|
pub fn Runner::virtio_blk_read_cache_miss_count(self : Runner) -> UInt64 {
  self.virtio_blk_read_cache_misses
}

///|
pub fn Runner::virtio_blk_read_first_offset(self : Runner) -> UInt64 {
  self.virtio_blk_read_first_offset
}

///|
pub fn Runner::virtio_blk_read_min_offset(self : Runner) -> UInt64 {
  self.virtio_blk_read_min_offset
}

///|
pub fn Runner::virtio_blk_read_max_end(self : Runner) -> UInt64 {
  self.virtio_blk_read_max_end
}

///|
pub fn Runner::virtio_blk_read_last_offset(self : Runner) -> UInt64 {
  self.virtio_blk_read_last_offset
}

///|
pub fn Runner::virtio_blk_read_last_end(self : Runner) -> UInt64 {
  self.virtio_blk_read_last_end
}

///|
pub fn Runner::virtio_blk_read_sequential_request_count(
  self : Runner,
) -> UInt64 {
  self.virtio_blk_read_sequential_requests
}

///|
pub fn Runner::virtio_blk_read_forward_gap_request_count(
  self : Runner,
) -> UInt64 {
  self.virtio_blk_read_forward_gap_requests
}

///|
pub fn Runner::virtio_blk_read_backward_request_count(self : Runner) -> UInt64 {
  self.virtio_blk_read_backward_requests
}

///|
/// Set up the SBI/Linux boot ABI: a0 = hart_id, a1 = dtb_addr.
pub fn Runner::setup_boot_abi(self : Runner) -> Unit {
  self.cpu.write_reg(10, self.config.hart_id) // a0 = hart_id
  self.cpu.write_reg(11, self.config.dtb_addr) // a1 = dtb_addr
}

///|
pub fn Runner::setup_fw_dynamic_handoff(
  self : Runner,
  info_addr : UInt64,
  next_addr : UInt64,
  next_mode : UInt64,
) -> Unit {
  self.bus.store_u64(info_addr, 0x4942534fU.to_uint64()) // magic = "OSBI"
  self.bus.store_u64(info_addr + 8U.to_uint64(), 2U.to_uint64()) // version = 2
  self.bus.store_u64(info_addr + 16U.to_uint64(), next_addr)
  self.bus.store_u64(info_addr + 24U.to_uint64(), next_mode)
  self.bus.store_u64(info_addr + 32U.to_uint64(), 0U.to_uint64()) // options = 0
  self.bus.store_u64(
    info_addr + 40U.to_uint64(),
    0xffffffffU.to_uint64() | (0xffffffffU.to_uint64() << 32),
  ) // boot_hart = -1
  self.setup_boot_abi()
  self.cpu.write_reg(12, info_addr) // a2 = &fw_dynamic_info
}
