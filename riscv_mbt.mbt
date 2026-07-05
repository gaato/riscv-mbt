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
  ram_size : Int
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
  base_addr : UInt64
  memory : Array[Byte]
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
  Lui(Int, UInt)
  Auipc(Int, UInt)
  Addi(Int, Int, Int)
  Slti(Int, Int, Int)
  Sltiu(Int, Int, Int)
  Xori(Int, Int, Int)
  Ori(Int, Int, Int)
  Andi(Int, Int, Int)
  Addiw(Int, Int, Int)
  Slli(Int, Int, Int)
  Srli(Int, Int, Int)
  Srai(Int, Int, Int)
  Slliw(Int, Int, Int)
  Srliw(Int, Int, Int)
  Sraiw(Int, Int, Int)
  Add(Int, Int, Int)
  Sub(Int, Int, Int)
  Addw(Int, Int, Int)
  Subw(Int, Int, Int)
  Mul(Int, Int, Int)
  Mulw(Int, Int, Int)
  Mulh(Int, Int, Int)
  Mulhsu(Int, Int, Int)
  Mulhu(Int, Int, Int)
  Div(Int, Int, Int)
  Divw(Int, Int, Int)
  Divu(Int, Int, Int)
  Divuw(Int, Int, Int)
  Rem(Int, Int, Int)
  Remw(Int, Int, Int)
  Remu(Int, Int, Int)
  Remuw(Int, Int, Int)
  Sll(Int, Int, Int)
  Sllw(Int, Int, Int)
  Slt(Int, Int, Int)
  Sltu(Int, Int, Int)
  Xor(Int, Int, Int)
  Srl(Int, Int, Int)
  Sra(Int, Int, Int)
  Srlw(Int, Int, Int)
  Sraw(Int, Int, Int)
  Or(Int, Int, Int)
  And(Int, Int, Int)
  Beq(Int, Int, Int)
  Bne(Int, Int, Int)
  Blt(Int, Int, Int)
  Bge(Int, Int, Int)
  Bltu(Int, Int, Int)
  Bgeu(Int, Int, Int)
  Lb(Int, Int, Int)
  Lh(Int, Int, Int)
  Lw(Int, Int, Int)
  Flw(Int, Int, Int)
  Fld(Int, Int, Int)
  Lwu(Int, Int, Int)
  Ld(Int, Int, Int)
  Lbu(Int, Int, Int)
  Lhu(Int, Int, Int)
  Sb(Int, Int, Int)
  Sh(Int, Int, Int)
  Sw(Int, Int, Int)
  Fsw(Int, Int, Int)
  Fsd(Int, Int, Int)
  Sd(Int, Int, Int)
  FMAddS(Int, Int, Int, Int, UInt)
  FMSubS(Int, Int, Int, Int, UInt)
  FNMSubS(Int, Int, Int, Int, UInt)
  FNMAddS(Int, Int, Int, Int, UInt)
  FMAddD(Int, Int, Int, Int, UInt)
  FMSubD(Int, Int, Int, Int, UInt)
  FNMSubD(Int, Int, Int, Int, UInt)
  FNMAddD(Int, Int, Int, Int, UInt)
  FAddS(Int, Int, Int, UInt)
  FSubS(Int, Int, Int, UInt)
  FMulS(Int, Int, Int, UInt)
  FDivS(Int, Int, Int, UInt)
  FSqrtS(Int, Int, UInt)
  FMinS(Int, Int, Int)
  FMaxS(Int, Int, Int)
  FSgnjS(Int, Int, Int)
  FSgnjnS(Int, Int, Int)
  FSgnjxS(Int, Int, Int)
  FLeS(Int, Int, Int)
  FLtS(Int, Int, Int)
  FEqS(Int, Int, Int)
  FClassS(Int, Int)
  FAddD(Int, Int, Int, UInt)
  FSubD(Int, Int, Int, UInt)
  FMulD(Int, Int, Int, UInt)
  FDivD(Int, Int, Int, UInt)
  FSgnjD(Int, Int, Int)
  FSgnjnD(Int, Int, Int)
  FSgnjxD(Int, Int, Int)
  FSqrtD(Int, Int, UInt)
  FMinD(Int, Int, Int)
  FMaxD(Int, Int, Int)
  FLeD(Int, Int, Int)
  FLtD(Int, Int, Int)
  FEqD(Int, Int, Int)
  FClassD(Int, Int)
  FmvXW(Int, Int)
  FmvWX(Int, Int)
  FmvXD(Int, Int)
  FmvDX(Int, Int)
  FCvtSD(Int, Int, UInt)
  FCvtDS(Int, Int, UInt)
  FCvtSW(Int, Int, UInt)
  FCvtSWU(Int, Int, UInt)
  FCvtSL(Int, Int, UInt)
  FCvtSLU(Int, Int, UInt)
  FCvtDW(Int, Int, UInt)
  FCvtDWU(Int, Int, UInt)
  FCvtDL(Int, Int, UInt)
  FCvtDLU(Int, Int, UInt)
  FCvtWS(Int, Int, UInt)
  FCvtWUS(Int, Int, UInt)
  FCvtLS(Int, Int, UInt)
  FCvtLUS(Int, Int, UInt)
  FCvtWD(Int, Int, UInt)
  FCvtWUD(Int, Int, UInt)
  FCvtLD(Int, Int, UInt)
  FCvtLUD(Int, Int, UInt)
  Vsetvli(Int, Int, UInt)
  Vsetivli(Int, UInt, UInt)
  Vsetvl(Int, Int, Int)
  VmvVI(Int, Int)
  VmvVX(Int, Int)
  VmvVV(Int, Int)
  VmvXS(Int, Int)
  VmergeVvm(Int, Int, Int)
  VmergeVxm(Int, Int, Int)
  VmergeVim(Int, Int, Int)
  VaddVv(Int, Int, Int)
  VaddVx(Int, Int, Int)
  VaddVi(Int, Int, Int)
  VsubVv(Int, Int, Int)
  VsubVx(Int, Int, Int)
  VrsubVx(Int, Int, Int)
  VrsubVi(Int, Int, Int)
  VwadduVv(Int, Int, Int)
  VwadduVx(Int, Int, Int)
  VwaddVv(Int, Int, Int)
  VwaddVx(Int, Int, Int)
  VwsubuVv(Int, Int, Int)
  VwsubuVx(Int, Int, Int)
  VwsubVv(Int, Int, Int)
  VwsubVx(Int, Int, Int)
  VmulVv(Int, Int, Int)
  VmulVx(Int, Int, Int)
  VmulhuVv(Int, Int, Int)
  VmulhuVx(Int, Int, Int)
  VmulhVv(Int, Int, Int)
  VmulhVx(Int, Int, Int)
  VmulhsuVv(Int, Int, Int)
  VmulhsuVx(Int, Int, Int)
  VdivuVv(Int, Int, Int)
  VdivuVx(Int, Int, Int)
  VdivVv(Int, Int, Int)
  VdivVx(Int, Int, Int)
  VremuVv(Int, Int, Int)
  VremuVx(Int, Int, Int)
  VremVv(Int, Int, Int)
  VremVx(Int, Int, Int)
  VminuVv(Int, Int, Int)
  VminuVx(Int, Int, Int)
  VminVv(Int, Int, Int)
  VminVx(Int, Int, Int)
  VmaxuVv(Int, Int, Int)
  VmaxuVx(Int, Int, Int)
  VmaxVv(Int, Int, Int)
  VmaxVx(Int, Int, Int)
  VmseqVv(Int, Int, Int)
  VmseqVx(Int, Int, Int)
  VmseqVi(Int, Int, Int)
  VmsneVv(Int, Int, Int)
  VmsneVx(Int, Int, Int)
  VmsneVi(Int, Int, Int)
  VmsltuVv(Int, Int, Int)
  VmsltuVx(Int, Int, Int)
  VmsltVv(Int, Int, Int)
  VmsltVx(Int, Int, Int)
  VmsleuVv(Int, Int, Int)
  VmsleuVx(Int, Int, Int)
  VmsleuVi(Int, Int, Int)
  VmsleVv(Int, Int, Int)
  VmsleVx(Int, Int, Int)
  VmsleVi(Int, Int, Int)
  VmsgtuVx(Int, Int, Int)
  VmsgtuVi(Int, Int, Int)
  VmsgtVx(Int, Int, Int)
  VmsgtVi(Int, Int, Int)
  VmandMm(Int, Int, Int)
  VmnandMm(Int, Int, Int)
  VmandnMm(Int, Int, Int)
  VmxorMm(Int, Int, Int)
  VmorMm(Int, Int, Int)
  VmnorMm(Int, Int, Int)
  VmornMm(Int, Int, Int)
  VmxnorMm(Int, Int, Int)
  VcpopM(Int, Int)
  VfirstM(Int, Int)
  VmsbfM(Int, Int)
  VmsofM(Int, Int)
  VmsifM(Int, Int)
  ViotaM(Int, Int)
  VidV(Int)
  VcompressVm(Int, Int, Int)
  VrgatherVv(Int, Int, Int)
  VrgatherVx(Int, Int, Int)
  VrgatherVi(Int, Int, Int)
  VslideupVx(Int, Int, Int)
  VslideupVi(Int, Int, Int)
  VslidedownVx(Int, Int, Int)
  VslidedownVi(Int, Int, Int)
  Vslide1upVx(Int, Int, Int)
  Vslide1downVx(Int, Int, Int)
  VmvNrR(Int, Int, Int)
  VsllVv(Int, Int, Int)
  VsllVx(Int, Int, Int)
  VsllVi(Int, Int, Int)
  VsrlVv(Int, Int, Int)
  VsrlVx(Int, Int, Int)
  VsrlVi(Int, Int, Int)
  VsraVv(Int, Int, Int)
  VsraVx(Int, Int, Int)
  VsraVi(Int, Int, Int)
  VandVv(Int, Int, Int)
  VandVx(Int, Int, Int)
  VandVi(Int, Int, Int)
  VorVv(Int, Int, Int)
  VorVx(Int, Int, Int)
  VorVi(Int, Int, Int)
  VxorVv(Int, Int, Int)
  VxorVx(Int, Int, Int)
  VxorVi(Int, Int, Int)
  VlmV(Int, Int)
  Vle8V(Int, Int)
  Vle16V(Int, Int)
  Vle32V(Int, Int)
  Vle64V(Int, Int)
  Vle8ffV(Int, Int)
  Vle16ffV(Int, Int)
  Vle32ffV(Int, Int)
  Vle64ffV(Int, Int)
  Vlseg2e32V(Int, Int)
  Vluxei32V(Int, Int, Int)
  Vloxei32V(Int, Int, Int)
  Vlse32V(Int, Int, Int)
  VsmV(Int, Int)
  Vse8V(Int, Int)
  Vse16V(Int, Int)
  Vse32V(Int, Int)
  Vse64V(Int, Int)
  Vsseg2e32V(Int, Int)
  Vsuxei32V(Int, Int, Int)
  Vsoxei32V(Int, Int, Int)
  Vsse32V(Int, Int, Int)
  Jal(Int, Int)
  Jalr(Int, Int, Int)
  Csrrw(Int, Int, Int)
  Csrrs(Int, Int, Int)
  Csrrc(Int, Int, Int)
  Csrrwi(Int, Int, UInt)
  Csrrsi(Int, Int, UInt)
  Csrrci(Int, Int, UInt)
  SfenceVma(Int, Int)
  Wfi
  AmoW(UInt, Int, Int, Int)
  AmoD(UInt, Int, Int, Int)
  Ecall
  Ebreak
  Mret
  Sret
  Unknown(UInt)
}

