// Compressed-instruction regressions for decode and execution. Keep these
// focused on C extension aliases and sign/zero extension corner cases.

///|
fn encode_c_addi(rd : Int, imm : Int) -> Int {
  0x0001 | (((imm >> 5) & 0x1) << 12) | (rd << 7) | ((imm & 0x1f) << 2)
}

///|
fn encode_c_addiw(rd : Int, imm : Int) -> Int {
  0x2001 | (((imm >> 5) & 0x1) << 12) | (rd << 7) | ((imm & 0x1f) << 2)
}

///|
fn encode_c_li(rd : Int, imm : Int) -> Int {
  0x4001 | (((imm >> 5) & 0x1) << 12) | (rd << 7) | ((imm & 0x1f) << 2)
}

///|
fn encode_c_lui(rd : Int, imm : Int) -> Int {
  0x6001 | (((imm >> 5) & 0x1) << 12) | (rd << 7) | ((imm & 0x1f) << 2)
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
  // Keep the compressed encoders local to tests. They document bit placement
  // without widening the public helper surface.
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
fn encode_c_ld(rd : Int, rs1 : Int, imm : Int) -> Int {
  0x6000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 6) & 0x3) << 5) |
  (((rd - 8) & 0x7) << 2)
}

///|
fn encode_c_sd(rs2 : Int, rs1 : Int, imm : Int) -> Int {
  0xe000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 6) & 0x3) << 5) |
  (((rs2 - 8) & 0x7) << 2)
}

///|
fn encode_c_fld(rd : Int, rs1 : Int, imm : Int) -> Int {
  0x2000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 6) & 0x3) << 5) |
  (((rd - 8) & 0x7) << 2)
}

