///|
fn encode_c_addi(rd : Int, imm : Int) -> Int {
  0x0001 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  ((imm & 0x1f) << 2)
}

///|
fn encode_c_li(rd : Int, imm : Int) -> Int {
  0x4001 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  ((imm & 0x1f) << 2)
}

///|
fn encode_c_lui(rd : Int, imm : Int) -> Int {
  0x6001 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  ((imm & 0x1f) << 2)
}

///|
fn encode_c_addi16sp(imm : Int) -> Int {
  0x6101 |
  (((imm >> 9) & 0x1) << 12) |
  (((imm >> 4) & 0x1) << 6) |
  (((imm >> 6) & 0x1) << 5) |
  (((imm >> 8) & 0x1) << 4) |
  (((imm >> 7) & 0x1) << 3) |
  (((imm >> 5) & 0x1) << 2)
}

///|
fn encode_c_addi4spn(rd : Int, imm : Int) -> Int {
  (((imm >> 5) & 0x1) << 12) |
  (((imm >> 4) & 0x1) << 11) |
  (((imm >> 9) & 0x1) << 10) |
  (((imm >> 8) & 0x1) << 9) |
  (((imm >> 7) & 0x1) << 8) |
  (((imm >> 6) & 0x1) << 7) |
  (((imm >> 2) & 0x1) << 6) |
  (((imm >> 3) & 0x1) << 5) |
  (((rd - 8) & 0x7) << 2)
}

///|
fn encode_c_j_like(funct3 : Int, offset : Int) -> Int {
  let encoded = offset & 0xfff
  ((funct3 & 0x7) << 13) |
  (((encoded >> 11) & 0x1) << 12) |
  (((encoded >> 4) & 0x1) << 11) |
  (((encoded >> 8) & 0x3) << 9) |
  (((encoded >> 10) & 0x1) << 8) |
  (((encoded >> 6) & 0x1) << 7) |
  (((encoded >> 7) & 0x1) << 6) |
  (((encoded >> 1) & 0x7) << 3) |
  (((encoded >> 5) & 0x1) << 2) |
  0x1
}

///|
fn encode_c_j(offset : Int) -> Int {
  encode_c_j_like(0x5, offset)
}

///|
fn encode_c_jal(offset : Int) -> Int {
  encode_c_j_like(0x1, offset)
}

///|
fn encode_c_branch(funct3 : Int, rs1 : Int, offset : Int) -> Int {
  let encoded = offset & 0x1ff
  ((funct3 & 0x7) << 13) |
  (((encoded >> 8) & 0x1) << 12) |
  (((rs1 - 8) & 0x7) << 7) |
  (((encoded >> 3) & 0x3) << 10) |
  (((encoded >> 6) & 0x3) << 5) |
  (((encoded >> 1) & 0x3) << 3) |
  (((encoded >> 5) & 0x1) << 2) |
  0x1
}

///|
fn encode_c_beqz(rs1 : Int, offset : Int) -> Int {
  encode_c_branch(0x6, rs1, offset)
}

///|
fn encode_c_bnez(rs1 : Int, offset : Int) -> Int {
  encode_c_branch(0x7, rs1, offset)
}

///|
fn encode_c_lw(rd : Int, rs1 : Int, imm : Int) -> Int {
  0x4000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 2) & 0x1) << 6) |
  (((imm >> 6) & 0x1) << 5) |
  (((rd - 8) & 0x7) << 2)
}

///|
fn encode_c_sw(rs2 : Int, rs1 : Int, imm : Int) -> Int {
  0xc000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 2) & 0x1) << 6) |
  (((imm >> 6) & 0x1) << 5) |
  (((rs2 - 8) & 0x7) << 2)
}

///|
fn encode_c_mv(rd : Int, rs2 : Int) -> Int {
  0x8002 | (rd << 7) | (rs2 << 2)
}

///|
fn encode_c_add(rd : Int, rs2 : Int) -> Int {
  0x9002 | (rd << 7) | (rs2 << 2)
}

///|
fn encode_c_jr(rs1 : Int) -> Int {
  0x8002 | (rs1 << 7)
}

///|
fn encode_c_jalr(rs1 : Int) -> Int {
  0x9002 | (rs1 << 7)
}

///|
fn encode_c_slli(rd : Int, shamt : Int) -> Int {
  0x0002 |
  (((shamt >> 5) & 0x1) << 12) |
  (rd << 7) |
  ((shamt & 0x1f) << 2)
}