///|
pub enum TrapCause {
  // TrapCause is the architectural cause before it is encoded into mcause or
  // scause. Keep it cause-centric, not handler-centric: delegation decides
  // which privilege mode receives the same underlying event.
  InstructionAccessFault
  IllegalInstruction
  Breakpoint
  LoadAccessFault
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
priv struct FetchedInstruction {
  fetch_pa : UInt64
  raw : UInt
  length : Int
}

///|
let decode_cache_sets : Int = 4096

///|
let decode_cache_invalid_tag : UInt64 = bit_not(0U.to_uint64())

///|
let translate_cache_sets : Int = 4096

///|
let translate_cache_invalid_vpage : UInt64 = bit_not(0U.to_uint64())

///|
let known_page_table_sets : Int = 256

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
  // Single-hart LR/SC reservation, tracked in physical-address space after
  // translation. This keeps Linux lock/futex loops from seeing impossible SC
  // success without modeling the full multi-hart reservation set yet.
  mut lr_sc_reserved_pa : UInt64?
  // Decode cache keys by physical fetch address plus raw bits. This avoids
  // mixing Sv39 virtual aliases and keeps cache invalidation tied to fence.i.
  decode_cache_tags : Array[UInt64]
  decode_cache_raws : Array[UInt]
  decode_cache_lengths : Array[Int]
  decode_cache_xlens : Array[Int]
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
  translate_cache_accesses : Array[Int]
  translate_cache_privileges : Array[Int]
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
  { registers: Array::make(4096, 0U.to_uint64()) }
}