///|
fn encode_c_fsd(rs2 : Int, rs1 : Int, imm : Int) -> Int {
  0xa000 |
  (((imm >> 3) & 0x7) << 10) |
  (((rs1 - 8) & 0x7) << 7) |
  (((imm >> 6) & 0x3) << 5) |
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
  0x0002 | (((shamt >> 5) & 0x1) << 12) | (rd << 7) | ((shamt & 0x1f) << 2)
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
fn encode_c_word_alu(funct2 : Int, rd : Int, rs2 : Int) -> Int {
  0x9c01 |
  (((rd - 8) & 0x7) << 7) |
  ((funct2 & 0x3) << 5) |
  (((rs2 - 8) & 0x7) << 2)
}

///|
fn encode_c_subw(rd : Int, rs2 : Int) -> Int {
  encode_c_word_alu(0x0, rd, rs2)
}

///|
fn encode_c_addw(rd : Int, rs2 : Int) -> Int {
  encode_c_word_alu(0x1, rd, rs2)
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
fn encode_c_ldsp(rd : Int, imm : Int) -> Int {
  0x6002 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  (((imm >> 3) & 0x3) << 5) |
  (((imm >> 6) & 0x7) << 2)
}

///|
fn encode_c_swsp(rs2 : Int, imm : Int) -> Int {
  0xc002 | (((imm >> 2) & 0xf) << 9) | (((imm >> 6) & 0x3) << 7) | (rs2 << 2)
}

///|
fn encode_c_sdsp(rs2 : Int, imm : Int) -> Int {
  0xe002 | (((imm >> 3) & 0x7) << 10) | (((imm >> 6) & 0x7) << 7) | (rs2 << 2)
}

///|
fn encode_c_fldsp(rd : Int, imm : Int) -> Int {
  0x2002 |
  (((imm >> 5) & 0x1) << 12) |
  (rd << 7) |
  (((imm >> 6) & 0x7) << 2) |
  (((imm >> 3) & 0x3) << 5)
}

///|
fn encode_c_fsdsp(rs2 : Int, imm : Int) -> Int {
  0xa002 | (((imm >> 6) & 0x7) << 7) | (((imm >> 3) & 0x7) << 10) | (rs2 << 2)
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
test "rv64c compressed control transfers allow halfword targets" {
  // RVC control-transfer immediates are scaled in 2-byte units. Under IALIGN=16
  // a taken C.J/C.B* target at pc % 4 == 2 is a normal target, not an
  // instruction-address-misaligned trap.
  let jump = make_runner(rv64_machine_config())
  jump.load_program(
    mixed_program_bytes([
      (2, encode_c_j(6).reinterpret_as_uint()),
      (2, encode_c_li(8, 31).reinterpret_as_uint()),
      (2, encode_c_li(9, 31).reinterpret_as_uint()),
      (2, encode_c_li(10, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match jump.run(2) {
    Running => ()
    _ => fail("expected c.j to a halfword target to run")
  }
  assert_eq(jump.read_reg_u64(8), 0U.to_uint64())
  assert_eq(jump.read_reg_u64(9), 0U.to_uint64())
  assert_eq(jump.read_reg_u64(10), 1U.to_uint64())
  assert_eq(jump.pc_u64(), 8U.to_uint64())

  let branch_eq = make_runner(rv64_machine_config())
  branch_eq.load_program(
    mixed_program_bytes([
      (2, encode_c_beqz(8, 6).reinterpret_as_uint()),
      (2, encode_c_li(9, 31).reinterpret_as_uint()),
      (2, encode_c_li(10, 31).reinterpret_as_uint()),
      (2, encode_c_li(11, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match branch_eq.run(2) {
    Running => ()
    _ => fail("expected c.beqz to a halfword target to run")
  }
  assert_eq(branch_eq.read_reg_u64(9), 0U.to_uint64())
  assert_eq(branch_eq.read_reg_u64(10), 0U.to_uint64())
  assert_eq(branch_eq.read_reg_u64(11), 1U.to_uint64())
  assert_eq(branch_eq.pc_u64(), 8U.to_uint64())

  let branch_ne = make_runner(rv64_machine_config())
  branch_ne.cpu.write_reg(8, 1U.to_uint64())
  branch_ne.load_program(
    mixed_program_bytes([
      (2, encode_c_bnez(8, 6).reinterpret_as_uint()),
      (2, encode_c_li(9, 31).reinterpret_as_uint()),
      (2, encode_c_li(10, 31).reinterpret_as_uint()),
      (2, encode_c_li(12, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match branch_ne.run(2) {
    Running => ()
    _ => fail("expected c.bnez to a halfword target to run")
  }
  assert_eq(branch_ne.read_reg_u64(9), 0U.to_uint64())
  assert_eq(branch_ne.read_reg_u64(10), 0U.to_uint64())
  assert_eq(branch_ne.read_reg_u64(12), 1U.to_uint64())
  assert_eq(branch_ne.pc_u64(), 8U.to_uint64())
}

///|
test "rv64c compressed control transfers sign extend backward offsets" {
  // The same 2-byte-scaled control immediates are signed. Start execution at
  // the control instruction so a bad zero-extension would jump forward into
  // untouched memory instead of back to the marked target.
  let jump = make_runner(rv64_machine_config())
  jump.load_program(
    mixed_program_bytes([
      (2, encode_c_li(10, 1).reinterpret_as_uint()),
      (2, encode_c_li(11, 31).reinterpret_as_uint()),
      (2, encode_c_j(-4).reinterpret_as_uint()),
    ]),
    0U,
  )
  match jump.run(3) {
    Running => ()
    _ => fail("expected backward c.j to run")
  }
  assert_eq(jump.read_reg_u64(10), 1U.to_uint64())
  assert_eq(jump.read_reg_u64(11), 31U.to_uint64())
  assert_eq(jump.pc_u64(), 0U.to_uint64())

  let branch_eq = make_runner(rv64_machine_config())
  branch_eq.load_program(
    mixed_program_bytes([
      (2, encode_c_li(12, 1).reinterpret_as_uint()),
      (2, encode_c_li(13, 31).reinterpret_as_uint()),
      (2, encode_c_beqz(8, -4).reinterpret_as_uint()),
    ]),
    0U,
  )
  match branch_eq.run(3) {
    Running => ()
    _ => fail("expected backward c.beqz to run")
  }
  assert_eq(branch_eq.read_reg_u64(12), 1U.to_uint64())
  assert_eq(branch_eq.read_reg_u64(13), 31U.to_uint64())
  assert_eq(branch_eq.pc_u64(), 0U.to_uint64())

  let branch_ne = make_runner(rv64_machine_config())
  branch_ne.load_program(
    mixed_program_bytes([
      (2, encode_c_li(8, 1).reinterpret_as_uint()),
      (2, encode_c_li(15, 31).reinterpret_as_uint()),
      (2, encode_c_bnez(8, -4).reinterpret_as_uint()),
    ]),
    0U,
  )
  match branch_ne.run(3) {
    Running => ()
    _ => fail("expected backward c.bnez to run")
  }
  assert_eq(branch_ne.read_reg_u64(8), 1U.to_uint64())
  assert_eq(branch_ne.read_reg_u64(15), 31U.to_uint64())
  assert_eq(branch_ne.pc_u64(), 0U.to_uint64())
}

///|
test "rv64c rejects rv32-only compressed jal" {
  // Quadrant-1 funct3=001 is C.JAL only for RV32C. RV64C reuses the same major
  // slot for C.ADDIW, so a 16-bit JAL x1 expansion must not slip through the
  // shared JAL execute path.
  let raw = encode_c_jal(2).reinterpret_as_uint()
  let runner = make_runner(rv64_machine_config())
  runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected rv64c c.jal code point to trap")
  }
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
test "rv64c compressed double load and store keep rv32c aliases reserved" {
  let raw_value = (0x11223344U.to_uint64() << 32) | 0x55667788U.to_uint64()
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(10, 32U.to_uint64())
  runner.cpu.write_reg(9, raw_value)
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_sd(9, 10, 16).reinterpret_as_uint()),
      (2, encode_c_ld(11, 10, 16).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64c compressed double memory round trip")
  }
  assert_eq(runner.read_reg_u64(11), raw_value)
  assert_eq(runner.pc_u64(), 4U.to_uint64())

  // The same quadrant-0 integer double forms are RV64C-only. RV32C may reuse
  // these code points for floating-point forms when the matching F profile is
  // present, but this integer-only RV32 profile must not decode them as LD/SD.
  for raw_int in [encode_c_ld(11, 10, 16), encode_c_sd(9, 10, 16)] {
    let rv32_runner = make_runner(default_machine_config())
    rv32_runner.load_program(
      mixed_program_bytes([(2, raw_int.reinterpret_as_uint())]),
      0U,
    )
    match rv32_runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw_int.reinterpret_as_uint().to_uint64())
      }
      _ => fail("expected rv32c register double form to trap")
    }
  }
}

///|
test "rv64dc compressed floating load and store reuse double memory path" {
  let raw = 0x12345678U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(8, raw)
  runner.load_program(
    mixed_program_bytes([
      (4, encode_i(32, 0, 0x0U, 10, 0x13U)),
      (2, encode_c_fsd(8, 10, 112).reinterpret_as_uint()),
      (2, encode_c_fld(9, 10, 112).reinterpret_as_uint()),
      (2, encode_c_fsdsp(9, 120).reinterpret_as_uint()),
      (2, encode_c_fldsp(10, 120).reinterpret_as_uint()),
      (2, encode_c_fsdsp(8, 112).reinterpret_as_uint()),
      (2, encode_c_fldsp(0, 112).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(7) {
    Running => ()
    _ => fail("expected compressed floating load/store round trip")
  }
  assert_eq(encode_c_fsd(8, 10, 112), 0xb920)
  assert_eq(runner.read_freg_u64(9), raw)
  assert_eq(runner.read_freg_u64(10), raw)
  assert_eq(runner.read_freg_u64(0), raw)
  assert_eq(runner.pc_u64(), 16U.to_uint64())
}

///|
test "rv64c compressed floating double forms require d extension" {
  // The C spec provides compressed double load/store aliases for RV64DC, but
  // they are not integer-only RV64C instructions. Pin this at the execute
  // profile gate so decode can keep expanding them to the matching F/D op.
  let cases = [
    encode_c_fld(8, 10, 16),
    encode_c_fsd(8, 10, 16),
    encode_c_fldsp(8, 16),
    encode_c_fsdsp(8, 16),
  ]
  for raw_int in cases {
    let raw = raw_int.reinterpret_as_uint()
    let runner = make_runner(rv64_machine_config())
    runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected rv64c floating double form without D to trap")
    }
  }
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
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 0x0000U.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "all-ones compressed sentinel traps as a 16-bit illegal instruction" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(mixed_program_bytes([(2, 0xffffU)]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 0xffffU.to_uint64())
    }
    _ => fail("expected all-ones compressed sentinel to trap")
  }
}

///|
test "rv64 compressed breakpoint traps as breakpoint" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    mixed_program_bytes([(2, encode_c_add(0, 0).reinterpret_as_uint())]),
    0U,
  )
  match runner.step() {
    Trap(info) => {
      match info.cause {
        Breakpoint => ()
        _ => fail("expected breakpoint trap")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 0U.to_uint64())
    }
    _ => fail("expected breakpoint trap")
  }
}

///|
test "rv64c addiw with x0 destination remains reserved" {
  let raw = encode_c_addiw(0, 1).reinterpret_as_uint()
  let runner = make_runner(rv64_machine_config())
  runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "rv64c lui and addi16sp zero immediates remain reserved" {
  let reserved = [
    encode_c_lui(0, 0), // rd=x0 is a hint only for nonzero nzimm.
    encode_c_lui(3, 0), // C.LUI requires a nonzero nzimm.
    encode_c_addi16sp(0), // C.ADDI16SP also reserves nzimm=0.
  ]
  for raw_int in reserved {
    let raw = raw_int.reinterpret_as_uint()
    let runner = make_runner(rv64_machine_config())
    runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected reserved compressed immediate form to trap")
    }
  }
}

///|
test "rv64c integer stack loads reserve x0 destination" {
  // Stack stores may use rs2=x0 to write zero, but stack loads cannot target
  // x0. Keep those neighboring encodings separated in the C reserved audit.
  for raw_int in [encode_c_lwsp(0, 8), encode_c_ldsp(0, 8)] {
    let raw = raw_int.reinterpret_as_uint()
    let runner = make_runner(rv64_machine_config())
    runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected compressed stack load with x0 destination to trap")
    }
  }

  let store_zero = make_runner(rv64_machine_config())
  store_zero.load_program(
    mixed_program_bytes([
      (2, encode_c_swsp(0, 8).reinterpret_as_uint()),
      (2, encode_c_sdsp(0, 16).reinterpret_as_uint()),
    ]),
    0U,
  )
  match store_zero.run(2) {
    Running => ()
    _ => fail("expected stack stores from x0 to remain legal")
  }
}

///|
test "rv64c addi nop and li hint forms execute as no-ops" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(5, 0x55U.to_uint64())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addi(0, 7).reinterpret_as_uint()),
      (2, encode_c_addi(5, 0).reinterpret_as_uint()),
      (2, encode_c_li(0, -1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    _ => fail("expected compressed immediate hints to execute as no-ops")
  }
  assert_eq(runner.pc_u64(), 6U.to_uint64())
  assert_eq(runner.read_reg_u64(0), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0x55U.to_uint64())
}

///|
test "rv64c right shift zero-shamt forms execute as hints" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(8, 0x80000000U.to_uint64())
  runner.cpu.write_reg(9, 0x80000000U.to_uint64())
  runner.cpu.write_reg(10, 0x12345678U.to_uint64())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_srli(8, 0).reinterpret_as_uint()),
      (2, encode_c_srai(9, 0).reinterpret_as_uint()),
      (2, encode_c_slli(10, 0).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    _ => fail("expected compressed zero-shift hints to execute as no-ops")
  }
  assert_eq(runner.pc_u64(), 6U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 0x80000000U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 0x80000000U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0x12345678U.to_uint64())
}

///|
test "rv64c architectural hints execute as no-ops" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_lui(0, 1).reinterpret_as_uint()),
      (2, encode_c_slli(0, 0).reinterpret_as_uint()),
      (2, encode_c_slli(0, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    _ => fail("expected compressed hints to execute as no-ops")
  }
  assert_eq(runner.pc_u64(), 6U.to_uint64())
  assert_eq(runner.read_reg_u64(0), 0U.to_uint64())
}

///|
test "rv64c slli uses six bit unsigned shift amount" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (4, encode_i(1, 0, 0x0U, 9, 0x13U)),
      (2, encode_c_slli(9, 40).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64 c.slli with shamt 40 to run")
  }
  assert_eq(runner.read_reg_u64(9), 1U.to_uint64() << 40)
}

///|
test "rv32c compressed shifts reserve high shamt bit" {
  let cases = [
    encode_c_slli(0, 32),
    encode_c_slli(9, 32),
    encode_c_srli(9, 32),
    encode_c_srai(9, 32),
  ]
  for raw in cases {
    let runner = make_runner(default_machine_config())
    runner.load_program(
      mixed_program_bytes([(2, raw.reinterpret_as_uint())]),
      0U,
    )
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.reinterpret_as_uint().to_uint64())
      }
      _ => fail("expected illegal instruction trap")
    }
  }
}

///|
test "rv32c compressed double stack integer forms remain reserved" {
  // Quadrant-2 funct3=011/111 spell LDSP/SDSP only in RV64C. Keep the RV32C
  // decoder from expanding them into RV64 integer memory operations.
  let cases = [encode_c_ldsp(9, 8), encode_c_sdsp(9, 8)]
  for raw in cases {
    let runner = make_runner(default_machine_config())
    runner.load_program(
      mixed_program_bytes([(2, raw.reinterpret_as_uint())]),
      0U,
    )
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.reinterpret_as_uint().to_uint64())
      }
      _ => fail("expected rv32c ldsp/sdsp reserved form to trap")
    }
  }
}

///|
test "rv64c compressed word ALU forms sign-extend and stay rv64-only" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(8, 0x00000000ffffffffUL)
  runner.cpu.write_reg(9, 1U.to_uint64())
  runner.cpu.write_reg(10, 0U.to_uint64())
  runner.cpu.write_reg(11, 1U.to_uint64())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addw(8, 9).reinterpret_as_uint()),
      (2, encode_c_subw(10, 11).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64c compressed word ALU forms to run")
  }
  assert_eq(runner.read_reg_u64(8), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0xffffffffffffffffUL)
  assert_eq(runner.pc_u64(), 4U.to_uint64())

  for raw_int in [encode_c_addw(8, 9), encode_c_subw(10, 11)] {
    let raw = raw_int.reinterpret_as_uint()
    let rv32_runner = make_runner(default_machine_config())
    rv32_runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
    match rv32_runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected rv32c compressed word ALU form to trap")
    }
  }
}

