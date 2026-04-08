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