///|
fn encode_c_shift_imm(funct2 : Int, rd : Int, imm : Int) -> Int {
  0x8001 |
  ((funct2 & 0x3) << 10) |
  (((imm >> 5) & 0x1) << 12) |
  (((rd - 8) & 0x7) << 7) |
  ((imm & 0x1f) << 2)
}

///|
fn encode_c_srli(rd : Int, shamt : Int) -> Int {
  encode_c_shift_imm(0x0, rd, shamt)
}

///|
fn encode_c_srai(rd : Int, shamt : Int) -> Int {
  encode_c_shift_imm(0x1, rd, shamt)
}

///|
fn encode_c_andi(rd : Int, imm : Int) -> Int {
  encode_c_shift_imm(0x2, rd, imm)
}

///|
fn encode_c_alu(funct2 : Int, rd : Int, rs2 : Int) -> Int {
  0x8c01 |
  (((rd - 8) & 0x7) << 7) |
  ((funct2 & 0x3) << 5) |
  (((rs2 - 8) & 0x7) << 2)
}

///|
fn encode_c_sub(rd : Int, rs2 : Int) -> Int {
  encode_c_alu(0x0, rd, rs2)
}

///|
fn encode_c_xor(rd : Int, rs2 : Int) -> Int {
  encode_c_alu(0x1, rd, rs2)
}

///|
fn encode_c_or(rd : Int, rs2 : Int) -> Int {
  encode_c_alu(0x2, rd, rs2)
}

///|
fn encode_c_and(rd : Int, rs2 : Int) -> Int {
  encode_c_alu(0x3, rd, rs2)
}

///|
fn encode_c_lwsp(rd : Int, imm : Int) -> Int {
  0x4002 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  (((imm >> 2) & 0x7) << 4) |
  (((imm >> 6) & 0x3) << 2)
}

///|
fn encode_c_swsp(rs2 : Int, imm : Int) -> Int {
  0xc002 |
  (((imm >> 2) & 0xf) << 9) |
  (((imm >> 6) & 0x3) << 7) |
  (rs2 << 2)
}

///|
fn mixed_program_bytes(parts : Array[(Int, UInt)]) -> Bytes {
  let bytes = []
  for part in parts {
    match part {
      (2, raw) => push_u16_le(bytes, raw.reinterpret_as_int())
      (4, raw) => push_u32_le(bytes, raw)
      _ => abort("unsupported instruction width")
    }
  }
  Bytes::from_array(bytes)
}

///|
test "compressed arithmetic instructions expand into the existing execute path" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_li(9, 5).reinterpret_as_uint()),
      (2, encode_c_addi(9, -1).reinterpret_as_uint()),
      (2, encode_c_li(8, 1).reinterpret_as_uint()),
      (2, encode_c_mv(10, 9).reinterpret_as_uint()),
      (2, encode_c_add(10, 8).reinterpret_as_uint()),
      (2, encode_c_lui(11, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    _ => fail("expected compressed arithmetic sequence to run")
  }
  assert_eq(runner.read_reg(9), 4U)
  assert_eq(runner.read_reg(10), 5U)
  assert_eq(runner.read_reg(11), 0x1000U)
  assert_eq(runner.pc(), 12U)
}

///|
test "compressed jumps and branches cross mixed-width boundaries correctly" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_jal(6).reinterpret_as_uint()),
      (4, encode_i(99, 0, 0x0U, 5, 0x13U)),
      (2, encode_c_li(9, 0).reinterpret_as_uint()),
      (2, encode_c_beqz(9, 6).reinterpret_as_uint()),
      (4, encode_i(77, 0, 0x0U, 6, 0x13U)),
      (2, encode_c_li(10, 1).reinterpret_as_uint()),
      (2, encode_c_bnez(10, 8).reinterpret_as_uint()),
      (2, encode_c_j(6).reinterpret_as_uint()),
      (4, encode_i(88, 0, 0x0U, 7, 0x13U)),
      (2, encode_c_addi(8, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    _ => fail("expected mixed-width jump program to run")
  }
  assert_eq(runner.read_reg(1), 2U)
  assert_eq(runner.read_reg(5), 0U)
  assert_eq(runner.read_reg(6), 0U)
  assert_eq(runner.read_reg(7), 0U)
  assert_eq(runner.read_reg(10), 1U)
  assert_eq(runner.read_reg(8), 1U)
  assert_eq(runner.pc(), 26U)
}

