// White-box profile-legality regressions for machine configurations that are
// deliberately not exposed as public constructors.

///|
fn wb_rv64_profile_machine_config(extensions : UInt64) -> MachineConfig {
  let config = rv64_machine_config()
  // Profile white-box tests intentionally request non-public ISA combinations.
  // Keep the platform fields identical to the ordinary RV64 config so each
  // test isolates extension legality rather than changing memory or device
  // layout at the same time.
  {
    xlen: config.xlen,
    extensions,
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
fn wb_rv64_without_c_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  wb_rv64_profile_machine_config(config.extensions & bit_not(MISA_EXT_C))
}

///|
fn wb_rv64_without_m_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  wb_rv64_profile_machine_config(config.extensions & bit_not(MISA_EXT_M))
}

///|
fn wb_rv64_without_s_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  wb_rv64_profile_machine_config(config.extensions & bit_not(MISA_EXT_S))
}

///|
fn wb_rv64_without_u_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  wb_rv64_profile_machine_config(config.extensions & bit_not(MISA_EXT_U))
}

///|
fn wb_rv64_d_only_requested_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  wb_rv64_profile_machine_config(
    (config.extensions & bit_not(MISA_EXT_F)) | MISA_EXT_D,
  )
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
fn wb_expect_absent_csr_forms(
  config : MachineConfig,
  csr : Int,
  label : String,
) -> Unit raise {
  let forms = [
    wb_encode_csr(csr, 1, 0x1U, 2), // CSRRW reads old value, then writes.
    wb_encode_csr(csr, 1, 0x1U, 0), // CSRRW rd=x0 suppresses only the read.
    wb_encode_csr(csr, 1, 0x2U, 2), // CSRRS with a nonzero register mask.
    wb_encode_csr(csr, 0, 0x2U, 2), // CSRRS with x0 is still a read.
    wb_encode_csr(csr, 1, 0x3U, 2), // CSRRC with a nonzero register mask.
    wb_encode_csr(csr, 0, 0x3U, 2), // CSRRC with x0 is still a read.
    wb_encode_csr(csr, 1, 0x5U, 2), // CSRRWI reads old value, then writes.
    wb_encode_csr(csr, 1, 0x5U, 0), // CSRRWI rd=x0 suppresses only the read.
    wb_encode_csr(csr, 1, 0x6U, 2), // CSRRSI with a nonzero immediate mask.
    wb_encode_csr(csr, 0, 0x6U, 2), // CSRRSI uimm=0 is still a read.
    wb_encode_csr(csr, 1, 0x7U, 2), // CSRRCI with a nonzero immediate mask.
    wb_encode_csr(csr, 0, 0x7U, 2), // CSRRCI uimm=0 is still a read.
  ]
  for raw in forms {
    let runner = make_runner(config)
    runner.cpu.write_reg(1, 1U.to_uint64())
    runner.load_program(wb_word_program(raw), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected absent CSR form to trap for " + label)
        }
        assert_eq(info.faulting_pc, 0U.to_uint64())
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected absent CSR form trap for " + label)
    }
  }
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
fn wb_encode_csr(csr : Int, rs1 : Int, funct3 : UInt, rd : Int) -> UInt {
  (csr.reinterpret_as_uint() << 20) |
  (rs1.reinterpret_as_uint() << 15) |
  (funct3 << 12) |
  (rd.reinterpret_as_uint() << 7) |
  0x73U
}

///|
fn wb_encode_mret() -> UInt {
  0x30200073U
}