///|
pub fn CsrFile::read(self : CsrFile, index : Int) -> UInt64 {
  self.registers[index]
}

///|
pub fn CsrFile::write(self : CsrFile, index : Int, value : UInt64) -> Unit {
  self.registers[index] = value
}

///|
const CSR_MSTATUS : Int = 0x300

///|
const CSR_MISA : Int = 0x301

///|
const CSR_FFLAGS : Int = 0x001

///|
const CSR_FRM : Int = 0x002

///|
const CSR_FCSR : Int = 0x003

///|
const CSR_MEDELEG : Int = 0x302

///|
const CSR_MIDELEG : Int = 0x303

///|
const MEDELEG_WRITABLE_MASK : UInt64 = 0xb3ae

///|
const MIDELEG_WRITABLE_MASK : UInt64 = 0x222

///|
const CSR_MIE : Int = 0x304

///|
const MACHINE_INTERRUPT_MASK : UInt64 = 0xaaa

///|
const MIP_WRITABLE_MASK : UInt64 = SIP_VISIBLE_MASK

///|
const CSR_MTVEC : Int = 0x305

///|
const CSR_SSTATUS : Int = 0x100

///|
const CSR_MEPC : Int = 0x341

///|
const CSR_MCAUSE : Int = 0x342

///|
const CSR_MTVAL : Int = 0x343

