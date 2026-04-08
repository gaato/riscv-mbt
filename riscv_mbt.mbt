///|
pub struct MachineConfig {
  ram_base : UInt
  ram_size : Int
  entry_point : UInt
  hart_id : UInt
}

///|
pub enum PrivilegeMode {
  User
  Supervisor
  Machine
}

///|
pub struct CsrFile {
  registers : Array[UInt]
}

///|
pub struct CpuState {
  mut pc : UInt
  registers : Array[UInt]
  csrs : CsrFile
  mut privilege : PrivilegeMode
}

///|
pub struct Bus {
  base_addr : UInt
  memory : Array[Byte]
}

///|
pub struct ElfInfo {
  entry_point : UInt
  tohost_addr : UInt?
  fromhost_addr : UInt?
  begin_signature_addr : UInt?
  end_signature_addr : UInt?
}

///|
pub enum LoadElfResult {
  Loaded(ElfInfo)
  LoadError(String)
}

///|
pub enum Instruction {
  Fence
  Lui(Int, UInt)
  Auipc(Int, UInt)
  Addi(Int, Int, Int)
  Slti(Int, Int, Int)
  Sltiu(Int, Int, Int)
  Xori(Int, Int, Int)
  Ori(Int, Int, Int)
  Andi(Int, Int, Int)
  Slli(Int, Int, Int)
  Srli(Int, Int, Int)
  Srai(Int, Int, Int)
  Add(Int, Int, Int)
  Sub(Int, Int, Int)
  Sll(Int, Int, Int)
  Slt(Int, Int, Int)
  Sltu(Int, Int, Int)
  Xor(Int, Int, Int)
  Srl(Int, Int, Int)
  Sra(Int, Int, Int)
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
  Lbu(Int, Int, Int)
  Lhu(Int, Int, Int)
  Sb(Int, Int, Int)
  Sh(Int, Int, Int)
  Sw(Int, Int, Int)
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
  faulting_pc : UInt
  trap_value : UInt
}

///|
pub enum StepResult {
  Running
  Trap(TrapInfo)
}

///|
pub struct Runner {
  cpu : CpuState
  bus : Bus
  config : MachineConfig
}

///|
pub fn default_machine_config() -> MachineConfig {
  { ram_base: 0U, ram_size: 65536, entry_point: 0U, hart_id: 0U }
}

///|
pub fn official_riscv_tests_machine_config() -> MachineConfig {
  {
    ram_base: 0x80000000U,
    ram_size: 0x20000,
    entry_point: 0x80000000U,
    hart_id: 0U,
  }
}

///|
pub fn CsrFile::new() -> CsrFile {
  { registers: Array::make(4096, 0U) }
}

///|
pub fn CsrFile::read(self : CsrFile, index : Int) -> UInt {
  self.registers[index]
}

///|
pub fn CsrFile::write(self : CsrFile, index : Int, value : UInt) -> Unit {
  self.registers[index] = value
}

///|
const CSR_MSTATUS : Int = 0x300
const CSR_MTVEC : Int = 0x305
const CSR_MEPC : Int = 0x341
const CSR_MCAUSE : Int = 0x342
const CSR_MTVAL : Int = 0x343
const CSR_MHARTID : Int = 0xF14
const MSTATUS_MPP_SHIFT : Int = 11
const MSTATUS_MPP_MASK : UInt = 0x1800U

///|
pub fn CpuState::new(entry_point : UInt, hart_id : UInt) -> CpuState {
  let csrs = CsrFile::new()
  csrs.write(CSR_MHARTID, hart_id)
  {
    pc: entry_point,
    registers: Array::make(32, 0U),
    csrs,
    privilege: Machine,
  }
}

///|
pub fn CpuState::read_reg(self : CpuState, index : Int) -> UInt {
  if index == 0 {
    0U
  } else {
    self.registers[index]
  }
}

///|
pub fn CpuState::write_reg(self : CpuState, index : Int, value : UInt) -> Unit {
  if index != 0 {
    self.registers[index] = value
  }
}

///|
pub fn CpuState::read_csr(self : CpuState, index : Int) -> UInt {
  self.csrs.read(index)
}

///|
pub fn CpuState::write_csr(self : CpuState, index : Int, value : UInt) -> Unit {
  self.csrs.write(index, value)
}

///|
pub fn Bus::new(base_addr : UInt, size : Int) -> Bus {
  { base_addr, memory: Array::make(size, 0U.to_byte()) }
}