///|
fn wb_encode_sret() -> UInt {
  0x10200073U
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
test "epc bit one visibility follows active ialign" {
  let with_c = make_runner(rv64_machine_config())
  with_c.cpu.write_csr(CSR_MEPC, 14U.to_uint64())
  with_c.load_program(wb_word_program(wb_encode_csr(CSR_MEPC, 0, 0x2U, 1)), 0U)
  match with_c.step() {
    Running => ()
    _ => fail("expected rv64c mepc read to run")
  }
  assert_eq(with_c.read_reg_u64(1), 14U.to_uint64())

  let no_c_read = make_runner(wb_rv64_without_c_machine_config())
  no_c_read.cpu.write_csr(CSR_MEPC, 14U.to_uint64())
  no_c_read.load_program(
    wb_word_program(wb_encode_csr(CSR_MEPC, 0, 0x2U, 1)),
    0U,
  )
  match no_c_read.step() {
    Running => ()
    _ => fail("expected non-c mepc read to run")
  }
  assert_eq(no_c_read.read_reg_u64(1), 12U.to_uint64())

  let no_c_sepc_read = make_runner(wb_rv64_without_c_machine_config())
  no_c_sepc_read.cpu.write_csr(CSR_SEPC, 14U.to_uint64())
  no_c_sepc_read.load_program(
    wb_word_program(wb_encode_csr(CSR_SEPC, 0, 0x2U, 1)),
    0U,
  )
  match no_c_sepc_read.step() {
    Running => ()
    _ => fail("expected non-c sepc read to run")
  }
  assert_eq(no_c_sepc_read.read_reg_u64(1), 12U.to_uint64())

  let no_c_mret = make_runner(wb_rv64_without_c_machine_config())
  no_c_mret.cpu.write_csr(CSR_MEPC, 14U.to_uint64())
  no_c_mret.load_program(wb_word_program(wb_encode_mret()), 0U)
  match no_c_mret.step() {
    Running => ()
    _ => fail("expected non-c mret to run")
  }
  assert_eq(no_c_mret.pc_u64(), 12U.to_uint64())

  let no_c_sret = make_runner(wb_rv64_without_c_machine_config())
  no_c_sret.cpu.write_csr(CSR_SEPC, 14U.to_uint64())
  no_c_sret.load_program(wb_word_program(wb_encode_sret()), 0U)
  match no_c_sret.step() {
    Running => ()
    _ => fail("expected non-c sret to run")
  }
  assert_eq(no_c_sret.pc_u64(), 12U.to_uint64())
}

///|
test "epc bit one remains writable when ialign masks reads" {
  let no_c_mepc = make_runner(wb_rv64_without_c_machine_config())
  no_c_mepc.cpu.write_reg(1, 14U.to_uint64())
  no_c_mepc.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MEPC, 1, 0x1U, 0),
      wb_encode_csr(CSR_MEPC, 0, 0x2U, 2),
    ]),
    0U,
  )
  match no_c_mepc.run(2) {
    Running => ()
    _ => fail("expected non-c mepc write/read program to run")
  }
  // The privileged spec masks EPC bit 1 on visible reads and xRET target
  // reads when IALIGN=32, but the bit remains writable storage. Keep both
  // layers pinned so a future simplification cannot make read masking destroy
  // the hidden halfword target bit.
  assert_eq(no_c_mepc.read_reg_u64(2), 12U.to_uint64())
  assert_eq(no_c_mepc.read_csr_u64(CSR_MEPC), 12U.to_uint64())
  assert_eq(no_c_mepc.cpu.read_csr(CSR_MEPC), 14U.to_uint64())

  let no_c_set = make_runner(wb_rv64_without_c_machine_config())
  no_c_set.cpu.write_reg(1, 2U.to_uint64())
  no_c_set.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MEPC, 1, 0x2U, 2),
      wb_encode_csr(CSR_MEPC, 0, 0x2U, 3),
      wb_encode_csr(CSR_SEPC, 1, 0x2U, 4),
      wb_encode_csr(CSR_SEPC, 0, 0x2U, 5),
    ]),
    0U,
  )
  match no_c_set.run(4) {
    Running => ()
    _ => fail("expected non-c epc set-form program to run")
  }
  // CSRRS writes a candidate derived from the masked visible old value. Setting
  // bit 1 through that candidate is still legal storage for both machine and
  // supervisor EPCs, even though the following CSR read must report zero.
  assert_eq(no_c_set.read_reg_u64(2), 0U.to_uint64())
  assert_eq(no_c_set.read_reg_u64(3), 0U.to_uint64())
  assert_eq(no_c_set.read_reg_u64(4), 0U.to_uint64())
  assert_eq(no_c_set.read_reg_u64(5), 0U.to_uint64())
  assert_eq(no_c_set.cpu.read_csr(CSR_MEPC), 2U.to_uint64())
  assert_eq(no_c_set.cpu.read_csr(CSR_SEPC), 2U.to_uint64())
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
test "misaligned jump targets do not write link registers" {
  let jal = make_runner(wb_rv64_without_c_machine_config())
  let jal_raw = wb_encode_j(2, 5, 0x6fU) // jal x5, +2
  jal.load_program(wb_word_program(jal_raw), 0U)
  match jal.step() {
    Trap(info) => {
      match info.cause {
        InstructionAddressMisaligned => ()
        _ => fail("expected jal to trap before writing the link register")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 2U.to_uint64())
    }
    _ => fail("expected jal to halfword target to trap without C")
  }
  assert_eq(jal.read_reg_u64(5), 0U.to_uint64())

  let jalr = make_runner(wb_rv64_without_c_machine_config())
  let jalr_program = words_to_bytes([
    wb_encode_i(6, 0, 0x0U, 1, 0x13U), // addi x1, x0, 6
    wb_encode_i(0, 1, 0x0U, 6, 0x67U), // jalr x6, 0(x1)
  ])
  jalr.load_program(jalr_program, 0U)
  match jalr.run(2) {
    Trap(info) => {
      match info.cause {
        InstructionAddressMisaligned => ()
        _ => fail("expected jalr to trap before writing the link register")
      }
      assert_eq(info.faulting_pc, 4U.to_uint64())
      assert_eq(info.trap_value, 6U.to_uint64())
    }
    _ => fail("expected jalr to halfword target to trap without C")
  }
  assert_eq(jalr.read_reg_u64(6), 0U.to_uint64())
}