///|
test "rv64c compressed word ALU reserved slots trap" {
  for raw_int in [encode_c_word_alu(0x2, 8, 9), encode_c_word_alu(0x3, 8, 9)] {
    let raw = raw_int.reinterpret_as_uint()
    let runner = make_runner(rv64_machine_config())
    runner.load_program(mixed_program_bytes([(2, raw)]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction trap")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected reserved compressed word ALU slot to trap")
    }
  }
}

///|
test "compressed add rd x0 forms execute as hints" {
  for rs2 in 1..<=31 {
    let raw = encode_c_add(0, rs2)
    let hint_runner = make_runner(rv64_machine_config())
    hint_runner.load_program(
      mixed_program_bytes([(2, raw.reinterpret_as_uint())]),
      0U,
    )
    hint_runner.cpu.write_reg(rs2, 0x1234U.to_uint64())
    match hint_runner.step() {
      Running => ()
      _ => fail("expected c.add hint to run as a no-op")
    }
    assert_eq(hint_runner.pc_u64(), 2U.to_uint64())
    assert_eq(hint_runner.read_reg_u64(0), 0U.to_uint64())
  }
}

///|
test "compressed mv rd x0 forms execute as hints" {
  for rs2 in 1..<=31 {
    let raw = encode_c_mv(0, rs2)
    let hint_runner = make_runner(rv64_machine_config())
    hint_runner.load_program(
      mixed_program_bytes([(2, raw.reinterpret_as_uint())]),
      0U,
    )
    hint_runner.cpu.write_reg(rs2, 0x4321U.to_uint64())
    match hint_runner.step() {
      Running => ()
      _ => fail("expected c.mv hint to run as a no-op")
    }
    assert_eq(hint_runner.pc_u64(), 2U.to_uint64())
    assert_eq(hint_runner.read_reg_u64(0), 0U.to_uint64())
  }
}

