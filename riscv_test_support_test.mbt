///|
struct OfficialRiscvTestCase {
  suite : String
  name : String
  arch : String
  tier : String
  path : String
  max_steps : Int
}

let official_riscv_tests_manifest_path = "tools/riscv-tests-manifest.tsv"
let official_riscv_tests_isa_dir_rv32 = "_build/riscv-tests-src/isa"
let official_riscv_tests_isa_dir_rv64 = "_build/riscv-tests-src-rv64/isa"

///|
async fn read_manifest_text(path : String) -> String {
  try {
    @fs.read_file(path).text()
  } catch {
    _ =>
      abort(
        "missing official riscv-tests manifest: \{path}; verify the repository checkout is complete",
      )
  }
}

///|
async fn read_official_test_elf(path : String) -> Bytes {
  try {
    @fs.read_file(path).binary()
  } catch {
    _ =>
      abort(
        "missing official riscv-tests ELF: \{path}; run ./scripts/build-riscv-tests-official.sh first",
      )
  }
}

///|
async fn load_official_riscv_test_cases() -> Array[OfficialRiscvTestCase] {
  let manifest = read_manifest_text(official_riscv_tests_manifest_path)
  let cases : Array[OfficialRiscvTestCase] = []
  for raw_line in manifest.split("\n") {
    let line = raw_line.to_string().trim().to_string()
    if line == "" || line.has_prefix("#") {
      continue
    }
    let fields : Array[String] = []
    for field in line.split("\t") {
      fields.push(field.to_string())
    }
    if fields.length() != 4 {
      abort("invalid riscv-tests manifest line: \{line}")
    }
    let suite = fields[0]
    let name = fields[1]
    let arch = fields[2]
    let tier = fields[3]
    let path = "\{official_riscv_tests_isa_dir_for_arch(arch)}/\{suite}-p-\{name}"
    cases.push({ suite, name, arch, tier, path, max_steps: 200000 })
  }
  cases
}

///|
fn official_riscv_tests_isa_dir_for_arch(arch : String) -> String {
  if arch.has_prefix("rv64") {
    official_riscv_tests_isa_dir_rv64
  } else {
    official_riscv_tests_isa_dir_rv32
  }
}

///|
fn official_riscv_tests_xlen_for_arch(arch : String) -> Xlen {
  if arch.has_prefix("rv64") {
    xlen64()
  } else {
    xlen32()
  }
}