///|
test "M extension instructions trap when M extension is not advertised" {
  let m_extension_representatives = [
    wb_encode_r(0x01U, 2, 1, 0x0U, 3, 0x33U), // MUL
    wb_encode_r(0x01U, 2, 1, 0x5U, 3, 0x33U), // DIVU
    wb_encode_r(0x01U, 2, 1, 0x7U, 3, 0x33U), // REMU
    wb_encode_r(0x01U, 2, 1, 0x0U, 3, 0x3bU), // MULW
    wb_encode_r(0x01U, 2, 1, 0x4U, 3, 0x3bU), // DIVW
    wb_encode_r(0x01U, 2, 1, 0x6U, 3, 0x3bU), // REMW
  ]
  for raw in m_extension_representatives {
    let runner = make_runner(wb_rv64_without_m_machine_config())
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
}

///|
test "supervisor profile resources trap when S extension is not advertised" {
  let no_s_config = wb_rv64_without_s_machine_config()
  for
    csr in [
      CSR_SSTATUS,
      CSR_SATP,
      CSR_MEDELEG,
      CSR_MIDELEG,
      CSR_SCOUNTEREN,
      CSR_SENVCFG,
    ] {
    wb_expect_absent_csr_forms(no_s_config, csr, "no-S supervisor CSR")
  }

  let supervisor_resources = [
    0x12000073U, // sfence.vma x0, x0
    wb_encode_sret(),
  ]
  for raw in supervisor_resources {
    let runner = make_runner(no_s_config)
    runner.cpu.write_reg(1, 1U.to_uint64())
    runner.load_program(wb_word_program(raw), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected absent supervisor resource to trap")
        }
        assert_eq(info.faulting_pc, 0U.to_uint64())
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected absent supervisor resource trap")
    }
  }
}

