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
  ram_base : UInt64
  ram_size : Int
  entry_point : UInt64
  hart_id : UInt64
}

///|
pub enum PrivilegeMode {
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
  Lwu(Int, Int, Int)
  Ld(Int, Int, Int)
  Lbu(Int, Int, Int)
  Lhu(Int, Int, Int)
  Sb(Int, Int, Int)
  Sh(Int, Int, Int)
  Sw(Int, Int, Int)
  Sd(Int, Int, Int)
  Jal(Int, Int)
  Jalr(Int, Int, Int)
  Csrrw(Int, Int, Int)
  Csrrs(Int, Int, Int)
  Csrrc(Int, Int, Int)
  Csrrwi(Int, Int, UInt)
  Csrrsi(Int, Int, UInt)
  Csrrci(Int, Int, UInt)
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
  EnvironmentCallFromUMode
  EnvironmentCallFromSMode
  EnvironmentCallFromMMode
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
}

///|
pub fn default_machine_config() -> MachineConfig {
  {
    xlen: Xlen32,
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
  }
}

///|
pub fn official_riscv_tests_machine_config_for_xlen(xlen : Xlen) -> MachineConfig {
  {
    xlen,
    ram_base: 0x80000000U.to_uint64(),
    ram_size: 0x20000,
    entry_point: 0x80000000U.to_uint64(),
    hart_id: 0U.to_uint64(),
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
    ram_base: 0U.to_uint64(),
    ram_size: 65536,
    entry_point: 0U.to_uint64(),
    hart_id: 0U.to_uint64(),
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
const CSR_SATP : Int = 0x180
const CSR_PMPCFG0 : Int = 0x3A0
const CSR_PMPADDR0 : Int = 0x3B0
const CSR_MNSTATUS : Int = 0x744
const CSR_MHARTID : Int = 0xF14
const XLEN_32 : Int = 32
const XLEN_64 : Int = 64
const MSTATUS_SIE_BIT : UInt = 0x2U
const MSTATUS_SPIE_BIT : UInt = 0x20U
const MSTATUS_SPP_BIT : UInt = 0x100U
const MSTATUS_MIE_BIT : UInt = 0x8U
const MSTATUS_MPIE_BIT : UInt = 0x80U
const MSTATUS_MPP_SHIFT : Int = 11
const MSTATUS_MPP_MASK : UInt = 0x1800U
const SSTATUS_VISIBLE_MASK : UInt = 0x122U

///|
fn misa_value(xlen : Xlen) -> UInt64 {
  let extensions = 0x101104U.to_uint64()
  match xlen {
    Xlen32 => (1U.to_uint64() << 30) | extensions
    Xlen64 => (2U.to_uint64() << 62) | extensions
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
pub fn CpuState::new(entry_point : UInt64, hart_id : UInt64, xlen : Xlen) -> CpuState {
  let csrs = CsrFile::new()
  csrs.write(CSR_MISA, misa_value(xlen))
  csrs.write(CSR_MHARTID, hart_id)
  {
    pc: entry_point,
    registers: Array::make(32, 0U.to_uint64()),
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
fn rd(raw : UInt) -> Int {
  ((raw >> 7) & 0x1fU).reinterpret_as_int()
}

///|
fn rs1(raw : UInt) -> Int {
  ((raw >> 15) & 0x1fU).reinterpret_as_int()
}

///|
fn rs2(raw : UInt) -> Int {
  ((raw >> 20) & 0x1fU).reinterpret_as_int()
}

///|
fn funct3(raw : UInt) -> UInt {
  (raw >> 12) & 0x7U
}

///|
fn funct7(raw : UInt) -> UInt {
  (raw >> 25) & 0x7fU
}

///|
fn funct6(raw : UInt) -> UInt {
  (raw >> 26) & 0x3fU
}

///|
fn c_funct3(raw : UInt) -> UInt {
  (raw >> 13) & 0x7U
}

///|
fn instruction_length_from_low16(low16 : UInt) -> Int {
  if (low16 & 0x3U) == 0x3U {
    4
  } else {
    2
  }
}

///|
fn csr_addr(raw : UInt) -> Int {
  ((raw >> 20) & 0xfffU).reinterpret_as_int()
}

///|
fn csr_uimm(raw : UInt) -> UInt {
  (raw >> 15) & 0x1fU
}

///|
fn c_rd_rs1(raw : UInt) -> Int {
  ((raw >> 7) & 0x1fU).reinterpret_as_int()
}

///|
fn c_rs2(raw : UInt) -> Int {
  ((raw >> 2) & 0x1fU).reinterpret_as_int()
}

///|
fn c_rd_prime(raw : UInt) -> Int {
  8 + (((raw >> 2) & 0x7U).reinterpret_as_int())
}

///|
fn c_rs1_prime(raw : UInt) -> Int {
  8 + (((raw >> 7) & 0x7U).reinterpret_as_int())
}

///|
fn c_rs2_prime(raw : UInt) -> Int {
  8 + (((raw >> 2) & 0x7U).reinterpret_as_int())
}

///|
fn sign_extend(value : UInt, bits : Int) -> Int {
  let shift = 32 - bits
  (value << shift).reinterpret_as_int() >> shift
}

///|
fn imm_i(raw : UInt) -> Int {
  sign_extend(raw >> 20, 12)
}

///|
fn shamt_i(raw : UInt) -> Int {
  ((raw >> 20) & 0x3fU).reinterpret_as_int()
}

///|
fn shamt_iw(raw : UInt) -> Int {
  ((raw >> 20) & 0x1fU).reinterpret_as_int()
}

///|
fn imm_s(raw : UInt) -> Int {
  let upper = ((raw >> 25) & 0x7fU) << 5
  let lower = (raw >> 7) & 0x1fU
  sign_extend(upper | lower, 12)
}

///|
fn imm_b(raw : UInt) -> Int {
  let bit12 = ((raw >> 31) & 0x1U) << 12
  let bit11 = ((raw >> 7) & 0x1U) << 11
  let bits10_5 = ((raw >> 25) & 0x3fU) << 5
  let bits4_1 = ((raw >> 8) & 0xfU) << 1
  sign_extend(bit12 | bit11 | bits10_5 | bits4_1, 13)
}

///|
fn imm_u(raw : UInt) -> UInt {
  raw & 0xfffff000U
}

///|
fn imm_j(raw : UInt) -> Int {
  let bit20 = ((raw >> 31) & 0x1U) << 20
  let bits19_12 = ((raw >> 12) & 0xffU) << 12
  let bit11 = ((raw >> 20) & 0x1U) << 11
  let bits10_1 = ((raw >> 21) & 0x3ffU) << 1
  sign_extend(bit20 | bits19_12 | bit11 | bits10_1, 21)
}

///|
fn c_imm_ci(raw : UInt) -> Int {
  sign_extend((((raw >> 12) & 0x1U) << 5) | ((raw >> 2) & 0x1fU), 6)
}

///|
fn c_lui_imm(raw : UInt) -> UInt {
  (sign_extend((((raw >> 12) & 0x1U) << 5) | ((raw >> 2) & 0x1fU), 6)
    .reinterpret_as_uint()) <<
  12
}

///|
fn c_imm_cj(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 11) |
    (((raw >> 11) & 0x1U) << 4) |
    (((raw >> 9) & 0x3U) << 8) |
    (((raw >> 8) & 0x1U) << 10) |
    (((raw >> 7) & 0x1U) << 6) |
    (((raw >> 6) & 0x1U) << 7) |
    (((raw >> 3) & 0x7U) << 1) |
    (((raw >> 2) & 0x1U) << 5)
  sign_extend(imm, 12)
}

///|
fn c_imm_cb(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 8) |
    (((raw >> 10) & 0x3U) << 3) |
    (((raw >> 5) & 0x3U) << 6) |
    (((raw >> 3) & 0x3U) << 1) |
    (((raw >> 2) & 0x1U) << 5)
  sign_extend(imm, 9)
}

///|
fn c_uimm_lw_sw(raw : UInt) -> Int {
  ((((raw >> 10) & 0x7U) << 3) |
  (((raw >> 6) & 0x1U) << 2) |
  (((raw >> 5) & 0x1U) << 6)).reinterpret_as_int()
}

///|
fn c_nzuimm_addi4spn(raw : UInt) -> Int {
  ((((raw >> 12) & 0x1U) << 5) |
  (((raw >> 11) & 0x1U) << 4) |
  (((raw >> 10) & 0x1U) << 9) |
  (((raw >> 9) & 0x1U) << 8) |
  (((raw >> 8) & 0x1U) << 7) |
  (((raw >> 7) & 0x1U) << 6) |
  (((raw >> 6) & 0x1U) << 2) |
  (((raw >> 5) & 0x1U) << 3)).reinterpret_as_int()
}

///|
fn c_nzimm_addi16sp(raw : UInt) -> Int {
  let imm = (((raw >> 12) & 0x1U) << 9) |
    (((raw >> 4) & 0x1U) << 8) |
    (((raw >> 3) & 0x1U) << 7) |
    (((raw >> 5) & 0x1U) << 6) |
    (((raw >> 2) & 0x1U) << 5) |
    (((raw >> 6) & 0x1U) << 4)
  sign_extend(imm, 10)
}

///|
fn c_uimm_lwsp(raw : UInt) -> Int {
  ((((raw >> 2) & 0x3U) << 6) |
  (((raw >> 4) & 0x7U) << 2) |
  (((raw >> 12) & 0x1U) << 5)).reinterpret_as_int()
}

///|
fn c_uimm_swsp(raw : UInt) -> Int {
  ((((raw >> 7) & 0x3U) << 6) |
  (((raw >> 9) & 0xfU) << 2)).reinterpret_as_int()
}

///|
fn c_funct2_cb(raw : UInt) -> UInt {
  (raw >> 10) & 0x3U
}

///|
fn c_funct2_ca(raw : UInt) -> UInt {
  (raw >> 5) & 0x3U
}

///|
fn int_to_uint64_bits(value : Int) -> UInt64 {
  value.to_int64().reinterpret_as_uint64()
}

///|
fn low32(value : UInt64) -> UInt {
  value.to_uint()
}

///|
fn as_signed_64(value : UInt64) -> Int64 {
  value.reinterpret_as_int64()
}

///|
fn sign_extend_to_32(value : UInt64, bits : Int) -> UInt64 {
  sign_extend(low32(value), bits).to_int64().reinterpret_as_uint64()
}

///|
fn sign_extend_64(value : UInt64, bits : Int) -> UInt64 {
  if bits >= 64 {
    value
  } else {
    let shift = 64 - bits
    ((value << shift).reinterpret_as_int64() >> shift).reinterpret_as_uint64()
  }
}

///|
fn shift_mask_32(value : UInt64) -> Int {
  low32(value).reinterpret_as_int() & 0x1f
}

///|
fn shift_mask_64(value : UInt64) -> Int {
  (value & 0x3fU.to_uint64()).reinterpret_as_int64().to_int()
}

///|
fn arithmetic_shift_right_32(value : UInt64, shamt : Int) -> UInt64 {
  let signed = sign_extend_to_32(value, 32).reinterpret_as_int64()
  (signed >> shamt).reinterpret_as_uint64()
}

///|
fn arithmetic_shift_right_64(value : UInt64, shamt : Int) -> UInt64 {
  (as_signed_64(value) >> shamt).reinterpret_as_uint64()
}

///|
fn compare_signed_32(lhs : UInt64, rhs : UInt64) -> Int {
  let left = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let right = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_unsigned_32(lhs : UInt64, rhs : UInt64) -> Int {
  let left = low32(lhs)
  let right = low32(rhs)
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_signed_64(lhs : UInt64, rhs : UInt64) -> Int {
  let left = as_signed_64(lhs)
  let right = as_signed_64(rhs)
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_unsigned_64(lhs : UInt64, rhs : UInt64) -> Int {
  if lhs < rhs {
    -1
  } else if lhs > rhs {
    1
  } else {
    0
  }
}

///|
fn high_word_u64(value : UInt64) -> UInt64 {
  value >> 32
}

///|
fn mulh_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(
    (sign_extend_to_32(lhs, 32).reinterpret_as_int64() *
    sign_extend_to_32(rhs, 32).reinterpret_as_int64()).reinterpret_as_uint64(),
  )
}

///|
fn mulhsu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(
    (sign_extend_to_32(lhs, 32).reinterpret_as_int64() *
    low32(rhs).to_uint64().reinterpret_as_int64()).reinterpret_as_uint64(),
  )
}

///|
fn mulhu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  high_word_u64(low32(lhs).to_uint64() * low32(rhs).to_uint64())
}

///|
fn mulhu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let lhs_low = lhs & 0xffffffffU.to_uint64()
  let lhs_high = lhs >> 32
  let rhs_low = rhs & 0xffffffffU.to_uint64()
  let rhs_high = rhs >> 32
  let ll = lhs_low * rhs_low
  let lh = lhs_low * rhs_high
  let hl = lhs_high * rhs_low
  let hh = lhs_high * rhs_high
  hh + (lh >> 32) + (hl >> 32) + (((ll >> 32) + (lh & 0xffffffffU.to_uint64()) + (hl & 0xffffffffU.to_uint64())) >> 32)
}

///|
fn mulh_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let mut high = mulhu_64(lhs, rhs)
  if as_signed_64(lhs) < 0L {
    high = high - rhs
  }
  if as_signed_64(rhs) < 0L {
    high = high - lhs
  }
  high
}

///|
fn mulhsu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let mut high = mulhu_64(lhs, rhs)
  if as_signed_64(lhs) < 0L {
    high = high - rhs
  }
  high
}

///|
fn div_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let divisor = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  let int_min = 0x80000000U.reinterpret_as_int()
  if divisor == 0 {
    0xffffffffU.to_uint64()
  } else if dividend == int_min.to_int64() && divisor == -1L {
    low32(lhs).to_uint64()
  } else {
    (dividend / divisor).reinterpret_as_uint64()
  }
}

