// Tiny built-in browser smoke guest. It exercises the shared CPU core before
// Linux artifacts are loaded through the browser runtime.

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
fn browser_demo_program_words() -> Array[UInt] {
  let words = [encode_u(0x10000000U, 1, 0x37U)]
  for ch in "echo ready\r\n> " {
    words.push(encode_i(ch.to_int(), 0, 0x0U, 2, 0x13U))
    words.push(encode_s(0, 2, 1, 0x0U, 0x23U))
  }
  words.push(encode_i(5, 1, 0x4U, 2, 0x03U))
  words.push(encode_i(1, 2, 0x7U, 2, 0x13U))
  words.push(encode_b(-8, 0, 2, 0x0U, 0x63U))
  words.push(encode_i(0, 1, 0x4U, 3, 0x03U))
  words.push(encode_s(0, 3, 1, 0x0U, 0x23U))
  words.push(encode_j(-20, 0, 0x6fU))
  words
}

///|
fn make_browser_demo_runner() -> @riscv.Runner {
  let config = @riscv.virt_machine_config()
  let runner = @riscv.make_runner(config)
  runner.load_program_u64(
    @riscv.words_to_bytes(browser_demo_program_words()),
    config.entry_point,
  )
  ignore(runner.run(256))
  runner
}