///|
test "supervisor interrupt bits are absent when S is not advertised" {
  let mie_runner = make_runner(wb_rv64_without_s_machine_config())
  mie_runner.cpu.write_reg(1, bit_not(0U.to_uint64()))
  mie_runner.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MIE, 1, 0x1U, 0), // write all implemented mie bits
      wb_encode_csr(CSR_MIE, 0, 0x2U, 2), // read mie
    ]),
    0U,
  )
  match mie_runner.run(2) {
    Running => ()
    _ => fail("expected no-S mie write/read program to run")
  }
  assert_eq(mie_runner.read_reg_u64(2), 0x888U.to_uint64())

  let mip_runner = make_runner(wb_rv64_without_s_machine_config())
  mip_runner.cpu.write_reg(1, bit_not(0U.to_uint64()))
  mip_runner.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MIP, 1, 0x1U, 0), // S pending bits are absent
      wb_encode_csr(CSR_MIP, 0, 0x2U, 2),
    ]),
    0U,
  )
  match mip_runner.run(2) {
    Running => ()
    _ => fail("expected no-S mip write/read program to run")
  }
  assert_eq(mip_runner.read_reg_u64(2), 0U.to_uint64())
}

///|
test "mcounteren permits user counter reads directly when S is absent" {
  let runner = make_runner(wb_rv64_without_s_machine_config())
  runner.load_program(
    words_to_bytes([
      wb_encode_i(1, 0, 0x0U, 1, 0x13U), // CY bit in mcounteren
      wb_encode_csr(CSR_MCOUNTEREN, 1, 0x1U, 0),
      wb_encode_i(24, 0, 0x0U, 5, 0x13U),
      wb_encode_csr(CSR_MEPC, 5, 0x1U, 0),
      wb_encode_csr(CSR_MSTATUS, 0, 0x1U, 0), // MPP=U
      wb_encode_mret(),
      wb_encode_csr(CSR_CYCLE, 0, 0x2U, 2),
      wb_encode_i(1, 0, 0x0U, 3, 0x13U),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    _ => fail("expected no-S U-mode cycle read with mcounteren")
  }
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected no-S profile to return to U-mode")
  }
  assert_true(runner.read_reg_u64(2) > 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 1U.to_uint64())
}

///|
test "mstatus write cannot expose supervisor return state without S" {
  let runner = make_runner(wb_rv64_without_s_machine_config())
  let mpp_s_and_spp = (1U.to_uint64() << MSTATUS_MPP_SHIFT) |
    MSTATUS_SPP_BIT.to_uint64() |
    MSTATUS_FS_DIRTY |
    MSTATUS_SD_BIT
  runner.cpu.write_reg(1, mpp_s_and_spp)
  runner.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MSTATUS, 1, 0x1U, 0), // CSRRW x0, mstatus, x1
      wb_encode_csr(CSR_MSTATUS, 0, 0x2U, 2), // CSRRS x2, mstatus, x0
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected no-S mstatus WARL program to run")
  }
  let visible = runner.read_reg_u64(2)
  assert_eq(visible & MSTATUS_MPP_MASK.to_uint64(), 0U.to_uint64())
  assert_eq(visible & MSTATUS_SPP_BIT.to_uint64(), 0U.to_uint64())
  assert_eq(visible & (MSTATUS_FS_MASK | MSTATUS_SD_BIT), 0U.to_uint64())
}

///|
test "requesting no-U profile canonicalizes away S as well" {
  let runner = make_runner(wb_rv64_without_u_machine_config())
  let misa = runner.cpu.read_csr(CSR_MISA)
  assert_eq(misa & MISA_EXT_U, 0U.to_uint64())
  assert_eq(misa & MISA_EXT_S, 0U.to_uint64())
  assert_eq(runner.config.extensions & MISA_EXT_U, 0U.to_uint64())
  assert_eq(runner.config.extensions & MISA_EXT_S, 0U.to_uint64())
}

