///|
fn test_sign_extend_word64(value : UInt) -> UInt64 {
  let shifted = value.to_uint64() << 32
  (shifted.reinterpret_as_int64() >> 32).reinterpret_as_uint64()
}

///|
fn test_join_u64(upper : UInt, lower : UInt) -> UInt64 {
  (upper.to_uint64() << 32) | lower.to_uint64()
}

///|
fn exec_test_sv39_satp(root_ppn : UInt64) -> UInt64 {
  (8U.to_uint64() << 60) | root_ppn
}

///|
fn exec_test_make_pte(ppn : UInt64, flags : UInt64) -> UInt64 {
  (ppn << 10) | flags
}

///|
fn exec_test_u64_to_le_bytes(value : UInt64) -> Bytes {
  let lo = (value & 0xffffffffU.to_uint64()).to_uint()
  let hi = (value >> 32).to_uint()
  words_to_bytes([lo, hi])
}

///|
fn exec_test_setup_basic_sv39_map(runner : Runner) -> Unit {
  let pte_v = 0x1U.to_uint64()
  let pte_r = 0x2U.to_uint64()
  let pte_w = 0x4U.to_uint64()
  let pte_a = 0x40U.to_uint64()
  let pte_d = 0x80U.to_uint64()

  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  let l0_ppn = 3U.to_uint64()
  let leaf_ppn = 4U.to_uint64()

  runner.load_program_u64(exec_test_u64_to_le_bytes(exec_test_make_pte(l1_ppn, pte_v)), 0x1000U.to_uint64())
  runner.load_program_u64(exec_test_u64_to_le_bytes(exec_test_make_pte(l0_ppn, pte_v)), 0x2000U.to_uint64())
  runner.load_program_u64(
    exec_test_u64_to_le_bytes(exec_test_make_pte(leaf_ppn, pte_v | pte_r | pte_w | pte_a | pte_d)),
    0x3000U.to_uint64(),
  )

  runner.load_program_u64(words_to_bytes([0x12345678U]), 0x4100U.to_uint64())
  runner.load_program_u64(words_to_bytes([0U]), 0x4104U.to_uint64())
  runner.load_program_u64(words_to_bytes([0xa5a5a5a5U]), 0x100U.to_uint64())

  let _ = exec_test_sv39_satp(root_ppn)
}

///|
test "x0 remains zero when written" {
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([encode_i(5, 0, 0x0U, 0, 0x13U)]), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(0), 0U)
  assert_eq(runner.pc(), 4U)
}