///|
pub fn Bus::size(self : Bus) -> Int {
  self.memory.length()
}

///|
fn Bus::contains_range(self : Bus, addr : UInt, width : Int) -> Bool {
  let start = addr - self.base_addr
  let start_index = start.reinterpret_as_int()
  let end_index = start_index + width
  addr >= self.base_addr &&
  start_index >= 0 &&
  end_index <= self.memory.length()
}

///|
fn Bus::load_u8(self : Bus, addr : UInt) -> UInt {
  self.memory[(addr - self.base_addr).reinterpret_as_int()].to_uint()
}

///|
pub fn Bus::load_u16(self : Bus, addr : UInt) -> UInt {
  let b0 = self.load_u8(addr)
  let b1 = self.load_u8(addr + 1U) << 8
  b0 | b1
}

///|
pub fn Bus::load_u32(self : Bus, addr : UInt) -> UInt {
  let b0 = self.load_u8(addr)
  let b1 = self.load_u8(addr + 1U) << 8
  let b2 = self.load_u8(addr + 2U) << 16
  let b3 = self.load_u8(addr + 3U) << 24
  b0 | b1 | b2 | b3
}

///|
pub fn Bus::store_u8(self : Bus, addr : UInt, value : UInt) -> Unit {
  self.memory[(addr - self.base_addr).reinterpret_as_int()] = value.to_byte()
}

///|
pub fn Bus::store_u16(self : Bus, addr : UInt, value : UInt) -> Unit {
  self.memory[(addr - self.base_addr).reinterpret_as_int()] = value.to_byte()
  self.memory[((addr + 1U) - self.base_addr).reinterpret_as_int()] = (value >> 8).to_byte()
}

///|
pub fn Bus::store_u32(self : Bus, addr : UInt, value : UInt) -> Unit {
  self.memory[(addr - self.base_addr).reinterpret_as_int()] = value.to_byte()
  self.memory[((addr + 1U) - self.base_addr).reinterpret_as_int()] = (value >> 8).to_byte()
  self.memory[((addr + 2U) - self.base_addr).reinterpret_as_int()] = (value >> 16).to_byte()
  self.memory[((addr + 3U) - self.base_addr).reinterpret_as_int()] = (value >> 24).to_byte()
}

///|
pub fn Bus::write_bytes(self : Bus, base_addr : UInt, bytes : Bytes) -> Unit {
  let mut index = 0
  while index < bytes.length() {
    self.memory[
      ((base_addr + index.reinterpret_as_uint()) - self.base_addr).reinterpret_as_int()
    ] = bytes[index]
    index = index + 1
  }
}

///|
pub fn Bus::zero_range(self : Bus, base_addr : UInt, len : Int) -> Unit {
  let mut index = 0
  while index < len {
    self.store_u8(base_addr + index.reinterpret_as_uint(), 0U)
    index = index + 1
  }
}

