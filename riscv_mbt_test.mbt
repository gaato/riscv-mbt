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
let official_riscv_tests_isa_dir = "_build/riscv-tests-src/isa"

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
    let path = "\{official_riscv_tests_isa_dir}/\{suite}-p-\{name}"
    cases.push({ suite, name, arch, tier, path, max_steps: 200000 })
  }
  cases
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
fn encode_fence() -> UInt {
  0x0ff0000fU
}

///|
fn trap_cause_name(cause : TrapCause) -> String {
  match cause {
    InstructionAccessFault => "instruction access fault"
    IllegalInstruction => "illegal instruction"
    LoadAccessFault => "load access fault"
    StoreAccessFault => "store access fault"
    EnvironmentCallFromUMode => "ecall from u-mode"
    EnvironmentCallFromSMode => "ecall from s-mode"
    EnvironmentCallFromMMode => "ecall from m-mode"
  }
}

///|
async fn run_official_riscv_test_case(test_case : OfficialRiscvTestCase) -> UInt {
  let runner = make_runner(official_riscv_tests_machine_config())
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
    let value = runner.load_u32(tohost)
    if value != 0U {
      return value
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
fn build_test_elf(
  load_addr : UInt,
  entry_point : UInt,
  program_words : Array[UInt],
) -> Bytes {
  let program = words_to_bytes(program_words)
  let buffer : Array[Byte] = []
  let mut index = 0
  while index < 52 + 32 {
    buffer.push(0U.to_byte())
    index = index + 1
  }

  let program_offset = 0x100
  while buffer.length() < program_offset {
    buffer.push(0U.to_byte())
  }
  let mut program_index = 0
  while program_index < program.length() {
    buffer.push(program[program_index])
    program_index = program_index + 1
  }

  align_buffer(buffer, 4)
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
  let mut sh_index = 0
  while sh_index < shstrtab.length() {
    buffer.push(shstrtab[sh_index])
    sh_index = sh_index + 1
  }

  align_buffer(buffer, 4)
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
  let mut str_index = 0
  while str_index < strtab.length() {
    buffer.push(strtab[str_index])
    str_index = str_index + 1
  }

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
  write_symbol(tohost_name_offset, load_addr + 0x1000U)
  write_symbol(fromhost_name_offset, load_addr + 0x1004U)
  write_symbol(begin_signature_name_offset, load_addr + 0x2000U)
  write_symbol(end_signature_name_offset, load_addr + 0x2010U)
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
    text_name_offset,
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
    symtab_name_offset,
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
    strtab_name_offset,
    3U,
    0U,
    0U,
    strtab_offset,
    strtab.length(),
    0,
    0,
    1U,
    0U,
  )
  write_section_header(
    shstrtab_name_offset,
    3U,
    0U,
    0U,
    shstrtab_offset,
    shstrtab.length(),
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
test "decode addi fields" {
  match decode(encode_i(-4, 2, 0x0U, 1, 0x13U)) {
    Addi(rd, rs1, imm) => {
      assert_eq(rd, 1)
      assert_eq(rs1, 2)
      assert_eq(imm, -4)
    }
    _ => fail("expected addi")
  }
}

///|
test "decode shift immediate fields" {
  match decode(encode_i(3, 4, 0x1U, 5, 0x13U)) {
    Slli(rd, rs1, shamt) => {
      assert_eq(rd, 5)
      assert_eq(rs1, 4)
      assert_eq(shamt, 3)
    }
    _ => fail("expected slli")
  }
}

///|
test "decode bltu fields" {
  match decode(encode_b(-8, 7, 6, 0x6U, 0x63U)) {
    Bltu(rs1, rs2, imm) => {
      assert_eq(rs1, 6)
      assert_eq(rs2, 7)
      assert_eq(imm, -8)
    }
    _ => fail("expected bltu")
  }
}

///|
test "x0 remains zero when written" {
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([encode_i(5, 0, 0x0U, 0, 0x13U)]), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(0), 0U)
  assert_eq(runner.pc(), 4U)
}

///|
test "alu immediate and register instructions cover logic compare and shifts" {
  let program = words_to_bytes([
    encode_i(-8, 0, 0x0U, 1, 0x13U),
    encode_i(4, 0, 0x0U, 2, 0x13U),
    encode_i(1, 2, 0x1U, 3, 0x13U),
    encode_i(1, 1, 0x5U, 4, 0x13U),
    encode_i(0x401, 1, 0x5U, 5, 0x13U),
    encode_i(0xff, 1, 0x4U, 6, 0x13U),
    encode_i(0xf0, 6, 0x6U, 7, 0x13U),
    encode_i(0xf0, 7, 0x7U, 8, 0x13U),
    encode_i(-7, 1, 0x2U, 9, 0x13U),
    encode_i(-7, 1, 0x3U, 10, 0x13U),
    encode_r(0x00U, 2, 1, 0x1U, 11, 0x33U),
    encode_r(0x00U, 2, 1, 0x2U, 12, 0x33U),
    encode_r(0x00U, 2, 1, 0x3U, 13, 0x33U),
    encode_r(0x00U, 2, 6, 0x4U, 14, 0x33U),
    encode_r(0x00U, 2, 11, 0x5U, 15, 0x33U),
    encode_r(0x20U, 2, 1, 0x5U, 16, 0x33U),
    encode_r(0x00U, 7, 6, 0x6U, 17, 0x33U),
    encode_r(0x00U, 7, 6, 0x7U, 18, 0x33U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(18) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 8U)
  assert_eq(runner.read_reg(4), 0x7ffffffcU)
  assert_eq(runner.read_reg(5), 0xfffffffcU)
  assert_eq(runner.read_reg(8), 0xf0U)
  assert_eq(runner.read_reg(9), 1U)
  assert_eq(runner.read_reg(10), 1U)
  assert_eq(runner.read_reg(11), 0xffffff80U)
  assert_eq(runner.read_reg(12), 1U)
  assert_eq(runner.read_reg(13), 0U)
  assert_eq(runner.read_reg(14), 0xffffff03U)
  assert_eq(runner.read_reg(15), 0x0ffffff8U)
  assert_eq(runner.read_reg(16), 0xffffffffU)
  assert_eq(runner.read_reg(17), 0xfffffff7U)
  assert_eq(runner.read_reg(18), 0xffffff07U)
}

///|
test "branch variants choose signed and unsigned comparisons correctly" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_b(8, 2, 1, 0x4U, 0x63U),
    encode_i(99, 0, 0x0U, 3, 0x13U),
    encode_b(8, 2, 1, 0x5U, 0x63U),
    encode_i(99, 0, 0x0U, 4, 0x13U),
    encode_b(8, 2, 1, 0x6U, 0x63U),
    encode_i(1, 0, 0x0U, 5, 0x13U),
    encode_b(8, 2, 1, 0x7U, 0x63U),
    encode_i(2, 0, 0x0U, 6, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 0U)
  assert_eq(runner.read_reg(4), 99U)
  assert_eq(runner.read_reg(5), 1U)
  assert_eq(runner.read_reg(6), 0U)
}

///|
test "byte and halfword loads and stores honor sign and zero extension" {
  let program = words_to_bytes([
    encode_i(0x80, 0, 0x0U, 1, 0x13U),
    encode_s(0, 1, 0, 0x0U, 0x23U),
    encode_i(0, 0, 0x0U, 2, 0x03U),
    encode_i(0, 0, 0x4U, 3, 0x03U),
    encode_u(0xffffa000U, 4, 0x37U),
    encode_i(0x678, 4, 0x6U, 4, 0x13U),
    encode_s(2, 4, 0, 0x1U, 0x23U),
    encode_i(2, 0, 0x1U, 5, 0x03U),
    encode_i(2, 0, 0x5U, 6, 0x03U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 0xffffff80U)
  assert_eq(runner.read_reg(3), 0x80U)
  assert_eq(runner.read_reg(5), 0xffffa678U)
  assert_eq(runner.read_reg(6), 0xa678U)
}

///|
test "bootstrap subset runs a small program" {
  let program = words_to_bytes([
    encode_u(0x12345000U, 6, 0x37U),
    encode_i(4, 0, 0x0U, 1, 0x13U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
    encode_r(0x00U, 2, 1, 0x0U, 3, 0x33U),
    encode_s(0, 3, 0, 0x2U, 0x23U),
    encode_i(0, 0, 0x2U, 4, 0x03U),
    encode_b(8, 4, 3, 0x0U, 0x63U),
    encode_i(99, 0, 0x0U, 5, 0x13U),
    encode_j(8, 0, 0x6fU),
    encode_i(77, 0, 0x0U, 7, 0x13U),
    encode_i(16, 0, 0x0U, 8, 0x13U),
    encode_i(32, 8, 0x0U, 8, 0x13U),
    encode_i(8, 8, 0x0U, 9, 0x67U),
    encode_i(111, 0, 0x0U, 10, 0x13U),
    encode_i(1, 0, 0x0U, 11, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(12) {
    Running => ()
    _ => fail("expected budgeted run to stay in running state")
  }
  assert_eq(runner.read_reg(3), 11U)
  assert_eq(runner.read_reg(4), 11U)
  assert_eq(runner.read_reg(5), 0U)
  assert_eq(runner.read_reg(6), 0x12345000U)
  assert_eq(runner.read_reg(7), 0U)
  assert_eq(runner.read_reg(9), 52U)
  assert_eq(runner.read_reg(10), 0U)
  assert_eq(runner.read_reg(11), 1U)
}

///|
test "unsupported instruction traps" {
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([0xffffffffU]), 0U)
  match runner.step() {
    Trap(_) => ()
    _ => fail("expected trap")
  }
}

///|
test "load_elf places PT_LOAD segments at linked addresses" {
  let load_addr = 0x80000000U
  let program = [
    encode_i(5, 0, 0x0U, 1, 0x13U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
  ]
  let elf = build_test_elf(load_addr, load_addr, program)
  let runner = make_runner(official_riscv_tests_machine_config())
  match runner.load_elf(elf) {
    Loaded(info) => {
      assert_eq(info.entry_point, load_addr)
      assert_eq(runner.pc(), load_addr)
      assert_eq(runner.load_u32(load_addr), program[0])
      assert_eq(runner.load_u32(load_addr + 4U), program[1])
    }
    LoadError(message) => abort(message)
  }
  match runner.run(2) {
    Running => ()
    _ => fail("expected loaded ELF program to run")
  }
  assert_eq(runner.read_reg(1), 5U)
  assert_eq(runner.read_reg(2), 7U)
}

///|
test "load_elf exposes tohost and signature symbols" {
  let load_addr = 0x80000000U
  let elf = build_test_elf(
    load_addr,
    load_addr,
    [encode_i(1, 0, 0x0U, 1, 0x13U)],
  )
  let runner = make_runner(official_riscv_tests_machine_config())
  match runner.load_elf(elf) {
    Loaded(info) => {
      match info.tohost_addr {
        Some(value) => assert_eq(value, load_addr + 0x1000U)
        None => fail("expected tohost symbol")
      }
      match info.fromhost_addr {
        Some(value) => assert_eq(value, load_addr + 0x1004U)
        None => fail("expected fromhost symbol")
      }
      match info.begin_signature_addr {
        Some(value) => assert_eq(value, load_addr + 0x2000U)
        None => fail("expected begin_signature symbol")
      }
      match info.end_signature_addr {
        Some(value) => assert_eq(value, load_addr + 0x2010U)
        None => fail("expected end_signature symbol")
      }
    }
    LoadError(message) => abort(message)
  }
}

///|
test "minimal env/p startup can reach a test body via mret" {
  let base = 0x80000000U
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(20, 5, 0x0U, 5, 0x13U),
    encode_csr(0x300, 0, 0x5U, 0),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_i(7, 0, 0x0U, 1, 0x13U),
  ])
  let runner = make_runner(official_riscv_tests_machine_config())
  runner.load_program(program, base)
  match runner.run(6) {
    Running => ()
    _ => fail("expected startup sequence to reach test body")
  }
  assert_eq(runner.read_reg(1), 7U)
  assert_eq(runner.pc(), base + 24U)
  assert_eq(runner.read_csr(0x341), base + 20U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user mode after mret")
  }
}

///|
test "user ecall traps to mtvec with mcause set" {
  let base = 0x80000000U
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(36, 5, 0x0U, 6, 0x13U),
    encode_csr(0x305, 6, 0x1U, 0),
    encode_i(28, 5, 0x0U, 5, 0x13U),
    encode_csr(0x300, 0, 0x5U, 0),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_fence(),
    encode_ecall(),
    encode_csr(0x342, 0, 0x2U, 7),
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
  let runner = make_runner(official_riscv_tests_machine_config())
  runner.load_program(program, base)
  match runner.run(11) {
    Running => ()
    _ => fail("expected ecall trap to be handled by mtvec")
  }
  assert_eq(runner.read_reg(7), 8U)
  assert_eq(runner.read_reg(8), 1U)
  assert_eq(runner.read_csr(0x342), 8U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine mode in trap handler")
  }
}

///|
async test "official rv32ui gating subset passes" {
  let cases = load_official_riscv_test_cases().filter(fn(test_case) {
    test_case.tier == "gating"
  })
  let mut index = 0
  while index < cases.length() {
    let result = run_official_riscv_test_case(cases[index])
    assert_eq(result, 1U)
    index = index + 1
  }
}
