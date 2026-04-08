///|
test "32-bit fetch path still advances pc by 4" {
  let runner = make_runner(default_machine_config())
  let raw = encode_i(5, 0, 0x0U, 1, 0x13U)
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.pc(), 4U)
  assert_eq(runner.read_reg(1), 5U)
}

///|
test "16-bit-looking instruction traps as illegal instruction" {
  let runner = make_runner(default_machine_config())
  let raw16 = Bytes::from_array([0x01U.to_byte(), 0x00U.to_byte()])
  runner.load_program(raw16, 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.faulting_pc, 0U)
      assert_eq(info.trap_value, 0x0001U)
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "32-bit-looking truncated fetch traps as instruction access fault" {
  let runner = make_runner(default_machine_config())
  let last_two_bytes = (runner.config().ram_size - 2).reinterpret_as_uint()
  runner.load_program(
    Bytes::from_array([0x13U.to_byte(), 0x00U.to_byte()]),
    last_two_bytes,
  )
  match runner.step() {
    Trap(info) => {
      match info.cause {
        InstructionAccessFault => ()
        _ => fail("expected instruction access fault")
      }
      assert_eq(info.faulting_pc, last_two_bytes)
      assert_eq(info.trap_value, last_two_bytes)
    }
    _ => fail("expected instruction access fault")
  }
}