///|
const CSR_MIP : Int = 0x344

///|
const CSR_STVEC : Int = 0x105

///|
const CSR_SSCRATCH : Int = 0x140

///|
const CSR_SEPC : Int = 0x141

///|
const CSR_SCAUSE : Int = 0x142

///|
const CSR_STVAL : Int = 0x143

///|
const CSR_SIE : Int = 0x104

///|
const CSR_SIP : Int = 0x144

///|
const CSR_SATP : Int = 0x180

///|
const CSR_PMPCFG0 : Int = 0x3A0

///|
const CSR_PMPADDR0 : Int = 0x3B0

///|
const CSR_MNSTATUS : Int = 0x744

///|
const CSR_MSCRATCH : Int = 0x340

///|
const CSR_MCOUNTEREN : Int = 0x306

///|
const CSR_SCOUNTEREN : Int = 0x106

///|
const COUNTEREN_WRITABLE_MASK : UInt64 = 0x7

///|
const CSR_MENVCFG : Int = 0x30A

///|
const CSR_SENVCFG : Int = 0x10A

///|
const CSR_CYCLE : Int = 0xC00

///|
const CSR_TIME : Int = 0xC01

///|
const CSR_INSTRET : Int = 0xC02

///|
const CSR_CYCLEH : Int = 0xC80