///|
fn encode_i(
  imm : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
  opcode : UInt,
) -> UInt {
  ((imm & 0xfff).reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn encode_r(
  funct7 : UInt,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
  opcode : UInt,
) -> UInt {
  (funct7 << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn encode_s(
  imm : Int,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  opcode : UInt,
) -> UInt {
  let encoded = (imm & 0xfff).reinterpret_as_uint()
  (((encoded >> 5) & 0x7fU) << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  ((encoded & 0x1fU) << 7) |
  opcode
}

///|
fn encode_b(
  imm : Int,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  opcode : UInt,
) -> UInt {
  let encoded = (imm & 0x1fff).reinterpret_as_uint()
  (((encoded >> 12) & 0x1U) << 31) |
  (((encoded >> 5) & 0x3fU) << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (((encoded >> 1) & 0xfU) << 8) |
  (((encoded >> 11) & 0x1U) << 7) |
  opcode
}

///|
fn encode_u(imm : UInt, rd : Int, opcode : UInt) -> UInt {
  (imm & 0xfffff000U) | (rd.reinterpret_as_uint() << 7) | opcode
}

///|
fn encode_j(imm : Int, rd : Int, opcode : UInt) -> UInt {
  let encoded = (imm & 0x1fffff).reinterpret_as_uint()
  (((encoded >> 20) & 0x1U) << 31) |
  (((encoded >> 1) & 0x3ffU) << 21) |
  (((encoded >> 11) & 0x1U) << 20) |
  (((encoded >> 12) & 0xffU) << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn encode_csr(
  csr : Int,
  rs1_or_uimm : Int,
  funct3 : UInt,
  rd : Int,
) -> UInt {
  (csr.reinterpret_as_uint() << 20) |
  (rs1_or_uimm.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  0x73U
}

///|
fn encode_ecall() -> UInt {
  0x00000073U
}

///|
fn encode_mret() -> UInt {
  0x30200073U
}

///|
fn encode_sret() -> UInt {
  0x10200073U
}

///|
fn encode_sfence_vma(rs1 : Int, rs2 : Int) -> UInt {
  (0x09U << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  0x73U
}

///|
fn encode_fence() -> UInt {
  0x0ff0000fU
}

///|
fn encode_fence_i() -> UInt {
  0x0000100fU
}

///|
fn trap_cause_name(cause : TrapCause) -> String {
  match cause {
    InstructionAccessFault => "instruction access fault"
    IllegalInstruction => "illegal instruction"
    LoadAccessFault => "load access fault"
    StoreAccessFault => "store access fault"
    InstructionPageFault => "instruction page fault"
    LoadPageFault => "load page fault"
    StorePageFault => "store page fault"
    EnvironmentCallFromUMode => "ecall from u-mode"
    EnvironmentCallFromSMode => "ecall from s-mode"
    EnvironmentCallFromMMode => "ecall from m-mode"
  }
}

///|
async fn run_official_riscv_test_case(test_case : OfficialRiscvTestCase) -> UInt {
  let runner = make_runner(
    official_riscv_tests_machine_config_for_xlen(
      official_riscv_tests_xlen_for_arch(test_case.arch),
    ),
  )
  let elf = read_official_test_elf(test_case.path)
  let info = match runner.load_elf(elf) {
    Loaded(info) => info
    LoadError(message) =>
      abort(
        "official riscv-tests ELF load failed: \{test_case.suite}/\{test_case.arch}/\{test_case.name}: \{message}",
      )
  }
  let tohost = match info.tohost_addr {
    Some(value) => value
    None =>
      abort(
        "official riscv-tests ELF missing tohost: \{test_case.suite}/\{test_case.arch}/\{test_case.name} at \{test_case.path}",
      )
  }
  let mut steps = 0
  while steps < test_case.max_steps {
    let value = runner.load_u32_u64(tohost)
    if value != 0U.to_uint64() {
      return value.to_uint()
    }
    match runner.step() {
      Running => steps = steps + 1
      Trap(info) =>
        abort(
          "official riscv-tests trap: \{test_case.suite}/\{test_case.arch}/\{test_case.name}: \{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tval=\{info.trap_value.to_string()}",
        )
    }
  }
  abort(
    "official riscv-tests timed out: \{test_case.suite}/\{test_case.arch}/\{test_case.name}",
  )
}

///|
fn push_u16_le(buffer : Array[Byte], value : Int) -> Unit {
  buffer.push(value.to_byte())
  buffer.push((value >> 8).to_byte())
}

///|
fn push_u32_le(buffer : Array[Byte], value : UInt) -> Unit {
  buffer.push(value.to_byte())
  buffer.push((value >> 8).to_byte())
  buffer.push((value >> 16).to_byte())
  buffer.push((value >> 24).to_byte())
}

///|
fn push_u64_le(buffer : Array[Byte], value : UInt64) -> Unit {
  buffer.push(value.to_byte())
  buffer.push((value >> 8).to_byte())
  buffer.push((value >> 16).to_byte())
  buffer.push((value >> 24).to_byte())
  buffer.push((value >> 32).to_byte())
  buffer.push((value >> 40).to_byte())
  buffer.push((value >> 48).to_byte())
  buffer.push((value >> 56).to_byte())
}

///|
fn patch_u16_le(buffer : Array[Byte], offset : Int, value : Int) -> Unit {
  buffer[offset] = value.to_byte()
  buffer[offset + 1] = (value >> 8).to_byte()
}

///|
fn patch_u32_le(buffer : Array[Byte], offset : Int, value : UInt) -> Unit {
  buffer[offset] = value.to_byte()
  buffer[offset + 1] = (value >> 8).to_byte()
  buffer[offset + 2] = (value >> 16).to_byte()
  buffer[offset + 3] = (value >> 24).to_byte()
}

///|
fn patch_u64_le(buffer : Array[Byte], offset : Int, value : UInt64) -> Unit {
  buffer[offset] = value.to_byte()
  buffer[offset + 1] = (value >> 8).to_byte()
  buffer[offset + 2] = (value >> 16).to_byte()
  buffer[offset + 3] = (value >> 24).to_byte()
  buffer[offset + 4] = (value >> 32).to_byte()
  buffer[offset + 5] = (value >> 40).to_byte()
  buffer[offset + 6] = (value >> 48).to_byte()
  buffer[offset + 7] = (value >> 56).to_byte()
}

///|
fn align_buffer(buffer : Array[Byte], alignment : Int) -> Unit {
  while buffer.length() % alignment != 0 {
    buffer.push(0U.to_byte())
  }
}

///|
fn append_ascii_cstr(buffer : Array[Byte], text : Array[Int]) -> Int {
  let offset = buffer.length()
  let mut index = 0
  while index < text.length() {
    buffer.push(text[index].reinterpret_as_uint().to_byte())
    index = index + 1
  }
  buffer.push(0U.to_byte())
  offset
}

///|
struct TestElfNameTableLayout {
  shstrtab_offset : Int
  shstrtab_size : Int
  strtab_offset : Int
  strtab_size : Int
  text_name_offset : Int
  symtab_name_offset : Int
  strtab_name_offset : Int
  shstrtab_name_offset : Int
  tohost_name_offset : Int
  fromhost_name_offset : Int
  begin_signature_name_offset : Int
  end_signature_name_offset : Int
}

///|
fn append_buffer_bytes(buffer : Array[Byte], bytes : Array[Byte]) -> Unit {
  let mut index = 0
  while index < bytes.length() {
    buffer.push(bytes[index])
    index = index + 1
  }
}

///|
fn append_program_bytes(buffer : Array[Byte], bytes : Bytes) -> Unit {
  let mut index = 0
  while index < bytes.length() {
    buffer.push(bytes[index])
    index = index + 1
  }
}

///|
fn reserve_zero_bytes(buffer : Array[Byte], count : Int) -> Unit {
  let mut index = 0
  while index < count {
    buffer.push(0U.to_byte())
    index = index + 1
  }
}

///|
fn build_test_elf_buffer(program : Bytes, reserved_header_bytes : Int) -> Array[Byte] {
  let buffer : Array[Byte] = []
  reserve_zero_bytes(buffer, reserved_header_bytes)
  let program_offset = 0x100
  while buffer.length() < program_offset {
    buffer.push(0U.to_byte())
  }
  append_program_bytes(buffer, program)
  buffer
}

///|
fn append_test_elf_name_tables(
  buffer : Array[Byte],
  alignment : Int,
) -> TestElfNameTableLayout {
  align_buffer(buffer, alignment)
  let shstrtab_offset = buffer.length()
  let shstrtab : Array[Byte] = []
  shstrtab.push(0U.to_byte())
  let text_name_offset = append_ascii_cstr(shstrtab, [46, 116, 101, 120, 116])
  let symtab_name_offset = append_ascii_cstr(shstrtab, [46, 115, 121, 109, 116, 97, 98])
  let strtab_name_offset = append_ascii_cstr(shstrtab, [46, 115, 116, 114, 116, 97, 98])
  let shstrtab_name_offset = append_ascii_cstr(
    shstrtab,
    [46, 115, 104, 115, 116, 114, 116, 97, 98],
  )
  let shstrtab_size = shstrtab.length()
  append_buffer_bytes(buffer, shstrtab)

  align_buffer(buffer, alignment)
  let strtab_offset = buffer.length()
  let strtab : Array[Byte] = []
  strtab.push(0U.to_byte())
  let tohost_name_offset = append_ascii_cstr(strtab, [116, 111, 104, 111, 115, 116])
  let fromhost_name_offset = append_ascii_cstr(strtab, [102, 114, 111, 109, 104, 111, 115, 116])
  let begin_signature_name_offset = append_ascii_cstr(
    strtab,
    [98, 101, 103, 105, 110, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
  )
  let end_signature_name_offset = append_ascii_cstr(
    strtab,
    [101, 110, 100, 95, 115, 105, 103, 110, 97, 116, 117, 114, 101],
  )
  let strtab_size = strtab.length()
  append_buffer_bytes(buffer, strtab)

  {
    shstrtab_offset,
    shstrtab_size,
    strtab_offset,
    strtab_size,
    text_name_offset,
    symtab_name_offset,
    strtab_name_offset,
    shstrtab_name_offset,
    tohost_name_offset,
    fromhost_name_offset,
    begin_signature_name_offset,
    end_signature_name_offset,
  }
}

///|
fn build_test_elf(
  load_addr : UInt,
  entry_point : UInt,
  program_words : Array[UInt],
) -> Bytes {
  let program = words_to_bytes(program_words)
  let buffer = build_test_elf_buffer(program, 52 + 32)
  let program_offset = 0x100
  let tables = append_test_elf_name_tables(buffer, 4)

  align_buffer(buffer, 4)
  let symtab_offset = buffer.length()
  let write_symbol = fn(name_offset : Int, value : UInt) {
    push_u32_le(buffer, name_offset.reinterpret_as_uint())
    push_u32_le(buffer, value)
    push_u32_le(buffer, 0U)
    buffer.push(0U.to_byte())
    buffer.push(0U.to_byte())
    push_u16_le(buffer, 1)
  }
  write_symbol(0, 0U)
  write_symbol(tables.tohost_name_offset, load_addr + 0x1000U)
  write_symbol(tables.fromhost_name_offset, load_addr + 0x1004U)
  write_symbol(tables.begin_signature_name_offset, load_addr + 0x2000U)
  write_symbol(tables.end_signature_name_offset, load_addr + 0x2010U)
  let symtab_size = buffer.length() - symtab_offset

  align_buffer(buffer, 4)
  let shoff = buffer.length()
  let write_section_header = fn(
    name_offset : Int,
    sh_type : UInt,
    flags : UInt,
    addr : UInt,
    offset : Int,
    size : Int,
    link : Int,
    info : Int,
    addralign : UInt,
    entsize : UInt,
  ) {
    push_u32_le(buffer, name_offset.reinterpret_as_uint())
    push_u32_le(buffer, sh_type)
    push_u32_le(buffer, flags)
    push_u32_le(buffer, addr)
    push_u32_le(buffer, offset.reinterpret_as_uint())
    push_u32_le(buffer, size.reinterpret_as_uint())
    push_u32_le(buffer, link.reinterpret_as_uint())
    push_u32_le(buffer, info.reinterpret_as_uint())
    push_u32_le(buffer, addralign)
    push_u32_le(buffer, entsize)
  }
  write_section_header(0, 0U, 0U, 0U, 0, 0, 0, 0, 0U, 0U)
  write_section_header(
    tables.text_name_offset,
    1U,
    0x6U,
    load_addr,
    program_offset,
    program.length(),
    0,
    0,
    4U,
    0U,
  )
  write_section_header(
    tables.symtab_name_offset,
    2U,
    0U,
    0U,
    symtab_offset,
    symtab_size,
    3,
    1,
    4U,
    16U,
  )
  write_section_header(
    tables.strtab_name_offset,
    3U,
    0U,
    0U,
    tables.strtab_offset,
    tables.strtab_size,
    0,
    0,
    1U,
    0U,
  )
  write_section_header(
    tables.shstrtab_name_offset,
    3U,
    0U,
    0U,
    tables.shstrtab_offset,
    tables.shstrtab_size,
    0,
    0,
    1U,
    0U,
  )

  buffer[0] = 0x7fU.to_byte()
  buffer[1] = 0x45U.to_byte()
  buffer[2] = 0x4cU.to_byte()
  buffer[3] = 0x46U.to_byte()
  buffer[4] = 1U.to_byte()
  buffer[5] = 1U.to_byte()
  buffer[6] = 1U.to_byte()
  patch_u16_le(buffer, 16, 2)
  patch_u16_le(buffer, 18, 243)
  patch_u32_le(buffer, 20, 1U)
  patch_u32_le(buffer, 24, entry_point)
  patch_u32_le(buffer, 28, 52U)
  patch_u32_le(buffer, 32, shoff.reinterpret_as_uint())
  patch_u16_le(buffer, 40, 52)
  patch_u16_le(buffer, 42, 32)
  patch_u16_le(buffer, 44, 1)
  patch_u16_le(buffer, 46, 40)
  patch_u16_le(buffer, 48, 5)
  patch_u16_le(buffer, 50, 4)

  patch_u32_le(buffer, 52, 1U)
  patch_u32_le(buffer, 56, program_offset.reinterpret_as_uint())
  patch_u32_le(buffer, 60, load_addr)
  patch_u32_le(buffer, 64, load_addr)
  patch_u32_le(buffer, 68, program.length().reinterpret_as_uint())
  patch_u32_le(buffer, 72, (program.length() + 16).reinterpret_as_uint())
  patch_u32_le(buffer, 76, 0x5U)
  patch_u32_le(buffer, 80, 0x1000U)

  Bytes::from_array(buffer)
}

///|
fn build_test_elf64(
  load_addr : UInt64,
  entry_point : UInt64,
  program_words : Array[UInt],
) -> Bytes {
  let program = words_to_bytes(program_words)
  let buffer = build_test_elf_buffer(program, 64 + 56)
  let program_offset = 0x100
  let tables = append_test_elf_name_tables(buffer, 8)

  align_buffer(buffer, 8)
  let symtab_offset = buffer.length()
  let write_symbol = fn(name_offset : Int, value : UInt64) {
    push_u32_le(buffer, name_offset.reinterpret_as_uint())
    buffer.push(0U.to_byte())
    buffer.push(0U.to_byte())
    push_u16_le(buffer, 1)
    push_u64_le(buffer, value)
    push_u64_le(buffer, 0U.to_uint64())
  }
  write_symbol(0, 0U.to_uint64())
  write_symbol(tables.tohost_name_offset, load_addr + 0x1000U.to_uint64())
  write_symbol(tables.fromhost_name_offset, load_addr + 0x1004U.to_uint64())
  write_symbol(tables.begin_signature_name_offset, load_addr + 0x2000U.to_uint64())
  write_symbol(tables.end_signature_name_offset, load_addr + 0x2010U.to_uint64())
  let symtab_size = buffer.length() - symtab_offset

  align_buffer(buffer, 8)
  let shoff = buffer.length()
  let write_section_header = fn(
    name_offset : Int,
    sh_type : UInt,
    flags : UInt64,
    addr : UInt64,
    offset : Int,
    size : Int,
    link : Int,
    info : Int,
    addralign : UInt64,
    entsize : UInt64,
  ) {
    push_u32_le(buffer, name_offset.reinterpret_as_uint())
    push_u32_le(buffer, sh_type)
    push_u64_le(buffer, flags)
    push_u64_le(buffer, addr)
    push_u64_le(buffer, offset.reinterpret_as_uint().to_uint64())
    push_u64_le(buffer, size.reinterpret_as_uint().to_uint64())
    push_u32_le(buffer, link.reinterpret_as_uint())
    push_u32_le(buffer, info.reinterpret_as_uint())
    push_u64_le(buffer, addralign)
    push_u64_le(buffer, entsize)
  }
  write_section_header(
    0,
    0U,
    0U.to_uint64(),
    0U.to_uint64(),
    0,
    0,
    0,
    0,
    0U.to_uint64(),
    0U.to_uint64(),
  )
  write_section_header(
    tables.text_name_offset,
    1U,
    0x6U.to_uint64(),
    load_addr,
    program_offset,
    program.length(),
    0,
    0,
    4U.to_uint64(),
    0U.to_uint64(),
  )
  write_section_header(
    tables.symtab_name_offset,
    2U,
    0U.to_uint64(),
    0U.to_uint64(),
    symtab_offset,
    symtab_size,
    3,
    1,
    8U.to_uint64(),
    24U.to_uint64(),
  )
  write_section_header(
    tables.strtab_name_offset,
    3U,
    0U.to_uint64(),
    0U.to_uint64(),
    tables.strtab_offset,
    tables.strtab_size,
    0,
    0,
    1U.to_uint64(),
    0U.to_uint64(),
  )
  write_section_header(
    tables.shstrtab_name_offset,
    3U,
    0U.to_uint64(),
    0U.to_uint64(),
    tables.shstrtab_offset,
    tables.shstrtab_size,
    0,
    0,
    1U.to_uint64(),
    0U.to_uint64(),
  )

  buffer[0] = 0x7fU.to_byte()
  buffer[1] = 0x45U.to_byte()
  buffer[2] = 0x4cU.to_byte()
  buffer[3] = 0x46U.to_byte()
  buffer[4] = 2U.to_byte()
  buffer[5] = 1U.to_byte()
  buffer[6] = 1U.to_byte()
  patch_u16_le(buffer, 16, 2)
  patch_u16_le(buffer, 18, 243)
  patch_u32_le(buffer, 20, 1U)
  patch_u64_le(buffer, 24, entry_point)
  patch_u64_le(buffer, 32, 64U.to_uint64())
  patch_u64_le(buffer, 40, shoff.reinterpret_as_uint().to_uint64())
  patch_u16_le(buffer, 52, 64)
  patch_u16_le(buffer, 54, 56)
  patch_u16_le(buffer, 56, 1)
  patch_u16_le(buffer, 58, 64)
  patch_u16_le(buffer, 60, 5)
  patch_u16_le(buffer, 62, 4)

  patch_u32_le(buffer, 64, 1U)
  patch_u32_le(buffer, 68, 0x5U)
  patch_u64_le(buffer, 72, program_offset.reinterpret_as_uint().to_uint64())
  patch_u64_le(buffer, 80, load_addr)
  patch_u64_le(buffer, 88, load_addr)
  patch_u64_le(buffer, 96, program.length().reinterpret_as_uint().to_uint64())
  patch_u64_le(buffer, 104, (program.length() + 16).reinterpret_as_uint().to_uint64())
  patch_u64_le(buffer, 112, 0x1000U.to_uint64())

  Bytes::from_array(buffer)
}