///|
fn divu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let left = low32(lhs).to_uint64()
  let right = low32(rhs).to_uint64()
  if right == 0U.to_uint64() {
    0xffffffffU.to_uint64()
  } else {
    left / right
  }
}

///|
fn rem_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = sign_extend_to_32(lhs, 32).reinterpret_as_int64()
  let divisor = sign_extend_to_32(rhs, 32).reinterpret_as_int64()
  let int_min = 0x80000000U.reinterpret_as_int()
  if divisor == 0 {
    low32(lhs).to_uint64()
  } else if dividend == int_min.to_int64() && divisor == -1L {
    0U.to_uint64()
  } else {
    (dividend % divisor).reinterpret_as_uint64()
  }
}

///|
fn remu_32(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let left = low32(lhs).to_uint64()
  let right = low32(rhs).to_uint64()
  if right == 0U.to_uint64() {
    left
  } else {
    left % right
  }
}

///|
fn div_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = as_signed_64(lhs)
  let divisor = as_signed_64(rhs)
  if divisor == 0L {
    bit_not(0U.to_uint64())
  } else if dividend == (1U.to_uint64() << 63).reinterpret_as_int64() && divisor == -1L {
    lhs
  } else {
    (dividend / divisor).reinterpret_as_uint64()
  }
}

///|
fn divu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if rhs == 0U.to_uint64() {
    bit_not(0U.to_uint64())
  } else {
    lhs / rhs
  }
}

///|
fn rem_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  let dividend = as_signed_64(lhs)
  let divisor = as_signed_64(rhs)
  if divisor == 0L {
    lhs
  } else if dividend == (1U.to_uint64() << 63).reinterpret_as_int64() && divisor == -1L {
    0U.to_uint64()
  } else {
    (dividend % divisor).reinterpret_as_uint64()
  }
}

///|
fn remu_64(lhs : UInt64, rhs : UInt64) -> UInt64 {
  if rhs == 0U.to_uint64() {
    lhs
  } else {
    lhs % rhs
  }
}

///|
fn xlen_shift_mask(value : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => shift_mask_32(value)
    XLEN_64 => shift_mask_64(value)
    _ => abort("unsupported xlen for shift mask")
  }
}

///|
fn xlen_sign_extend(value : UInt64, bits : Int, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => sign_extend_to_32(value, bits)
    XLEN_64 => sign_extend_64(value, bits)
    _ => abort("unsupported xlen for sign extension")
  }
}

///|
fn xlen_load_sign_extend(value : UInt64, bits : Int, xlen : Int) -> UInt64 {
  match bits {
    8 => xlen_sign_extend(value, 8, xlen)
    16 => xlen_sign_extend(value, 16, xlen)
    32 => xlen_sign_extend(value, 32, xlen)
    _ => abort("unsupported load sign extension width")
  }
}

///|
fn xlen_arithmetic_shift_right(value : UInt64, shamt : Int, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => arithmetic_shift_right_32(value, shamt)
    XLEN_64 => arithmetic_shift_right_64(value, shamt)
    _ => abort("unsupported xlen for arithmetic shift")
  }
}

///|
fn xlen_compare_signed(lhs : UInt64, rhs : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => compare_signed_32(lhs, rhs)
    XLEN_64 => compare_signed_64(lhs, rhs)
    _ => abort("unsupported xlen for signed compare")
  }
}

///|
fn xlen_compare_unsigned(lhs : UInt64, rhs : UInt64, xlen : Int) -> Int {
  match xlen {
    XLEN_32 => compare_unsigned_32(lhs, rhs)
    XLEN_64 => compare_unsigned_64(lhs, rhs)
    _ => abort("unsupported xlen for unsigned compare")
  }
}

///|
fn xlen_mulh(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulh_32(lhs, rhs)
    XLEN_64 => mulh_64(lhs, rhs)
    _ => abort("unsupported xlen for mulh")
  }
}

///|
fn xlen_mulhsu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulhsu_32(lhs, rhs)
    XLEN_64 => mulhsu_64(lhs, rhs)
    _ => abort("unsupported xlen for mulhsu")
  }
}

