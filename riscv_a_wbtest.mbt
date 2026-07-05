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
test "AMO.W traps when A extension is not advertised" {
  let runner = make_runner(wb_rv64_without_a_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 42U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 1U.to_uint64())
  let raw = wb_encode_amo(0x00U, 2, 1, 0x2U, 3)
  runner.bus.store_u32(runner.cpu.pc, raw.to_uint64())
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected IllegalInstruction when MISA.A is clear")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected AMO.W to trap without A extension")
  }
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