///|
test "user-mode counter delegation csr traps when U is not advertised" {
  wb_expect_absent_csr_forms(
    wb_rv64_without_u_machine_config(),
    CSR_MCOUNTEREN,
    "no-U mcounteren",
  )
}

///|
test "floating-point csrs trap when F is not advertised" {
  // RV64 integer/S-mode profiles may still expose mstatus.FS for supervisor
  // context-status bookkeeping, but the actual floating-point CSR address
  // surface belongs to the F extension and must be absent without MISA.F.
  for csr in [CSR_FFLAGS, CSR_FRM, CSR_FCSR] {
    wb_expect_absent_csr_forms(
      rv64_machine_config(),
      csr,
      "no-F floating-point CSR",
    )
  }
}

///|
test "mstatus write cannot expose user return state without U" {
  let runner = make_runner(wb_rv64_without_u_machine_config())
  runner.cpu.write_reg(
    1,
    MSTATUS_UXL_MASK |
    MSTATUS_MPRV_BIT |
    MSTATUS_TW_BIT |
    MSTATUS_FS_DIRTY |
    MSTATUS_SD_BIT,
  )
  runner.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MSTATUS, 1, 0x1U, 0), // CSRRW x0, mstatus, x1
      wb_encode_csr(CSR_MSTATUS, 0, 0x2U, 2), // CSRRS x2, mstatus, x0
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected no-U mstatus UXL WARL program to run")
  }
  assert_eq(
    runner.read_reg_u64(2) &
    (
      MSTATUS_UXL_MASK |
      MSTATUS_MPRV_BIT |
      MSTATUS_TW_BIT |
      MSTATUS_FS_MASK |
      MSTATUS_SD_BIT
    ),
    0U.to_uint64(),
  )

  let mpp_u = make_runner(wb_rv64_without_u_machine_config())
  mpp_u.cpu.write_reg(1, 0U.to_uint64())
  mpp_u.load_program(
    words_to_bytes([
      wb_encode_csr(CSR_MSTATUS, 1, 0x1U, 0), // write MPP=U encoding
      wb_encode_csr(CSR_MSTATUS, 0, 0x2U, 2),
    ]),
    0U,
  )
  match mpp_u.run(2) {
    Running => ()
    _ => fail("expected no-U mstatus MPP WARL program to run")
  }
  assert_eq(
    mpp_u.read_reg_u64(2) & MSTATUS_MPP_MASK.to_uint64(),
    MSTATUS_MPP_MASK.to_uint64(),
  )
}

///|
test "mret resets MPP to least implemented mode without U" {
  let runner = make_runner(wb_rv64_without_u_machine_config())
  runner.cpu.write_csr(CSR_MSTATUS, MSTATUS_MPP_MASK.to_uint64())
  runner.cpu.write_csr(CSR_MEPC, 4U.to_uint64())
  runner.load_program(wb_word_program(wb_encode_mret()), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected no-U MRET-to-M program to run")
  }
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected no-U MRET to remain in machine mode")
  }
  assert_eq(runner.pc_u64(), 4U.to_uint64())
  assert_eq(
    runner.cpu.read_csr(CSR_MSTATUS) & MSTATUS_MPP_MASK.to_uint64(),
    MSTATUS_MPP_MASK.to_uint64(),
  )
}

///|
test "requesting D without F canonicalizes both extensions away" {
  let runner = make_runner(wb_rv64_d_only_requested_machine_config())
  let misa = runner.cpu.read_csr(CSR_MISA)
  assert_eq(misa & (MISA_EXT_D | MISA_EXT_F), 0U.to_uint64())
  assert_eq(
    runner.config.extensions & (MISA_EXT_D | MISA_EXT_F),
    0U.to_uint64(),
  )

  let raw = wb_encode_r(0x00U, 2, 1, 0x0U, 3, 0x53U) // fadd.s f3, f1, f2
  runner.load_program(wb_word_program(raw), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected F instruction to trap after D/F canonicalization")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected F instruction to trap after D/F canonicalization")
  }
}
