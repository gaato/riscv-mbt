// Fetch-path regressions. Keep these separate from execute tests so instruction
// length, alignment, and memory-read failures stay easy to diagnose.

///|
test "32-bit fetch path still advances pc by 4" {
  let runner = @riscv_mbt.make_runner(@riscv_mbt.default_machine_config())
  let raw = encode_i(5, 0, 0x0U, 1, 0x13U)
  runner.load_program(@riscv_mbt.words_to_bytes([raw]), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.pc(), 4U)
  assert_eq(runner.read_reg(1), 5U)
}

///|
test "unsupported compressed-looking instruction traps as illegal instruction" {
  let runner = @riscv_mbt.make_runner(@riscv_mbt.default_machine_config())
  let raw16 = Bytes::from_array([0x25U.to_byte(), 0x9cU.to_byte()])
  runner.load_program(raw16, 0U)
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
test "32-bit-looking truncated fetch traps as instruction access fault" {
  // A low halfword that advertises a 32-bit instruction must translate/read the
  // high halfword too. This guards the Linux page-boundary fetch bug.
  let runner = @riscv_mbt.make_runner(@riscv_mbt.default_machine_config())
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
      assert_eq(info.faulting_pc, last_two_bytes.to_uint64())
      assert_eq(info.trap_value, last_two_bytes.to_uint64() + 2U.to_uint64())
    }
    _ => fail("expected instruction access fault")
  }
}

///|
test "decode cache records hits after a small instruction loop" {
  let runner = @riscv_mbt.make_runner(@riscv_mbt.default_machine_config())
  let program = @riscv_mbt.words_to_bytes([
    encode_i(1, 1, 0x0U, 1, 0x13U),
    encode_j(-4, 0, 0x6fU),
  ])
  runner.load_program(program, 0U)
  assert_eq(runner.decode_cache_hit_count(), 0U.to_uint64())
  assert_eq(runner.decode_cache_miss_count(), 0U.to_uint64())
  match runner.run(10) {
    Running => ()
    _ => fail("expected loop to keep running")
  }
  assert_eq(runner.decode_cache_miss_count(), 2U.to_uint64())
  assert_eq(runner.decode_cache_fill_count(), 2U.to_uint64())
  assert_eq(runner.decode_cache_hit_count(), 8U.to_uint64())
  assert_eq(runner.read_reg(1), 5U)
}

///|
test "fence.i flushes the decode cache" {
  let runner = @riscv_mbt.make_runner(@riscv_mbt.default_machine_config())
  runner.load_program(@riscv_mbt.words_to_bytes([encode_fence_i()]), 0U)
  let flushes_after_load = runner.decode_cache_flush_count()
  match runner.step() {
    Running => ()
    _ => fail("expected fence.i to run")
  }
  assert_eq(
    runner.decode_cache_flush_count(),
    flushes_after_load + 1U.to_uint64(),
  )
}