///|
pub fn Bus::fetch(self : Bus, addr : UInt) -> UInt {
  self.load_u32(addr)
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
fn csr_addr(raw : UInt) -> Int {
  ((raw >> 20) & 0xfffU).reinterpret_as_int()
}

///|
fn csr_uimm(raw : UInt) -> UInt {
  (raw >> 15) & 0x1fU
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
fn as_signed(value : UInt) -> Int {
  value.reinterpret_as_int()
}

///|
fn bool_to_reg(value : Bool) -> UInt {
  if value {
    1U
  } else {
    0U
  }
}

///|
fn trap_cause_code(cause : TrapCause) -> UInt {
  match cause {
    InstructionAccessFault => 1U
    IllegalInstruction => 2U
    LoadAccessFault => 5U
    StoreAccessFault => 7U
    EnvironmentCallFromUMode => 8U
    EnvironmentCallFromSMode => 9U
    EnvironmentCallFromMMode => 11U
  }
}

///|
fn privilege_mode_from_code(code : UInt) -> PrivilegeMode {
  match code {
    1U => Supervisor
    3U => Machine
    _ => User
  }
}

///|
fn bit_not(value : UInt) -> UInt {
  value ^ 0xffffffffU
}

///|
pub fn decode(raw : UInt) -> Instruction {
  match raw & 0x7fU {
    0x0fU => Fence
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
          match funct7(raw) {
            0x00U => Srli(rd(raw), rs1(raw), shamt_i(raw))
            0x20U => Srai(rd(raw), rs1(raw), shamt_i(raw))
            _ => Unknown(raw)
          }
        _ => Unknown(raw)
      }
    0x33U =>
      match (funct3(raw), funct7(raw)) {
        (0x0U, 0x00U) => Add(rd(raw), rs1(raw), rs2(raw))
        (0x0U, 0x20U) => Sub(rd(raw), rs1(raw), rs2(raw))
        (0x1U, 0x00U) => Sll(rd(raw), rs1(raw), rs2(raw))
        (0x2U, 0x00U) => Slt(rd(raw), rs1(raw), rs2(raw))
        (0x3U, 0x00U) => Sltu(rd(raw), rs1(raw), rs2(raw))
        (0x4U, 0x00U) => Xor(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x00U) => Srl(rd(raw), rs1(raw), rs2(raw))
        (0x5U, 0x20U) => Sra(rd(raw), rs1(raw), rs2(raw))
        (0x6U, 0x00U) => Or(rd(raw), rs1(raw), rs2(raw))
        (0x7U, 0x00U) => And(rd(raw), rs1(raw), rs2(raw))
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
        0x4U => Lbu(rd(raw), rs1(raw), imm_i(raw))
        0x5U => Lhu(rd(raw), rs1(raw), imm_i(raw))
        _ => Unknown(raw)
      }
    0x23U =>
      match funct3(raw) {
        0x0U => Sb(rs1(raw), rs2(raw), imm_s(raw))
        0x1U => Sh(rs1(raw), rs2(raw), imm_s(raw))
        0x2U => Sw(rs1(raw), rs2(raw), imm_s(raw))
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
pub fn make_runner(config : MachineConfig) -> Runner {
  {
    cpu: CpuState::new(config.entry_point, config.hart_id),
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
  self.cpu.pc
}

///|
pub fn Runner::read_reg(self : Runner, index : Int) -> UInt {
  self.cpu.read_reg(index)
}

///|
pub fn Runner::read_csr(self : Runner, index : Int) -> UInt {
  self.cpu.read_csr(index)
}

///|
pub fn Runner::privilege_mode(self : Runner) -> PrivilegeMode {
  self.cpu.privilege
}

///|
pub fn Runner::load_u32(self : Runner, addr : UInt) -> UInt {
  self.bus.load_u32(addr)
}

///|
pub fn Runner::load_program(
  self : Runner,
  bytes : Bytes,
  base_addr : UInt,
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
  name_offset : UInt,
  expected : Array[Int],
) -> Bool {
  c_string_matches(bytes, string_base, name_offset.reinterpret_as_int(), expected)
}

///|
fn find_symbol_addr(
  bytes : Bytes,
  symtab_offset : Int,
  symtab_size : Int,
  strtab_offset : Int,
  target_name : Array[Int],
) -> UInt? {
  let mut index = 0
  while index + 16 <= symtab_size {
    let entry_offset = symtab_offset + index
    let name_offset = bytes_load_u32(bytes, entry_offset)
    let value = bytes_load_u32(bytes, entry_offset + 4)
    if elf_symbol_matches(bytes, strtab_offset, name_offset, target_name) {
      return Some(value)
    }
    index = index + 16
  }
  None
}

///|
fn parse_elf_symbols(
  bytes : Bytes,
  shoff : Int,
  shentsize : Int,
  shnum : Int,
) -> (UInt?, UInt?, UInt?, UInt?) {
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
        tohost = find_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [116, 111, 104, 111, 115, 116],
        )
        fromhost = find_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [102, 114, 111, 109, 104, 111, 115, 116],
        )
        begin_signature = find_symbol_addr(
          bytes,
          symtab_offset,
          symtab_size,
          strtab_offset,
          [98, 101, 103, 105, 110, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
        )
        end_signature = find_symbol_addr(
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
  if bytes[4].to_int() != 1 {
    return LoadError("only ELF32 is supported")
  }
  if bytes[5].to_int() != 1 {
    return LoadError("only little-endian ELF is supported")
  }
  if bytes_load_u16(bytes, 18) != 243U {
    return LoadError("ELF is not for RISC-V")
  }

  let entry_point = bytes_load_u32(bytes, 24)
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
      let virtual_addr = bytes_load_u32(bytes, ph_offset + 8)
      let file_size = bytes_load_u32(bytes, ph_offset + 16).reinterpret_as_int()
      let mem_size = bytes_load_u32(bytes, ph_offset + 20).reinterpret_as_int()
      if !bytes_range_ok(bytes, file_offset, file_size) {
        return LoadError("segment data is truncated")
      }
      if !self.bus.contains_range(virtual_addr, mem_size) {
        return LoadError("segment does not fit in configured RAM")
      }
      let mut byte_index = 0
      while byte_index < file_size {
        self.bus.store_u8(
          virtual_addr + byte_index.reinterpret_as_uint(),
          bytes[file_offset + byte_index].to_uint(),
        )
        byte_index = byte_index + 1
      }
      if mem_size > file_size {
        self.bus.zero_range(
          virtual_addr + file_size.reinterpret_as_uint(),
          mem_size - file_size,
        )
      }
    }
    ph_index = ph_index + 1
  }

  let (tohost, fromhost, begin_signature, end_signature) = if shoff != 0 &&
    shentsize >= 40 && shnum > 0 {
    parse_elf_symbols(bytes, shoff, shentsize, shnum)
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

///|
fn Runner::step_next_pc(self : Runner, delta : Int) -> UInt {
  self.cpu.pc + delta.reinterpret_as_uint()
}

///|
fn Runner::address_from(self : Runner, rs1 : Int, imm : Int) -> UInt {
  self.cpu.read_reg(rs1) + imm.reinterpret_as_uint()
}

///|
fn Runner::load_check(self : Runner, addr : UInt, width : Int) -> StepResult? {
  if self.bus.contains_range(addr, width) {
    None
  } else {
    Some(self.raise_trap(LoadAccessFault, self.cpu.pc, addr))
  }
}

///|
fn Runner::store_check(self : Runner, addr : UInt, width : Int) -> StepResult? {
  if self.bus.contains_range(addr, width) {
    None
  } else {
    Some(self.raise_trap(StoreAccessFault, self.cpu.pc, addr))
  }
}

///|
fn Runner::trap_vector(self : Runner) -> UInt {
  self.cpu.read_csr(CSR_MTVEC) & 0xfffffffcU
}

///|
fn Runner::raise_trap(
  self : Runner,
  cause : TrapCause,
  faulting_pc : UInt,
  trap_value : UInt,
) -> StepResult {
  self.cpu.write_csr(CSR_MEPC, faulting_pc)
  self.cpu.write_csr(CSR_MCAUSE, trap_cause_code(cause))
  self.cpu.write_csr(CSR_MTVAL, trap_value)
  let target = self.trap_vector()
  if target != 0U && self.bus.contains_range(target, 4) {
    self.cpu.pc = target
    self.cpu.privilege = Machine
    Running
  } else {
    Trap({ cause, faulting_pc, trap_value })
  }
}

///|
fn shift_mask_32(value : UInt) -> Int {
  value.reinterpret_as_int() & 0x1f
}

///|
fn load_sign_extend_8_16_32(value : UInt, bits : Int) -> UInt {
  match bits {
    8 => sign_extend(value, 8).reinterpret_as_uint()
    16 => sign_extend(value, 16).reinterpret_as_uint()
    _ => value
  }
}

///|
fn compare_signed_u32(lhs : UInt, rhs : UInt) -> Int {
  let left = as_signed(lhs)
  let right = as_signed(rhs)
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_unsigned_u32(lhs : UInt, rhs : UInt) -> Int {
  if lhs < rhs {
    -1
  } else if lhs > rhs {
    1
  } else {
    0
  }
}

///|
fn Runner::execute_op_imm(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt,
) -> StepResult {
  match instruction {
    Addi(rd, rs1, imm) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) + imm.reinterpret_as_uint())
      self.cpu.pc = next_pc
      Running
    }
    Slti(rd, rs1, imm) => {
      self.cpu.write_reg(
        rd,
        bool_to_reg(compare_signed_u32(self.cpu.read_reg(rs1), imm.reinterpret_as_uint()) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sltiu(rd, rs1, imm) => {
      self.cpu.write_reg(
        rd,
        bool_to_reg(compare_unsigned_u32(self.cpu.read_reg(rs1), imm.reinterpret_as_uint()) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Xori(rd, rs1, imm) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) ^ imm.reinterpret_as_uint())
      self.cpu.pc = next_pc
      Running
    }
    Ori(rd, rs1, imm) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) | imm.reinterpret_as_uint())
      self.cpu.pc = next_pc
      Running
    }
    Andi(rd, rs1, imm) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) & imm.reinterpret_as_uint())
      self.cpu.pc = next_pc
      Running
    }
    Slli(rd, rs1, shamt) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) << shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srli(rd, rs1, shamt) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) >> shamt)
      self.cpu.pc = next_pc
      Running
    }
    Srai(rd, rs1, shamt) => {
      self.cpu.write_reg(
        rd,
        (as_signed(self.cpu.read_reg(rs1)) >> shamt).reinterpret_as_uint(),
      )
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
  next_pc : UInt,
) -> StepResult {
  match instruction {
    Add(rd, rs1, rs2) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) + self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Running
    }
    Sub(rd, rs1, rs2) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) - self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Running
    }
    Sll(rd, rs1, rs2) => {
      self.cpu.write_reg(
        rd,
        self.cpu.read_reg(rs1) << shift_mask_32(self.cpu.read_reg(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    Slt(rd, rs1, rs2) => {
      self.cpu.write_reg(
        rd,
        bool_to_reg(compare_signed_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sltu(rd, rs1, rs2) => {
      self.cpu.write_reg(
        rd,
        bool_to_reg(compare_unsigned_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) < 0),
      )
      self.cpu.pc = next_pc
      Running
    }
    Xor(rd, rs1, rs2) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) ^ self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Running
    }
    Srl(rd, rs1, rs2) => {
      self.cpu.write_reg(
        rd,
        self.cpu.read_reg(rs1) >> shift_mask_32(self.cpu.read_reg(rs2)),
      )
      self.cpu.pc = next_pc
      Running
    }
    Sra(rd, rs1, rs2) => {
      self.cpu.write_reg(
        rd,
        (as_signed(self.cpu.read_reg(rs1)) >>
        shift_mask_32(self.cpu.read_reg(rs2))).reinterpret_as_uint(),
      )
      self.cpu.pc = next_pc
      Running
    }
    Or(rd, rs1, rs2) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) | self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Running
    }
    And(rd, rs1, rs2) => {
      self.cpu.write_reg(rd, self.cpu.read_reg(rs1) & self.cpu.read_reg(rs2))
      self.cpu.pc = next_pc
      Running
    }
    _ => abort("unexpected op dispatch")
  }
}