///|
const CSR_TIMEH : Int = 0xC81

///|
const CSR_INSTRETH : Int = 0xC82

///|
const CSR_MHARTID : Int = 0xF14

///|
const CSR_MVENDORID : Int = 0xF11

///|
const CSR_MARCHID : Int = 0xF12

///|
const CSR_MIMPID : Int = 0xF13

///|
const CSR_VSTART : Int = 0x008

///|
const CSR_VXSAT : Int = 0x009

///|
const CSR_VXRM : Int = 0x00A

///|
const CSR_VCSR : Int = 0x00F

///|
const CSR_VL : Int = 0xC20

///|
const CSR_VTYPE : Int = 0xC21

///|
const CSR_VLENB : Int = 0xC22

///|
const XLEN_32 : Int = 32

///|
const XLEN_64 : Int = 64

///|
const MSTATUS_SIE_BIT : UInt = 0x2U

///|
const MSTATUS_SPIE_BIT : UInt = 0x20U

///|
const MSTATUS_SPP_BIT : UInt = 0x100U

///|
const MSTATUS_MIE_BIT : UInt = 0x8U

///|
const MSTATUS_MPIE_BIT : UInt = 0x80U

///|
const MSTATUS_MPP_SHIFT : Int = 11

///|
const MSTATUS_MPP_MASK : UInt = 0x1800U

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
const FCSR_FRM_SHIFT : Int = 5

///|
const FCSR_FRM_MASK : UInt64 = 0xe0

///|
const FCSR_VISIBLE_MASK : UInt64 = 0xff

///|
const VCSR_VXSAT_MASK : UInt64 = 0x1

///|
const VCSR_VXRM_SHIFT : Int = 1

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
const VREG_COUNT : Int = 32

///|
const VREG_WORDS_PER_REG : Int = 2

///|
const VLEN_BYTES : Int = 16

///|
fn current_base_extensions() -> UInt64 {
  // Base configs advertise the RV64 Linux baseline we actively execute:
  // integer, multiply/divide, atomics, compressed, supervisor, and user.
  // Floating point and vector support are added explicitly by the configs
  // whose tests or Linux probes need them.
  MISA_EXT_A | MISA_EXT_C | MISA_EXT_I | MISA_EXT_M | MISA_EXT_S | MISA_EXT_U
}

