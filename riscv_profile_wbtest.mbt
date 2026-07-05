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
