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
  xlen : Xlen
  extensions : UInt64
  ram_base : UInt64
  ram_size : Int
  entry_point : UInt64
  hart_id : UInt64
  uart0_base : UInt64
  clint_base : UInt64
  plic_base : UInt64
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
  FAddS(Int, Int, Int, UInt)
  FSubS(Int, Int, Int, UInt)
  FMulS(Int, Int, Int, UInt)
  FDivS(Int, Int, Int, UInt)
  FSqrtS(Int, Int, UInt)
  FMinS(Int, Int, Int)
  FMaxS(Int, Int, Int)
  FAddD(Int, Int, Int, UInt)
  FSubD(Int, Int, Int, UInt)
  FMulD(Int, Int, Int, UInt)
  FDivD(Int, Int, Int, UInt)
  FSqrtD(Int, Int, UInt)
  FMinD(Int, Int, Int)
  FMaxD(Int, Int, Int)
  FmvXW(Int, Int)
  FmvWX(Int, Int)
  FmvXD(Int, Int)
  FmvDX(Int, Int)
  FCvtSD(Int, Int, UInt)
  FCvtDS(Int, Int, UInt)
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
  Mret
  Sret
  Unknown(UInt)
}

///|
pub enum TrapCause {
  InstructionAccessFault
  IllegalInstruction
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
  raw : UInt
  length : Int
}

///|
pub struct Runner {
  cpu : CpuState
  bus : Bus
  config : MachineConfig
  uart_output : Array[Byte]
  uart_input : @queue.Queue[Byte]
  mtime : Array[UInt64]      // [0] = current mtime; shared across SMP harts
  clint_msip : Array[Bool]   // [hart_id] = MSIP bit; shared across SMP harts
  all_mtimecmp : Array[UInt64] // [hart_id] = mtimecmp; shared across SMP harts
  plic_regs : Array[Byte]    // flat PLIC register file (4 MB); shared across SMP harts
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
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn official_riscv_tests_machine_config_for_xlen(xlen : Xlen) -> MachineConfig {
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
    dtb_addr: 0U.to_uint64(),
  }
}