///|
test "compressed jump-register x0 forms keep reserved and ebreak meanings" {
  let jr_x0 = encode_c_jr(0)
  let jr_runner = make_runner(rv64_machine_config())
  jr_runner.load_program(
    mixed_program_bytes([(2, jr_x0.reinterpret_as_uint())]),
    0U,
  )
  match jr_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected c.jr x0 to remain reserved")
      }
      assert_eq(info.trap_value, jr_x0.reinterpret_as_uint().to_uint64())
    }
    _ => fail("expected c.jr x0 to trap")
  }

  let jalr_x0 = encode_c_jalr(0)
  let ebreak_runner = make_runner(rv64_machine_config())
  ebreak_runner.load_program(
    mixed_program_bytes([(2, jalr_x0.reinterpret_as_uint())]),
    0U,
  )
  match ebreak_runner.step() {
    Trap(info) => {
      match info.cause {
        Breakpoint => ()
        _ => fail("expected c.jalr x0 encoding to mean c.ebreak")
      }
      assert_eq(info.trap_value, 0U.to_uint64())
    }
    _ => fail("expected c.ebreak trap")
  }
}

///|
test "compressed jump-register forms use jalr semantics with a 2-byte link address" {
  let target = 8
  let jr_runner = make_runner(default_machine_config())
  jr_runner.load_program(
    mixed_program_bytes([
      (4, encode_i(target, 0, 0x0U, 9, 0x13U)),
      (2, encode_c_jr(9).reinterpret_as_uint()),
      (2, encode_c_li(5, 31).reinterpret_as_uint()),
      (2, encode_c_li(6, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match jr_runner.run(3) {
    Running => ()
    _ => fail("expected c.jr to branch through the register target")
  }
  assert_eq(jr_runner.read_reg(1), 0U)
  assert_eq(jr_runner.read_reg(5), 0U)
  assert_eq(jr_runner.read_reg(6), 1U)
  assert_eq(jr_runner.pc(), 10U)

  let jalr_runner = make_runner(default_machine_config())
  jalr_runner.load_program(
    mixed_program_bytes([
      (4, encode_i(target, 0, 0x0U, 9, 0x13U)),
      (2, encode_c_jalr(9).reinterpret_as_uint()),
      (2, encode_c_li(5, 31).reinterpret_as_uint()),
      (2, encode_c_li(6, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match jalr_runner.run(3) {
    Running => ()
    _ => fail("expected c.jalr to branch through the register target")
  }
  // C.JALR writes the address after the 16-bit instruction, not pc+4.
  assert_eq(jalr_runner.read_reg(1), 6U)
  assert_eq(jalr_runner.read_reg(5), 0U)
  assert_eq(jalr_runner.read_reg(6), 1U)
  assert_eq(jalr_runner.pc(), 10U)
}

///|
test "unsupported compressed instructions still trap as illegal instruction" {
  let runner = make_runner(default_machine_config())
  runner.load_program(mixed_program_bytes([(2, 0x9c25U)]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 0x9c25U.to_uint64())
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

///|
test "rv64 carries forward the supported compressed subset through the mixed-width execute path" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_li(9, 5).reinterpret_as_uint()),
      (2, encode_c_addi(9, -1).reinterpret_as_uint()),
      (4, encode_i(1, 0, 0x0U, 10, 0x13U)),
      (2, encode_c_add(10, 9).reinterpret_as_uint()),
      (2, encode_c_j(6).reinterpret_as_uint()),
      (4, encode_i(99, 0, 0x0U, 11, 0x13U)),
      (2, encode_c_addi(8, 1).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    _ => fail("expected rv64 compressed carry-forward sequence to run")
  }
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 5U.to_uint64())
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.pc_u64(), 18U.to_uint64())
}

///|
test "rv64c addiw executes where rv32c uses the c.jal opcode quadrant" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(10, 0x00000000ffffffffUL)
  runner.load_program(
    mixed_program_bytes([
      (2, encode_c_addiw(9, 2).reinterpret_as_uint()),
      (2, encode_c_addiw(10, 0).reinterpret_as_uint()),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected valid rv64 c.addiw encoding to run")
  }
  assert_eq(runner.read_reg_u64(9), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0xffffffffffffffffUL)
}