///|
fn misa_value(xlen : Xlen, extensions : UInt64) -> UInt64 {
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
fn xlen_mask(xlen : Int) -> UInt64 {
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
pub fn CpuState::read_reg(self : CpuState, index : Int) -> UInt64 {
  if index == 0 {
    0U.to_uint64()
  } else {
    self.registers[index]
  }
}

///|
pub fn CpuState::write_reg(
  self : CpuState,
  index : Int,
  value : UInt64,
) -> Unit {
  if index != 0 {
    self.registers[index] = value
  }
}

///|
pub fn CpuState::read_freg(self : CpuState, index : Int) -> UInt64 {
  self.fregisters[index]
}

///|
pub fn CpuState::write_freg(
  self : CpuState,
  index : Int,
  value : UInt64,
) -> Unit {
  self.fregisters[index] = value
}

///|
pub fn CpuState::read_vreg(self : CpuState, index : Int, word : Int) -> UInt64 {
  self.vregisters[index * VREG_WORDS_PER_REG + word]
}

///|
pub fn CpuState::write_vreg(
  self : CpuState,
  index : Int,
  word : Int,
  value : UInt64,
) -> Unit {
  self.vregisters[index * VREG_WORDS_PER_REG + word] = value
}

///|
pub fn CpuState::read_csr(self : CpuState, index : Int) -> UInt64 {
  self.csrs.read(index)
}

///|
pub fn CpuState::write_csr(
  self : CpuState,
  index : Int,
  value : UInt64,
) -> Unit {
  self.csrs.write(index, value)
}

///|
pub fn Bus::new(base_addr : UInt64, size : Int) -> Bus {
  { base_addr, memory: Array::make(size, 0U.to_byte()) }
}

///|
pub fn Bus::size(self : Bus) -> Int {
  self.memory.length()
}

///|
fn bus_offset_as_int(offset : UInt64) -> Int {
  offset.reinterpret_as_int64().to_int()
}

///|
fn Bus::contains_range(self : Bus, addr : UInt64, width : Int) -> Bool {
  let start = addr - self.base_addr
  let start_index = bus_offset_as_int(start)
  let end_index = start_index + width
  addr >= self.base_addr &&
  start_index >= 0 &&
  end_index <= self.memory.length()
}

///|
fn Bus::load_raw_u8(self : Bus, addr : UInt64) -> UInt {
  self.memory[bus_offset_as_int(addr - self.base_addr)].to_uint()
}

///|
fn Bus::load_raw_u16(self : Bus, addr : UInt64) -> UInt {
  let b0 = self.load_raw_u8(addr)
  let b1 = self.load_raw_u8(addr + 1U.to_uint64()) << 8
  b0 | b1
}

///|
fn Bus::load_raw_u32(self : Bus, addr : UInt64) -> UInt {
  let b0 = self.load_raw_u8(addr)
  let b1 = self.load_raw_u8(addr + 1U.to_uint64()) << 8
  let b2 = self.load_raw_u8(addr + 2U.to_uint64()) << 16
  let b3 = self.load_raw_u8(addr + 3U.to_uint64()) << 24
  b0 | b1 | b2 | b3
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
  let b0 = self.load_u8(addr)
  let b1 = self.load_u8(addr + 1U.to_uint64()) << 8
  let b2 = self.load_u8(addr + 2U.to_uint64()) << 16
  let b3 = self.load_u8(addr + 3U.to_uint64()) << 24
  let b4 = self.load_u8(addr + 4U.to_uint64()) << 32
  let b5 = self.load_u8(addr + 5U.to_uint64()) << 40
  let b6 = self.load_u8(addr + 6U.to_uint64()) << 48
  let b7 = self.load_u8(addr + 7U.to_uint64()) << 56
  b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7
}

///|
pub fn Bus::store_u8(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
}

///|
pub fn Bus::store_u16(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
  self.memory[bus_offset_as_int(addr + 1U.to_uint64() - self.base_addr)] = (value >>
  8).to_byte()
}

///|
pub fn Bus::store_u32(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
  self.memory[bus_offset_as_int(addr + 1U.to_uint64() - self.base_addr)] = (value >>
  8).to_byte()
  self.memory[bus_offset_as_int(addr + 2U.to_uint64() - self.base_addr)] = (value >>
  16).to_byte()
  self.memory[bus_offset_as_int(addr + 3U.to_uint64() - self.base_addr)] = (value >>
  24).to_byte()
}

///|
pub fn Bus::store_u64(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
  self.memory[bus_offset_as_int(addr + 1U.to_uint64() - self.base_addr)] = (value >>
  8).to_byte()
  self.memory[bus_offset_as_int(addr + 2U.to_uint64() - self.base_addr)] = (value >>
  16).to_byte()
  self.memory[bus_offset_as_int(addr + 3U.to_uint64() - self.base_addr)] = (value >>
  24).to_byte()
  self.memory[bus_offset_as_int(addr + 4U.to_uint64() - self.base_addr)] = (value >>
  32).to_byte()
  self.memory[bus_offset_as_int(addr + 5U.to_uint64() - self.base_addr)] = (value >>
  40).to_byte()
  self.memory[bus_offset_as_int(addr + 6U.to_uint64() - self.base_addr)] = (value >>
  48).to_byte()
  self.memory[bus_offset_as_int(addr + 7U.to_uint64() - self.base_addr)] = (value >>
  56).to_byte()
}

///|
pub fn Bus::write_bytes(self : Bus, base_addr : UInt64, bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    self.memory[bus_offset_as_int(
      base_addr + index.reinterpret_as_uint().to_uint64() - self.base_addr,
    )] = bytes[index]
  }
}

///|
fn Bus::write_bytes_from(
  self : Bus,
  base_addr : UInt64,
  bytes : Bytes,
  source_offset : Int,
  len : Int,
) -> Int {
  // Device DMA-style copies should validate the guest range once per
  // descriptor, not once per byte. Reads past the source bytes are zero-filled
  // to match the old virtio-blk behavior for sectors past the backing image.
  if len <= 0 || base_addr < self.base_addr {
    return 0
  }
  let start_index = bus_offset_as_int(base_addr - self.base_addr)
  if start_index < 0 || start_index >= self.memory.length() {
    return 0
  }
  let available = self.memory.length() - start_index
  let copy_len = if len < available { len } else { available }
  for offset in 0..<copy_len {
    let source_index = source_offset + offset
    self.memory[start_index + offset] = if source_index >= 0 &&
      source_index < bytes.length() {
      bytes[source_index]
    } else {
      0U.to_byte()
    }
  }
  copy_len
}

///|
fn Bus::copy_bytes_to_array(
  self : Bus,
  base_addr : UInt64,
  dest : Array[Byte],
  dest_offset : Int,
  len : Int,
) -> Int {
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
  if start_index < 0 || start_index >= self.memory.length() {
    return 0
  }
  let guest_available = self.memory.length() - start_index
  let dest_available = dest.length() - dest_offset
  let guest_copy_len = if len < guest_available { len } else { guest_available }
  let copy_len = if guest_copy_len < dest_available {
    guest_copy_len
  } else {
    dest_available
  }
  for offset in 0..<copy_len {
    dest[dest_offset + offset] = self.memory[start_index + offset]
  }
  copy_len
}

///|
pub fn Bus::zero_range(self : Bus, base_addr : UInt64, len : Int) -> Unit {
  for index in 0..<len {
    self.store_u8(
      base_addr + index.reinterpret_as_uint().to_uint64(),
      0U.to_uint64(),
    )
  }
}

///|
fn Bus::fetch_u16(self : Bus, addr : UInt64) -> UInt {
  self.load_raw_u16(addr)
}

///|

///|
pub fn make_runner(config : MachineConfig) -> Runner {
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
    uart_input: @queue.Queue([]),
    uart_ier: [0U.to_byte()],
    uart_lcr: [0U.to_byte()],
    mtime: [0U.to_uint64()],
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
    lr_sc_reserved_pa: None,
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
  num_harts : Int,
) -> Array[Runner] {
  let shared_bus = Bus::new(config.ram_base, config.ram_size)
  let shared_uart : Array[Byte] = []
  let shared_uart_input : @queue.Queue[Byte] = @queue.Queue([])
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
      lr_sc_reserved_pa: None,
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
pub fn Runner::pc(self : Runner) -> UInt {
  self.cpu.pc.to_uint()
}

///|
pub fn Runner::pc_u64(self : Runner) -> UInt64 {
  self.cpu.pc
}

///|
pub fn Runner::read_reg(self : Runner, index : Int) -> UInt {
  self.cpu.read_reg(index).to_uint()
}

///|
pub fn Runner::read_reg_u64(self : Runner, index : Int) -> UInt64 {
  self.cpu.read_reg(index)
}

///|
pub fn Runner::read_freg_u64(self : Runner, index : Int) -> UInt64 {
  self.cpu.read_freg(index)
}

///|
pub fn Runner::read_vreg_u64(self : Runner, index : Int, word : Int) -> UInt64 {
  self.cpu.read_vreg(index, word)
}

///|
pub fn Runner::read_csr(self : Runner, index : Int) -> UInt {
  self.read_csr_visible(index).to_uint()
}

///|
pub fn Runner::read_csr_u64(self : Runner, index : Int) -> UInt64 {
  self.read_csr_visible(index)
}

///|
pub fn Runner::privilege_mode(self : Runner) -> PrivilegeMode {
  self.cpu.privilege
}

///|
pub fn Runner::load_u32(self : Runner, addr : UInt) -> UInt {
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
  base_addr : UInt,
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