///|
pub fn virt_machine_config() -> MachineConfig {
  {
    xlen: Xlen64,
    extensions: current_base_extensions(),
    ram_base: 0x80000000U.to_uint64(),
    ram_size: 0x08000000,
    entry_point: 0x80000000U.to_uint64(),
    hart_id: 0U.to_uint64(),
    uart0_base: 0x10000000U.to_uint64(),
    clint_base: 0x02000000U.to_uint64(),
    plic_base: 0x0C000000U.to_uint64(),
    dtb_addr: 0x87E00000U.to_uint64(),
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
const CSR_MISA : Int = 0x301
const CSR_FFLAGS : Int = 0x001
const CSR_FRM : Int = 0x002
const CSR_FCSR : Int = 0x003
const CSR_MEDELEG : Int = 0x302
const CSR_MIDELEG : Int = 0x303
const CSR_MIE : Int = 0x304
const CSR_MTVEC : Int = 0x305
const CSR_SSTATUS : Int = 0x100
const CSR_MEPC : Int = 0x341
const CSR_MCAUSE : Int = 0x342
const CSR_MTVAL : Int = 0x343
const CSR_MIP : Int = 0x344
const CSR_STVEC : Int = 0x105
const CSR_SSCRATCH : Int = 0x140
const CSR_SEPC : Int = 0x141
const CSR_SCAUSE : Int = 0x142
const CSR_STVAL : Int = 0x143
const CSR_SIE : Int = 0x104
const CSR_SIP : Int = 0x144
const CSR_SATP : Int = 0x180
const CSR_PMPCFG0 : Int = 0x3A0
const CSR_PMPADDR0 : Int = 0x3B0
const CSR_MNSTATUS : Int = 0x744
const CSR_MSCRATCH : Int = 0x340
const CSR_MCOUNTEREN : Int = 0x306
const CSR_SCOUNTEREN : Int = 0x106
const CSR_MENVCFG : Int = 0x30A
const CSR_SENVCFG : Int = 0x10A
const CSR_MHARTID : Int = 0xF14
const CSR_MVENDORID : Int = 0xF11
const CSR_MARCHID : Int = 0xF12
const CSR_MIMPID : Int = 0xF13
const CSR_VSTART : Int = 0x008
const CSR_VXSAT : Int = 0x009
const CSR_VXRM : Int = 0x00A
const CSR_VCSR : Int = 0x00F
const CSR_VL : Int = 0xC20
const CSR_VTYPE : Int = 0xC21
const CSR_VLENB : Int = 0xC22
const XLEN_32 : Int = 32
const XLEN_64 : Int = 64
const MSTATUS_SIE_BIT : UInt = 0x2U
const MSTATUS_SPIE_BIT : UInt = 0x20U
const MSTATUS_SPP_BIT : UInt = 0x100U
const MSTATUS_MIE_BIT : UInt = 0x8U
const MSTATUS_MPIE_BIT : UInt = 0x80U
const MSTATUS_MPP_SHIFT : Int = 11
const MSTATUS_MPP_MASK : UInt = 0x1800U
const SSTATUS_VISIBLE_MASK : UInt = 0xC0122U
// SIP/SIE visible mask: SSIP(bit 1) | STIP(bit 5) | SEIP(bit 9)
const SIP_VISIBLE_MASK : UInt64 = 0x222
const MSTATUS_MPRV_BIT : UInt64 = 0x20000 // bit 17
const MSTATUS_SUM_BIT : UInt64 = 0x40000 // bit 18
const MSTATUS_MXR_BIT : UInt64 = 0x80000 // bit 19
const FCSR_FFLAGS_MASK : UInt64 = 0x1f
const FCSR_FRM_SHIFT : Int = 5
const FCSR_FRM_MASK : UInt64 = 0xe0
const FCSR_VISIBLE_MASK : UInt64 = 0xff
const VCSR_VXSAT_MASK : UInt64 = 0x1
const VCSR_VXRM_SHIFT : Int = 1
const VCSR_VXRM_MASK : UInt64 = 0x6
const VCSR_VISIBLE_MASK : UInt64 = 0x7
const MISA_EXT_A : UInt64 = 0x1
const MISA_EXT_C : UInt64 = 0x4
const MISA_EXT_D : UInt64 = 0x8
const MISA_EXT_F : UInt64 = 0x20
const MISA_EXT_I : UInt64 = 0x100
const MISA_EXT_M : UInt64 = 0x1000
const MISA_EXT_S : UInt64 = 0x40000
const MISA_EXT_U : UInt64 = 0x100000
const MISA_EXT_V : UInt64 = 0x200000
const VREG_COUNT : Int = 32
const VREG_WORDS_PER_REG : Int = 2
const VLEN_BYTES : Int = 16

///|
fn current_base_extensions() -> UInt64 {
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
pub fn CpuState::write_reg(self : CpuState, index : Int, value : UInt64) -> Unit {
  if index != 0 {
    self.registers[index] = value
  }
}

///|
pub fn CpuState::read_freg(self : CpuState, index : Int) -> UInt64 {
  self.fregisters[index]
}

///|
pub fn CpuState::write_freg(self : CpuState, index : Int, value : UInt64) -> Unit {
  self.fregisters[index] = value
}

///|
pub fn CpuState::read_vreg(self : CpuState, index : Int, word : Int) -> UInt64 {
  self.vregisters[(index * VREG_WORDS_PER_REG) + word]
}

///|
pub fn CpuState::write_vreg(self : CpuState, index : Int, word : Int, value : UInt64) -> Unit {
  self.vregisters[(index * VREG_WORDS_PER_REG) + word] = value
}

///|
pub fn CpuState::read_csr(self : CpuState, index : Int) -> UInt64 {
  self.csrs.read(index)
}

///|
pub fn CpuState::write_csr(self : CpuState, index : Int, value : UInt64) -> Unit {
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
  self.memory[bus_offset_as_int((addr + 1U.to_uint64()) - self.base_addr)] = (value >> 8).to_byte()
}

///|
pub fn Bus::store_u32(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
  self.memory[bus_offset_as_int((addr + 1U.to_uint64()) - self.base_addr)] = (value >> 8).to_byte()
  self.memory[bus_offset_as_int((addr + 2U.to_uint64()) - self.base_addr)] = (value >> 16).to_byte()
  self.memory[bus_offset_as_int((addr + 3U.to_uint64()) - self.base_addr)] = (value >> 24).to_byte()
}

///|
pub fn Bus::store_u64(self : Bus, addr : UInt64, value : UInt64) -> Unit {
  self.memory[bus_offset_as_int(addr - self.base_addr)] = value.to_byte()
  self.memory[bus_offset_as_int((addr + 1U.to_uint64()) - self.base_addr)] = (value >> 8).to_byte()
  self.memory[bus_offset_as_int((addr + 2U.to_uint64()) - self.base_addr)] = (value >> 16).to_byte()
  self.memory[bus_offset_as_int((addr + 3U.to_uint64()) - self.base_addr)] = (value >> 24).to_byte()
  self.memory[bus_offset_as_int((addr + 4U.to_uint64()) - self.base_addr)] = (value >> 32).to_byte()
  self.memory[bus_offset_as_int((addr + 5U.to_uint64()) - self.base_addr)] = (value >> 40).to_byte()
  self.memory[bus_offset_as_int((addr + 6U.to_uint64()) - self.base_addr)] = (value >> 48).to_byte()
  self.memory[bus_offset_as_int((addr + 7U.to_uint64()) - self.base_addr)] = (value >> 56).to_byte()
}

///|
pub fn Bus::write_bytes(self : Bus, base_addr : UInt64, bytes : Bytes) -> Unit {
  let mut index = 0
  while index < bytes.length() {
    self.memory[
      bus_offset_as_int((base_addr + index.reinterpret_as_uint().to_uint64()) - self.base_addr)
    ] = bytes[index]
    index = index + 1
  }
}

///|
pub fn Bus::zero_range(self : Bus, base_addr : UInt64, len : Int) -> Unit {
  let mut index = 0
  while index < len {
    self.store_u8(base_addr + index.reinterpret_as_uint().to_uint64(), 0U.to_uint64())
    index = index + 1
  }
}

///|
fn Bus::fetch_u16(self : Bus, addr : UInt64) -> UInt {
  self.load_raw_u16(addr)
}

///|
fn Bus::fetch_u32(self : Bus, addr : UInt64) -> UInt {
  self.load_raw_u32(addr)
}

///|
///|
pub fn make_runner(config : MachineConfig) -> Runner {
  {
    cpu: CpuState::new(
      config.entry_point,
      config.hart_id,
      config.xlen,
      config.extensions,
    ),
    bus: Bus::new(config.ram_base, config.ram_size),
    config,
    uart_output: [],
    uart_input: @queue.new(),
    mtime: [0U.to_uint64()],
    clint_msip: Array::make(2, false),
    all_mtimecmp: Array::make(2, bit_not(0U.to_uint64())),
    plic_regs: if config.plic_base != 0U.to_uint64() {
      Array::make(0x400000, 0U.to_byte())
    } else {
      []
    },
  }
}

///|
/// Create N runners sharing bus, UART, PLIC, CLINT, and mtime for SMP simulation.
/// All harts start at the same entry point (cold/warm boot path is chosen via MHARTID).
pub fn make_smp_runners(config : MachineConfig, num_harts : Int) -> Array[Runner] {
  let shared_bus = Bus::new(config.ram_base, config.ram_size)
  let shared_uart : Array[Byte] = []
  let shared_uart_input : @queue.Queue[Byte] = @queue.new()
  let shared_plic : Array[Byte] = if config.plic_base != 0U.to_uint64() {
    Array::make(0x400000, 0U.to_byte())
  } else {
    []
  }
  let shared_mtime : Array[UInt64] = [0U.to_uint64()]
  let shared_msip : Array[Bool] = Array::make(num_harts, false)
  let shared_mtimecmp : Array[UInt64] = Array::make(
    num_harts,
    bit_not(0U.to_uint64()),
  )
  let harts : Array[Runner] = []
  let mut i = 0
  while i < num_harts {
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
      dtb_addr: config.dtb_addr,
    }
    harts.push({
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
      mtime: shared_mtime,
      clint_msip: shared_msip,
      all_mtimecmp: shared_mtimecmp,
      plic_regs: shared_plic,
    })
    i = i + 1
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
}

///|
/// Load a DTB blob into RAM at config.dtb_addr.
pub fn Runner::load_dtb(self : Runner, dtb : Bytes) -> Unit {
  self.bus.write_bytes(self.config.dtb_addr, dtb)
}

///|
/// Set up the SBI/Linux boot ABI: a0 = hart_id, a1 = dtb_addr.
pub fn Runner::setup_boot_abi(self : Runner) -> Unit {
  self.cpu.write_reg(10, self.config.hart_id) // a0 = hart_id
  self.cpu.write_reg(11, self.config.dtb_addr) // a1 = dtb_addr
}
