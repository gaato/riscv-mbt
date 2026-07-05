// White-box A-extension regressions that need direct access to machine-profile
// construction. Black-box execute tests cover architectural AMO/LR/SC results.

///|
fn wb_encode_r(
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
fn wb_encode_amo(
  funct5 : UInt,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
) -> UInt {
  wb_encode_r(funct5 << 2, rs2, rs1, funct3, rd, 0x2fU)
}

///|
fn wb_rv64_without_a_machine_config() -> MachineConfig {
  let config = rv64_machine_config()
  {
    xlen: config.xlen,
    extensions: config.extensions & bit_not(MISA_EXT_A),
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
fn wb_expect_illegal_atomic(raw : UInt, runner : Runner) -> Unit raise {
  runner.bus.store_u32(runner.cpu.pc, raw.to_uint64())
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected atomic encoding to raise illegal instruction")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected atomic encoding to trap")
  }
}

///|
test "AMO.W traps when A extension is not advertised" {
  let runner = make_runner(wb_rv64_without_a_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 42U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 1U.to_uint64())
  let raw = wb_encode_amo(0x00U, 2, 1, 0x2U, 3)
  wb_expect_illegal_atomic(raw, runner)
}

///|
test "A extension rejects reserved AMO encodings before execution" {
  let reserved_op = wb_encode_amo(0x05U, 2, 1, 0x2U, 3)
  wb_expect_illegal_atomic(reserved_op, make_runner(rv64_machine_config()))

  // LR.W/LR.D reserve rs2 as zero. Keeping this at decode/profile-legality
  // time avoids constructing an LR instruction with an impossible source.
  let malformed_lr = wb_encode_amo(0x02U, 4, 1, 0x2U, 3)
  wb_expect_illegal_atomic(malformed_lr, make_runner(rv64_machine_config()))
}

///|
test "AMO.D traps in the 32-bit A profile" {
  let runner = make_runner(default_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u64(addr, 42U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 1U.to_uint64())
  let raw = wb_encode_amo(0x00U, 2, 1, 0x3U, 3)
  wb_expect_illegal_atomic(raw, runner)
}

///|
test "device write overlapping LR reservation makes SC fail" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(addr, 0x11223344U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, 0x55667788U.to_uint64())
  runner.bus.store_u32(pc0, wb_encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    wb_encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected LR.W to run")
  }
  runner.device_store_u8(addr + 1U.to_uint64(), 0xaaU.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected SC.W to run")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), 0x1122aa44U.to_uint64())
}

///|
test "official riscv-tests arch config advertises FP profile bits" {
  let runner = make_runner(
    official_riscv_tests_machine_config_for_arch("rv64imafdc"),
  )
  let misa = runner.cpu.read_csr(CSR_MISA)
  assert_true((misa & MISA_EXT_F) != 0U.to_uint64())
  assert_true((misa & MISA_EXT_D) != 0U.to_uint64())
}