///|
fn xlen_mulhu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => mulhu_32(lhs, rhs)
    XLEN_64 => mulhu_64(lhs, rhs)
    _ => abort("unsupported xlen for mulhu")
  }
}

///|
fn xlen_div(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => div_32(lhs, rhs)
    XLEN_64 => div_64(lhs, rhs)
    _ => abort("unsupported xlen for div")
  }
}

///|
fn xlen_divu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => divu_32(lhs, rhs)
    XLEN_64 => divu_64(lhs, rhs)
    _ => abort("unsupported xlen for divu")
  }
}

///|
fn xlen_rem(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => rem_32(lhs, rhs)
    XLEN_64 => rem_64(lhs, rhs)
    _ => abort("unsupported xlen for rem")
  }
}

///|
fn xlen_remu(lhs : UInt64, rhs : UInt64, xlen : Int) -> UInt64 {
  match xlen {
    XLEN_32 => remu_32(lhs, rhs)
    XLEN_64 => remu_64(lhs, rhs)
    _ => abort("unsupported xlen for remu")
  }
}

///|
fn bool_to_reg(value : Bool) -> UInt64 {
  if value {
    1U.to_uint64()
  } else {
    0U.to_uint64()
  }
}

///|
fn trap_cause_code(cause : TrapCause) -> UInt64 {
  match cause {
    InstructionAccessFault => 1U.to_uint64()
    IllegalInstruction => 2U.to_uint64()
    LoadAccessFault => 5U.to_uint64()
    StoreAccessFault => 7U.to_uint64()
    EnvironmentCallFromUMode => 8U.to_uint64()
    EnvironmentCallFromSMode => 9U.to_uint64()
    EnvironmentCallFromMMode => 11U.to_uint64()
  }
}

///|
fn privilege_mode_from_code(code : UInt64) -> PrivilegeMode {
  if code == 1U.to_uint64() {
    Supervisor
  } else if code == 3U.to_uint64() {
    Machine
  } else {
    User
  }
}

///|
fn bit_not(value : UInt64) -> UInt64 {
  value ^ (-1L).reinterpret_as_uint64()
}