///|
test "alu immediate and register instructions cover logic compare and shifts" {
  let program = words_to_bytes([
    encode_i(-8, 0, 0x0U, 1, 0x13U),
    encode_i(4, 0, 0x0U, 2, 0x13U),
    encode_i(1, 2, 0x1U, 3, 0x13U),
    encode_i(1, 1, 0x5U, 4, 0x13U),
    encode_i(0x401, 1, 0x5U, 5, 0x13U),
    encode_i(0xff, 1, 0x4U, 6, 0x13U),
    encode_i(0xf0, 6, 0x6U, 7, 0x13U),
    encode_i(0xf0, 7, 0x7U, 8, 0x13U),
    encode_i(-7, 1, 0x2U, 9, 0x13U),
    encode_i(-7, 1, 0x3U, 10, 0x13U),
    encode_r(0x00U, 2, 1, 0x1U, 11, 0x33U),
    encode_r(0x00U, 2, 1, 0x2U, 12, 0x33U),
    encode_r(0x00U, 2, 1, 0x3U, 13, 0x33U),
    encode_r(0x00U, 2, 6, 0x4U, 14, 0x33U),
    encode_r(0x00U, 2, 11, 0x5U, 15, 0x33U),
    encode_r(0x20U, 2, 1, 0x5U, 16, 0x33U),
    encode_r(0x00U, 7, 6, 0x6U, 17, 0x33U),
    encode_r(0x00U, 7, 6, 0x7U, 18, 0x33U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(18) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 8U)
  assert_eq(runner.read_reg(4), 0x7ffffffcU)
  assert_eq(runner.read_reg(5), 0xfffffffcU)
  assert_eq(runner.read_reg(8), 0xf0U)
  assert_eq(runner.read_reg(9), 1U)
  assert_eq(runner.read_reg(10), 1U)
  assert_eq(runner.read_reg(11), 0xffffff80U)
  assert_eq(runner.read_reg(12), 1U)
  assert_eq(runner.read_reg(13), 0U)
  assert_eq(runner.read_reg(14), 0xffffff03U)
  assert_eq(runner.read_reg(15), 0x0ffffff8U)
  assert_eq(runner.read_reg(16), 0xffffffffU)
  assert_eq(runner.read_reg(17), 0xfffffff7U)
  assert_eq(runner.read_reg(18), 0xffffff07U)
}

///|
test "branch variants choose signed and unsigned comparisons correctly" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_b(8, 2, 1, 0x4U, 0x63U),
    encode_i(99, 0, 0x0U, 3, 0x13U),
    encode_b(8, 2, 1, 0x5U, 0x63U),
    encode_i(99, 0, 0x0U, 4, 0x13U),
    encode_b(8, 2, 1, 0x6U, 0x63U),
    encode_i(1, 0, 0x0U, 5, 0x13U),
    encode_b(8, 2, 1, 0x7U, 0x63U),
    encode_i(2, 0, 0x0U, 6, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 0U)
  assert_eq(runner.read_reg(4), 99U)
  assert_eq(runner.read_reg(5), 1U)
  assert_eq(runner.read_reg(6), 0U)
}

///|
test "byte and halfword loads and stores honor sign and zero extension" {
  let program = words_to_bytes([
    encode_i(0x80, 0, 0x0U, 1, 0x13U),
    encode_s(0, 1, 0, 0x0U, 0x23U),
    encode_i(0, 0, 0x0U, 2, 0x03U),
    encode_i(0, 0, 0x4U, 3, 0x03U),
    encode_u(0xffffa000U, 4, 0x37U),
    encode_i(0x678, 4, 0x6U, 4, 0x13U),
    encode_s(2, 4, 0, 0x1U, 0x23U),
    encode_i(2, 0, 0x1U, 5, 0x03U),
    encode_i(2, 0, 0x5U, 6, 0x03U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 0xffffff80U)
  assert_eq(runner.read_reg(3), 0x80U)
  assert_eq(runner.read_reg(5), 0xffffa678U)
  assert_eq(runner.read_reg(6), 0xa678U)
}

///|
test "bootstrap subset runs a small program" {
  let program = words_to_bytes([
    encode_u(0x12345000U, 6, 0x37U),
    encode_i(4, 0, 0x0U, 1, 0x13U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
    encode_r(0x00U, 2, 1, 0x0U, 3, 0x33U),
    encode_s(0, 3, 0, 0x2U, 0x23U),
    encode_i(0, 0, 0x2U, 4, 0x03U),
    encode_b(8, 4, 3, 0x0U, 0x63U),
    encode_i(99, 0, 0x0U, 5, 0x13U),
    encode_j(8, 0, 0x6fU),
    encode_i(77, 0, 0x0U, 7, 0x13U),
    encode_i(16, 0, 0x0U, 8, 0x13U),
    encode_i(32, 8, 0x0U, 8, 0x13U),
    encode_i(8, 8, 0x0U, 9, 0x67U),
    encode_i(111, 0, 0x0U, 10, 0x13U),
    encode_i(1, 0, 0x0U, 11, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(12) {
    Running => ()
    _ => fail("expected budgeted run to stay in running state")
  }
  assert_eq(runner.read_reg(3), 11U)
  assert_eq(runner.read_reg(4), 11U)
  assert_eq(runner.read_reg(5), 0U)
  assert_eq(runner.read_reg(6), 0x12345000U)
  assert_eq(runner.read_reg(7), 0U)
  assert_eq(runner.read_reg(9), 52U)
  assert_eq(runner.read_reg(10), 0U)
  assert_eq(runner.read_reg(11), 1U)
}

///|
test "unsupported instruction traps" {
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([0xffffffffU]), 0U)
  match runner.step() {
    Trap(_) => ()
    _ => fail("expected trap")
  }
}

///|
test "rv32 rejects rv64-only instructions as illegal" {
  let rv64_only_words = [
    encode_i(1, 0, 0x0U, 1, 0x1bU),
    encode_i(0, 0, 0x6U, 1, 0x03U),
    encode_s(0, 1, 0, 0x3U, 0x23U),
  ]
  for raw in rv64_only_words {
    let runner = make_runner(default_machine_config())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected rv64-only instruction to trap on rv32")
    }
  }
}

///|
test "m extension execute path covers multiply variants" {
  let program = words_to_bytes([
    encode_i(-2, 0, 0x0U, 1, 0x13U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
    encode_r(0x01U, 2, 1, 0x0U, 3, 0x33U),
    encode_u(0x80000000U, 4, 0x37U),
    encode_i(2, 0, 0x0U, 5, 0x13U),
    encode_r(0x01U, 5, 4, 0x1U, 6, 0x33U),
    encode_r(0x01U, 5, 4, 0x2U, 7, 0x33U),
    encode_r(0x01U, 5, 4, 0x3U, 8, 0x33U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 0xfffffff2U)
  assert_eq(runner.read_reg(6), 0xffffffffU)
  assert_eq(runner.read_reg(7), 0xffffffffU)
  assert_eq(runner.read_reg(8), 0x1U)
}

///|
test "m extension division and remainder edge cases match the spec" {
  let program = words_to_bytes([
    encode_i(-13, 0, 0x0U, 1, 0x13U),
    encode_i(5, 0, 0x0U, 2, 0x13U),
    encode_i(0, 0, 0x0U, 3, 0x13U),
    encode_r(0x01U, 2, 1, 0x4U, 4, 0x33U),
    encode_r(0x01U, 2, 1, 0x6U, 5, 0x33U),
    encode_r(0x01U, 3, 1, 0x4U, 6, 0x33U),
    encode_r(0x01U, 3, 1, 0x5U, 7, 0x33U),
    encode_r(0x01U, 3, 1, 0x6U, 8, 0x33U),
    encode_r(0x01U, 3, 1, 0x7U, 9, 0x33U),
    encode_u(0x80000000U, 10, 0x37U),
    encode_i(-1, 0, 0x0U, 11, 0x13U),
    encode_r(0x01U, 11, 10, 0x4U, 12, 0x33U),
    encode_r(0x01U, 11, 10, 0x6U, 13, 0x33U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(13) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(4), 0xfffffffeU)
  assert_eq(runner.read_reg(5), 0xfffffffdU)
  assert_eq(runner.read_reg(6), 0xffffffffU)
  assert_eq(runner.read_reg(7), 0xffffffffU)
  assert_eq(runner.read_reg(8), 0xfffffff3U)
  assert_eq(runner.read_reg(9), 0xfffffff3U)
  assert_eq(runner.read_reg(12), 0x80000000U)
  assert_eq(runner.read_reg(13), 0U)
}

///|
test "mixed i and m program runs naturally" {
  let program = words_to_bytes([
    encode_i(6, 0, 0x0U, 1, 0x13U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
    encode_r(0x01U, 2, 1, 0x0U, 3, 0x33U),
    encode_i(5, 0, 0x0U, 4, 0x13U),
    encode_r(0x01U, 4, 3, 0x4U, 5, 0x33U),
    encode_r(0x01U, 4, 3, 0x6U, 6, 0x33U),
    encode_s(0, 5, 0, 0x2U, 0x23U),
    encode_i(4, 0, 0x0U, 7, 0x13U),
    encode_s(4, 6, 0, 0x2U, 0x23U),
    encode_i(0, 0, 0x2U, 8, 0x03U),
    encode_i(4, 0, 0x2U, 9, 0x03U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(11) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(3), 42U)
  assert_eq(runner.read_reg(5), 8U)
  assert_eq(runner.read_reg(6), 2U)
  assert_eq(runner.read_reg(8), 8U)
  assert_eq(runner.read_reg(9), 2U)
}

///|
test "minimal env/p startup can reach a test body via mret" {
  let base = 0x80000000U
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(20, 5, 0x0U, 5, 0x13U),
    encode_csr(0x300, 0, 0x5U, 0),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_i(7, 0, 0x0U, 1, 0x13U),
  ])
  let runner = make_runner(official_riscv_tests_machine_config())
  runner.load_program(program, base)
  match runner.run(6) {
    Running => ()
    _ => fail("expected startup sequence to reach test body")
  }
  assert_eq(runner.read_reg(1), 7U)
  assert_eq(runner.pc(), base + 24U)
  assert_eq(runner.read_csr(0x341), base + 20U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user mode after mret")
  }
}

///|
test "user ecall traps to mtvec with mcause set" {
  let base = 0x80000000U
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(36, 5, 0x0U, 6, 0x13U),
    encode_csr(0x305, 6, 0x1U, 0),
    encode_i(28, 5, 0x0U, 5, 0x13U),
    encode_csr(0x300, 0, 0x5U, 0),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_fence(),
    encode_ecall(),
    encode_csr(0x342, 0, 0x2U, 7),
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
  let runner = make_runner(official_riscv_tests_machine_config())
  runner.load_program(program, base)
  match runner.run(11) {
    Running => ()
    _ => fail("expected ecall trap to be handled by mtvec")
  }
  assert_eq(runner.read_reg(7), 8U)
  assert_eq(runner.read_reg(8), 1U)
  assert_eq(runner.read_csr(0x342), 8U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine mode in trap handler")
  }
}

///|
test "reset invariants are explicit for modeled machine state" {
  let runner = make_runner(default_machine_config())
  assert_eq(runner.pc(), 0U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine mode after reset")
  }
  assert_eq(runner.read_csr(0x301), 0x40101104U)
  assert_eq(runner.read_csr(0xF14), 0U)
  assert_eq(runner.read_csr(0x300), 0U)
  assert_eq(runner.read_csr(0x304), 0U)
  assert_eq(runner.read_csr(0x344), 0U)
  assert_eq(runner.read_csr(0x305), 0U)
  assert_eq(runner.read_csr(0x341), 0U)
  assert_eq(runner.read_csr(0x342), 0U)
  assert_eq(runner.read_csr(0x343), 0U)
}

///|
test "rv64 supervisor fetch traps with instruction page fault when satp selects Sv39" {
  let program = words_to_bytes([
    encode_i(8, 0, 0x0U, 1, 0x13U),
    encode_i(60, 1, 0x1U, 1, 0x13U),
    encode_csr(0x180, 1, 0x1U, 0),
    encode_i(8, 0, 0x0U, 2, 0x13U),
    encode_i(8, 2, 0x1U, 2, 0x13U),
    encode_csr(0x300, 2, 0x1U, 0),
    encode_i(36, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_i(1, 0, 0x0U, 3, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(10) {
    Trap(info) => {
      match info.cause {
        InstructionPageFault => ()
        _ => fail("expected instruction page fault")
      }
      assert_eq(info.faulting_pc, 36U.to_uint64())
      assert_eq(info.trap_value, 36U.to_uint64())
    }
    _ => fail("expected supervisor fetch to fault under Sv39")
  }
  assert_eq(runner.read_csr(0x342), 12U)
  assert_eq(runner.read_csr(0x343), 36U)
}

///|
test "rv64 mprv makes machine load and store follow Sv39 using mpp privilege" {
  let program = words_to_bytes([
    encode_i(0x100, 0, 0x0U, 1, 0x13U),
    encode_i(8, 0, 0x0U, 2, 0x13U),
    encode_i(60, 2, 0x1U, 2, 0x13U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_csr(0x180, 2, 0x1U, 0),
    encode_i(1, 0, 0x0U, 3, 0x13U),
    encode_i(17, 3, 0x1U, 3, 0x13U),
    encode_i(1, 0, 0x0U, 4, 0x13U),
    encode_i(11, 4, 0x1U, 4, 0x13U),
    encode_r(0x00U, 4, 3, 0x6U, 3, 0x33U),
    encode_csr(0x300, 3, 0x1U, 0),
    encode_i(42, 0, 0x0U, 12, 0x13U),
    encode_i(0, 1, 0x2U, 10, 0x03U),
    encode_s(4, 12, 1, 0x2U, 0x23U),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.load_program(program, 0U)
  match runner.run(14) {
    Running => ()
    _ => fail("expected mprv-assisted memory accesses to run")
  }
  assert_eq(runner.read_reg(10), 0x12345678U)
  assert_eq(runner.load_u32_u64(0x4104U.to_uint64()), 42U.to_uint64())
}

///|
test "rv64 machine load remains physical when mprv is clear" {
  let program = words_to_bytes([
    encode_i(0x100, 0, 0x0U, 1, 0x13U),
    encode_i(8, 0, 0x0U, 2, 0x13U),
    encode_i(60, 2, 0x1U, 2, 0x13U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_csr(0x180, 2, 0x1U, 0),
    encode_i(0, 1, 0x2U, 10, 0x03U),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.load_program(program, 0U)
  match runner.run(6) {
    Running => ()
    _ => fail("expected machine load to stay physical without mprv")
  }
  assert_eq(runner.read_reg(10), 0xa5a5a5a5U)
}

///|
test "rv64 mprv does not affect machine-mode instruction fetch" {
  let program = words_to_bytes([
    encode_i(8, 0, 0x0U, 2, 0x13U),
    encode_i(60, 2, 0x1U, 2, 0x13U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_csr(0x180, 2, 0x1U, 0),
    encode_i(1, 0, 0x0U, 3, 0x13U),
    encode_i(17, 3, 0x1U, 3, 0x13U),
    encode_i(1, 0, 0x0U, 4, 0x13U),
    encode_i(11, 4, 0x1U, 4, 0x13U),
    encode_r(0x00U, 4, 3, 0x6U, 3, 0x33U),
    encode_csr(0x300, 3, 0x1U, 0),
    encode_i(99, 0, 0x0U, 7, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(11) {
    Running => ()
    _ => fail("expected machine fetch to stay physical with mprv")
  }
  assert_eq(runner.read_reg(7), 99U)
}

///|
test "trap entry from machine updates mstatus trap fields" {
  let program = words_to_bytes([
    encode_csr(0x300, 8, 0x5U, 0),
    encode_ecall(),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(2) {
    Trap(info) => {
      match info.cause {
        EnvironmentCallFromMMode => ()
        _ => fail("expected machine ecall trap")
      }
    }
    _ => fail("expected trap")
  }
  assert_eq(runner.read_csr(0x341), 4U)
  assert_eq(runner.read_csr(0x342), 11U)
  assert_eq(runner.read_csr(0x343), 0U)
  assert_eq(runner.read_csr(0x300), 0x1880U)
}

///|
test "trap entry from user updates mstatus trap fields" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(20, 5, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_csr(0x300, 8, 0x5U, 0),
    encode_mret(),
    encode_ecall(),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Trap(info) => {
      match info.cause {
        EnvironmentCallFromUMode => ()
        _ => fail("expected user ecall trap")
      }
    }
    _ => fail("expected trap")
  }
  assert_eq(runner.read_csr(0x341), 20U)
  assert_eq(runner.read_csr(0x342), 8U)
  assert_eq(runner.read_csr(0x343), 0U)
  assert_eq(runner.read_csr(0x300), 0U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine mode in trap entry")
  }
}

///|
test "mtvec direct target masks low bits and ignores mode dispatch" {
  let program = words_to_bytes([
    encode_csr(0x305, 0x15, 0x5U, 0),
    encode_ecall(),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(1, 0, 0x0U, 1, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  match runner.step() {
    Running => ()
    _ => fail("expected trap redirection to running state")
  }
  assert_eq(runner.pc(), 20U)
  match runner.step() {
    Running => ()
    _ => fail("expected handler instruction to run")
  }
  assert_eq(runner.read_reg(1), 1U)
}

///|
test "supervisor csr surface is writable and sstatus aliases the modeled mstatus subset" {
  let program = words_to_bytes([
    encode_i(0x122, 0, 0x0U, 1, 0x13U),
    encode_csr(0x100, 1, 0x1U, 0),
    encode_csr(0x105, 0x15, 0x5U, 0),
    encode_csr(0x140, 9, 0x5U, 0),
    encode_csr(0x141, 13, 0x5U, 0),
    encode_csr(0x142, 8, 0x5U, 0),
    encode_csr(0x143, 7, 0x5U, 0),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected supervisor csr setup to run")
  }
  assert_eq(runner.read_csr(0x100), 0x122U)
  assert_eq(runner.read_csr(0x300), 0x122U)
  assert_eq(runner.read_csr(0x105), 0x15U)
  assert_eq(runner.read_csr(0x140), 9U)
  assert_eq(runner.read_csr(0x141), 13U)
  assert_eq(runner.read_csr(0x142), 8U)
  assert_eq(runner.read_csr(0x143), 7U)
}

///|
test "sstatus exposes and writes SUM and MXR bits through the alias mask" {
  let program = words_to_bytes([
    encode_u(0x000C0000U, 1, 0x37U),
    encode_i(0x122, 1, 0x0U, 1, 0x13U),
    encode_csr(0x100, 1, 0x1U, 0),
    encode_csr(0x100, 0, 0x2U, 2),
    encode_csr(0x300, 0, 0x2U, 3),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected sstatus SUM/MXR aliasing program to run")
  }
  assert_eq(runner.read_reg(2), 0xC0122U)
  assert_eq(runner.read_reg(3), 0xC0122U)
  assert_eq(runner.read_csr(0x100), 0xC0122U)
  assert_eq(runner.read_csr(0x300), 0xC0122U)
}

///|
test "delegated user ecall traps to stvec with supervisor trap state" {
  let program = words_to_bytes([
    encode_i(33, 0, 0x0U, 6, 0x13U),
    encode_csr(0x105, 6, 0x1U, 0),
    encode_i(256, 0, 0x0U, 1, 0x13U),
    encode_csr(0x302, 1, 0x1U, 0),
    encode_i(28, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_ecall(),
    encode_csr(0x142, 0, 0x2U, 7),
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(10) {
    Running => ()
    _ => fail("expected delegated supervisor trap handler to run")
  }
  assert_eq(runner.read_reg(7), 8U)
  assert_eq(runner.read_reg(8), 1U)
  assert_eq(runner.read_csr(0x141), 28U)
  assert_eq(runner.read_csr(0x142), 8U)
  assert_eq(runner.read_csr(0x143), 0U)
  assert_eq(runner.read_csr(0x100), 0U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode in delegated trap handler")
  }
}

///|
test "stvec direct target masks low bits during delegated supervisor trap entry" {
  let program = words_to_bytes([
    encode_i(33, 0, 0x0U, 6, 0x13U),
    encode_csr(0x105, 6, 0x1U, 0),
    encode_i(256, 0, 0x0U, 1, 0x13U),
    encode_csr(0x302, 1, 0x1U, 0),
    encode_i(28, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_ecall(),
    encode_i(1, 0, 0x0U, 9, 0x13U),
    encode_i(2, 0, 0x0U, 10, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected delegated supervisor trap redirection to running state")
  }
  assert_eq(runner.pc(), 36U)
  assert_eq(runner.read_reg(9), 1U)
  assert_eq(runner.read_reg(10), 0U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode after delegated trap redirection")
  }
}

///|
test "sret restores user mode from delegated supervisor trap and resumes at sepc" {
  let program = words_to_bytes([
    encode_i(33, 0, 0x0U, 6, 0x13U),
    encode_csr(0x105, 6, 0x1U, 0),
    encode_i(256, 0, 0x0U, 1, 0x13U),
    encode_csr(0x302, 1, 0x1U, 0),
    encode_i(28, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_ecall(),
    encode_i(48, 0, 0x0U, 12, 0x13U),
    encode_csr(0x141, 12, 0x1U, 0),
    encode_csr(0x100, 0, 0x2U, 13),
    encode_sret(),
    encode_i(1, 0, 0x0U, 14, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(13) {
    Running => ()
    _ => fail("expected delegated trap handler to return with sret")
  }
  assert_eq(runner.read_reg(13), 0U)
  assert_eq(runner.read_reg(14), 1U)
  assert_eq(runner.read_csr(0x100), 0x20U)
  assert_eq(runner.read_csr(0x141), 48U)
  assert_eq(runner.pc(), 52U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user mode after sret from delegated user trap")
  }
}

///|
test "sret restores supervisor mode when sstatus.spp is set" {
  let program = words_to_bytes([
    encode_i(0x120, 0, 0x0U, 1, 0x13U),
    encode_csr(0x100, 1, 0x1U, 0),
    encode_i(52, 0, 0x0U, 2, 0x13U),
    encode_csr(0x141, 2, 0x1U, 0),
    encode_i(44, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00001000U, 3, 0x37U),
    encode_i(-1760, 3, 0x0U, 3, 0x13U),
    encode_csr(0x300, 3, 0x1U, 0),
    encode_mret(),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_sret(),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(1, 0, 0x0U, 15, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(12) {
    Running => ()
    _ => fail("expected sret supervisor-mode return path to run")
  }
  assert_eq(runner.read_reg(15), 1U)
  assert_eq(runner.read_csr(0x100), 0x22U)
  assert_eq(runner.read_csr(0x141), 52U)
  assert_eq(runner.pc(), 56U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode after sret with spp=1")
  }
}

///|
test "mret sets mie from mpie, sets mpie to 1, and clears mpp" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(28, 5, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00002000U, 1, 0x37U),
    encode_i(-2048, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_i(1, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 1U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine privilege restored from mpp")
  }
  assert_eq(runner.read_csr(0x300), 0x80U)
  assert_eq(runner.read_csr(0x341), 28U)
}

///|
test "mret restores user mode when mpp is user and promotes mie from mpie" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(24, 5, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_i(128, 0, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_i(1, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 1U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user privilege restored from mpp")
  }
  assert_eq(runner.read_csr(0x300), 0x88U)
}

///|
test "csr instruction families enforce the supported surface and no-write semantics" {
  let program = words_to_bytes([
    encode_i(5, 0, 0x0U, 1, 0x13U),
    encode_csr(0x305, 1, 0x1U, 2),
    encode_csr(0x305, 0, 0x2U, 3),
    encode_csr(0x305, 0, 0x3U, 4),
    encode_csr(0x305, 7, 0x5U, 5),
    encode_csr(0x305, 2, 0x6U, 6),
    encode_csr(0x305, 1, 0x7U, 7),
    encode_csr(0x301, 0, 0x2U, 8),
    encode_csr(0x301, 0, 0x3U, 9),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 0U)
  assert_eq(runner.read_reg(3), 5U)
  assert_eq(runner.read_reg(4), 5U)
  assert_eq(runner.read_reg(5), 5U)
  assert_eq(runner.read_reg(6), 7U)
  assert_eq(runner.read_reg(7), 7U)
  assert_eq(runner.read_reg(8), 0x40101104U)
  assert_eq(runner.read_reg(9), 0x40101104U)
  assert_eq(runner.read_csr(0x305), 6U)
}

///|
test "mip behaves as modeled writable machine-state storage without side effects" {
  let program = words_to_bytes([
    encode_i(10, 0, 0x0U, 1, 0x13U),
    encode_csr(0x344, 1, 0x1U, 2),
    encode_csr(0x344, 1, 0x2U, 3),
    encode_csr(0x344, 1, 0x3U, 4),
    encode_csr(0x344, 3, 0x6U, 5),
    encode_csr(0x344, 1, 0x7U, 6),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 0U)
  assert_eq(runner.read_reg(3), 10U)
  assert_eq(runner.read_reg(4), 10U)
  assert_eq(runner.read_reg(5), 0U)
  assert_eq(runner.read_reg(6), 3U)
  assert_eq(runner.read_csr(0x344), 2U)
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected privilege mode to remain machine")
  }
}

///|
test "csr contract distinguishes modeled, compatibility-only, and unsupported csrs" {
  let program = words_to_bytes([
    encode_i(5, 0, 0x0U, 1, 0x13U),
    encode_csr(0x344, 1, 0x1U, 2),
    encode_csr(0x302, 1, 0x1U, 3),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected modeled and compatibility-only writes to run")
  }
  assert_eq(runner.read_csr(0x344), 5U)
  assert_eq(runner.read_csr(0x302), 5U)
  let unsupported = encode_csr(0x340, 1, 0x1U, 0)
  let trap_runner = make_runner(default_machine_config())
  trap_runner.load_program(words_to_bytes([unsupported]), 0U)
  match trap_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, unsupported.to_uint64())
    }
    _ => fail("expected unsupported csr trap")
  }
}

///|
test "unsupported csr access traps as illegal instruction" {
  let raw = encode_csr(0x340, 0, 0x2U, 1)
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "writes to read-only csrs trap as illegal instruction" {
  let runner = make_runner(default_machine_config())
  let misa_raw = encode_csr(0x301, 1, 0x1U, 0)
  runner.load_program(words_to_bytes([misa_raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, misa_raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
  let mhartid_raw = encode_csr(0xF14, 1, 0x1U, 0)
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([mhartid_raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, mhartid_raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "fence.i is explicit and remains compatible with the current coherent fetch model" {
  let target = encode_i(7, 0, 0x0U, 5, 0x13U)
  let program = words_to_bytes([
    encode_i(28, 0, 0x0U, 1, 0x13U),
    encode_u(0x00700000U, 2, 0x37U),
    encode_i(0x293, 2, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x2U, 0x23U),
    encode_fence_i(),
    encode_j(8, 0, 0x6fU),
    encode_i(99, 0, 0x0U, 6, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(1, 0, 0x0U, 7, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(5), 7U)
  assert_eq(runner.read_reg(6), 0U)
  assert_eq(runner.read_reg(7), 1U)
  assert_eq(runner.load_u32(28U), target)
}

///|
test "sfence.vma decodes as explicit supervisor barrier and executes as no-op" {
  let program = words_to_bytes([
    encode_i(1, 0, 0x0U, 1, 0x13U),
    encode_sfence_vma(0, 0),
    encode_i(2, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected sfence.vma sequence to run")
  }
  assert_eq(runner.read_reg(1), 1U)
  assert_eq(runner.read_reg(2), 2U)
  assert_eq(runner.pc(), 12U)
}

///|
test "rv64 machine config resets widened state and misa" {
  let runner = make_runner(rv64_machine_config())
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine privilege at reset")
  }
  assert_eq(runner.pc_u64(), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(1), 0U.to_uint64())
  assert_eq(
    runner.read_csr_u64(0x301),
    (2U.to_uint64() << 62) | 0x101104U.to_uint64(),
  )
  assert_eq(runner.read_csr_u64(0xF14), 0U.to_uint64())
  let config = runner.config()
  assert_eq(config.uart0_base, 0U.to_uint64())
  assert_eq(config.clint_base, 0U.to_uint64())
  assert_eq(config.plic_base, 0U.to_uint64())
  assert_eq(config.dtb_addr, 0U.to_uint64())
}

///|
test "virt machine config exposes virt-like platform addresses" {
  let config = virt_machine_config()
  assert_eq(config.ram_base, 0x80000000U.to_uint64())
  assert_eq(config.entry_point, 0x80000000U.to_uint64())
  assert_eq(config.uart0_base, 0x10000000U.to_uint64())
  assert_eq(config.clint_base, 0x02000000U.to_uint64())
  assert_eq(config.plic_base, 0x0C000000U.to_uint64())
  assert_eq(config.dtb_addr, 0x87E00000U.to_uint64())
}

///|
test "rv64 loads and stores preserve sign extension and full-width round trips" {
  let program = words_to_bytes([
    encode_u(0x80000000U, 1, 0x37U),
    encode_i(0x80, 1, 0x0U, 1, 0x13U),
    encode_s(0, 1, 0, 0x2U, 0x23U),
    encode_i(0, 0, 0x2U, 2, 0x03U),
    encode_i(0, 0, 0x6U, 3, 0x03U),
    encode_u(0x12345000U, 4, 0x37U),
    encode_i(32, 4, 0x1U, 4, 0x13U),
    encode_u(0x6789a000U, 5, 0x37U),
    encode_r(0x00U, 5, 4, 0x0U, 6, 0x33U),
    encode_s(8, 6, 0, 0x3U, 0x23U),
    encode_i(8, 0, 0x3U, 7, 0x03U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(11) {
    Running => ()
    _ => fail("expected rv64 load/store program to run")
  }
  assert_eq(runner.read_reg_u64(2), test_sign_extend_word64(0x80000080U))
  assert_eq(runner.read_reg_u64(3), 0x80000080U.to_uint64())
  assert_eq(runner.read_reg_u64(7), test_join_u64(0x12345000U, 0x6789a000U))
}

///|
test "rv64 word operations keep 32-bit results sign-extended" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x1bU),
    encode_i(31, 1, 0x1U, 2, 0x1bU),
    encode_i(31, 2, 0x5U, 3, 0x1bU),
    encode_i(0x404, 1, 0x5U, 4, 0x1bU),
    encode_r(0x00U, 3, 1, 0x0U, 5, 0x3bU),
    encode_r(0x20U, 3, 1, 0x0U, 6, 0x3bU),
    encode_r(0x00U, 3, 1, 0x1U, 7, 0x3bU),
    encode_r(0x00U, 3, 2, 0x5U, 8, 0x3bU),
    encode_r(0x20U, 3, 2, 0x5U, 9, 0x3bU),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected rv64 word-op program to run")
  }
  assert_eq(runner.read_reg_u64(1), (-1L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(2), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(4), (-1L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(5), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(6), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(7), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(8), 0x40000000U.to_uint64())
  assert_eq(runner.read_reg_u64(9), test_sign_extend_word64(0xc0000000U))
}

///|
test "rv64m word instructions honor divide edge cases and sign extension" {
  let program = words_to_bytes([
    encode_i(-13, 0, 0x0U, 1, 0x1bU),
    encode_i(5, 0, 0x0U, 2, 0x1bU),
    encode_i(13, 0, 0x0U, 3, 0x1bU),
    encode_i(0, 0, 0x0U, 4, 0x1bU),
    encode_r(0x01U, 2, 1, 0x0U, 5, 0x3bU),
    encode_r(0x01U, 2, 1, 0x4U, 6, 0x3bU),
    encode_r(0x01U, 2, 1, 0x6U, 7, 0x3bU),
    encode_r(0x01U, 2, 3, 0x5U, 8, 0x3bU),
    encode_r(0x01U, 2, 3, 0x7U, 9, 0x3bU),
    encode_r(0x01U, 4, 1, 0x4U, 10, 0x3bU),
    encode_r(0x01U, 4, 1, 0x6U, 11, 0x3bU),
    encode_u(0x80000000U, 12, 0x37U),
    encode_i(-1, 0, 0x0U, 13, 0x1bU),
    encode_r(0x01U, 13, 12, 0x4U, 14, 0x3bU),
    encode_r(0x01U, 13, 12, 0x6U, 15, 0x3bU),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(15) {
    Running => ()
    _ => fail("expected rv64m word-op program to run")
  }
  assert_eq(runner.read_reg_u64(5), test_sign_extend_word64(0xffffffbfU))
  assert_eq(runner.read_reg_u64(6), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(7), test_sign_extend_word64(0xfffffffdU))
  assert_eq(runner.read_reg_u64(8), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 3U.to_uint64())
  assert_eq(runner.read_reg_u64(10), (-1L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(11), test_sign_extend_word64(0xfffffff3U))
  assert_eq(runner.read_reg_u64(14), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(15), 0U.to_uint64())
}

///|
test "rv64 widened state still supports trap entry and mret round trip" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(20, 5, 0x0U, 5, 0x13U),
    encode_csr(0x300, 0, 0x5U, 0),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_i(7, 0, 0x0U, 1, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Running => ()
    _ => fail("expected rv64 mret startup sequence to reach test body")
  }
  assert_eq(runner.read_reg_u64(1), 7U.to_uint64())
  assert_eq(runner.pc_u64(), 24U.to_uint64())
  assert_eq(runner.read_csr_u64(0x341), 20U.to_uint64())
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user mode after rv64 mret")
  }
}

///|
test "rv64 csr semantics carry forward writable and read-only behavior" {
  let program = words_to_bytes([
    encode_i(9, 0, 0x0U, 1, 0x13U),
    encode_csr(0x305, 1, 0x1U, 2),
    encode_csr(0x305, 0, 0x2U, 3),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected rv64 csr program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 9U.to_uint64())
  assert_eq(runner.read_csr_u64(0x305), 9U.to_uint64())

  let misa_raw = encode_csr(0x301, 1, 0x1U, 0)
  let trap_runner = make_runner(rv64_machine_config())
  trap_runner.load_program(words_to_bytes([misa_raw]), 0U)
  match trap_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, misa_raw.to_uint64())
    }
    _ => fail("expected read-only csr trap")
  }
}

///|
test "rv64 fence.i remains explicit under the current coherent fetch model" {
  let target = encode_i(7, 0, 0x0U, 5, 0x13U)
  let program = words_to_bytes([
    encode_i(28, 0, 0x0U, 1, 0x13U),
    encode_u(0x00700000U, 2, 0x37U),
    encode_i(0x293, 2, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x2U, 0x23U),
    encode_fence_i(),
    encode_j(8, 0, 0x6fU),
    encode_i(99, 0, 0x0U, 6, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(1, 0, 0x0U, 7, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected rv64 fence.i sequence to run")
  }
  assert_eq(runner.read_reg_u64(5), 7U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 1U.to_uint64())
  assert_eq(runner.load_u32_u64(28U.to_uint64()), target.to_uint64())
}

// ---------------------------------------------------------------------------
// MMIO physical access layer tests
// ---------------------------------------------------------------------------

///|
test "uart sb to tx fifo captures byte in uart_output" {
  // LUI x1, 0x10000 → x1 = 0x10000000 (uart base)
  // ADDI x2, x0, 72  → x2 = 'H'
  // SB x2, 0(x1)     → write THR: char captured in uart_output
  let program = words_to_bytes([
    encode_u(0x10000000U, 1, 0x37U),
    encode_i(72, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x0U, 0x23U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected running after uart sb write")
  }
  assert_eq(runner.uart_drain(), "H")
}

///|
test "uart lbu from lsr offset returns tx-ready status" {
  // LUI x1, 0x10000 → x1 = 0x10000000 (uart base)
  // LBU x3, 5(x1)   → read LSR: should return 0x60 (THRE+TEMT)
  let program = words_to_bytes([
    encode_u(0x10000000U, 1, 0x37U),
    encode_i(5, 1, 0x4U, 3, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after uart lsr read")
  }
  assert_eq(runner.read_reg_u64(3), 0x60U.to_uint64())
}

///|
test "clint mtime read/write via sd/ld 64-bit" {
  // mtime = clint_base + 0xBFF8 = 0x0200C000 - 8 = 0x0200BFF8
  // LUI x1, 0x200C → x1 = 0x0200C000
  // ADDI x1, x1, -8 → x1 = 0x0200BFF8
  // ADDI x2, x0, 66 → x2 = 0x42 (test value)
  // SD x2, 0(x1)    → write mtime
  // LD x4, 0(x1)    → read mtime back into x4
  let program = words_to_bytes([
    encode_u(0x0200C000U, 1, 0x37U),
    encode_i(-8, 1, 0x0U, 1, 0x13U),
    encode_i(66, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    encode_i(0, 1, 0x3U, 4, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected running after clint mtime write/read")
  }
  assert_eq(runner.clint_mtime(), 66U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 66U.to_uint64())
}

///|
test "clint mtimecmp write via sw (32-bit halves)" {
  // mtimecmp[0] lo = clint_base + 0x4000 = 0x02004000
  // LUI x1, 0x2004   → x1 = 0x02004000
  // LUI x2, 0x12345000; ADDI x2, x2, 0x678 → x2 = 0x12345678
  // SW x2, 0(x1)     → write lo word
  // ADDI x5, x0, 1   → x5 = 1
  // SW x5, 4(x1)     → write hi word at offset 4
  let program = words_to_bytes([
    encode_u(0x02004000U, 1, 0x37U),
    encode_u(0x12345000U, 2, 0x37U),
    encode_i(0x678, 2, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x2U, 0x23U),
    encode_i(1, 0, 0x0U, 5, 0x13U),
    encode_s(4, 5, 1, 0x2U, 0x23U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(6) {
    Running => ()
    _ => fail("expected running after mtimecmp writes")
  }
  let expected = (1U.to_uint64() << 32) | 0x12345678U.to_uint64()
  assert_eq(runner.clint_mtimecmp(), expected)
}

///|
test "non-device non-ram physical address faults with Trap" {
  // LW from 0x50000000 (not RAM, not UART, not CLINT) should raise a Trap.
  // LUI x1, 0x50000 → x1 = 0x50000000
  // LW x2, 0(x1)    → load access fault → Trap result (mtvec=0, not in RAM)
  let program = words_to_bytes([
    encode_u(0x50000000U, 1, 0x37U),
    encode_i(0, 1, 0x2U, 2, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected lui to run")
  }
  match runner.step() {
    Trap(_) => ()
    Running => fail("expected Trap for unmapped address, got Running")
  }
}