///|
test "compressed load and store reuse the normal memory execute path" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (4, encode_i(32, 0, 0x0U, 10, 0x13U)),
      (2, encode_c_li(9, 7).reinterpret_as_uint()),
      (2, encode_c_sw(9, 10, 12).reinterpret_as_uint()),
      (2, encode_c_lw(11, 10, 12).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected compressed load/store round trip")
  }
  assert_eq(runner.read_reg(11), 7U)
  assert_eq(runner.pc(), 10U)
}

///|
test "stack-pointer compressed forms reuse addi shift and memory execute paths" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addi16sp(16).reinterpret_as_uint()),
      (2, encode_c_li(13, 17).reinterpret_as_uint()),
      (2, encode_c_swsp(13, 20).reinterpret_as_uint()),
      (2, encode_c_lwsp(14, 20).reinterpret_as_uint()),
      (2, encode_c_slli(14, 3).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected stack-pointer compressed sequence to run")
  }
  assert_eq(runner.read_reg(2), 16U)
  assert_eq(runner.read_reg(14), 136U)
  assert_eq(runner.pc(), 10U)
}

///|
test "compressed reusable integer ALU forms expand through existing op helpers" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addi4spn(8, 32).reinterpret_as_uint()),
      (4, encode_i(0xff, 0, 0x0U, 9, 0x13U)),
      (2, encode_c_srli(8, 3).reinterpret_as_uint()),
      (2, encode_c_srai(9, 4).reinterpret_as_uint()),
      (2, encode_c_andi(9, -16).reinterpret_as_uint()),
      (2, encode_c_li(10, 3).reinterpret_as_uint()),
      (2, encode_c_sub(9, 10).reinterpret_as_uint()),
      (2, encode_c_xor(8, 9).reinterpret_as_uint()),
      (2, encode_c_or(8, 10).reinterpret_as_uint()),
      (2, encode_c_and(9, 10).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(10) {
    Running => ()
    _ => fail("expected compressed integer ALU sequence to run")
  }
  assert_eq(runner.read_reg(8), 0xfffffffbU)
  assert_eq(runner.read_reg(9), 1U)
  assert_eq(runner.read_reg(10), 3U)
  assert_eq(runner.pc(), 22U)
}

///|
test "compressed mixed-width integration covers addi4spn and ALU subgroup" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addi4spn(8, 32).reinterpret_as_uint()),
      (2, encode_c_li(9, 7).reinterpret_as_uint()),
      (2, encode_c_sw(9, 8, 12).reinterpret_as_uint()),
      (4, encode_i(5, 0, 0x0U, 11, 0x13U)),
      (2, encode_c_lw(12, 8, 12).reinterpret_as_uint()),
      (2, encode_c_andi(12, 5).reinterpret_as_uint()),
      (2, encode_c_or(12, 9).reinterpret_as_uint()),
      (2, encode_c_j(6).reinterpret_as_uint()),
      (4, encode_i(77, 0, 0x0U, 6, 0x13U)),
      (2, encode_c_sub(12, 11).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(9) {
    Running => ()
    _ => fail("expected mixed-width reusable subset program to run")
  }
  assert_eq(runner.read_reg(6), 0U)
  assert_eq(runner.read_reg(12), 2U)
  assert_eq(runner.pc(), 24U)
}

///|
test "c.addi4spn with zero immediate remains illegal" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([(2, encode_c_addi4spn(8, 0).reinterpret_as_uint())]),
    0U,
  )
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U)
      assert_eq(info.trap_value, 0x0000U)
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "compressed jump-register forms use jalr semantics with a 2-byte link address" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (4, encode_i(12, 0, 0x0U, 9, 0x13U)),
      (2, encode_c_jalr(9).reinterpret_as_uint()),
      (4, encode_i(99, 0, 0x0U, 5, 0x13U)),
      (2, encode_c_jr(9).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.step() {
    Running => ()
    _ => fail("expected setup addi to run")
  }
  match runner.step() {
    Running => ()
    _ => fail("expected c.jalr to run")
  }
  assert_eq(runner.read_reg(1), 6U)
  assert_eq(runner.pc(), 12U)
}

///|
test "unsupported compressed instructions still trap as illegal instruction" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([(2, 0x9c25U)]),
    0U,
  )
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U)
      assert_eq(info.trap_value, 0x9c25U)
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "mixed 16-bit and 32-bit instructions keep sequential pc accounting correct" {
  let runner = make_runner(default_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_li(9, 1).reinterpret_as_uint()),
      (4, encode_i(2, 0, 0x0U, 10, 0x13U)),
      (2, encode_c_add(10, 9).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    _ => fail("expected mixed-width sequence to run")
  }
  assert_eq(runner.read_reg(10), 3U)
  assert_eq(runner.pc(), 8U)
}