///|
fn mstatus_mie(value : UInt64) -> Bool {
  (value & MSTATUS_MIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_sie(value : UInt64) -> Bool {
  (value & MSTATUS_SIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_mpie(value : UInt64) -> Bool {
  (value & MSTATUS_MPIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_spie(value : UInt64) -> Bool {
  (value & MSTATUS_SPIE_BIT.to_uint64()) != 0U.to_uint64()
}

///|
fn mstatus_spp(value : UInt64) -> PrivilegeMode {
  if (value & MSTATUS_SPP_BIT.to_uint64()) != 0U.to_uint64() {
    Supervisor
  } else {
    User
  }
}

fn mstatus_mpp(value : UInt64) -> PrivilegeMode {
  privilege_mode_from_code((value & MSTATUS_MPP_MASK.to_uint64()) >> MSTATUS_MPP_SHIFT)
}

///|
fn set_mstatus_mie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_MIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_MIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_sie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_SIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_SIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_mpie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_MPIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_MPIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_spie(value : UInt64, enabled : Bool) -> UInt64 {
  if enabled {
    value | MSTATUS_SPIE_BIT.to_uint64()
  } else {
    value & bit_not(MSTATUS_SPIE_BIT.to_uint64())
  }
}

///|
fn set_mstatus_spp(value : UInt64, mode : PrivilegeMode) -> UInt64 {
  match mode {
    Supervisor => value | MSTATUS_SPP_BIT.to_uint64()
    _ => value & bit_not(MSTATUS_SPP_BIT.to_uint64())
  }
}

///|
fn set_mstatus_mpp(value : UInt64, mode : PrivilegeMode) -> UInt64 {
  let mode_bits = match mode {
    User => 0U.to_uint64()
    Supervisor => 1U.to_uint64()
    Machine => 3U.to_uint64()
  }
  (value & bit_not(MSTATUS_MPP_MASK.to_uint64())) |
  ((mode_bits << MSTATUS_MPP_SHIFT) & MSTATUS_MPP_MASK.to_uint64())
}

///|
fn mstatus_after_mret(mstatus : UInt64) -> UInt64 {
  set_mstatus_mpie(
    set_mstatus_mie(set_mstatus_mpp(mstatus, User), mstatus_mpie(mstatus)),
    true,
  )
}

///|
fn mstatus_after_sret(mstatus : UInt64) -> UInt64 {
  set_mstatus_spp(
    set_mstatus_spie(set_mstatus_sie(mstatus, mstatus_spie(mstatus)), true),
    User,
  )
}

///|
// Modeled machine CSRs participate in current machine-state semantics.
// Compatibility-only storage CSRs are kept writable for upstream env/p startup.
fn is_modeled_machine_csr(csr : Int) -> Bool {
  match csr {
    CSR_MSTATUS => true
    CSR_MIE => true
    CSR_MIP => true
    CSR_MTVEC => true
    CSR_MEPC => true
    CSR_MCAUSE => true
    CSR_MTVAL => true
    CSR_MISA => true
    CSR_MHARTID => true
    _ => false
  }
}

///|
fn is_modeled_supervisor_csr(csr : Int) -> Bool {
  match csr {
    CSR_SSTATUS => true
    CSR_STVEC => true
    CSR_SSCRATCH => true
    CSR_SEPC => true
    CSR_SCAUSE => true
    CSR_STVAL => true
    _ => false
  }
}

///|
fn is_compatibility_storage_csr(csr : Int) -> Bool {
  match csr {
    CSR_SATP => true
    CSR_MEDELEG => true
    CSR_MIDELEG => true
    CSR_PMPCFG0 => true
    CSR_PMPADDR0 => true
    CSR_MNSTATUS => true
    _ => false
  }
}

///|
fn is_read_only_csr(csr : Int) -> Bool {
  match csr {
    CSR_MISA => true
    CSR_MHARTID => true
    _ => false
  }
}

///|
fn is_supported_rw_csr(csr : Int) -> Bool {
  (is_modeled_machine_csr(csr) && !is_read_only_csr(csr)) ||
  is_modeled_supervisor_csr(csr) ||
  is_compatibility_storage_csr(csr)
}

///|
fn is_supported_csr(csr : Int) -> Bool {
  is_supported_rw_csr(csr) || is_read_only_csr(csr)
}

///|
fn instruction_supported_in_xlen(
  instruction : Instruction,
  xlen : Int,
  length : Int,
) -> Bool {
  match instruction {
    Addiw(_, _, _) => xlen == XLEN_64
    Slliw(_, _, _) => xlen == XLEN_64
    Srliw(_, _, _) => xlen == XLEN_64
    Sraiw(_, _, _) => xlen == XLEN_64
    Addw(_, _, _) => xlen == XLEN_64
    Subw(_, _, _) => xlen == XLEN_64
    Mulw(_, _, _) => xlen == XLEN_64
    Divw(_, _, _) => xlen == XLEN_64
    Divuw(_, _, _) => xlen == XLEN_64
    Remw(_, _, _) => xlen == XLEN_64
    Remuw(_, _, _) => xlen == XLEN_64
    Sllw(_, _, _) => xlen == XLEN_64
    Srlw(_, _, _) => xlen == XLEN_64
    Sraw(_, _, _) => xlen == XLEN_64
    Lwu(_, _, _) => xlen == XLEN_64
    Ld(_, _, _) => xlen == XLEN_64
    Sd(_, _, _) => xlen == XLEN_64
    // C.JAL exists only on RV32C; the 32-bit JAL x1 form remains legal on both widths.
    Jal(rd, _) => !(length == 2 && rd == 1 && xlen == XLEN_64)
    _ => true
  }
}

///|
pub fn decode(raw : UInt) -> Instruction {
  match raw & 0x7fU {
    0x0fU =>
      match funct3(raw) {
        0x0U => Fence
        0x1U => FenceI
        _ => Unknown(raw)
      }
    0x37U => Lui(rd(raw), imm_u(raw))
    0x17U => Auipc(rd(raw), imm_u(raw))
    0x13U =>
      match funct3(raw) {
        0x0U => Addi(rd(raw), rs1(raw), imm_i(raw))
        0x1U => Slli(rd(raw), rs1(raw), shamt_i(raw))
        0x2U => Slti(rd(raw), rs1(raw), imm_i(raw))
        0x3U => Sltiu(rd(raw), rs1(raw), imm_i(raw))
        0x4U => Xori(rd(raw), rs1(raw), imm_i(raw))
        0x6U => Ori(rd(raw), rs1(raw), imm_i(raw))
        0x7U => Andi(rd(raw), rs1(raw), imm_i(raw))
        0x5U =>
          match funct6(raw) {
            0x00U => Srli(rd(raw), rs1(raw), shamt_i(raw))
            0x10U => Srai(rd(raw), rs1(raw), shamt_i(raw))
            _ => Unknown(raw)
          }
        _ => Unknown(raw)
      }
    0x1bU =>
      match funct3(raw) {
        0x0U => Addiw(rd(raw), rs1(raw), imm_i(raw))
        0x1U =>
          match funct7(raw) {
            0x00U => Slliw(rd(raw), rs1(raw), shamt_iw(raw))
            _ => Unknown(raw)
          }
        0x5U =>
          match funct7(raw) {
            0x00U => Srliw(rd(raw), rs1(raw), shamt_iw(raw))
            0x20U => Sraiw(rd(raw), rs1(raw), shamt_iw(raw))
            _ => Unknown(raw)
          }
        _ => Unknown(raw)
      }
    0x33U =>
      match (funct3(raw), funct7(raw)) {
        (0x0U, 0x00U) => Add(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x20U) => Sub(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x01U) => Mul(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x00U) => Sll(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x01U) => Mulh(rd(raw), rs1(raw), rs2(raw))
        (0x2U, 0x00U) => Slt(rd(raw), rs1(raw), rs2(raw))
        (0x2U, 0x01U) => Mulhsu(rd(raw), rs1(raw), rs2(raw))
        (0x3U, 0x00U) => Sltu(rd(raw), rs1(raw), rs2(raw))
        (0x3U, 0x01U) => Mulhu(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x00U) => Xor(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x01U) => Div(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x00U) => Srl(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x20U) => Sra(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x01U) => Divu(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x00U) => Or(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x01U) => Rem(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x00U) => And(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x01U) => Remu(rd(raw), rs1(raw), rs2(raw))
        _ => Unknown(raw)
      }
    0x3bU =>
      match (funct3(raw), funct7(raw)) {
        (0x0U, 0x00U) => Addw(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x20U) => Subw(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x01U) => Mulw(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x00U) => Sllw(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x01U) => Divw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x00U) => Srlw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x20U) => Sraw(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x01U) => Divuw(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x01U) => Remw(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x01U) => Remuw(rd(raw), rs1(raw), rs2(raw))
        _ => Unknown(raw)
      }
    0x63U =>
      match funct3(raw) {
        0x0U => Beq(rs1(raw), rs2(raw), imm_b(raw))
        0x1U => Bne(rs1(raw), rs2(raw), imm_b(raw))
        0x4U => Blt(rs1(raw), rs2(raw), imm_b(raw))
        0x5U => Bge(rs1(raw), rs2(raw), imm_b(raw))
        0x6U => Bltu(rs1(raw), rs2(raw), imm_b(raw))
        0x7U => Bgeu(rs1(raw), rs2(raw), imm_b(raw))
        _ => Unknown(raw)
      }
    0x03U =>
      match funct3(raw) {
        0x0U => Lb(rd(raw), rs1(raw), imm_i(raw))
        0x1U => Lh(rd(raw), rs1(raw), imm_i(raw))
        0x2U => Lw(rd(raw), rs1(raw), imm_i(raw))
        0x3U => Ld(rd(raw), rs1(raw), imm_i(raw))
        0x4U => Lbu(rd(raw), rs1(raw), imm_i(raw))
        0x5U => Lhu(rd(raw), rs1(raw), imm_i(raw))
        0x6U => Lwu(rd(raw), rs1(raw), imm_i(raw))
        _ => Unknown(raw)
      }
    0x23U =>
      match funct3(raw) {
        0x0U => Sb(rs1(raw), rs2(raw), imm_s(raw))
        0x1U => Sh(rs1(raw), rs2(raw), imm_s(raw))
        0x2U => Sw(rs1(raw), rs2(raw), imm_s(raw))
        0x3U => Sd(rs1(raw), rs2(raw), imm_s(raw))
        _ => Unknown(raw)
      }
    0x6fU => Jal(rd(raw), imm_j(raw))
    0x67U =>
      match funct3(raw) {
        0x0U => Jalr(rd(raw), rs1(raw), imm_i(raw))
        _ => Unknown(raw)
      }
    0x73U =>
      match funct3(raw) {
        0x0U =>
          match csr_addr(raw) {
            0x000 => Ecall
            0x302 => Mret
            0x102 => Sret
            _ => Unknown(raw)
          }
        0x1U => Csrrw(rd(raw), csr_addr(raw), rs1(raw))
        0x2U => Csrrs(rd(raw), csr_addr(raw), rs1(raw))
        0x3U => Csrrc(rd(raw), csr_addr(raw), rs1(raw))
        0x5U => Csrrwi(rd(raw), csr_addr(raw), csr_uimm(raw))
        0x6U => Csrrsi(rd(raw), csr_addr(raw), csr_uimm(raw))
        0x7U => Csrrci(rd(raw), csr_addr(raw), csr_uimm(raw))
        _ => Unknown(raw)
      }
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q0(raw : UInt) -> Instruction {
  match c_funct3(raw) {
    0x0U => {
      let imm = c_nzuimm_addi4spn(raw)
      if imm == 0 {
        Unknown(raw)
      } else {
        Addi(c_rd_prime(raw), 2, imm)
      }
    }
    0x2U => Lw(c_rd_prime(raw), c_rs1_prime(raw), c_uimm_lw_sw(raw))
    0x6U => Sw(c_rs1_prime(raw), c_rs2_prime(raw), c_uimm_lw_sw(raw))
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q1_cb(raw : UInt) -> Instruction {
  let rd = c_rs1_prime(raw)
  let rs2 = c_rs2_prime(raw)
  match c_funct2_cb(raw) {
    0x0U => {
      if ((raw >> 12) & 0x1U) != 0U {
        Unknown(raw)
      } else {
        Srli(rd, rd, c_imm_ci(raw))
      }
    }
    0x1U => {
      if ((raw >> 12) & 0x1U) != 0U {
        Unknown(raw)
      } else {
        Srai(rd, rd, c_imm_ci(raw))
      }
    }
    0x2U => Andi(rd, rd, c_imm_ci(raw))
    0x3U =>
      if ((raw >> 12) & 0x1U) != 0U {
        Unknown(raw)
      } else {
        match c_funct2_ca(raw) {
          0x0U => Sub(rd, rd, rs2)
          0x1U => Xor(rd, rd, rs2)
          0x2U => Or(rd, rd, rs2)
          0x3U => And(rd, rd, rs2)
          _ => Unknown(raw)
        }
      }
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q1(raw : UInt) -> Instruction {
  match c_funct3(raw) {
    0x0U => Addi(c_rd_rs1(raw), c_rd_rs1(raw), c_imm_ci(raw))
    0x1U => Jal(1, c_imm_cj(raw))
    0x2U => Addi(c_rd_rs1(raw), 0, c_imm_ci(raw))
    0x3U => {
      let rd = c_rd_rs1(raw)
      if rd == 2 {
        let imm = c_nzimm_addi16sp(raw)
        if imm == 0 {
          Unknown(raw)
        } else {
          Addi(2, 2, imm)
        }
      } else {
        let imm = c_imm_ci(raw)
        if rd == 0 || imm == 0 {
          Unknown(raw)
        } else {
          Lui(rd, c_lui_imm(raw))
        }
      }
    }
    0x4U => decode_c_q1_cb(raw)
    0x5U => Jal(0, c_imm_cj(raw))
    0x6U => Beq(c_rs1_prime(raw), 0, c_imm_cb(raw))
    0x7U => Bne(c_rs1_prime(raw), 0, c_imm_cb(raw))
    _ => Unknown(raw)
  }
}

///|
fn decode_c_q2_cr(raw : UInt) -> Instruction {
  let rd = c_rd_rs1(raw)
  let rs2 = c_rs2(raw)
  if ((raw >> 12) & 0x1U) == 0U {
    if rs2 == 0 {
      if rd == 0 { Unknown(raw) } else { Jalr(0, rd, 0) }
    } else {
      Add(rd, 0, rs2)
    }
  } else {
    if rs2 == 0 {
      if rd == 0 { Unknown(raw) } else { Jalr(1, rd, 0) }
    } else {
      Add(rd, rd, rs2)
    }
  }
}

///|
fn decode_c_q2(raw : UInt) -> Instruction {
  match c_funct3(raw) {
    0x0U => {
      let rd = c_rd_rs1(raw)
      if rd == 0 {
        Unknown(raw)
      } else {
        Slli(rd, rd, c_imm_ci(raw))
      }
    }
    0x2U => {
      let rd = c_rd_rs1(raw)
      if rd == 0 {
        Unknown(raw)
      } else {
        Lw(rd, 2, c_uimm_lwsp(raw))
      }
    }
    0x4U => decode_c_q2_cr(raw)
    0x6U => Sw(2, c_rs2(raw), c_uimm_swsp(raw))
    _ => Unknown(raw)
  }
}

///|
fn decode_compressed(raw : UInt) -> Instruction {
  match raw & 0x3U {
    0x0U => decode_c_q0(raw)
    0x1U => decode_c_q1(raw)
    0x2U => decode_c_q2(raw)
    _ => Unknown(raw)
  }
}

///|
pub fn make_runner(config : MachineConfig) -> Runner {
  {
    cpu: CpuState::new(config.entry_point, config.hart_id, config.xlen),
    bus: Bus::new(config.ram_base, config.ram_size),
    config,
  }
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
fn bytes_load_u8(bytes : Bytes, offset : Int) -> UInt {
  bytes[offset].to_uint()
}

///|
fn bytes_load_u16(bytes : Bytes, offset : Int) -> UInt {
  bytes_load_u8(bytes, offset) |
  (bytes_load_u8(bytes, offset + 1) << 8)
}

///|
fn bytes_load_u32(bytes : Bytes, offset : Int) -> UInt {
  bytes_load_u8(bytes, offset) |
  (bytes_load_u8(bytes, offset + 1) << 8) |
  (bytes_load_u8(bytes, offset + 2) << 16) |
  (bytes_load_u8(bytes, offset + 3) << 24)
}

///|
fn bytes_load_u64(bytes : Bytes, offset : Int) -> UInt64 {
  bytes_load_u8(bytes, offset).to_uint64() |
  (bytes_load_u8(bytes, offset + 1).to_uint64() << 8) |
  (bytes_load_u8(bytes, offset + 2).to_uint64() << 16) |
  (bytes_load_u8(bytes, offset + 3).to_uint64() << 24) |
  (bytes_load_u8(bytes, offset + 4).to_uint64() << 32) |
  (bytes_load_u8(bytes, offset + 5).to_uint64() << 40) |
  (bytes_load_u8(bytes, offset + 6).to_uint64() << 48) |
  (bytes_load_u8(bytes, offset + 7).to_uint64() << 56)
}

///|
fn bytes_range_ok(bytes : Bytes, offset : Int, len : Int) -> Bool {
  offset >= 0 && len >= 0 && offset + len <= bytes.length()
}

///|
fn c_string_matches(
  bytes : Bytes,
  string_base : Int,
  name_offset : Int,
  expected : Array[Int],
) -> Bool {
  let mut index = 0
  while index < expected.length() {
    let current = string_base + name_offset + index
    if current >= bytes.length() || bytes[current].to_int() != expected[index] {
      return false
    }
    index = index + 1
  }
  let terminator = string_base + name_offset + expected.length()
  terminator < bytes.length() && bytes[terminator].to_int() == 0
}

///|
fn elf_symbol_matches(
  bytes : Bytes,
  string_base : Int,
  name_offset : UInt64,
  expected : Array[Int],
) -> Bool {
  c_string_matches(bytes, string_base, name_offset.reinterpret_as_int64().to_int(), expected)
}

///|
fn find_elf32_symbol_addr(
  bytes : Bytes,
  symtab_offset : Int,
  symtab_size : Int,
  strtab_offset : Int,
  target_name : Array[Int],
) -> UInt64? {
  let mut index = 0
  while index + 16 <= symtab_size {
    let entry_offset = symtab_offset + index
    let name_offset = bytes_load_u32(bytes, entry_offset).to_uint64()
    let value = bytes_load_u32(bytes, entry_offset + 4).to_uint64()
    if elf_symbol_matches(bytes, strtab_offset, name_offset, target_name) {
      return Some(value)
    }
    index = index + 16
  }
  None
}

///|
fn find_elf64_symbol_addr(
  bytes : Bytes,
  symtab_offset : Int,
  symtab_size : Int,
  strtab_offset : Int,
  target_name : Array[Int],
) -> UInt64? {
  let mut index = 0
  while index + 24 <= symtab_size {
    let entry_offset = symtab_offset + index
    let name_offset = bytes_load_u32(bytes, entry_offset).to_uint64()
    let value = bytes_load_u64(bytes, entry_offset + 8)
    if elf_symbol_matches(bytes, strtab_offset, name_offset, target_name) {
      return Some(value)
    }
    index = index + 24
  }
  None
}

///|
fn parse_elf32_symbols(
  bytes : Bytes,
  shoff : Int,
  shentsize : Int,
  shnum : Int,
) -> (UInt64?, UInt64?, UInt64?, UInt64?) {
  let mut tohost = None
  let mut fromhost = None
  let mut begin_signature = None
  let mut end_signature = None
  let mut index = 0
  while index < shnum {
    let sh_offset = shoff + (index * shentsize)
    let sh_type = bytes_load_u32(bytes, sh_offset + 4)
    if sh_type == 2U {
      let symtab_offset = bytes_load_u32(bytes, sh_offset + 16).reinterpret_as_int()
      let symtab_size = bytes_load_u32(bytes, sh_offset + 20).reinterpret_as_int()
      let strtab_index = bytes_load_u32(bytes, sh_offset + 24).reinterpret_as_int()
      let strtab_header = shoff + (strtab_index * shentsize)
      let strtab_offset = bytes_load_u32(bytes, strtab_header + 16).reinterpret_as_int()
      if bytes_range_ok(bytes, symtab_offset, symtab_size) {
        tohost = find_elf32_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [116, 111, 104, 111, 115, 116],
        )
        fromhost = find_elf32_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [102, 114, 111, 109, 104, 111, 115, 116],
        )
        begin_signature = find_elf32_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [98, 101, 103, 105, 110, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
        )
        end_signature = find_elf32_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [101, 110, 100, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
        )
      }
    }
    index = index + 1
  }
  (tohost, fromhost, begin_signature, end_signature)
}

///|
fn parse_elf64_symbols(
  bytes : Bytes,
  shoff : Int,
  shentsize : Int,
  shnum : Int,
) -> (UInt64?, UInt64?, UInt64?, UInt64?) {
  let mut tohost = None
  let mut fromhost = None
  let mut begin_signature = None
  let mut end_signature = None
  let mut index = 0
  while index < shnum {
    let sh_offset = shoff + (index * shentsize)
    let sh_type = bytes_load_u32(bytes, sh_offset + 4)
    if sh_type == 2U {
      let symtab_offset = bytes_load_u64(bytes, sh_offset + 24).reinterpret_as_int64().to_int()
      let symtab_size = bytes_load_u64(bytes, sh_offset + 32).reinterpret_as_int64().to_int()
      let strtab_index = bytes_load_u32(bytes, sh_offset + 40).reinterpret_as_int()
      let strtab_header = shoff + (strtab_index * shentsize)
      let strtab_offset = bytes_load_u64(bytes, strtab_header + 24).reinterpret_as_int64().to_int()
      if bytes_range_ok(bytes, symtab_offset, symtab_size) {
        tohost = find_elf64_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [116, 111, 104, 111, 115, 116],
        )
        fromhost = find_elf64_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [102, 114, 111, 109, 104, 111, 115, 116],
        )
        begin_signature = find_elf64_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [98, 101, 103, 105, 110, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
        )
        end_signature = find_elf64_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [101, 110, 100, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
        )
      }
    }
    index = index + 1
  }
  (tohost, fromhost, begin_signature, end_signature)
}

///|
fn Runner::load_elf_segment(
  self : Runner,
  bytes : Bytes,
  file_offset : Int,
  file_size : Int,
  virtual_addr : UInt64,
  mem_size : Int,
) -> String? {
  if !bytes_range_ok(bytes, file_offset, file_size) {
    return Some("segment data is truncated")
  }
  if !self.bus.contains_range(virtual_addr, mem_size) {
    return Some("segment does not fit in configured RAM")
  }
  let mut byte_index = 0
  while byte_index < file_size {
    self.bus.store_u8(
      virtual_addr + byte_index.reinterpret_as_uint().to_uint64(),
      bytes[file_offset + byte_index].to_uint().to_uint64(),
    )
    byte_index = byte_index + 1
  }
  if mem_size > file_size {
    self.bus.zero_range(
      virtual_addr + file_size.reinterpret_as_uint().to_uint64(),
      mem_size - file_size,
    )
  }
  None
}

///|
pub fn Runner::load_elf(self : Runner, bytes : Bytes) -> LoadElfResult {
  if !bytes_range_ok(bytes, 0, 52) {
    return LoadError("ELF header is truncated")
  }
  if bytes[0].to_int() != 0x7f ||
    bytes[1].to_int() != 0x45 ||
    bytes[2].to_int() != 0x4c ||
    bytes[3].to_int() != 0x46 {
    return LoadError("invalid ELF magic")
  }
  if bytes[5].to_int() != 1 {
    return LoadError("only little-endian ELF is supported")
  }
  if bytes_load_u16(bytes, 18) != 243U {
    return LoadError("ELF is not for RISC-V")
  }

  match bytes[4].to_int() {
    1 => {
      let entry_point = bytes_load_u32(bytes, 24).to_uint64()
      let phoff = bytes_load_u32(bytes, 28).reinterpret_as_int()
      let shoff = bytes_load_u32(bytes, 32).reinterpret_as_int()
      let phentsize = bytes_load_u16(bytes, 42).reinterpret_as_int()
      let phnum = bytes_load_u16(bytes, 44).reinterpret_as_int()
      let shentsize = bytes_load_u16(bytes, 46).reinterpret_as_int()
      let shnum = bytes_load_u16(bytes, 48).reinterpret_as_int()

      let mut ph_index = 0
      while ph_index < phnum {
        let ph_offset = phoff + (ph_index * phentsize)
        if !bytes_range_ok(bytes, ph_offset, phentsize) {
          return LoadError("program header is truncated")
        }
        if bytes_load_u32(bytes, ph_offset) == 1U {
          let file_offset = bytes_load_u32(bytes, ph_offset + 4).reinterpret_as_int()
          let virtual_addr = bytes_load_u32(bytes, ph_offset + 8).to_uint64()
          let file_size = bytes_load_u32(bytes, ph_offset + 16).reinterpret_as_int()
          let mem_size = bytes_load_u32(bytes, ph_offset + 20).reinterpret_as_int()
          match self.load_elf_segment(bytes, file_offset, file_size, virtual_addr, mem_size) {
            Some(message) => return LoadError(message)
            None => ()
          }
        }
        ph_index = ph_index + 1
      }

      let (tohost, fromhost, begin_signature, end_signature) = if shoff != 0 &&
        shentsize >= 40 && shnum > 0 {
        parse_elf32_symbols(bytes, shoff, shentsize, shnum)
      } else {
        (None, None, None, None)
      }

      self.cpu.pc = entry_point
      Loaded({
        entry_point,
        tohost_addr: tohost,
        fromhost_addr: fromhost,
        begin_signature_addr: begin_signature,
        end_signature_addr: end_signature,
      })
    }
    2 => {
      if !bytes_range_ok(bytes, 0, 64) {
        return LoadError("ELF header is truncated")
      }
      let entry_point = bytes_load_u64(bytes, 24)
      let phoff = bytes_load_u64(bytes, 32).reinterpret_as_int64().to_int()
      let shoff = bytes_load_u64(bytes, 40).reinterpret_as_int64().to_int()
      let phentsize = bytes_load_u16(bytes, 54).reinterpret_as_int()
      let phnum = bytes_load_u16(bytes, 56).reinterpret_as_int()
      let shentsize = bytes_load_u16(bytes, 58).reinterpret_as_int()
      let shnum = bytes_load_u16(bytes, 60).reinterpret_as_int()

      let mut ph_index = 0
      while ph_index < phnum {
        let ph_offset = phoff + (ph_index * phentsize)
        if !bytes_range_ok(bytes, ph_offset, phentsize) {
          return LoadError("program header is truncated")
        }
        if bytes_load_u32(bytes, ph_offset) == 1U {
          let file_offset = bytes_load_u64(bytes, ph_offset + 8).reinterpret_as_int64().to_int()
          let virtual_addr = bytes_load_u64(bytes, ph_offset + 16)
          let file_size = bytes_load_u64(bytes, ph_offset + 32).reinterpret_as_int64().to_int()
          let mem_size = bytes_load_u64(bytes, ph_offset + 40).reinterpret_as_int64().to_int()
          match self.load_elf_segment(bytes, file_offset, file_size, virtual_addr, mem_size) {
            Some(message) => return LoadError(message)
            None => ()
          }
        }
        ph_index = ph_index + 1
      }

      let (tohost, fromhost, begin_signature, end_signature) = if shoff != 0 &&
        shentsize >= 64 && shnum > 0 {
        parse_elf64_symbols(bytes, shoff, shentsize, shnum)
      } else {
        (None, None, None, None)
      }

      self.cpu.pc = entry_point
      Loaded({
        entry_point,
        tohost_addr: tohost,
        fromhost_addr: fromhost,
        begin_signature_addr: begin_signature,
        end_signature_addr: end_signature,
      })
    }
    _ => LoadError("only ELF32 and ELF64 are supported")
  }
}

///|
fn Runner::xlen_bits(self : Runner) -> Int {
  match self.config.xlen {
    Xlen32 => XLEN_32
    Xlen64 => XLEN_64
  }
}

///|
fn Runner::mask_value_to_xlen(self : Runner, value : UInt64) -> UInt64 {
  value & xlen_mask(self.xlen_bits())
}

///|
fn Runner::write_xlen_reg(self : Runner, rd : Int, value : UInt64) -> Unit {
  self.cpu.write_reg(rd, self.mask_value_to_xlen(value))
}

///|
fn Runner::write_word_reg(self : Runner, rd : Int, value : UInt64) -> Unit {
  match self.xlen_bits() {
    XLEN_32 => self.write_xlen_reg(rd, value)
    XLEN_64 => self.write_xlen_reg(rd, sign_extend_64(value & 0xffffffffU.to_uint64(), 32))
    _ => abort("unsupported xlen for word writeback")
  }
}

///|
fn Runner::step_next_pc(self : Runner, delta : Int) -> UInt64 {
  self.cpu.pc + int_to_uint64_bits(delta)
}

///|
fn Runner::fetch_instruction(
  self : Runner,
  addr : UInt64,
) -> FetchedInstruction? {
  if !self.bus.contains_range(addr, 2) {
    return None
  }
  let low16 = self.bus.fetch_u16(addr)
  let length = instruction_length_from_low16(low16)
  if !self.bus.contains_range(addr, length) {
    return None
  }
  let raw = if length == 2 {
    low16
  } else {
    self.bus.fetch_u32(addr)
  }
  Some({ raw, length })
}

///|
fn Runner::address_from(self : Runner, rs1 : Int, imm : Int) -> UInt64 {
  self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)
}

///|
fn Runner::load_check(self : Runner, addr : UInt64, width : Int) -> StepResult? {
  if self.bus.contains_range(addr, width) {
    None
  } else {
    Some(self.raise_trap(LoadAccessFault, self.cpu.pc, addr))
  }
}

///|
fn Runner::store_check(self : Runner, addr : UInt64, width : Int) -> StepResult? {
  if self.bus.contains_range(addr, width) {
    None
  } else {
    Some(self.raise_trap(StoreAccessFault, self.cpu.pc, addr))
  }
}

///|
fn Runner::trap_target_for_privilege(self : Runner, target_privilege : PrivilegeMode) -> UInt64 {
  let tvec_csr = match target_privilege {
    Supervisor => CSR_STVEC
    Machine => CSR_MTVEC
    User => return 0U.to_uint64()
  }
  self.read_csr_visible(tvec_csr) & bit_not(0x3U.to_uint64())
}

///|
fn Runner::enter_machine_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
  prior_privilege : PrivilegeMode,
) -> Unit {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let next_mstatus = set_mstatus_mie(
    set_mstatus_mpie(
      set_mstatus_mpp(mstatus, prior_privilege),
      mstatus_mie(mstatus),
    ),
    false,
  )
  self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
  self.cpu.write_csr(CSR_MEPC, faulting_pc)
  self.cpu.write_csr(CSR_MCAUSE, trap_cause_code(cause))
  self.cpu.write_csr(CSR_MTVAL, trap_value)
  self.cpu.privilege = Machine
}

///|
fn Runner::enter_supervisor_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
  prior_privilege : PrivilegeMode,
) -> Unit {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  let next_mstatus = set_mstatus_sie(
    set_mstatus_spie(
      set_mstatus_spp(mstatus, prior_privilege),
      mstatus_sie(mstatus),
    ),
    false,
  )
  self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
  self.cpu.write_csr(CSR_SEPC, faulting_pc)
  self.cpu.write_csr(CSR_SCAUSE, trap_cause_code(cause))
  self.cpu.write_csr(CSR_STVAL, trap_value)
  self.cpu.privilege = Supervisor
}

///|
fn Runner::trap_target_privilege(
  self : Runner,
  cause : TrapCause,
  prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  if self.trap_cause_is_interrupt(cause) {
    self.delegated_interrupt_target(cause, prior_privilege)
  } else {
    self.delegated_exception_target(cause, prior_privilege)
  }
}

///|
fn Runner::trap_cause_is_interrupt(_self : Runner, _cause : TrapCause) -> Bool {
  // Interrupt causes are not modeled yet.
  false
}

///|
fn Runner::delegated_interrupt_target(
  self : Runner,
  _cause : TrapCause,
  _prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  // Keep MIDELEG wired as the future interrupt routing source of truth.
  let _mideleg = self.cpu.read_csr(CSR_MIDELEG)
  Machine
}

///|
fn Runner::delegated_exception_target(
  self : Runner,
  cause : TrapCause,
  prior_privilege : PrivilegeMode,
) -> PrivilegeMode {
  let may_delegate_to_supervisor = match prior_privilege {
    Machine => false
    _ => true
  }
  if !may_delegate_to_supervisor {
    return Machine
  }
  let cause_code = trap_cause_code(cause)
  let cause_shift = cause_code.reinterpret_as_int64().to_int()
  let medeleg = self.cpu.read_csr(CSR_MEDELEG)
  let delegated = (medeleg & (1U.to_uint64() << cause_shift)) != 0U.to_uint64()
  if delegated {
    Supervisor
  } else {
    Machine
  }
}

///|
fn Runner::raise_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt64,
  trap_value : UInt64,
) -> StepResult {
  let prior_privilege = self.cpu.privilege
  let target_privilege = self.trap_target_privilege(cause, prior_privilege)
  match target_privilege {
    Supervisor => self.enter_supervisor_trap(cause, faulting_pc, trap_value, prior_privilege)
    Machine => self.enter_machine_trap(cause, faulting_pc, trap_value, prior_privilege)
    User => abort("user trap targets are not supported")
  }
  let target = self.trap_target_for_privilege(target_privilege)
  if target != 0U.to_uint64() && self.bus.contains_range(target, 4) {
    self.cpu.pc = target
    Running
  } else {
    Trap({ cause, faulting_pc, trap_value })
  }
}

///|
fn Runner::execute_op_imm(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Addi(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) + int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Addiw(rd, rs1, imm) => {
      self.write_word_reg(rd, self.cpu.read_reg(rs1) + int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Slti(rd, rs1, imm) => {
      self.write_xlen_reg(
        rd,
        bool_to_reg(xlen_compare_signed(self.cpu.read_reg(rs1), int_to_uint64_bits(imm), xlen) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sltiu(rd, rs1, imm) => {
      self.write_xlen_reg(
        rd,
        bool_to_reg(
          xlen_compare_unsigned(self.cpu.read_reg(rs1), int_to_uint64_bits(imm), xlen) < 0,
        ),
      )
      self.cpu.pc = next_pc
      Running
    }
    Xori(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) ^ int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Ori(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) | int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Andi(rd, rs1, imm) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) & int_to_uint64_bits(imm))
      self.cpu.pc = next_pc
      Running
    }
    Slli(rd, rs1, shamt) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) << shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srli(rd, rs1, shamt) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) >> shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srai(rd, rs1, shamt) => {
      self.write_xlen_reg(
        rd,
        xlen_arithmetic_shift_right(self.cpu.read_reg(rs1), shamt, xlen),
      )
      self.cpu.pc = next_pc
      Running
    }
    Slliw(rd, rs1, shamt) => {
      self.write_word_reg(rd, self.cpu.read_reg(rs1) << shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srliw(rd, rs1, shamt) => {
      self.write_word_reg(rd, low32(self.cpu.read_reg(rs1)).to_uint64() >> shamt)
      self.cpu.pc = next_pc
      Running
    }
    Sraiw(rd, rs1, shamt) => {
      self.write_word_reg(rd, arithmetic_shift_right_32(self.cpu.read_reg(rs1), shamt))
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected op-imm dispatch")
  }
}

///|
fn Runner::execute_op(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match self.execute_op_m(instruction, next_pc) {
    Some(result) => result
    None =>
      match instruction {
        Add(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Sub(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Addw(rd, rs1, rs2) => {
          self.write_word_reg(rd, self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Subw(rd, rs1, rs2) => {
          self.write_word_reg(rd, self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Sll(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) << xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sllw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            low32(self.cpu.read_reg(rs1)).to_uint64() <<
            shift_mask_32(self.cpu.read_reg(rs2)),
          )
          self.cpu.pc = next_pc
          Running
        }
        Slt(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            bool_to_reg(
              xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sltu(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            bool_to_reg(
              xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Xor(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) ^ self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        Srl(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            self.cpu.read_reg(rs1) >> xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
        Srlw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            low32(self.cpu.read_reg(rs1)).to_uint64() >>
            shift_mask_32(self.cpu.read_reg(rs2)),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sra(rd, rs1, rs2) => {
          self.write_xlen_reg(
            rd,
            xlen_arithmetic_shift_right(
              self.cpu.read_reg(rs1),
              xlen_shift_mask(self.cpu.read_reg(rs2), xlen),
              xlen,
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Sraw(rd, rs1, rs2) => {
          self.write_word_reg(
            rd,
            arithmetic_shift_right_32(
              self.cpu.read_reg(rs1),
              shift_mask_32(self.cpu.read_reg(rs2)),
            ),
          )
          self.cpu.pc = next_pc
          Running
        }
        Or(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) | self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        And(rd, rs1, rs2) => {
          self.write_xlen_reg(rd, self.cpu.read_reg(rs1) & self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
        _ => abort("unexpected op dispatch")
      }
  }
}

///|
fn Runner::execute_op_m(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult? {
  let xlen = self.xlen_bits()
  match instruction {
    Mul(rd, rs1, rs2) => {
      self.write_xlen_reg(rd, self.cpu.read_reg(rs1) * self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulw(rd, rs1, rs2) => {
      self.write_word_reg(rd, low32(self.cpu.read_reg(rs1)).to_uint64() * low32(self.cpu.read_reg(rs2)).to_uint64())
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulh(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulh(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulhsu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulhsu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Mulhu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_mulhu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Div(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_div(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divw(rd, rs1, rs2) => {
      self.write_word_reg(rd, div_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_divu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Divuw(rd, rs1, rs2) => {
      self.write_word_reg(rd, divu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Rem(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_rem(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remw(rd, rs1, rs2) => {
      self.write_word_reg(rd, rem_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remu(rd, rs1, rs2) => {
      self.write_xlen_reg(
        rd,
        xlen_remu(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen),
      )
      self.cpu.pc = next_pc
      Some(Running)
    }
    Remuw(rd, rs1, rs2) => {
      self.write_word_reg(rd, remu_32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)))
      self.cpu.pc = next_pc
      Some(Running)
    }
    _ => None
  }
}

///|
fn Runner::execute_branch(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Beq(rs1, rs2, imm) => {
      self.cpu.pc = if self.cpu.read_reg(rs1) == self.cpu.read_reg(rs2) {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bne(rs1, rs2, imm) => {
      self.cpu.pc = if self.cpu.read_reg(rs1) != self.cpu.read_reg(rs2) {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Blt(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bge(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_signed(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) >= 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bltu(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bgeu(rs1, rs2, imm) => {
      self.cpu.pc = if xlen_compare_unsigned(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2), xlen) >= 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    _ => abort("unexpected branch dispatch")
  }
}

///|
fn Runner::execute_load(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  let xlen = self.xlen_bits()
  match instruction {
    Lb(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 1) {
        Some(result) => result
        None => {
          self.write_xlen_reg(
            rd,
            xlen_load_sign_extend(self.bus.load_u8(addr), 8, xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lh(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 2) {
        Some(result) => result
        None => {
          self.write_xlen_reg(
            rd,
            xlen_load_sign_extend(self.bus.load_u16(addr), 16, xlen),
          )
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lw(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 4) {
        Some(result) => result
        None => {
          self.write_word_reg(
            rd,
            self.bus.load_u32(addr),
          )
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lwu(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 4) {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.bus.load_u32(addr))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Ld(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 8) {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.bus.load_u64(addr))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lbu(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 1) {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.bus.load_u8(addr))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Lhu(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 2) {
        Some(result) => result
        None => {
          self.write_xlen_reg(rd, self.bus.load_u16(addr))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    _ => abort("unexpected load dispatch")
  }
}

///|
fn Runner::execute_store(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Sb(rs1, rs2, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.store_check(addr, 1) {
        Some(result) => result
        None => {
          self.bus.store_u8(addr, self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sh(rs1, rs2, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.store_check(addr, 2) {
        Some(result) => result
        None => {
          self.bus.store_u16(addr, self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sw(rs1, rs2, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.store_check(addr, 4) {
        Some(result) => result
        None => {
          self.bus.store_u32(addr, self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    Sd(rs1, rs2, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.store_check(addr, 8) {
        Some(result) => result
        None => {
          self.bus.store_u64(addr, self.cpu.read_reg(rs2))
          self.cpu.pc = next_pc
          Running
        }
      }
    }
    _ => abort("unexpected store dispatch")
  }
}

///|
fn Runner::execute_jump(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt64,
) -> StepResult {
  match instruction {
    Jal(rd, imm) => {
      self.write_xlen_reg(rd, next_pc)
      self.cpu.pc = self.step_next_pc(imm)
      Running
    }
    Jalr(rd, rs1, imm) => {
      let target = (self.cpu.read_reg(rs1) + int_to_uint64_bits(imm)) &
        bit_not(1U.to_uint64())
      self.write_xlen_reg(rd, next_pc)
      self.cpu.pc = target
      Running
    }
    _ => abort("unexpected jump dispatch")
  }
}

fn Runner::read_csr_visible(self : Runner, csr : Int) -> UInt64 {
  match csr {
    CSR_SSTATUS => self.cpu.read_csr(CSR_MSTATUS) & SSTATUS_VISIBLE_MASK.to_uint64()
    _ => self.cpu.read_csr(csr)
  }
}

///|
fn Runner::write_csr_visible(self : Runner, csr : Int, value : UInt64) -> Unit {
  match csr {
    CSR_SSTATUS => {
      let mstatus = self.cpu.read_csr(CSR_MSTATUS)
      let next_mstatus =
        (mstatus & bit_not(SSTATUS_VISIBLE_MASK.to_uint64())) |
        (value & SSTATUS_VISIBLE_MASK.to_uint64())
      self.cpu.write_csr(CSR_MSTATUS, next_mstatus)
    }
    _ => self.cpu.write_csr(csr, value)
  }
}

///|
fn Runner::read_csr_checked(self : Runner, csr : Int) -> UInt64? {
  if is_supported_csr(csr) {
    Some(self.read_csr_visible(csr))
  } else {
    None
  }
}

///|
fn Runner::execute_csr_read_write_checked(
  self : Runner,
  rd : Int,
  csr : Int,
  write_value : UInt64,
  should_write : Bool,
  next_pc : UInt64,
  current_pc : UInt64,
  raw : UInt,
) -> StepResult {
  let old_value = match self.read_csr_checked(csr) {
    Some(value) => value
    None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  if should_write {
    if !is_supported_rw_csr(csr) {
      return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    }
    self.write_csr_visible(csr, write_value)
  }
  self.write_xlen_reg(rd, old_value)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_system(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt64,
  next_pc : UInt64,
  raw : UInt,
) -> StepResult {
  match instruction {
    Csrrw(rd, csr, rs1) =>
      self.execute_csr_read_write_checked(
        rd,
        csr,
        self.cpu.read_reg(rs1),
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrs(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value | self.cpu.read_reg(rs1),
        rs1 != 0,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrc(rd, csr, rs1) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value & bit_not(self.cpu.read_reg(rs1)),
        rs1 != 0,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrwi(rd, csr, uimm) =>
      self.execute_csr_read_write_checked(
        rd,
        csr,
        uimm.to_uint64(),
        true,
        next_pc,
        current_pc,
        raw,
      )
    Csrrsi(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value | uimm.to_uint64(),
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    Csrrci(rd, csr, uimm) => {
      let old_value = match self.read_csr_checked(csr) {
        Some(value) => value
        None => return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
      }
      self.execute_csr_read_write_checked(
        rd,
        csr,
        old_value & bit_not(uimm.to_uint64()),
        uimm != 0U,
        next_pc,
        current_pc,
        raw,
      )
    }
    Ecall => {
      let cause = match self.cpu.privilege {
        User => EnvironmentCallFromUMode
        Supervisor => EnvironmentCallFromSMode
        Machine => EnvironmentCallFromMMode
      }
      self.raise_trap(cause, current_pc, 0U.to_uint64())
    }
    Mret => self.execute_mret()
    Sret => self.execute_sret()
    Unknown(_) => self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
    _ => abort("unexpected system dispatch")
  }
}

///|
fn Runner::execute_mret(self : Runner) -> StepResult {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_mret(mstatus))
  self.cpu.privilege = mstatus_mpp(mstatus)
  self.cpu.pc = self.cpu.read_csr(CSR_MEPC)
  Running
}

///|
fn Runner::execute_sret(self : Runner) -> StepResult {
  let mstatus = self.cpu.read_csr(CSR_MSTATUS)
  self.cpu.write_csr(CSR_MSTATUS, mstatus_after_sret(mstatus))
  self.cpu.privilege = mstatus_spp(mstatus)
  self.cpu.pc = self.cpu.read_csr(CSR_SEPC)
  Running
}

///|
pub fn Runner::step(self : Runner) -> StepResult {
  let current_pc = self.cpu.pc
  let fetched = match self.fetch_instruction(current_pc) {
    Some(instruction) => instruction
    None => return self.raise_trap(InstructionAccessFault, current_pc, current_pc)
  }
  let next_pc = current_pc + fetched.length.reinterpret_as_uint().to_uint64()
  let raw = fetched.raw
  let instruction = if fetched.length == 2 {
    decode_compressed(raw)
  } else {
    decode(raw)
  }
  if !instruction_supported_in_xlen(instruction, self.xlen_bits(), fetched.length) {
    return self.raise_trap(IllegalInstruction, current_pc, raw.to_uint64())
  }
  match instruction {
    Fence => {
      self.cpu.pc = next_pc
      Running
    }
    FenceI => {
      self.cpu.pc = next_pc
      Running
    }
    Lui(rd, imm) => {
      self.write_xlen_reg(rd, xlen_sign_extend(imm.to_uint64(), 32, self.xlen_bits()))
      self.cpu.pc = next_pc
      Running
    }
    Auipc(rd, imm) => {
      self.write_xlen_reg(
        rd,
        current_pc + xlen_sign_extend(imm.to_uint64(), 32, self.xlen_bits()),
      )
      self.cpu.pc = next_pc
      Running
    }
    Addi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Addiw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slti(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Sltiu(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Xori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Ori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Andi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srai(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slliw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srliw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Sraiw(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Add(_, _, _) => self.execute_op(instruction, next_pc)
    Sub(_, _, _) => self.execute_op(instruction, next_pc)
    Addw(_, _, _) => self.execute_op(instruction, next_pc)
    Subw(_, _, _) => self.execute_op(instruction, next_pc)
    Mul(_, _, _) => self.execute_op(instruction, next_pc)
    Mulw(_, _, _) => self.execute_op(instruction, next_pc)
    Mulh(_, _, _) => self.execute_op(instruction, next_pc)
    Mulhsu(_, _, _) => self.execute_op(instruction, next_pc)
    Mulhu(_, _, _) => self.execute_op(instruction, next_pc)
    Div(_, _, _) => self.execute_op(instruction, next_pc)
    Divw(_, _, _) => self.execute_op(instruction, next_pc)
    Divu(_, _, _) => self.execute_op(instruction, next_pc)
    Divuw(_, _, _) => self.execute_op(instruction, next_pc)
    Rem(_, _, _) => self.execute_op(instruction, next_pc)
    Remw(_, _, _) => self.execute_op(instruction, next_pc)
    Remu(_, _, _) => self.execute_op(instruction, next_pc)
    Remuw(_, _, _) => self.execute_op(instruction, next_pc)
    Sll(_, _, _) => self.execute_op(instruction, next_pc)
    Sllw(_, _, _) => self.execute_op(instruction, next_pc)
    Slt(_, _, _) => self.execute_op(instruction, next_pc)
    Sltu(_, _, _) => self.execute_op(instruction, next_pc)
    Xor(_, _, _) => self.execute_op(instruction, next_pc)
    Srl(_, _, _) => self.execute_op(instruction, next_pc)
    Sra(_, _, _) => self.execute_op(instruction, next_pc)
    Srlw(_, _, _) => self.execute_op(instruction, next_pc)
    Sraw(_, _, _) => self.execute_op(instruction, next_pc)
    Or(_, _, _) => self.execute_op(instruction, next_pc)
    And(_, _, _) => self.execute_op(instruction, next_pc)
    Beq(_, _, _) => self.execute_branch(instruction, next_pc)
    Bne(_, _, _) => self.execute_branch(instruction, next_pc)
    Blt(_, _, _) => self.execute_branch(instruction, next_pc)
    Bge(_, _, _) => self.execute_branch(instruction, next_pc)
    Bltu(_, _, _) => self.execute_branch(instruction, next_pc)
    Bgeu(_, _, _) => self.execute_branch(instruction, next_pc)
    Lb(_, _, _) => self.execute_load(instruction, next_pc)
    Lh(_, _, _) => self.execute_load(instruction, next_pc)
    Lw(_, _, _) => self.execute_load(instruction, next_pc)
    Lwu(_, _, _) => self.execute_load(instruction, next_pc)
    Ld(_, _, _) => self.execute_load(instruction, next_pc)
    Lbu(_, _, _) => self.execute_load(instruction, next_pc)
    Lhu(_, _, _) => self.execute_load(instruction, next_pc)
    Sb(_, _, _) => self.execute_store(instruction, next_pc)
    Sh(_, _, _) => self.execute_store(instruction, next_pc)
    Sw(_, _, _) => self.execute_store(instruction, next_pc)
    Sd(_, _, _) => self.execute_store(instruction, next_pc)
    Jal(_, _) => self.execute_jump(instruction, next_pc)
    Jalr(_, _, _) => self.execute_jump(instruction, next_pc)
    Csrrw(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrs(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrc(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrwi(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrsi(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Csrrci(_, _, _) => self.execute_system(instruction, current_pc, next_pc, raw)
    Ecall => self.execute_system(instruction, current_pc, next_pc, raw)
    Mret => self.execute_system(instruction, current_pc, next_pc, raw)
    Sret => self.execute_system(instruction, current_pc, next_pc, raw)
    Unknown(_) => self.execute_system(instruction, current_pc, next_pc, raw)
  }
}

///|
pub fn Runner::run(self : Runner, max_steps : Int) -> StepResult {
  let mut steps = 0
  while steps < max_steps {
    match self.step() {
      Running => steps = steps + 1
      result => return result
    }
  }
  Running
}

///|
pub fn words_to_bytes(words : Array[UInt]) -> Bytes {
  let bytes = []
  let mut index = 0
  while index < words.length() {
    let word = words[index]
    bytes.push(word.to_byte())
    bytes.push((word >> 8).to_byte())
    bytes.push((word >> 16).to_byte())
    bytes.push((word >> 24).to_byte())
    index = index + 1
  }
  Bytes::from_array(bytes)
}

///|
pub fn demo_program_words() -> Array[UInt] {
  [0x00200093U, 0x00508113U, 0x002081b3U, 0x00302023U, 0x00002203U]
}
