// White-box profile-legality regressions for machine configurations that are
// deliberately not exposed as public constructors.

///|
fn wb_rv64_without_c_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  {
    xlen: config.xlen,
    extensions: config.extensions & bit_not(MISA_EXT_C),
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
}

///|
fn wb_rv64_without_m_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  {
    xlen: config.xlen,
    extensions: config.extensions & bit_not(MISA_EXT_M),
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
}

///|
fn wb_rv64_d_only_requested_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  {
    xlen: config.xlen,
    extensions: (config.extensions & bit_not(MISA_EXT_F)) | MISA_EXT_D,
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
}

///|
fn wb_halfword_program(raw : UInt) -> Bytes {
  Bytes::from_array([raw.to_byte(), (raw >> 8).to_byte()])
}

///|
fn wb_word_program(raw : UInt) -> Bytes {
  Bytes::from_array([
    raw.to_byte(),
    (raw >> 8).to_byte(),
    (raw >> 16).to_byte(),
    (raw >> 24).to_byte(),
  ])
}

///|
fn wb_encode_i(
  imm : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
  opcode : UInt,
) -> UInt {
  ((imm.reinterpret_as_uint() & 0xfffU) << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
fn wb_encode_b(
  imm : Int,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  opcode : UInt,
) -> UInt {
  let value = imm.reinterpret_as_uint()
  (((value >> 12) & 0x1U) << 31) |
  (((value >> 5) & 0x3fU) << 25) |
  (rs2.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (((value >> 1) & 0xfU) << 8) |
  (((value >> 11) & 0x1U) << 7) |
  opcode
}

///|
fn wb_encode_j(imm : Int, rd : Int, opcode : UInt) -> UInt {
  let encoded = (imm & 0x1fffff).reinterpret_as_uint()
  (((encoded >> 20) & 0x1U) << 31) |
  (((encoded >> 1) & 0x3ffU) << 21) |
  (((encoded >> 11) & 0x1U) << 20) |
  (((encoded >> 12) & 0xffU) << 12) |
  (rd.reinterpret_as_uint() << 7) |
  opcode
}

///|
test "compressed instruction traps when C extension is not advertised" {
  let runner = make_runner(wb_rv64_without_c_machine_config())
  let raw = 0x0405U // c.addi x8, 1
  runner.load_program(wb_halfword_program(raw), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected compressed instruction to trap without MISA.C")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected compressed instruction trap without MISA.C")
  }
}

///|
test "non-C profile traps on taken branch to halfword target" {
  let runner = make_runner(wb_rv64_without_c_machine_config())
  let raw = wb_encode_b(2, 0, 0, 0x0U, 0x63U) // beq x0, x0, +2
  runner.load_program(wb_word_program(raw), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        InstructionAddressMisaligned => ()
        _ => fail("expected taken branch to report instruction misalignment")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 2U.to_uint64())
    }
    _ => fail("expected taken branch to halfword target to trap without C")
  }
}

///|
test "non-C profile does not trap untaken branch to halfword target" {
  let runner = make_runner(wb_rv64_without_c_machine_config())
  let raw = wb_encode_b(2, 0, 0, 0x1U, 0x63U) // bne x0, x0, +2
  runner.load_program(wb_word_program(raw), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected untaken branch to ignore misaligned target")
  }
  assert_eq(runner.pc_u64(), 4U.to_uint64())
}

///|
test "jalr target alignment follows C extension ialign" {
  let program = words_to_bytes([
    wb_encode_i(2, 0, 0x0U, 1, 0x13U), // addi x1, x0, 2
    wb_encode_i(0, 1, 0x0U, 0, 0x67U), // jalr x0, 0(x1)
  ])

  let no_c = make_runner(wb_rv64_without_c_machine_config())
  no_c.load_program(program, 0U)
  match no_c.run(2) {
    Trap(info) => {
      match info.cause {
        InstructionAddressMisaligned => ()
        _ => fail("expected jalr to report instruction misalignment")
      }
      assert_eq(info.faulting_pc, 4U.to_uint64())
      assert_eq(info.trap_value, 2U.to_uint64())
    }
    _ => fail("expected jalr to halfword target to trap without C")
  }

  let with_c = make_runner(rv64_machine_config())
  with_c.load_program(program, 0U)
  match with_c.run(2) {
    Running => ()
    _ => fail("expected jalr to halfword target to run with C")
  }
  assert_eq(with_c.pc_u64(), 2U.to_uint64())
}

///|
test "jal target alignment follows C extension ialign" {
  let raw = wb_encode_j(2, 0, 0x6fU) // jal x0, +2

  let no_c = make_runner(wb_rv64_without_c_machine_config())
  no_c.load_program(wb_word_program(raw), 0U)
  match no_c.step() {
    Trap(info) => {
      match info.cause {
        InstructionAddressMisaligned => ()
        _ => fail("expected jal to report instruction misalignment")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 2U.to_uint64())
    }
    _ => fail("expected jal to halfword target to trap without C")
  }

  let with_c = make_runner(rv64_machine_config())
  with_c.load_program(wb_word_program(raw), 0U)
  match with_c.step() {
    Running => ()
    _ => fail("expected jal to halfword target to run with C")
  }
  assert_eq(with_c.pc_u64(), 2U.to_uint64())
}

///|
test "multiply instruction traps when M extension is not advertised" {
  let runner = make_runner(wb_rv64_without_m_machine_config())
  let raw = wb_encode_r(0x01U, 2, 1, 0x0U, 3, 0x33U) // mul x3, x1, x2
  runner.load_program(wb_word_program(raw), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected M instruction to trap without MISA.M")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected M instruction trap without MISA.M")
  }
}

///|
test "requesting D-only profile canonicalizes to include F" {
  let runner = make_runner(wb_rv64_d_only_requested_machine_config())
  let misa = runner.cpu.read_csr(CSR_MISA)
  assert_true((misa & MISA_EXT_D) != 0U.to_uint64())
  assert_true((misa & MISA_EXT_F) != 0U.to_uint64())
  assert_true((runner.config.extensions & MISA_EXT_F) != 0U.to_uint64())

  let raw = wb_encode_r(0x00U, 2, 1, 0x0U, 3, 0x53U) // fadd.s f3, f1, f2
  runner.load_program(wb_word_program(raw), 0U)
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected D-implies-F profile to accept fadd.s, got trap value=\{info.trap_value}",
      )
  }
}