///|
fn Runner::execute_branch(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt,
) -> StepResult {
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
      self.cpu.pc = if compare_signed_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bge(rs1, rs2, imm) => {
      self.cpu.pc = if compare_signed_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) >= 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bltu(rs1, rs2, imm) => {
      self.cpu.pc = if compare_unsigned_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) < 0 {
        self.step_next_pc(imm)
      } else {
        next_pc
      }
      Running
    }
    Bgeu(rs1, rs2, imm) => {
      self.cpu.pc = if compare_unsigned_u32(self.cpu.read_reg(rs1), self.cpu.read_reg(rs2)) >= 0 {
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
  next_pc : UInt,
) -> StepResult {
  match instruction {
    Lb(rd, rs1, imm) => {
      let addr = self.address_from(rs1, imm)
      match self.load_check(addr, 1) {
        Some(result) => result
        None => {
          self.cpu.write_reg(
            rd,
            load_sign_extend_8_16_32(self.bus.load_u8(addr), 8),
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
          self.cpu.write_reg(
            rd,
            load_sign_extend_8_16_32(self.bus.load_u16(addr), 16),
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
          self.cpu.write_reg(
            rd,
            load_sign_extend_8_16_32(self.bus.load_u32(addr), 32),
          )
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
          self.cpu.write_reg(rd, self.bus.load_u8(addr))
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
          self.cpu.write_reg(rd, self.bus.load_u16(addr))
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
  next_pc : UInt,
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
    _ => abort("unexpected store dispatch")
  }
}

///|
fn Runner::execute_jump(
  self : Runner,
  instruction : Instruction,
  next_pc : UInt,
) -> StepResult {
  match instruction {
    Jal(rd, imm) => {
      self.cpu.write_reg(rd, next_pc)
      self.cpu.pc = self.step_next_pc(imm)
      Running
    }
    Jalr(rd, rs1, imm) => {
      let target = (self.cpu.read_reg(rs1) + imm.reinterpret_as_uint()) &
        0xfffffffeU
      self.cpu.write_reg(rd, next_pc)
      self.cpu.pc = target
      Running
    }
    _ => abort("unexpected jump dispatch")
  }
}

///|
fn Runner::execute_csr_read_write(
  self : Runner,
  rd : Int,
  csr : Int,
  write_value : UInt,
  should_write : Bool,
  next_pc : UInt,
) -> StepResult {
  let old_value = self.cpu.read_csr(csr)
  if should_write {
    self.cpu.write_csr(csr, write_value)
  }
  self.cpu.write_reg(rd, old_value)
  self.cpu.pc = next_pc
  Running
}

///|
fn Runner::execute_system(
  self : Runner,
  instruction : Instruction,
  current_pc : UInt,
  next_pc : UInt,
  raw : UInt,
) -> StepResult {
  match instruction {
    Csrrw(rd, csr, rs1) =>
      self.execute_csr_read_write(
        rd,
        csr,
        self.cpu.read_reg(rs1),
        true,
        next_pc,
      )
    Csrrs(rd, csr, rs1) => {
      let old_value = self.cpu.read_csr(csr)
      self.execute_csr_read_write(
        rd,
        csr,
        old_value | self.cpu.read_reg(rs1),
        rs1 != 0,
        next_pc,
      )
    }
    Csrrc(rd, csr, rs1) => {
      let old_value = self.cpu.read_csr(csr)
      self.execute_csr_read_write(
        rd,
        csr,
        old_value & bit_not(self.cpu.read_reg(rs1)),
        rs1 != 0,
        next_pc,
      )
    }
    Csrrwi(rd, csr, uimm) =>
      self.execute_csr_read_write(rd, csr, uimm, true, next_pc)
    Csrrsi(rd, csr, uimm) => {
      let old_value = self.cpu.read_csr(csr)
      self.execute_csr_read_write(
        rd,
        csr,
        old_value | uimm,
        uimm != 0U,
        next_pc,
      )
    }
    Csrrci(rd, csr, uimm) => {
      let old_value = self.cpu.read_csr(csr)
      self.execute_csr_read_write(
        rd,
        csr,
        old_value & bit_not(uimm),
        uimm != 0U,
        next_pc,
      )
    }
    Ecall => {
      let cause = match self.cpu.privilege {
        User => EnvironmentCallFromUMode
        Supervisor => EnvironmentCallFromSMode
        Machine => EnvironmentCallFromMMode
      }
      self.raise_trap(cause, current_pc, 0U)
    }
    Mret => {
      let mstatus = self.cpu.read_csr(CSR_MSTATUS)
      let next_privilege = privilege_mode_from_code(
        (mstatus & MSTATUS_MPP_MASK) >> MSTATUS_MPP_SHIFT,
      )
      self.cpu.write_csr(CSR_MSTATUS, mstatus & bit_not(MSTATUS_MPP_MASK))
      self.cpu.privilege = next_privilege
      self.cpu.pc = self.cpu.read_csr(CSR_MEPC)
      Running
    }
    Unknown(_) => self.raise_trap(IllegalInstruction, current_pc, raw)
    _ => abort("unexpected system dispatch")
  }
}

///|
pub fn Runner::step(self : Runner) -> StepResult {
  if !self.bus.contains_range(self.cpu.pc, 4) {
    return self.raise_trap(InstructionAccessFault, self.cpu.pc, self.cpu.pc)
  }
  let current_pc = self.cpu.pc
  let next_pc = current_pc + 4U
  let raw = self.bus.fetch(current_pc)
  let instruction = decode(raw)
  match instruction {
    Fence => {
      self.cpu.pc = next_pc
      Running
    }
    Lui(rd, imm) => {
      self.cpu.write_reg(rd, imm)
      self.cpu.pc = next_pc
      Running
    }
    Auipc(rd, imm) => {
      self.cpu.write_reg(rd, current_pc + imm)
      self.cpu.pc = next_pc
      Running
    }
    Addi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slti(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Sltiu(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Xori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Ori(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Andi(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Slli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srli(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Srai(_, _, _) => self.execute_op_imm(instruction, next_pc)
    Add(_, _, _) => self.execute_op(instruction, next_pc)
    Sub(_, _, _) => self.execute_op(instruction, next_pc)
    Sll(_, _, _) => self.execute_op(instruction, next_pc)
    Slt(_, _, _) => self.execute_op(instruction, next_pc)
    Sltu(_, _, _) => self.execute_op(instruction, next_pc)
    Xor(_, _, _) => self.execute_op(instruction, next_pc)
    Srl(_, _, _) => self.execute_op(instruction, next_pc)
    Sra(_, _, _) => self.execute_op(instruction, next_pc)
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
    Lbu(_, _, _) => self.execute_load(instruction, next_pc)
    Lhu(_, _, _) => self.execute_load(instruction, next_pc)
    Sb(_, _, _) => self.execute_store(instruction, next_pc)
    Sh(_, _, _) => self.execute_store(instruction, next_pc)
    Sw(_, _, _) => self.execute_store(instruction, next_pc)
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
