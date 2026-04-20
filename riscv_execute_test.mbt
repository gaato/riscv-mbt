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
fn exec_test_f32_bits(value : Float) -> UInt {
  Float::reinterpret_as_uint(value)
}

///|
fn exec_test_f64_bits(value : Double) -> UInt64 {
  value.reinterpret_as_uint64()
}

///|
fn exec_test_nan_box_single(value : UInt) -> UInt64 {
  (0xffffffffU.to_uint64() << 32) | value.to_uint64()
}

///|
fn exec_test_f64_canonical_nan_bits() -> UInt64 {
  (0x7ffU.to_uint64() << 52) | (1U.to_uint64() << 51)
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
  assert_eq(runner.read_csr(0x301), 0x40141105U)
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
test "rv64f move path preserves raw single-precision bits" {
  let program = words_to_bytes([
    encode_u(0xdeadc000U, 1, 0x37U),
    encode_i(-0x111, 1, 0x0U, 1, 0x13U),
    encode_fmv_w_x(1, 2),
    encode_fmv_x_w(2, 3),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(program, 0U)
  for _ in 0..<4 {
    match runner.step() {
      Running => ()
      _ => fail("expected rv64f move path to stay running")
    }
  }
  assert_eq(runner.read_freg_u64(2), 0xdeadbeefU.to_uint64())
  assert_eq(runner.read_reg_u64(3), test_join_u64(0xffffffffU, 0xdeadbeefU))
}

///|
test "rv64f flw and fsw preserve raw payload bits" {
  let program = words_to_bytes([
    encode_flw(0x100, 0, 1),
    encode_fsw(0x104, 1, 0),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(words_to_bytes([0x7fc01234U]), 0x100U)
  runner.load_program(program, 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected flw to run")
  }
  assert_eq(runner.read_freg_u64(1), 0x7fc01234U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected fsw to run")
  }
  assert_eq(runner.load_u32(0x104U), 0x7fc01234U)
}

///|
test "rv64f basic scalar arithmetic executes with host ieee defaults" {
  let four = exec_test_f32_bits(4.0)
  let two = exec_test_f32_bits(2.0)
  let program = words_to_bytes([
    encode_flw(0x100, 0, 1),
    encode_flw(0x104, 0, 2),
    encode_fp_r(0x00U, 2, 1, 0x0U, 3),
    encode_fp_r(0x04U, 2, 1, 0x0U, 4),
    encode_fp_r(0x08U, 2, 1, 0x0U, 5),
    encode_fp_r(0x0cU, 2, 1, 0x0U, 6),
    encode_fsqrt_s(1, 0x0U, 7),
    encode_fp_r(0x14U, 2, 1, 0x0U, 8),
    encode_fp_r(0x14U, 2, 1, 0x1U, 9),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(words_to_bytes([four, two]), 0x100U)
  runner.load_program(program, 0U)
  for _ in 0..<9 {
    match runner.step() {
      Running => ()
      Trap(info) =>
        fail(
          "expected rv64f arithmetic path to stay running, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
        )
    }
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f32_bits(6.0).to_uint64())
  assert_eq(runner.read_freg_u64(4), exec_test_f32_bits(2.0).to_uint64())
  assert_eq(runner.read_freg_u64(5), exec_test_f32_bits(8.0).to_uint64())
  assert_eq(runner.read_freg_u64(6), exec_test_f32_bits(2.0).to_uint64())
  assert_eq(runner.read_freg_u64(7), exec_test_f32_bits(2.0).to_uint64())
  assert_eq(runner.read_freg_u64(8), two.to_uint64())
  assert_eq(runner.read_freg_u64(9), four.to_uint64())
}

///|
test "rv64f min and max handle signed zero and canonical nan fallback" {
  let neg_zero = exec_test_f32_bits(-0.0)
  let pos_zero = exec_test_f32_bits(0.0)
  let nan_bits = 0x7fc01234U
  let one = exec_test_f32_bits(1.0)
  let program = words_to_bytes([
    encode_flw(0x100, 0, 1),
    encode_flw(0x104, 0, 2),
    encode_fp_r(0x14U, 2, 1, 0x0U, 3),
    encode_fp_r(0x14U, 2, 1, 0x1U, 4),
    encode_flw(0x108, 0, 5),
    encode_flw(0x10c, 0, 6),
    encode_fp_r(0x14U, 6, 5, 0x0U, 7),
    encode_fp_r(0x14U, 6, 5, 0x1U, 8),
    encode_fp_r(0x14U, 5, 5, 0x0U, 9),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(words_to_bytes([neg_zero, pos_zero, nan_bits, one]), 0x100U)
  runner.load_program(program, 0U)
  for _ in 0..<9 {
    match runner.step() {
      Running => ()
      Trap(info) =>
        fail(
          "expected rv64f min/max path to stay running, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
        )
    }
  }
  assert_eq(runner.read_freg_u64(3), neg_zero.to_uint64())
  assert_eq(runner.read_freg_u64(4), pos_zero.to_uint64())
  assert_eq(runner.read_freg_u64(7), one.to_uint64())
  assert_eq(runner.read_freg_u64(8), one.to_uint64())
  assert_eq(runner.read_freg_u64(9), 0x7fc00000U.to_uint64())
}

///|
test "rv64f fcsr frm and fflags views share one visible register" {
  let csr_fflags = 0x001
  let csr_frm = 0x002
  let csr_fcsr = 0x003
  let program = words_to_bytes([
    encode_i(0x6d, 0, 0x0U, 1, 0x13U),
    encode_csr(csr_fcsr, 1, 0x1U, 0),
    encode_csr(csr_fflags, 0, 0x2U, 2),
    encode_csr(csr_frm, 0, 0x2U, 3),
    encode_i(0x02, 0, 0x0U, 4, 0x13U),
    encode_csr(csr_frm, 4, 0x1U, 0),
    encode_csr(csr_fcsr, 0, 0x2U, 5),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected fcsr view path to run")
  }
  assert_eq(runner.read_reg(2), 0x0dU)
  assert_eq(runner.read_reg(3), 0x03U)
  assert_eq(runner.read_reg(5), 0x4dU)
  assert_eq(runner.read_csr(csr_fcsr), 0x4dU)
  assert_eq(runner.read_csr(csr_frm), 0x02U)
  assert_eq(runner.read_csr(csr_fflags), 0x0dU)
}

///|
test "rv64f traps on unsupported dynamic rounding mode" {
  let two = exec_test_f32_bits(2.0)
  let program = words_to_bytes([
    encode_flw(0x100, 0, 2),
    encode_flw(0x104, 0, 3),
    encode_fp_r(0x00U, 3, 2, 0x1U, 4),
  ])
  let raw = encode_fp_r(0x00U, 3, 2, 0x1U, 4)
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(words_to_bytes([two, two]), 0x100U)
  runner.load_program(program, 0U)
  match runner.run(3) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected unsupported rounding mode to trap")
  }
}

///|
test "rv64 without f rejects scalar f instructions as illegal" {
  let fp_words = [
    encode_flw(0, 0, 1),
    encode_fp_r(0x00U, 2, 1, 0x0U, 3),
  ]
  for raw in fp_words {
    let runner = make_runner(rv64_machine_config())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected scalar f instruction to trap without F")
    }
  }
}

///|
test "rv64fd move path preserves raw double-precision bits" {
  let raw = exec_test_f64_bits(1.5)
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program_u64(exec_test_u64_to_le_bytes(raw), 0x100U.to_uint64())
  runner.load_program(words_to_bytes([
    encode_i(0x100, 0, 0x0U, 5, 0x13U),
    encode_i(0, 5, 0x3U, 1, 0x03U),
    encode_fmv_d_x(1, 3),
    encode_fmv_x_d(3, 4),
  ]), 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64fd move path to stay running")
  }
  assert_eq(runner.read_freg_u64(3), raw)
  assert_eq(runner.read_reg_u64(4), raw)
}

///|
test "rv64fd fld and fsd preserve raw payload bits" {
  let raw = exec_test_f64_canonical_nan_bits() | 0x1234U.to_uint64()
  let program = words_to_bytes([
    encode_fld(0x100, 0, 1),
    encode_fsd(0x108, 1, 0),
  ])
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program_u64(exec_test_u64_to_le_bytes(raw), 0x100U.to_uint64())
  runner.load_program(program, 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected fld to run")
  }
  assert_eq(runner.read_freg_u64(1), raw)
  match runner.step() {
    Running => ()
    _ => fail("expected fsd to run")
  }
  assert_eq(runner.bus.load_u64(0x108U.to_uint64()), raw)
}

///|
test "rv64fd basic scalar arithmetic executes with host ieee defaults" {
  let four = exec_test_f64_bits(4.0)
  let two = exec_test_f64_bits(2.0)
  let program = words_to_bytes([
    encode_fld(0x100, 0, 1),
    encode_fld(0x108, 0, 2),
    encode_fp_r(0x01U, 2, 1, 0x0U, 3),
    encode_fp_r(0x05U, 2, 1, 0x0U, 4),
    encode_fp_r(0x09U, 2, 1, 0x0U, 5),
    encode_fp_r(0x0dU, 2, 1, 0x0U, 6),
    encode_fsqrt_d(1, 0x0U, 7),
    encode_fp_r(0x15U, 2, 1, 0x0U, 8),
    encode_fp_r(0x15U, 2, 1, 0x1U, 9),
  ])
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program_u64(exec_test_u64_to_le_bytes(four), 0x100U.to_uint64())
  runner.load_program_u64(exec_test_u64_to_le_bytes(two), 0x108U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    Trap(info) =>
      fail(
        "expected rv64fd arithmetic path to stay running, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(6.0))
  assert_eq(runner.read_freg_u64(4), exec_test_f64_bits(2.0))
  assert_eq(runner.read_freg_u64(5), exec_test_f64_bits(8.0))
  assert_eq(runner.read_freg_u64(6), exec_test_f64_bits(2.0))
  assert_eq(runner.read_freg_u64(7), exec_test_f64_bits(2.0))
  assert_eq(runner.read_freg_u64(8), two)
  assert_eq(runner.read_freg_u64(9), four)
}

///|
test "rv64fd f and d conversion paths preserve expected values" {
  let single = exec_test_f32_bits(1.5)
  let double = exec_test_f64_bits(2.25)
  let program = words_to_bytes([
    encode_flw(0x100, 0, 1),
    encode_fld(0x108, 0, 2),
    encode_fcvt_d_s(1, 0x0U, 3),
    encode_fcvt_s_d(2, 0x0U, 4),
  ])
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([single]), 0x100U)
  runner.load_program_u64(exec_test_u64_to_le_bytes(double), 0x108U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64fd convert path to run")
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(1.5))
  assert_eq(
    runner.read_freg_u64(4),
    exec_test_nan_box_single(exec_test_f32_bits(Float::from_double(2.25))),
  )
}

///|
test "rv64fd flw boxes single values and arithmetic treats unboxed input as canonical nan" {
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([exec_test_f32_bits(1.0)]), 0x100U)
  runner.load_program(words_to_bytes([
    encode_flw(0x100, 0, 1),
    encode_fp_r(0x00U, 2, 1, 0x0U, 3),
  ]), 0U)
  runner.cpu.write_freg(2, exec_test_f32_bits(1.0).to_uint64())
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail("expected flw to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}")
  }
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail("expected fadd.s to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}")
  }
  assert_eq(
    runner.read_freg_u64(1),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(
    runner.read_freg_u64(3),
    exec_test_nan_box_single(0x7fc00000U),
  )
}

///|
test "rv64f without d rejects scalar d instructions as illegal" {
  let d_words = [
    encode_fld(0, 0, 1),
    encode_fp_r(0x01U, 2, 1, 0x0U, 3),
    encode_fcvt_s_d(1, 0x0U, 2),
  ]
  for raw in d_words {
    let runner = make_runner(rv64f_machine_config())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected scalar d instruction to trap without D")
    }
  }
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
  assert_eq(runner.read_reg(8), 0x40141105U)
  assert_eq(runner.read_reg(9), 0x40141105U)
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
  let unsupported = encode_csr(0x7A0, 1, 0x1U, 0)
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
  let raw = encode_csr(0x7A0, 0, 0x2U, 1)
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
    (2U.to_uint64() << 62) | 0x141105U.to_uint64(),
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
test "uart input sets data-ready bit and rbr consumes the queued byte" {
  // LUI x1, 0x10000 → x1 = 0x10000000 (uart base)
  // LBU x2, 5(x1)   → read LSR with pending RX data: bit 0 should be set
  // LBU x3, 0(x1)   → dequeue one byte from RBR
  // LBU x4, 5(x1)   → read LSR again: only TX-ready bits should remain
  let program = words_to_bytes([
    encode_u(0x10000000U, 1, 0x37U),
    encode_i(5, 1, 0x4U, 2, 0x03U),
    encode_i(0, 1, 0x4U, 3, 0x03U),
    encode_i(5, 1, 0x4U, 4, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.uart_push_input("A")
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(4) {
    Running => ()
    _ => fail("expected running after uart receive sequence")
  }
  assert_eq(runner.read_reg_u64(2), 0x61U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 65U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0x60U.to_uint64())
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
  // After 5 steps, update_timer incremented mtime once on the LD step
  // (step 5), so the value read from mtime is 66 + 1 = 67.
  assert_eq(runner.clint_mtime(), 67U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 67U.to_uint64())
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

///|
test "mtime auto-increments each step" {
  // Run 10 NOP instructions (ADDI x0, x0, 0) and verify mtime == 10.
  let nop = encode_i(0, 0, 0x0U, 0, 0x13U)
  let program = words_to_bytes([nop, nop, nop, nop, nop, nop, nop, nop, nop, nop])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(10) {
    Running => ()
    _ => fail("expected running after 10 NOPs")
  }
  assert_eq(runner.clint_mtime(), 10U.to_uint64())
}

///|
test "MIP.MTIP set when mtime >= mtimecmp" {
  // Default mtimecmp = MAX, so MTIP is never set until we lower mtimecmp.
  // Write mtimecmp = 3 via SD. update_timer runs BEFORE each instruction,
  // so the new mtimecmp takes effect on the NEXT step after SD.
  // mtimecmp[0] = clint_base + 0x4000 = 0x02004000
  // Step timeline (update_timer then instruction):
  //   1. tick mtime 0→1, 1<MAX → MTIP clear;  LUI x1, 0x2004
  //   2. tick mtime 1→2, 2<MAX → MTIP clear;  ADDI x2, x0, 3
  //   3. tick mtime 2→3, 3<MAX → MTIP clear;  SD x2,0(x1) → mtimecmp=3
  //   4. tick mtime 3→4, 4>=3  → MTIP SET;    NOP
  let program = words_to_bytes([
    encode_u(0x02004000U, 1, 0x37U),
    encode_i(3, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  // After 3 steps: mtime=3, mtimecmp just set to 3, but MTIP was evaluated
  // with old mtimecmp(MAX) so still clear.
  match runner.run(3) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.clint_mtime(), 3U.to_uint64())
  assert_eq(runner.clint_mtimecmp(), 3U.to_uint64())
  let mip_after_3 = runner.cpu.read_csr(0x344)
  assert_eq(mip_after_3 & 0x80U.to_uint64(), 0U.to_uint64())
  // Step 4: update_timer sees mtime=4 >= mtimecmp=3 → MTIP set
  match runner.step() {
    Running => ()
    _ => fail("expected running after NOP")
  }
  let mip_after_4 = runner.cpu.read_csr(0x344)
  assert_eq(mip_after_4 & 0x80U.to_uint64(), 0x80U.to_uint64())
}

///|
test "MIP.MTIP cleared when mtimecmp raised above mtime" {
  // Set mtimecmp=2 so MTIP fires, then raise mtimecmp=100 so MTIP clears.
  // update_timer runs BEFORE each instruction, so mtimecmp changes take
  // effect on the next step.
  // Step timeline:
  //   1. tick 0→1, 1<MAX  → clear;  LUI x1, 0x2004
  //   2. tick 1→2, 2<MAX  → clear;  ADDI x2, x0, 2
  //   3. tick 2→3, 3<MAX  → clear;  SD x2,0(x1) → mtimecmp=2
  //   4. tick 3→4, 4>=2   → SET;    ADDI x2, x0, 100
  //   5. tick 4→5, 5>=2   → SET;    SD x2,0(x1) → mtimecmp=100
  //   6. tick 5→6, 6<100  → CLEAR;  NOP
  let nop = encode_i(0, 0, 0x0U, 0, 0x13U)
  let program = words_to_bytes([
    encode_u(0x02004000U, 1, 0x37U),
    encode_i(2, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    encode_i(100, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    nop,
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  // After 4 steps: mtimecmp=2, mtime=4, MTIP set (4>=2)
  match runner.run(4) {
    Running => ()
    _ => fail("expected running")
  }
  let mip4 = runner.cpu.read_csr(0x344)
  assert_eq(mip4 & 0x80U.to_uint64(), 0x80U.to_uint64())
  // After 2 more steps (SD mtimecmp=100, then NOP):
  // Step 5 still has MTIP set (5>=2), then SD writes mtimecmp=100
  // Step 6: update_timer sees 6<100 → MTIP cleared
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after mtimecmp update")
  }
  assert_eq(runner.clint_mtime(), 6U.to_uint64())
  assert_eq(runner.clint_mtimecmp(), 100U.to_uint64())
  let mip6 = runner.cpu.read_csr(0x344)
  assert_eq(mip6 & 0x80U.to_uint64(), 0U.to_uint64())
}

///|
test "SIE is masked view of MIE (bits 1,5,9)" {
  // Write 0xFFFF to MIE directly, then read SIE — should see only bits 1,5,9.
  // 1. ADDI x1, x0, -1   → x1 = 0xFFFF...FFFF
  // 2. CSRRW x0, MIE, x1 → MIE = 0xFFFF...FFFF
  // 3. CSRRS x2, SIE, x0 → x2 = MIE & 0x222 (read SIE, no write since rs1=x0)
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(0x304, 1, 0x1U, 0),
    encode_csr(0x104, 0, 0x2U, 2),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected running")
  }
  // SIE should show only bits 1, 5, 9 = 0x222
  assert_eq(runner.read_reg_u64(2), 0x222U.to_uint64())
  // MIE should have all bits set
  let mie = runner.cpu.read_csr(0x304)
  assert_eq(mie & 0xFFFU.to_uint64(), 0xFFFU.to_uint64())
}

///|
test "CSRRW to SIE only affects bits 1,5,9 of MIE" {
  // Pre-set MIE to 0xFFF (all low 12 bits), then CSRRW SIE with 0.
  // Only bits 1,5,9 should be cleared; other MIE bits preserved.
  // 1. ADDI x1, x0, -1     → x1 = all 1s
  // 2. CSRRW x0, MIE, x1   → MIE = all 1s
  // 3. CSRRW x3, SIE, x0   → write 0 to SIE (clears bits 1,5,9), x3 = old SIE
  // 4. CSRRS x4, MIE, x0   → x4 = current MIE (read MIE)
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(0x304, 1, 0x1U, 0),
    encode_csr(0x104, 0, 0x1U, 3),
    encode_csr(0x304, 0, 0x2U, 4),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(4) {
    Running => ()
    _ => fail("expected running")
  }
  // x3 = old SIE = 0x222
  assert_eq(runner.read_reg_u64(3), 0x222U.to_uint64())
  // MIE should have bits 1,5,9 cleared, rest intact
  // 0xFFF & ~0x222 = 0xDDD
  let mie = runner.cpu.read_csr(0x304)
  assert_eq(mie & 0xFFFU.to_uint64(), 0xDDDU.to_uint64())
}

///|
test "SIP is masked view of MIP; write does not affect MTIP" {
  // Set MIP.MTIP (bit 7) via update_timer (mtime >= mtimecmp with mtimecmp=1).
  // Then CSRRS SIP with SSIP (bit 1). Verify MTIP still set but not visible via SIP.
  // 1. LUI x1, 0x2004       → x1 = 0x02004000 (mtimecmp addr)
  // 2. ADDI x2, x0, 1       → x2 = 1
  // 3. SD x2, 0(x1)         → mtimecmp = 1
  // 4. NOP                   → mtime=4 >= 1, MTIP set
  // 5. CSRRSI x3, SIP, 0x2  → read SIP into x3 (SSIP=bit1 via uimm=2), set SSIP
  // 6. CSRRS x4, SIP, x0    → read SIP into x4
  let nop = encode_i(0, 0, 0x0U, 0, 0x13U)
  let program = words_to_bytes([
    encode_u(0x02004000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    nop,
    encode_csr(0x144, 0x2, 0x6U, 3),
    encode_csr(0x144, 0, 0x2U, 4),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(6) {
    Running => ()
    _ => fail("expected running")
  }
  // MIP should have MTIP (bit 7) set by update_timer
  let mip = runner.cpu.read_csr(0x344)
  assert_eq(mip & 0x80U.to_uint64(), 0x80U.to_uint64())
  // MIP should also have SSIP (bit 1) set from CSRRSI
  assert_eq(mip & 0x02U.to_uint64(), 0x02U.to_uint64())
  // SIP read (x4) should show SSIP (bit 1) only, not MTIP (bit 7)
  // STIP (bit 5) is also not set, SEIP (bit 9) not set
  assert_eq(runner.read_reg_u64(4), 0x02U.to_uint64())
}

///|
test "PLIC priority write/read via sw/lw" {
  // PLIC base = 0x0C000000. Priority register for source 1 is at offset 4.
  // LUI x1, 0x0C000 → x1 = 0x0C000000
  // ADDI x2, x0, 7  → x2 = 7 (priority value)
  // SW x2, 4(x1)    → write priority[1] = 7
  // LW x3, 4(x1)    → read priority[1] into x3
  let program = words_to_bytes([
    encode_u(0x0C000000U, 1, 0x37U),
    encode_i(7, 0, 0x0U, 2, 0x13U),
    encode_s(4, 2, 1, 0x2U, 0x23U),
    encode_i(4, 1, 0x2U, 3, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(4) {
    Running => ()
    _ => fail("expected running after PLIC write/read")
  }
  assert_eq(runner.read_reg_u64(3), 7U.to_uint64())
}

///|
test "PLIC claim returns 0 (no pending interrupts)" {
  // Claim register for context 0 = PLIC base + 0x200004 = 0x0C200004
  // LUI x1, 0x0C200 → x1 = 0x0C200000
  // LW x2, 4(x1)    → read claim[ctx0] into x2 (should be 0)
  let program = words_to_bytes([
    encode_u(0x0C200000U, 1, 0x37U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after PLIC claim read")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
}

///|
test "load_dtb places bytes at dtb_addr and setup_boot_abi sets a0/a1" {
  let runner = make_runner(virt_machine_config())
  // Small fake DTB: magic 0xD00DFEED in big-endian at offset 0
  let dtb = Bytes::from_array([0xD0U.to_byte(), 0x0DU.to_byte(), 0xFEU.to_byte(), 0xEDU.to_byte()])
  runner.load_dtb(dtb)
  runner.setup_boot_abi()
  // a0 = hart_id = 0
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  // a1 = dtb_addr = 0x87E00000
  assert_eq(runner.read_reg_u64(11), 0x87E00000U.to_uint64())
  // Read first 4 bytes from dtb_addr in memory
  let b0 = runner.bus.load_u8(0x87E00000U.to_uint64())
  let b1 = runner.bus.load_u8(0x87E00001U.to_uint64())
  let b2 = runner.bus.load_u8(0x87E00002U.to_uint64())
  let b3 = runner.bus.load_u8(0x87E00003U.to_uint64())
  assert_eq(b0, 0xD0U.to_uint64())
  assert_eq(b1, 0x0DU.to_uint64())
  assert_eq(b2, 0xFEU.to_uint64())
  assert_eq(b3, 0xEDU.to_uint64())
}

///|
test "WFI advances PC without side effects" {
  let runner = make_runner(virt_machine_config())
  let pc = runner.cpu.pc
  // WFI encoding: 0x10500073
  runner.bus.store_u32(pc, 0x10500073U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.cpu.pc, pc + 4U.to_uint64())
}

///|
fn encode_amo(funct5 : UInt, rs2 : Int, rs1 : Int, funct3 : UInt, rd : Int) -> UInt {
  encode_r(funct5 << 2, rs2, rs1, funct3, rd, 0x2fU)
}

///|
test "AMOSWAP.W loads old value into rd and stores rs2 at address" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  // Store initial value 42 at addr
  runner.bus.store_u32(addr, 42U.to_uint64())
  // x1 = addr, x2 = 99 (new value)
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 99U.to_uint64())
  // amoswap.w x3, x2, (x1): funct5=0x01, rs2=2, rs1=1, funct3=0x2 (W), rd=3
  let inst = encode_amo(0x01U, 2, 1, 0x2U, 3)
  runner.bus.store_u32(runner.cpu.pc, inst.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  // rd=x3 should have old value 42
  assert_eq(runner.read_reg_u64(3), 42U.to_uint64())
  // Memory at addr should have new value 99
  assert_eq(runner.bus.load_u32(addr), 99U.to_uint64())
}

///|
test "AMOADD.D loads old value and stores sum" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  // Store initial value 100 at addr (8-byte aligned)
  runner.bus.store_u64(addr, 100U.to_uint64())
  // x1 = addr, x2 = 50
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 50U.to_uint64())
  // amoadd.d x3, x2, (x1): funct5=0x00, rs2=2, rs1=1, funct3=0x3 (D), rd=3
  let inst = encode_amo(0x00U, 2, 1, 0x3U, 3)
  runner.bus.store_u32(runner.cpu.pc, inst.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(3), 100U.to_uint64())
  assert_eq(runner.bus.load_u64(addr), 150U.to_uint64())
}

///|
test "LR.W/SC.W pair succeeds on single hart" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 77U.to_uint64())
  runner.cpu.write_reg(1, addr)
  // LR.W x3, (x1): funct5=0x02, rs2=0, rs1=1, funct3=0x2, rd=3
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  // SC.W x4, x5, (x1): funct5=0x03, rs2=5, rs1=1, funct3=0x2, rd=4
  runner.bus.store_u32(pc0 + 4U.to_uint64(), encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64())
  runner.cpu.write_reg(5, 88U.to_uint64())
  // Step 1: LR.W
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(3), 77U.to_uint64())
  // Step 2: SC.W
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64()) // success
  assert_eq(runner.bus.load_u32(addr), 88U.to_uint64())
}

///|
fn write_u64_le(runner : Runner, addr : UInt64, value : UInt64) -> Unit {
  runner.bus.store_u64(addr, value)
}

///|
async test "OpenSBI fw_dynamic smoke: boots and produces UART output" {
  // Load OpenSBI fw_dynamic binary
  let fw_bytes = try {
    @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary()
  } catch {
    _ => {
      // Skip if binary not available
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load DTB — use our generated minimal DTB, or fall back to virt.dtb
  let dtb_bytes = try {
    @fs.read_file("_build/minimal.dtb").binary()
  } catch {
    _ =>
      try {
        @fs.read_file("_build/virt.dtb").binary()
      } catch {
        _ => {
          println("SKIP: no DTB found (run 'make minimal-dtb' or 'make virt-dtb')")
          return
        }
      }
  }
  let runner = make_runner(virt_machine_config())
  // Load OpenSBI at 0x80000000
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  // Load DTB at dtb_addr
  runner.load_dtb(dtb_bytes)
  // Place infinite loop (j .) at next_addr = 0x80200000
  runner.bus.store_u32(0x80200000U.to_uint64(), 0x0000006fU.to_uint64())
  // Build fw_dynamic_info struct at 0x80100000
  let info_addr = 0x80100000U.to_uint64()
  write_u64_le(runner, info_addr, 0x4942534fU.to_uint64()) // magic = "OSBI"
  write_u64_le(runner, info_addr + 8U.to_uint64(), 2U.to_uint64()) // version = 2
  write_u64_le(runner, info_addr + 16U.to_uint64(), 0x80200000U.to_uint64()) // next_addr
  write_u64_le(runner, info_addr + 24U.to_uint64(), 1U.to_uint64()) // next_mode = S
  write_u64_le(runner, info_addr + 32U.to_uint64(), 0U.to_uint64()) // options = 0
  write_u64_le(
    runner,
    info_addr + 40U.to_uint64(),
    0xffffffffU.to_uint64() | (0xffffffffU.to_uint64() << 32),
  ) // boot_hart = -1
  // Set boot registers: a0 = hart_id, a1 = dtb_addr, a2 = fw_dynamic_info
  runner.setup_boot_abi()
  runner.cpu.write_reg(12, info_addr) // a2 = &fw_dynamic_info
  // Run for up to 10 million steps
  let max_steps = 10000000
  let mut steps = 0
  let mut trapped = false
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        // Check if we've reached the infinite loop at next_addr
        if runner.cpu.pc == 0x80200000U.to_uint64() {
          break
        }
      }
      Trap(info) => {
        println(
          "Trap at step \{steps}: cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tval=\{info.trap_value.to_string()}",
        )
        trapped = true
        break
      }
    }
  }
  let output = runner.uart_drain()
  println("OpenSBI UART output (\{output.length()} chars, \{steps} steps):")
  println(output)
  // Require OpenSBI banner in UART output
  if !output.contains("OpenSBI") {
    fail(
      "OpenSBI should print its banner (trapped=\{trapped}, steps=\{steps})",
    )
  }
}

///|
async test "Task 0015: S-mode entry stub via OpenSBI handoff" {
  // Load OpenSBI fw_dynamic binary
  let fw_bytes = try {
    @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary()
  } catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load S-mode entry stub
  let stub_bytes = try {
    @fs.read_file("_build/smode-entry.bin").binary()
  } catch {
    _ => {
      println("SKIP: smode-entry.bin not found (run scripts/build-smode-entry.sh)")
      return
    }
  }
  // Load DTB
  let dtb_bytes = try {
    @fs.read_file("_build/minimal.dtb").binary()
  } catch {
    _ =>
      try {
        @fs.read_file("_build/virt.dtb").binary()
      } catch {
        _ => {
          println("SKIP: no DTB found (run 'make minimal-dtb' or 'make virt-dtb')")
          return
        }
      }
  }
  let runner = make_runner(virt_machine_config())
  // Load OpenSBI at 0x80000000 (also sets PC = 0x80000000)
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  // Load S-mode stub at 0x80200000 — use write_bytes to avoid overwriting PC
  runner.bus.write_bytes(0x80200000U.to_uint64(), stub_bytes)
  // Load DTB at dtb_addr
  runner.load_dtb(dtb_bytes)
  // Build fw_dynamic_info struct at 0x80100000
  let info_addr = 0x80100000U.to_uint64()
  write_u64_le(runner, info_addr, 0x4942534fU.to_uint64()) // magic = "OSBI"
  write_u64_le(runner, info_addr + 8U.to_uint64(), 2U.to_uint64()) // version = 2
  write_u64_le(runner, info_addr + 16U.to_uint64(), 0x80200000U.to_uint64()) // next_addr
  write_u64_le(runner, info_addr + 24U.to_uint64(), 1U.to_uint64()) // next_mode = S
  write_u64_le(runner, info_addr + 32U.to_uint64(), 0U.to_uint64()) // options = 0
  write_u64_le(
    runner,
    info_addr + 40U.to_uint64(),
    0xffffffffU.to_uint64() | (0xffffffffU.to_uint64() << 32),
  ) // boot_hart = -1
  // Set boot registers: a0 = hart_id, a1 = dtb_addr, a2 = fw_dynamic_info
  runner.setup_boot_abi()
  runner.cpu.write_reg(12, info_addr) // a2 = &fw_dynamic_info
  // Run until stub spin loop (0x80200020) or trap or timeout
  let max_steps = 15000000
  let mut steps = 0
  let mut trapped = false
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        // 0x80200020 is the infinite spin at end of stub (banner already printed)
        if runner.cpu.pc == 0x80200020U.to_uint64() {
          break
        }
      }
      Trap(info) => {
        println(
          "Trap at step \{steps}: cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tval=\{info.trap_value.to_string()}",
        )
        trapped = true
        break
      }
    }
  }
  let output = runner.uart_drain()
  println(
    "Task 0015 UART output (\{output.length()} chars, \{steps} steps):",
  )
  println(output)
  // Require OpenSBI banner
  if !output.contains("OpenSBI") {
    fail(
      "OpenSBI should print its banner (trapped=\{trapped}, steps=\{steps})",
    )
  }
  // Require S-mode entry confirmation from stub
  if !output.contains("Linux ABI: S-mode entry OK") {
    fail(
      "S-mode stub should confirm entry (trapped=\{trapped}, steps=\{steps})",
    )
  }
}

///|
async test "Task 0015: Linux kernel boot via OpenSBI" {
  // Load OpenSBI fw_dynamic binary
  let fw_bytes = try {
    @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary()
  } catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load Linux kernel Image
  let kernel_bytes = try {
    @fs.read_file("_build/linux-kernel-riscv64").binary()
  } catch {
    _ => {
      println("SKIP: _build/linux-kernel-riscv64 not found (copy Debian riscv64 vmlinux)")
      return
    }
  }
  // Load DTB
  let dtb_bytes = try {
    @fs.read_file("_build/minimal.dtb").binary()
  } catch {
    _ =>
      try {
        @fs.read_file("_build/virt.dtb").binary()
      } catch {
        _ => {
          println("SKIP: no DTB found")
          return
        }
      }
  }
  let runner = make_runner(virt_machine_config())
  // Load OpenSBI at 0x80000000
  runner.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  // Load Linux kernel at 0x80200000 (text_offset from RAM base = 2MB)
  runner.bus.write_bytes(0x80200000U.to_uint64(), kernel_bytes)
  // Load DTB
  runner.load_dtb(dtb_bytes)
  // fw_dynamic_info at 0x80100000: next_addr = Linux kernel entry (0x80200000)
  let info_addr = 0x80100000U.to_uint64()
  write_u64_le(runner, info_addr, 0x4942534fU.to_uint64()) // magic
  write_u64_le(runner, info_addr + 8U.to_uint64(), 2U.to_uint64()) // version
  write_u64_le(runner, info_addr + 16U.to_uint64(), 0x80200000U.to_uint64()) // next_addr = kernel
  write_u64_le(runner, info_addr + 24U.to_uint64(), 1U.to_uint64()) // next_mode = S
  write_u64_le(runner, info_addr + 32U.to_uint64(), 0U.to_uint64()) // options
  write_u64_le(
    runner,
    info_addr + 40U.to_uint64(),
    0xffffffffU.to_uint64() | (0xffffffffU.to_uint64() << 32),
  ) // boot_hart = -1
  runner.setup_boot_abi()
  runner.cpu.write_reg(12, info_addr) // a2 = &fw_dynamic_info
  // Run: generous limit to allow OpenSBI + early kernel init
  let max_steps = 200000000 // 200M steps
  let mut steps = 0
  let mut trapped = false
  let mut trap_pc = 0U.to_uint64()
  let mut trap_cause = ""
  let mut all_output = ""
  while steps < max_steps {
    match runner.step() {
      Running => {
        steps = steps + 1
        // Drain and accumulate UART output periodically
        if steps % 1000000 == 0 {
          let partial = runner.uart_drain()
          if partial.length() > 0 {
            all_output = all_output + partial
            if all_output.contains("Linux version") {
              break
            }
          }
        }
      }
      Trap(info) => {
        trap_pc = info.faulting_pc
        trap_cause = trap_cause_name(info.cause)
        trapped = true
        break
      }
    }
  }
  // Drain any remaining output
  let tail = runner.uart_drain()
  if tail.length() > 0 {
    all_output = all_output + tail
  }
  println(
    "Task 0015 Linux boot: \{all_output.length()} chars total, \{steps} steps",
  )
  if trapped {
    println("Trapped: cause=\{trap_cause} pc=\{trap_pc}")
  }
  // OpenSBI must boot
  if !all_output.contains("OpenSBI") {
    fail("OpenSBI should print its banner (trapped=\{trapped}, steps=\{steps})")
  }
  // Kernel must produce 'Linux version' output
  if !all_output.contains("Linux version") {
    fail(
      "Kernel has not produced 'Linux version' output (steps=\{steps}, trapped=\{trapped})",
    )
  }
}

///|
// ---------------------------------------------------------------------------
// Task 0016: SMP boot — two harts, secondary hart wakes via CLINT MSIP IPI.
// ---------------------------------------------------------------------------
async test "Task 0016: SMP 2-hart boot via OpenSBI" {
  // Load OpenSBI fw_dynamic binary
  let fw_bytes = try {
    @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary()
  } catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load Linux kernel Image
  let kernel_bytes = try {
    @fs.read_file("_build/linux-kernel-riscv64").binary()
  } catch {
    _ => {
      println("SKIP: _build/linux-kernel-riscv64 not found")
      return
    }
  }
  // Load 2-hart DTB
  let dtb_bytes = try {
    @fs.read_file("_build/minimal-smp.dtb").binary()
  } catch {
    _ => {
      println("SKIP: _build/minimal-smp.dtb not found (run: dtc -I dts -O dtb -o _build/minimal-smp.dtb tools/minimal-smp.dts)")
      return
    }
  }
  // Create 2 SMP runners sharing bus, UART, PLIC, CLINT, mtime
  let harts = make_smp_runners(virt_machine_config(), 2)
  let h0 = harts[0] // boot hart
  let h1 = harts[1] // secondary hart
  // Load firmware and kernel into shared bus (via hart 0)
  h0.load_program_u64(fw_bytes, 0x80000000U.to_uint64())
  h0.bus.write_bytes(0x80200000U.to_uint64(), kernel_bytes)
  h0.load_dtb(dtb_bytes)
  // fw_dynamic_info for the boot hart
  let info_addr = 0x80100000U.to_uint64()
  write_u64_le(h0, info_addr, 0x4942534fU.to_uint64()) // magic
  write_u64_le(h0, info_addr + 8U.to_uint64(), 2U.to_uint64()) // version
  write_u64_le(h0, info_addr + 16U.to_uint64(), 0x80200000U.to_uint64()) // next_addr
  write_u64_le(h0, info_addr + 24U.to_uint64(), 1U.to_uint64()) // next_mode = S
  write_u64_le(h0, info_addr + 32U.to_uint64(), 0U.to_uint64()) // options
  write_u64_le(
    h0,
    info_addr + 40U.to_uint64(),
    0xffffffffU.to_uint64() | (0xffffffffU.to_uint64() << 32),
  ) // boot_hart = -1
  // Both harts boot from the same OpenSBI entry point; OpenSBI uses MHARTID
  // to split cold/warm boot paths.  Hart 1 will WFI until hart 0 sends IPI.
  h0.setup_boot_abi()
  h0.cpu.write_reg(12, info_addr) // a2 = &fw_dynamic_info (hart 0 only)
  h1.setup_boot_abi() // sets a0=1, a1=dtb_addr
  h1.cpu.write_reg(12, info_addr) // warm-boot path: same info_addr is fine
  // Run up to 200M total steps, alternating 1 step per hart
  let max_steps = 200000000
  let mut steps = 0
  let mut all_output = ""
  let mut done = false
  while steps < max_steps && not(done) {
    // Hart 0 step
    match h0.step() {
      Running => ()
      Trap(_) => { done = true }
    }
    // Hart 1 step
    match h1.step() {
      Running => ()
      Trap(_) => ()
    }
    steps = steps + 2
    // Drain shared UART every 2M steps
    if steps % 2000000 == 0 {
      let partial = h0.uart_drain()
      if partial.length() > 0 {
        all_output = all_output + partial
        if all_output.contains("Linux version") {
          done = true
        }
      }
    }
  }
  let tail = h0.uart_drain()
  if tail.length() > 0 {
    all_output = all_output + tail
  }
  println(
    "Task 0016 SMP boot: \{all_output.length()} chars total, \{steps} steps",
  )
  if !all_output.contains("OpenSBI") {
    fail("OpenSBI banner not found in SMP boot output (steps=\{steps})")
  }
  if !all_output.contains("Linux version") {
    fail(
      "Kernel 'Linux version' not found in SMP boot output (steps=\{steps})",
    )
  }
}
