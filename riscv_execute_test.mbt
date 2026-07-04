// End-to-end execution regressions for scalar, privileged, floating-point,
// vector, platform, and Linux/OpenSBI paths. Prefer small architectural
// programs over snapshots so failures point to a specific contract.

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
fn test_not_u64(value : UInt64) -> UInt64 {
  value ^ test_join_u64(0xffffffffU, 0xffffffffU)
}

///|
fn assert_vreg_e32x4(
  runner : Runner,
  vreg : Int,
  e0 : UInt,
  e1 : UInt,
  e2 : UInt,
  e3 : UInt,
) -> Unit raise {
  assert_eq(runner.read_vreg_u64(vreg, 0), test_join_u64(e1, e0))
  assert_eq(runner.read_vreg_u64(vreg, 1), test_join_u64(e3, e2))
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

  runner.load_program_u64(
    exec_test_u64_to_le_bytes(exec_test_make_pte(l1_ppn, pte_v)),
    0x1000U.to_uint64(),
  )
  runner.load_program_u64(
    exec_test_u64_to_le_bytes(exec_test_make_pte(l0_ppn, pte_v)),
    0x2000U.to_uint64(),
  )
  runner.load_program_u64(
    exec_test_u64_to_le_bytes(
      exec_test_make_pte(leaf_ppn, pte_v | pte_r | pte_w | pte_a | pte_d),
    ),
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
test "rv64 store effective address keeps high bits with negative immediate" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(8, 0x3fd100a420UL)
  runner.cpu.write_reg(13, 0x1234UL)
  runner.load_program(words_to_bytes([0xeed43423U]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        StoreAccessFault => ()
        _ => fail("expected store access fault")
      }
      assert_eq(info.trap_value, 0x3fd100a308UL)
    }
    Running => fail("expected high-address store to fault outside RAM")
  }
  match decode(0xeed43423U) {
    Sd(rs1, rs2, imm) => {
      assert_eq(rs1, 8)
      assert_eq(rs2, 13)
      assert_eq(imm, -280)
    }
    _ => fail("expected Linux musl store to decode as sd a3,-280(s0)")
  }
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
  runner.load_program(
    words_to_bytes([neg_zero, pos_zero, nan_bits, one]),
    0x100U,
  )
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
  let fp_words = [encode_flw(0, 0, 1), encode_fp_r(0x00U, 2, 1, 0x0U, 3)]
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
  runner.load_program(
    words_to_bytes([
      encode_i(0x100, 0, 0x0U, 5, 0x13U),
      encode_i(0, 5, 0x3U, 1, 0x03U),
      encode_fmv_d_x(1, 3),
      encode_fmv_x_d(3, 4),
    ]),
    0U,
  )
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
  runner.load_program(
    words_to_bytes([encode_flw(0x100, 0, 1), encode_fp_r(0x00U, 2, 1, 0x0U, 3)]),
    0U,
  )
  runner.cpu.write_freg(2, exec_test_f32_bits(1.0).to_uint64())
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected flw to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected fadd.s to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(
    runner.read_freg_u64(1),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(runner.read_freg_u64(3), exec_test_nan_box_single(0x7fc00000U))
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
    encode_i(0, 1, 0x6U, 10, 0x03U),
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
test "sv39 translation cache records repeated data-page hits" {
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
    encode_i(0, 1, 0x6U, 10, 0x03U),
    encode_i(0, 1, 0x6U, 11, 0x03U),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.load_program(program, 0U)
  match runner.run(13) {
    Running => ()
    _ => fail("expected repeated mprv loads to run")
  }
  assert_eq(runner.read_reg(10), 0x12345678U)
  assert_eq(runner.read_reg(11), 0x12345678U)
  assert_eq(runner.translate_cache_miss_count(), 1U.to_uint64())
  assert_eq(runner.translate_cache_fill_count(), 1U.to_uint64())
  assert_eq(runner.translate_cache_hit_count(), 1U.to_uint64())
}

///|
test "sfence.vma flushes the translation cache" {
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
    encode_i(0, 1, 0x2U, 10, 0x03U),
    encode_sfence_vma(0, 0),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.load_program(program, 0U)
  match runner.run(13) {
    Running => ()
    _ => fail("expected sfence.vma sequence to run")
  }
  assert_eq(runner.translate_cache_fill_count(), 1U.to_uint64())
  assert_eq(runner.translate_cache_flush_count() >= 3U.to_uint64(), true)
}

///|
test "store to observed page-table page flushes translation cache" {
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
    encode_i(0, 1, 0x2U, 10, 0x03U),
    encode_i(0, 0, 0x0U, 7, 0x13U),
    encode_csr(0x300, 7, 0x1U, 0),
    encode_i(3, 0, 0x0U, 5, 0x13U),
    encode_i(12, 5, 0x1U, 5, 0x13U),
    encode_u(0x1000U, 6, 0x37U),
    encode_i(0x4c7, 6, 0x0U, 6, 0x13U),
    encode_s(0, 6, 5, 0x3U, 0x23U),
    encode_csr(0x300, 3, 0x1U, 0),
    encode_i(0, 1, 0x6U, 11, 0x03U),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.load_program_u64(words_to_bytes([0x11111111U]), 0x4100U.to_uint64())
  runner.load_program_u64(words_to_bytes([0x22222222U]), 0x5100U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(21) {
    Running => ()
    Trap(info) =>
      fail(
        "expected PTE-store invalidation program to run, got \{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_reg_u64(10), 0x11111111U.to_uint64())
  assert_eq(runner.read_reg_u64(11), 0x22222222U.to_uint64())
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
  let program = words_to_bytes([encode_csr(0x300, 8, 0x5U, 0), encode_ecall()])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(2) {
    Trap(info) =>
      match info.cause {
        EnvironmentCallFromMMode => ()
        _ => fail("expected machine ecall trap")
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
    Trap(info) =>
      match info.cause {
        EnvironmentCallFromUMode => ()
        _ => fail("expected user ecall trap")
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
  assert_eq(config.virtio_blk_base, 0U.to_uint64())
  assert_eq(config.dtb_addr, 0U.to_uint64())
}

///|
test "rv64fdv machine config resets vector state and exposes vector misa bit" {
  let runner = make_runner(rv64fdv_machine_config())
  assert_eq(
    runner.read_csr_u64(0x301),
    (2U.to_uint64() << 62) | 0x34112dU.to_uint64(),
  )
  assert_eq(runner.read_csr_u64(0x008), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x009), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x00A), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x00F), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC20), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 1U.to_uint64() << 63)
  assert_eq(runner.read_csr_u64(0xC22), 16U.to_uint64())
  assert_eq(runner.read_vreg_u64(0, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(0, 1), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(31, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(31, 1), 0U.to_uint64())
}

///|
test "rv64fdv vector csr visible surface mirrors vcsr state" {
  let program = words_to_bytes([
    encode_i(1, 0, 0x0U, 1, 0x13U),
    encode_i(2, 0, 0x0U, 2, 0x13U),
    encode_i(9, 0, 0x0U, 3, 0x13U),
    encode_csr(0x009, 1, 0x1U, 0),
    encode_csr(0x00A, 2, 0x1U, 0),
    encode_csr(0x008, 3, 0x1U, 0),
    encode_csr(0x00F, 0, 0x2U, 4),
    encode_csr(0x009, 0, 0x2U, 5),
    encode_csr(0x00A, 0, 0x2U, 6),
    encode_csr(0x008, 0, 0x2U, 7),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(10) {
    Running => ()
    _ => fail("expected vector csr surface path to run")
  }
  assert_eq(runner.read_reg_u64(4), 0x5U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0x1U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0x2U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 0x9U.to_uint64())
  assert_eq(runner.read_csr_u64(0x00F), 0x5U.to_uint64())
  assert_eq(runner.read_csr_u64(0x009), 0x1U.to_uint64())
  assert_eq(runner.read_csr_u64(0x00A), 0x2U.to_uint64())
  assert_eq(runner.read_csr_u64(0x008), 0x9U.to_uint64())
}

///|
test "rv64fdv rejects writes to read-only vector csrs" {
  let raws = [
    encode_csr(0xC20, 1, 0x1U, 0),
    encode_csr(0xC21, 1, 0x1U, 0),
    encode_csr(0xC22, 1, 0x1U, 0),
  ]
  for raw in raws {
    let runner = make_runner(rv64fdv_machine_config())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected write to read-only vector csr to trap")
    }
  }
}

///|
test "rv64fd without v rejects vector csr access as illegal" {
  let raw = encode_csr(0x00F, 0, 0x2U, 1)
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected vector csr access to trap without v")
  }
}

///|
test "rv64fdv vsetvli updates vl and vtype for supported e32 m1 request" {
  let program = words_to_bytes([
    encode_i(3, 0, 0x0U, 1, 0x13U),
    encode_vsetvli(2, 1, 0x10U),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(2) {
    Running => ()
    _ => fail("expected vsetvli sequence to run")
  }
  assert_eq(runner.read_reg_u64(2), 3U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC20), 3U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 0x10U.to_uint64())
  assert_eq(runner.read_csr_u64(0x008), 0U.to_uint64())
}

///|
test "rv64fdv vsetivli clamps vl to vlmax" {
  let program = words_to_bytes([encode_vsetivli(1, 31U, 0x10U)])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  assert_eq(runner.read_reg_u64(1), 4U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC20), 4U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 0x10U.to_uint64())
}

///|
test "rv64fdv vsetvl uses register avl and vtype" {
  let program = words_to_bytes([
    encode_i(2, 0, 0x0U, 1, 0x13U),
    encode_i(0x18, 0, 0x0U, 2, 0x13U),
    encode_vsetvl(3, 1, 2),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected vsetvl sequence to run")
  }
  assert_eq(runner.read_reg_u64(3), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC20), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 0x18U.to_uint64())
}

///|
test "rv64fdv vsetivli supports fractional lmul and rejects reserved shapes" {
  let program = words_to_bytes([encode_vsetivli(1, 7U, 0x17U)])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected fractional vsetivli request to complete without trap")
  }
  assert_eq(runner.read_reg_u64(1), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC20), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 0x17U.to_uint64())

  let reserved = make_runner(rv64fdv_machine_config())
  reserved.load_program(words_to_bytes([encode_vsetivli(1, 7U, 0x04U)]), 0U)
  match reserved.step() {
    Running => ()
    _ => fail("expected reserved vsetivli request to complete without trap")
  }
  assert_eq(reserved.read_reg_u64(1), 0U.to_uint64())
  assert_eq(reserved.read_csr_u64(0xC20), 0U.to_uint64())
  assert_eq(reserved.read_csr_u64(0xC21), 1U.to_uint64() << 63)

  let too_wide = make_runner(rv64fdv_machine_config())
  too_wide.load_program(words_to_bytes([encode_vsetivli(1, 7U, 0x1fU)]), 0U)
  match too_wide.step() {
    Running => ()
    _ => fail("expected too-wide fractional vsetivli request to complete")
  }
  assert_eq(too_wide.read_reg_u64(1), 0U.to_uint64())
  assert_eq(too_wide.read_csr_u64(0xC20), 0U.to_uint64())
  assert_eq(too_wide.read_csr_u64(0xC21), 1U.to_uint64() << 63)
}

///|
test "rv64fd without v rejects vsetvli as illegal" {
  let raw = encode_vsetvli(1, 0, 0x10U)
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected vsetvli to trap without v")
  }
}

///|
test "rv64fdv vmv.v.i updates active elements and leaves tail undisturbed" {
  let program = words_to_bytes([
    encode_i(3, 0, 0x0U, 1, 0x13U),
    encode_vsetvli(2, 1, 0x10U),
    encode_vmv_v_i(0, 7),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  let all_ones = (-1L).reinterpret_as_uint64()
  runner.cpu.write_vreg(0, 0, all_ones)
  runner.cpu.write_vreg(0, 1, all_ones)
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected vmv.v.i sequence to run")
  }
  assert_eq(runner.read_vreg_u64(0, 0), (7U.to_uint64() << 32) | 7U.to_uint64())
  assert_eq(
    runner.read_vreg_u64(0, 1),
    (0xffffffffU.to_uint64() << 32) | 7U.to_uint64(),
  )
}

///|
test "rv64fdv vmv.v.x and vmv.x.s honor sew and sign extension" {
  let program = words_to_bytes([
    encode_i(4, 0, 0x0U, 1, 0x13U),
    encode_vsetvli(2, 1, 0x0U),
    encode_i(-1, 0, 0x0U, 3, 0x13U),
    encode_vmv_v_x(4, 3),
    encode_vmv_x_s(5, 4),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected vmv.v.x/vmv.x.s sequence to run")
  }
  assert_eq(runner.read_reg_u64(5), (-1L).reinterpret_as_uint64())
  assert_eq(runner.read_vreg_u64(4, 0), 0xffffffffU.to_uint64())
}

///|
test "rv64fdv vmv.v.v copies an lmul2 vector register group" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmv_v_i(2, 5),
    encode_vmv_v_v(4, 2),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected vmv.v.v sequence to run")
  }
  assert_eq(runner.read_vreg_u64(4, 0), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(4, 1), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(5, 0), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(5, 1), test_join_u64(5U, 5U))

  let misaligned = make_runner(rv64fdv_machine_config())
  misaligned.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), encode_vmv_v_v(3, 2)]),
    0U,
  )
  match misaligned.step() {
    Running => ()
    _ => fail("expected lmul2 vsetivli to run")
  }
  match misaligned.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected misaligned vmv.v.v destination to trap")
  }
}

///|
test "rv64fdv vmerge selects vector scalar and immediate sources by v0 mask" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmv_v_i(2, 2),
    encode_vmv_v_i(4, 9),
    encode_vmerge_vvm(6, 2, 4),
    encode_vmerge_vxm(8, 2, 10),
    encode_vmerge_vim(10, 2, -1),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_reg(10, 7U.to_uint64())
  // vmerge uses v0 as a selector and writes every body element: zero bits pick
  // vs2, one bits pick the vector/scalar/immediate second source.
  runner.cpu.write_vreg(0, 0, 0xaaU.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Running => ()
    _ => fail("expected vmerge sequence to run")
  }
  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(9U, 2U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(9U, 2U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(9U, 2U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(9U, 2U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(7U, 2U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(7U, 2U))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(7U, 2U))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(7U, 2U))
  assert_eq(runner.read_vreg_u64(10, 0), test_join_u64(0xffffffffU, 2U))
  assert_eq(runner.read_vreg_u64(10, 1), test_join_u64(0xffffffffU, 2U))
  assert_eq(runner.read_vreg_u64(11, 0), test_join_u64(0xffffffffU, 2U))
  assert_eq(runner.read_vreg_u64(11, 1), test_join_u64(0xffffffffU, 2U))
}

///|
test "rv64fdv first vector arithmetic slice supports unmasked lmul1 integer add" {
  let program = words_to_bytes([
    encode_i(2, 0, 0x0U, 1, 0x13U),
    encode_vsetvli(2, 1, 0x10U),
    encode_vmv_v_i(1, 1),
    encode_vmv_v_i(2, 2),
    encode_vadd_vv(3, 1, 2, true),
    encode_i(5, 0, 0x0U, 4, 0x13U),
    encode_vadd_vx(4, 3, 4, true),
    encode_vadd_vi(5, 4, -1, true),
    encode_vmv_x_s(6, 5),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected vector arithmetic sequence to run")
  }
  assert_eq(runner.read_reg_u64(6), 7U.to_uint64())
  assert_eq(runner.read_vreg_u64(3, 0), (3U.to_uint64() << 32) | 3U.to_uint64())
  assert_eq(runner.read_vreg_u64(4, 0), (8U.to_uint64() << 32) | 8U.to_uint64())
  assert_eq(runner.read_vreg_u64(5, 0), (7U.to_uint64() << 32) | 7U.to_uint64())
}

///|
test "rv64fd without v rejects first vector arithmetic slice as illegal" {
  let raw = encode_vadd_vv(1, 2, 3, true)
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected vector arithmetic to trap without v")
  }
}

///|
test "rv64fdv vector widening add-sub supports e32 to e64 results" {
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_i(4, 0, 0x0U, 1, 0x13U),
      encode_vsetvli(2, 1, 0x10U),
      encode_vwadd_vv(8, 4, 5, true),
      encode_vwaddu_vx(10, 4, 6, true),
      encode_vwsub_vv(12, 4, 5, true),
      encode_vwsubu_vx(14, 4, 7, true),
    ]),
    0U,
  )
  runner.cpu.write_vreg(4, 0, test_join_u64(2U, 0xffffffffU))
  runner.cpu.write_vreg(4, 1, test_join_u64(0x80000000U, 7U))
  runner.cpu.write_vreg(5, 0, test_join_u64(3U, 1U))
  runner.cpu.write_vreg(5, 1, test_join_u64(0xffffffffU, 8U))
  runner.cpu.write_reg(6, 5U.to_uint64())
  runner.cpu.write_reg(7, 9U.to_uint64())
  match runner.run(6) {
    Running => ()
    _ => fail("expected vector widening arithmetic sequence to run")
  }
  assert_eq(runner.read_vreg_u64(8, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 1), 5U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 2), 15U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 3), test_join_u64(0xffffffffU, 0x7fffffffU))
  assert_eq(
    runner.read_vreg_u64(10, 0),
    (1U.to_uint64() << 32) | 4U.to_uint64(),
  )
  assert_eq(runner.read_vreg_u64(10, 1), 7U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 2), 12U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 3), 0x80000005U.to_uint64())
  assert_eq(runner.read_vreg_u64(12, 0), test_not_u64(1U.to_uint64()))
  assert_eq(runner.read_vreg_u64(12, 1), test_not_u64(0U.to_uint64()))
  assert_eq(runner.read_vreg_u64(12, 2), test_not_u64(0U.to_uint64()))
  assert_eq(
    runner.read_vreg_u64(12, 3),
    test_join_u64(0xffffffffU, 0x80000001U),
  )
  assert_eq(runner.read_vreg_u64(14, 0), 0xfffffff6U.to_uint64())
  assert_eq(runner.read_vreg_u64(14, 1), test_not_u64(6U.to_uint64()))
  assert_eq(runner.read_vreg_u64(14, 2), test_not_u64(1U.to_uint64()))
  assert_eq(runner.read_vreg_u64(14, 3), 0x7ffffff7U.to_uint64())
}

///|
test "rv64fdv vector widening arithmetic honors masks and rejects bad groups" {
  let masked = make_runner(rv64fdv_machine_config())
  masked.load_program(
    words_to_bytes([
      encode_i(4, 0, 0x0U, 1, 0x13U),
      encode_vsetvli(2, 1, 0x10U),
      encode_vwadd_vv(6, 4, 5, false),
    ]),
    0U,
  )
  masked.cpu.write_vreg(0, 0, 0x5U.to_uint64())
  masked.cpu.write_vreg(4, 0, test_join_u64(2U, 1U))
  masked.cpu.write_vreg(4, 1, test_join_u64(4U, 3U))
  masked.cpu.write_vreg(5, 0, test_join_u64(20U, 10U))
  masked.cpu.write_vreg(5, 1, test_join_u64(40U, 30U))
  let aaaa = test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU)
  let bbbb = test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU)
  for word in 0..<2 {
    masked.cpu.write_vreg(6, word, aaaa)
    masked.cpu.write_vreg(7, word, bbbb)
  }
  match masked.run(3) {
    Running => ()
    _ => fail("expected masked vector widening arithmetic to run")
  }
  assert_eq(masked.read_vreg_u64(6, 0), 11U.to_uint64())
  assert_eq(masked.read_vreg_u64(6, 1), aaaa)
  assert_eq(masked.read_vreg_u64(7, 0), 33U.to_uint64())
  assert_eq(masked.read_vreg_u64(7, 1), bbbb)

  let bad_dest = make_runner(rv64fdv_machine_config())
  let bad_raw = encode_vwadd_vv(7, 4, 5, true)
  bad_dest.load_program(
    words_to_bytes([
      encode_i(4, 0, 0x0U, 1, 0x13U),
      encode_vsetvli(2, 1, 0x10U),
      bad_raw,
    ]),
    0U,
  )
  match bad_dest.run(3) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, bad_raw.to_uint64())
    }
    _ => fail("expected misaligned widening destination to trap")
  }

  let e64 = make_runner(rv64fdv_machine_config())
  let e64_raw = encode_vwadd_vv(8, 4, 5, true)
  e64.load_program(
    words_to_bytes([
      encode_i(2, 0, 0x0U, 1, 0x13U),
      encode_vsetvli(2, 1, 0x18U),
      e64_raw,
    ]),
    0U,
  )
  match e64.run(3) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, e64_raw.to_uint64())
    }
    _ => fail("expected e64 widening result to trap")
  }
}

///|
test "rv64fdv vector arithmetic rejects masked vill and nonzero vstart" {
  let masked_raw = encode_vadd_vv(1, 2, 3, false)
  let masked = make_runner(rv64fdv_machine_config())
  masked.load_program(words_to_bytes([masked_raw]), 0U)
  match masked.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, masked_raw.to_uint64())
    }
    _ => fail("expected masked vector arithmetic to trap")
  }

  let vill = make_runner(rv64fdv_machine_config())
  vill.load_program(
    words_to_bytes([encode_vsetivli(1, 2U, 0x04U), encode_vmv_v_i(0, 1)]),
    0U,
  )
  match vill.step() {
    Running => ()
    _ => fail("expected vill-producing vsetivli to run")
  }
  match vill.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected vill vector arithmetic to trap")
  }

  let vstart = make_runner(rv64fdv_machine_config())
  vstart.load_program(words_to_bytes([encode_vmv_v_i(0, 1)]), 0U)
  vstart.cpu.write_csr(0x008, 1U.to_uint64())
  match vstart.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected vstart!=0 vector arithmetic to trap")
  }
}

///|
test "rv64fdv vector arithmetic supports lmul2 register groups" {
  // e32,m2 with VLEN=128 spans eight elements across each aligned register
  // group, so these operations intentionally touch v2-v3, v4-v5, and so on.
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmv_v_i(2, 1),
    encode_vmv_v_i(4, 2),
    encode_vadd_vv(6, 2, 4, true),
    encode_vadd_vi(8, 6, -1, true),
    encode_vadd_vx(10, 8, 10, true),
    encode_vsub_vv(12, 10, 4, true),
    encode_vsub_vx(14, 12, 10, true),
    encode_vsub_vv(16, 4, 10, true),
    encode_vrsub_vx(18, 4, 10, true),
    encode_vrsub_vi(20, 10, -1, true),
    encode_vmul_vv(22, 10, 4, true),
    encode_vmul_vx(24, 10, 10, true),
    encode_vmul_vv(26, 16, 4, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 5U.to_uint64())
  match runner.run(14) {
    Running => ()
    _ => fail("expected lmul2 vector arithmetic sequence to run")
  }
  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(10, 0), test_join_u64(7U, 7U))
  assert_eq(runner.read_vreg_u64(10, 1), test_join_u64(7U, 7U))
  assert_eq(runner.read_vreg_u64(11, 0), test_join_u64(7U, 7U))
  assert_eq(runner.read_vreg_u64(11, 1), test_join_u64(7U, 7U))
  assert_eq(runner.read_vreg_u64(12, 0), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(12, 1), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(13, 0), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(13, 1), test_join_u64(5U, 5U))
  assert_eq(runner.read_vreg_u64(14, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(14, 1), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(15, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(15, 1), test_join_u64(0U, 0U))
  // 2 - 7 wraps independently in each e32 lane.
  assert_eq(
    runner.read_vreg_u64(16, 0),
    test_join_u64(0xfffffffbU, 0xfffffffbU),
  )
  assert_eq(
    runner.read_vreg_u64(16, 1),
    test_join_u64(0xfffffffbU, 0xfffffffbU),
  )
  assert_eq(
    runner.read_vreg_u64(17, 0),
    test_join_u64(0xfffffffbU, 0xfffffffbU),
  )
  assert_eq(
    runner.read_vreg_u64(17, 1),
    test_join_u64(0xfffffffbU, 0xfffffffbU),
  )
  assert_eq(runner.read_vreg_u64(18, 0), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(18, 1), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(19, 0), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(19, 1), test_join_u64(3U, 3U))
  assert_eq(
    runner.read_vreg_u64(20, 0),
    test_join_u64(0xfffffff8U, 0xfffffff8U),
  )
  assert_eq(
    runner.read_vreg_u64(20, 1),
    test_join_u64(0xfffffff8U, 0xfffffff8U),
  )
  assert_eq(
    runner.read_vreg_u64(21, 0),
    test_join_u64(0xfffffff8U, 0xfffffff8U),
  )
  assert_eq(
    runner.read_vreg_u64(21, 1),
    test_join_u64(0xfffffff8U, 0xfffffff8U),
  )
  assert_eq(runner.read_vreg_u64(22, 0), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(22, 1), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(23, 0), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(23, 1), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(24, 0), test_join_u64(35U, 35U))
  assert_eq(runner.read_vreg_u64(24, 1), test_join_u64(35U, 35U))
  assert_eq(runner.read_vreg_u64(25, 0), test_join_u64(35U, 35U))
  assert_eq(runner.read_vreg_u64(25, 1), test_join_u64(35U, 35U))
  // `vmul` keeps the low half of the product. For e32 lanes,
  // 0xfffffffb * 2 wraps to 0xfffffff6 in each lane.
  assert_eq(
    runner.read_vreg_u64(26, 0),
    test_join_u64(0xfffffff6U, 0xfffffff6U),
  )
  assert_eq(
    runner.read_vreg_u64(26, 1),
    test_join_u64(0xfffffff6U, 0xfffffff6U),
  )
  assert_eq(
    runner.read_vreg_u64(27, 0),
    test_join_u64(0xfffffff6U, 0xfffffff6U),
  )
  assert_eq(
    runner.read_vreg_u64(27, 1),
    test_join_u64(0xfffffff6U, 0xfffffff6U),
  )

  let misaligned = make_runner(rv64fdv_machine_config())
  misaligned.load_program(
    words_to_bytes([encode_vsetivli(0, 2U, 0x11U), encode_vmv_v_i(3, 1)]),
    0U,
  )
  match misaligned.step() {
    Running => ()
    _ => fail("expected lmul2 vsetivli to run")
  }
  match misaligned.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected misaligned lmul2 vector arithmetic to trap")
  }
}

///|
test "rv64fdv vector arithmetic supports lmul4 register groups" {
  // e32,m4 with VLEN=128 spans sixteen elements across each aligned register
  // group. This is the next integer-LMUL step after the existing m2 coverage.
  let program = words_to_bytes([
    encode_vsetivli(0, 16U, 0x12U),
    encode_vmv_v_i(4, 1),
    encode_vmv_v_i(8, 2),
    encode_vadd_vv(12, 4, 8, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected lmul4 vector arithmetic sequence to run")
  }
  for reg in 12..<16 {
    assert_eq(runner.read_vreg_u64(reg, 0), test_join_u64(3U, 3U))
    assert_eq(runner.read_vreg_u64(reg, 1), test_join_u64(3U, 3U))
  }

  let misaligned = make_runner(rv64fdv_machine_config())
  misaligned.load_program(
    words_to_bytes([encode_vsetivli(0, 4U, 0x12U), encode_vmv_v_i(2, 1)]),
    0U,
  )
  match misaligned.step() {
    Running => ()
    _ => fail("expected lmul4 vsetivli to run")
  }
  match misaligned.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected misaligned lmul4 vector arithmetic to trap")
  }
}

///|
test "rv64fdv vector arithmetic supports lmul8 register groups" {
  // e32,m8 is the largest required integer LMUL group: with VLEN=128 it
  // spans thirty-two elements across eight consecutive vector registers.
  let program = words_to_bytes([
    encode_vsetvli(0, 5, 0x13U),
    encode_vmv_v_i(8, 1),
    encode_vmv_v_i(16, 2),
    encode_vadd_vv(24, 8, 16, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(5, 32U.to_uint64())
  match runner.run(4) {
    Running => ()
    _ => fail("expected lmul8 vector arithmetic sequence to run")
  }
  for reg in 24..<32 {
    assert_eq(runner.read_vreg_u64(reg, 0), test_join_u64(3U, 3U))
    assert_eq(runner.read_vreg_u64(reg, 1), test_join_u64(3U, 3U))
  }

  let misaligned = make_runner(rv64fdv_machine_config())
  misaligned.load_program(
    words_to_bytes([encode_vsetivli(0, 4U, 0x13U), encode_vmv_v_i(4, 1)]),
    0U,
  )
  match misaligned.step() {
    Running => ()
    _ => fail("expected lmul8 vsetivli to run")
  }
  match misaligned.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected misaligned lmul8 vector arithmetic to trap")
  }
}

///|
test "rv64fdv vrsub honors mask and reverse operand order" {
  let program = words_to_bytes([
    encode_vsetivli(0, 4U, 0x10U),
    encode_vmv_v_i(2, 3),
    encode_vmv_v_i(4, -1),
    encode_vrsub_vx(4, 2, 10, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_reg(10, 10U.to_uint64())
  // Mask bits 1 and 3 are active. Normal masked arithmetic leaves masked-off
  // destination elements undisturbed, unlike vmerge/vadc-style body operations.
  runner.cpu.write_vreg(0, 0, 0x0aU.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected masked vrsub sequence to run")
  }
  assert_eq(runner.read_vreg_u64(4, 0), test_join_u64(7U, 0xffffffffU))
  assert_eq(runner.read_vreg_u64(4, 1), test_join_u64(7U, 0xffffffffU))
}

///|
test "rv64fdv vmul honors mask and low-half product" {
  let program = words_to_bytes([
    encode_vsetivli(0, 4U, 0x10U),
    encode_vmv_v_i(2, 3),
    encode_vmv_v_i(4, -1),
    encode_vmul_vx(4, 2, 10, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_reg(10, 4U.to_uint64())
  // Mask bits 1 and 3 are active. Inactive lanes must keep the old all-ones
  // value while active e32 lanes receive the low half of 3 * 4.
  runner.cpu.write_vreg(0, 0, 0x0aU.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected masked vmul sequence to run")
  }
  assert_eq(runner.read_vreg_u64(4, 0), test_join_u64(12U, 0xffffffffU))
  assert_eq(runner.read_vreg_u64(4, 1), test_join_u64(12U, 0xffffffffU))
}

///|
test "rv64fdv vector arithmetic supports fractional lmul register fractions" {
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, 0x17U),
      encode_vadd_vv(6, 2, 4, true),
    ]),
    0U,
  )
  runner.cpu.write_vreg(2, 0, test_join_u64(0xaaaaaaaaU, 2U))
  runner.cpu.write_vreg(4, 0, test_join_u64(0xbbbbbbbbU, 3U))
  runner.cpu.write_vreg(6, 0, test_join_u64(0xddddddddU, 0xccccccccU))
  runner.cpu.write_vreg(6, 1, test_join_u64(0xffffffffU, 0xeeeeeeeeU))
  match runner.run(2) {
    Running => ()
    _ => fail("expected mf2 vector arithmetic sequence to run")
  }
  assert_eq(runner.read_csr_u64(0xC20), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC21), 0x17U.to_uint64())
  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(0x66666665U, 5U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(0xffffffffU, 0xeeeeeeeeU))
}

///|
test "rv64fdv vector multiply high slice supports lmul2 register groups" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmv_v_i(2, -2),
    encode_vmv_v_i(4, 3),
    encode_vmulhu_vv(6, 2, 4, true),
    encode_vmulh_vv(8, 2, 4, true),
    encode_vmulhsu_vv(10, 2, 4, true),
    encode_vmulhu_vx(12, 2, 10, true),
    encode_vmulh_vx(14, 2, 10, true),
    encode_vmulhsu_vx(16, 2, 10, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_reg(10, 3U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected lmul2 vector multiply-high sequence to run")
  }
  // e32 unsigned: 0xfffffffe * 3 has high word 2.
  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(2U, 2U))
  // e32 signed and signed-unsigned: -2 * 3 has high word -1.
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(0xffffffffU, 0xffffffffU))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(0xffffffffU, 0xffffffffU))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(0xffffffffU, 0xffffffffU))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(0xffffffffU, 0xffffffffU))
  assert_eq(
    runner.read_vreg_u64(10, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(10, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(11, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(11, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(runner.read_vreg_u64(12, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(12, 1), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(13, 0), test_join_u64(2U, 2U))
  assert_eq(runner.read_vreg_u64(13, 1), test_join_u64(2U, 2U))
  assert_eq(
    runner.read_vreg_u64(14, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(14, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(15, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(15, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(16, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(16, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(17, 0),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
  assert_eq(
    runner.read_vreg_u64(17, 1),
    test_join_u64(0xffffffffU, 0xffffffffU),
  )
}

///|
test "rv64fdv vector multiply high handles e64 signedness and masks" {
  let all_ones = 0U.to_uint64() - 1U.to_uint64()
  let sign_bit = 1U.to_uint64() << 63
  let program = words_to_bytes([
    encode_vsetivli(0, 2U, 0x18U),
    encode_vmulhu_vv(6, 2, 4, true),
    encode_vmulh_vv(8, 2, 4, true),
    encode_vmulhsu_vv(10, 2, 4, true),
    encode_vmulh_vx(12, 2, 10, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_vreg(0, 0, 0x01U.to_uint64())
  runner.cpu.write_vreg(2, 0, all_ones)
  runner.cpu.write_vreg(2, 1, sign_bit)
  runner.cpu.write_vreg(4, 0, 2U.to_uint64())
  runner.cpu.write_vreg(4, 1, 2U.to_uint64())
  runner.cpu.write_vreg(12, 0, 99U.to_uint64())
  runner.cpu.write_vreg(12, 1, 100U.to_uint64())
  runner.cpu.write_reg(10, 2U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected e64 vector multiply-high sequence to run")
  }
  // Unsigned high half sees both lanes as large positive values.
  assert_eq(runner.read_vreg_u64(6, 0), 1U.to_uint64())
  assert_eq(runner.read_vreg_u64(6, 1), 1U.to_uint64())
  // Signed and signed-unsigned high halves sign-correct the vs2 operand.
  assert_eq(runner.read_vreg_u64(8, 0), all_ones)
  assert_eq(runner.read_vreg_u64(8, 1), all_ones)
  assert_eq(runner.read_vreg_u64(10, 0), all_ones)
  assert_eq(runner.read_vreg_u64(10, 1), all_ones)
  assert_eq(runner.read_vreg_u64(12, 0), all_ones)
  assert_eq(runner.read_vreg_u64(12, 1), 100U.to_uint64())
}

///|
test "rv64fdv vector divide slice supports lmul2 register groups" {
  let packed_20 = test_join_u64(20U, 20U)
  let packed_6 = test_join_u64(6U, 6U)
  let packed_neg_7 = test_join_u64(0xfffffff9U, 0xfffffff9U)
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vdivu_vv(6, 2, 4, true),
    encode_vremu_vv(8, 2, 4, true),
    encode_vdiv_vv(10, 12, 4, true),
    encode_vrem_vv(14, 12, 4, true),
    encode_vdivu_vx(16, 2, 10, true),
    encode_vremu_vx(18, 2, 10, true),
    encode_vdiv_vx(20, 12, 10, true),
    encode_vrem_vx(22, 12, 10, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_reg(10, 6U.to_uint64())
  for reg in [2, 3] {
    runner.cpu.write_vreg(reg, 0, packed_20)
    runner.cpu.write_vreg(reg, 1, packed_20)
  }
  for reg in [4, 5] {
    runner.cpu.write_vreg(reg, 0, packed_6)
    runner.cpu.write_vreg(reg, 1, packed_6)
  }
  for reg in [12, 13] {
    runner.cpu.write_vreg(reg, 0, packed_neg_7)
    runner.cpu.write_vreg(reg, 1, packed_neg_7)
  }
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected lmul2 vector divide sequence to run")
  }
  for reg in [6, 7, 16, 17] {
    assert_eq(runner.read_vreg_u64(reg, 0), test_join_u64(3U, 3U))
    assert_eq(runner.read_vreg_u64(reg, 1), test_join_u64(3U, 3U))
  }
  for reg in [8, 9, 18, 19] {
    assert_eq(runner.read_vreg_u64(reg, 0), test_join_u64(2U, 2U))
    assert_eq(runner.read_vreg_u64(reg, 1), test_join_u64(2U, 2U))
  }
  for reg in [10, 11, 14, 15, 20, 21, 22, 23] {
    assert_eq(
      runner.read_vreg_u64(reg, 0),
      test_join_u64(0xffffffffU, 0xffffffffU),
    )
    assert_eq(
      runner.read_vreg_u64(reg, 1),
      test_join_u64(0xffffffffU, 0xffffffffU),
    )
  }
}

///|
test "rv64fdv vector divide handles e64 zero overflow and masks" {
  let all_ones = 0U.to_uint64() - 1U.to_uint64()
  let sign_bit = 1U.to_uint64() << 63
  let program = words_to_bytes([
    encode_vsetivli(0, 2U, 0x18U),
    encode_vdiv_vv(6, 2, 4, true),
    encode_vrem_vv(8, 2, 4, true),
    encode_vdiv_vx(10, 2, 10, false),
    encode_vrem_vx(12, 2, 10, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.cpu.write_vreg(0, 0, 0x01U.to_uint64())
  runner.cpu.write_vreg(2, 0, sign_bit)
  runner.cpu.write_vreg(2, 1, 9U.to_uint64())
  runner.cpu.write_vreg(4, 0, all_ones)
  runner.cpu.write_vreg(4, 1, 0U.to_uint64())
  runner.cpu.write_vreg(10, 0, 77U.to_uint64())
  runner.cpu.write_vreg(10, 1, 78U.to_uint64())
  runner.cpu.write_vreg(12, 0, 88U.to_uint64())
  runner.cpu.write_vreg(12, 1, 89U.to_uint64())
  runner.cpu.write_reg(10, 0U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected e64 vector divide edge sequence to run")
  }
  // INT_MIN / -1 overflows to the dividend; division by zero returns -1.
  assert_eq(runner.read_vreg_u64(6, 0), sign_bit)
  assert_eq(runner.read_vreg_u64(6, 1), all_ones)
  // Overflow remainder is zero; division-by-zero remainder keeps the dividend.
  assert_eq(runner.read_vreg_u64(8, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 1), 9U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 0), all_ones)
  assert_eq(runner.read_vreg_u64(10, 1), 78U.to_uint64())
  assert_eq(runner.read_vreg_u64(12, 0), sign_bit)
  assert_eq(runner.read_vreg_u64(12, 1), 89U.to_uint64())
}

///|
test "rv64fdv vector logical slice supports lmul2 register groups" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmv_v_i(2, 10),
    encode_vmv_v_i(4, 12),
    encode_vand_vv(6, 2, 4, true),
    encode_vand_vx(8, 2, 10, true),
    encode_vand_vi(10, 4, 3, true),
    encode_vor_vv(12, 2, 4, true),
    encode_vor_vx(14, 2, 10, true),
    encode_vxor_vv(16, 2, 4, true),
    encode_vxor_vx(18, 2, 10, true),
    encode_vxor_vi(20, 2, -1, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 5U.to_uint64())
  match runner.run(11) {
    Running => ()
    _ => fail("expected lmul2 vector logical sequence to run")
  }
  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(8U, 8U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(8U, 8U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(8U, 8U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(8U, 8U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(10, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(10, 1), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(11, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(11, 1), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(12, 0), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(12, 1), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(13, 0), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(13, 1), test_join_u64(14U, 14U))
  assert_eq(runner.read_vreg_u64(14, 0), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(14, 1), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(15, 0), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(15, 1), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(16, 0), test_join_u64(6U, 6U))
  assert_eq(runner.read_vreg_u64(16, 1), test_join_u64(6U, 6U))
  assert_eq(runner.read_vreg_u64(17, 0), test_join_u64(6U, 6U))
  assert_eq(runner.read_vreg_u64(17, 1), test_join_u64(6U, 6U))
  assert_eq(runner.read_vreg_u64(18, 0), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(18, 1), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(19, 0), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(19, 1), test_join_u64(15U, 15U))
  // vxor.vi with -1 is the architectural vnot pseudoinstruction shape.
  assert_eq(
    runner.read_vreg_u64(20, 0),
    test_join_u64(0xfffffff5U, 0xfffffff5U),
  )
  assert_eq(
    runner.read_vreg_u64(20, 1),
    test_join_u64(0xfffffff5U, 0xfffffff5U),
  )
  assert_eq(
    runner.read_vreg_u64(21, 0),
    test_join_u64(0xfffffff5U, 0xfffffff5U),
  )
  assert_eq(
    runner.read_vreg_u64(21, 1),
    test_join_u64(0xfffffff5U, 0xfffffff5U),
  )
}

///|
test "rv64fdv vector min max slice distinguishes signed and unsigned e32 lanes" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vminu_vv(6, 2, 4, true),
    encode_vmin_vv(8, 2, 4, true),
    encode_vmaxu_vv(10, 2, 4, true),
    encode_vmax_vv(12, 2, 4, true),
    encode_vminu_vx(14, 2, 10, true),
    encode_vmin_vx(16, 2, 10, true),
    encode_vmaxu_vx(18, 2, 10, true),
    encode_vmax_vx(20, 2, 10, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 0xffffffffU.to_uint64())

  // e32,m2 sources span v2-v3 and v4-v5. The values deliberately mix
  // high-bit-set lanes so signed `vmin/vmax` differs from unsigned `vminu/vmaxu`.
  runner.cpu.write_vreg(2, 0, test_join_u64(2U, 0xfffffffeU))
  runner.cpu.write_vreg(2, 1, test_join_u64(9U, 0x80000000U))
  runner.cpu.write_vreg(3, 0, test_join_u64(0xffffffffU, 5U))
  runner.cpu.write_vreg(3, 1, test_join_u64(0x7fffffffU, 0U))
  runner.cpu.write_vreg(4, 0, test_join_u64(3U, 1U))
  runner.cpu.write_vreg(4, 1, test_join_u64(0xfffffffcU, 0x7fffffffU))
  runner.cpu.write_vreg(5, 0, test_join_u64(0xfffffffeU, 6U))
  runner.cpu.write_vreg(5, 1, test_join_u64(0x80000000U, 0xffffffffU))

  match runner.run(9) {
    Running => ()
    _ => fail("expected vector min/max sequence to run")
  }

  assert_vreg_e32x4(runner, 6, 1U, 2U, 0x7fffffffU, 9U)
  assert_vreg_e32x4(runner, 7, 5U, 0xfffffffeU, 0U, 0x7fffffffU)
  assert_vreg_e32x4(runner, 8, 0xfffffffeU, 2U, 0x80000000U, 0xfffffffcU)
  assert_vreg_e32x4(runner, 9, 5U, 0xfffffffeU, 0xffffffffU, 0x80000000U)
  assert_vreg_e32x4(runner, 10, 0xfffffffeU, 3U, 0x80000000U, 0xfffffffcU)
  assert_vreg_e32x4(runner, 11, 6U, 0xffffffffU, 0xffffffffU, 0x80000000U)
  assert_vreg_e32x4(runner, 12, 1U, 3U, 0x7fffffffU, 9U)
  assert_vreg_e32x4(runner, 13, 6U, 0xffffffffU, 0U, 0x7fffffffU)

  // With x10 holding e32 -1, unsigned min/max treats it as the largest lane
  // value while signed min/max treats it as -1.
  assert_vreg_e32x4(runner, 14, 0xfffffffeU, 2U, 0x80000000U, 9U)
  assert_vreg_e32x4(runner, 15, 5U, 0xffffffffU, 0U, 0x7fffffffU)
  assert_vreg_e32x4(
    runner, 16, 0xfffffffeU, 0xffffffffU, 0x80000000U, 0xffffffffU,
  )
  assert_vreg_e32x4(
    runner, 17, 0xffffffffU, 0xffffffffU, 0xffffffffU, 0xffffffffU,
  )
  assert_vreg_e32x4(
    runner, 18, 0xffffffffU, 0xffffffffU, 0xffffffffU, 0xffffffffU,
  )
  assert_vreg_e32x4(
    runner, 19, 0xffffffffU, 0xffffffffU, 0xffffffffU, 0xffffffffU,
  )
  assert_vreg_e32x4(runner, 20, 0xffffffffU, 2U, 0xffffffffU, 9U)
  assert_vreg_e32x4(runner, 21, 5U, 0xffffffffU, 0U, 0x7fffffffU)
}

///|
test "rv64fdv vector shift slice masks shift amounts by sew" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vsll_vv(6, 2, 4, true),
    encode_vsrl_vv(8, 2, 4, true),
    encode_vsra_vv(10, 2, 4, true),
    encode_vsll_vx(12, 2, 10, true),
    encode_vsrl_vx(14, 2, 10, true),
    encode_vsra_vx(16, 2, 10, true),
    encode_vsll_vi(18, 2, 31, true),
    encode_vsrl_vi(20, 2, 31, true),
    encode_vsra_vi(22, 2, 31, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 33U.to_uint64())

  runner.cpu.write_vreg(2, 0, test_join_u64(0x80000000U, 1U))
  runner.cpu.write_vreg(2, 1, test_join_u64(0x7fffffffU, 0xfffffffeU))
  runner.cpu.write_vreg(3, 0, test_join_u64(0xffffffffU, 0x10U))
  runner.cpu.write_vreg(3, 1, test_join_u64(3U, 0x40000000U))

  // The shift counts deliberately exceed the e32 shift width in some lanes.
  // RVV uses only the low lg2(SEW) bits, so 33 behaves as 1 and 32 as 0.
  runner.cpu.write_vreg(4, 0, test_join_u64(33U, 1U))
  runner.cpu.write_vreg(4, 1, test_join_u64(31U, 4U))
  runner.cpu.write_vreg(5, 0, test_join_u64(2U, 0U))
  runner.cpu.write_vreg(5, 1, test_join_u64(32U, 30U))

  match runner.run(10) {
    Running => ()
    _ => fail("expected vector shift sequence to run")
  }

  assert_vreg_e32x4(runner, 6, 2U, 0U, 0xffffffe0U, 0x80000000U)
  assert_vreg_e32x4(runner, 7, 0x10U, 0xfffffffcU, 0U, 3U)
  assert_vreg_e32x4(runner, 8, 0U, 0x40000000U, 0x0fffffffU, 0U)
  assert_vreg_e32x4(runner, 9, 0x10U, 0x3fffffffU, 1U, 3U)
  assert_vreg_e32x4(runner, 10, 0U, 0xc0000000U, 0xffffffffU, 0U)
  assert_vreg_e32x4(runner, 11, 0x10U, 0xffffffffU, 1U, 3U)
  assert_vreg_e32x4(runner, 12, 2U, 0U, 0xfffffffcU, 0xfffffffeU)
  assert_vreg_e32x4(runner, 13, 0x20U, 0xfffffffeU, 0x80000000U, 6U)
  assert_vreg_e32x4(runner, 14, 0U, 0x40000000U, 0x7fffffffU, 0x3fffffffU)
  assert_vreg_e32x4(runner, 15, 8U, 0x7fffffffU, 0x20000000U, 1U)
  assert_vreg_e32x4(runner, 16, 0U, 0xc0000000U, 0xffffffffU, 0x3fffffffU)
  assert_vreg_e32x4(runner, 17, 8U, 0xffffffffU, 0x20000000U, 1U)
  assert_vreg_e32x4(runner, 18, 0x80000000U, 0U, 0U, 0x80000000U)
  assert_vreg_e32x4(runner, 19, 0U, 0x80000000U, 0U, 0x80000000U)
  assert_vreg_e32x4(runner, 20, 0U, 1U, 1U, 0U)
  assert_vreg_e32x4(runner, 21, 0U, 1U, 0U, 0U)
  assert_vreg_e32x4(runner, 22, 0U, 0xffffffffU, 0xffffffffU, 0U)
  assert_vreg_e32x4(runner, 23, 0U, 0xffffffffU, 0U, 0U)
}

///|
test "rv64fdv vector compare slice writes mask register bits" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmseq_vv(6, 2, 4, true),
    encode_vmsne_vv(7, 2, 4, true),
    encode_vmsltu_vv(8, 2, 4, true),
    encode_vmslt_vv(9, 2, 4, true),
    encode_vmsleu_vv(10, 2, 4, true),
    encode_vmsle_vv(11, 2, 4, true),
    encode_vmseq_vx(12, 2, 10, true),
    encode_vmsltu_vx(13, 2, 10, true),
    encode_vmslt_vx(14, 2, 10, true),
    encode_vmsgtu_vx(15, 2, 10, true),
    encode_vmsgt_vx(16, 2, 10, true),
    encode_vmseq_vi(17, 2, -1, true),
    encode_vmsleu_vi(18, 2, 15, true),
    encode_vmsle_vi(19, 2, -1, true),
    encode_vmsgtu_vi(20, 2, 15, true),
    encode_vmsgt_vi(21, 2, -1, true),
    encode_vmseq_vv(30, 2, 4, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 5U.to_uint64())

  // e32,m2 source groups deliberately mix high-bit values so signed and
  // unsigned comparisons produce different destination mask bits.
  runner.cpu.write_vreg(2, 0, test_join_u64(2U, 1U))
  runner.cpu.write_vreg(2, 1, test_join_u64(0x80000000U, 0xffffffffU))
  runner.cpu.write_vreg(3, 0, test_join_u64(6U, 5U))
  runner.cpu.write_vreg(3, 1, test_join_u64(0x7fffffffU, 0U))
  runner.cpu.write_vreg(4, 0, test_join_u64(3U, 1U))
  runner.cpu.write_vreg(4, 1, test_join_u64(0xffffffffU, 0U))
  runner.cpu.write_vreg(5, 0, test_join_u64(6U, 4U))
  runner.cpu.write_vreg(5, 1, test_join_u64(0x80000000U, 0xffffffffU))
  runner.cpu.write_vreg(0, 0, 0x55U.to_uint64())
  runner.cpu.write_vreg(30, 0, 0xaaU.to_uint64())

  match runner.run(18) {
    Running => ()
    _ => fail("expected vector compare sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0) & 0xffU.to_uint64(), 0x21U.to_uint64())
  assert_eq(runner.read_vreg_u64(7, 0) & 0xffU.to_uint64(), 0xdeU.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 0) & 0xffU.to_uint64(), 0xcaU.to_uint64())
  assert_eq(runner.read_vreg_u64(9, 0) & 0xffU.to_uint64(), 0x0eU.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 0) & 0xffU.to_uint64(), 0xebU.to_uint64())
  assert_eq(runner.read_vreg_u64(11, 0) & 0xffU.to_uint64(), 0x2fU.to_uint64())
  assert_eq(runner.read_vreg_u64(12, 0) & 0xffU.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_vreg_u64(13, 0) & 0xffU.to_uint64(), 0x43U.to_uint64())
  assert_eq(runner.read_vreg_u64(14, 0) & 0xffU.to_uint64(), 0x4fU.to_uint64())
  assert_eq(runner.read_vreg_u64(15, 0) & 0xffU.to_uint64(), 0xacU.to_uint64())
  assert_eq(runner.read_vreg_u64(16, 0) & 0xffU.to_uint64(), 0xa0U.to_uint64())
  assert_eq(runner.read_vreg_u64(17, 0) & 0xffU.to_uint64(), 0x04U.to_uint64())
  assert_eq(runner.read_vreg_u64(18, 0) & 0xffU.to_uint64(), 0x73U.to_uint64())
  assert_eq(runner.read_vreg_u64(19, 0) & 0xffU.to_uint64(), 0x0cU.to_uint64())
  assert_eq(runner.read_vreg_u64(20, 0) & 0xffU.to_uint64(), 0x8cU.to_uint64())
  assert_eq(runner.read_vreg_u64(21, 0) & 0xffU.to_uint64(), 0xf3U.to_uint64())
  assert_eq(runner.read_vreg_u64(30, 0) & 0xffU.to_uint64(), 0xabU.to_uint64())
}

///|
test "rv64fdv vector mask logical slice ignores lmul grouping" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmand_mm(6, 2, 4),
    encode_vmnand_mm(7, 2, 4),
    encode_vmandn_mm(8, 2, 4),
    encode_vmxor_mm(9, 2, 4),
    encode_vmor_mm(10, 2, 4),
    encode_vmnor_mm(11, 2, 4),
    encode_vmorn_mm(12, 2, 4),
    encode_vmxnor_mm(13, 2, 4),
    encode_vmand_mm(14, 3, 5),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // Mask logical operations read one bit per element from single vector
  // registers. They are not widened to LMUL=2 register groups.
  runner.cpu.write_vreg(2, 0, 0xccU.to_uint64())
  runner.cpu.write_vreg(4, 0, 0xaaU.to_uint64())
  runner.cpu.write_vreg(3, 0, 0xf0U.to_uint64())
  runner.cpu.write_vreg(5, 0, 0x0fU.to_uint64())

  match runner.run(10) {
    Running => ()
    _ => fail("expected vector mask logical sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0) & 0xffU.to_uint64(), 0x88U.to_uint64())
  assert_eq(runner.read_vreg_u64(7, 0) & 0xffU.to_uint64(), 0x77U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 0) & 0xffU.to_uint64(), 0x44U.to_uint64())
  assert_eq(runner.read_vreg_u64(9, 0) & 0xffU.to_uint64(), 0x66U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 0) & 0xffU.to_uint64(), 0xeeU.to_uint64())
  assert_eq(runner.read_vreg_u64(11, 0) & 0xffU.to_uint64(), 0x11U.to_uint64())
  assert_eq(runner.read_vreg_u64(12, 0) & 0xffU.to_uint64(), 0xddU.to_uint64())
  assert_eq(runner.read_vreg_u64(13, 0) & 0xffU.to_uint64(), 0x99U.to_uint64())
  assert_eq(runner.read_vreg_u64(14, 0) & 0xffU.to_uint64(), 0x00U.to_uint64())
}

///|
test "rv64fdv vector mask population and first set respect masks" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vcpop_m(6, 2, true),
    encode_vfirst_m(7, 2, true),
    encode_vcpop_m(8, 2, false),
    encode_vfirst_m(9, 2, false),
    encode_vcpop_m(10, 3, true),
    encode_vfirst_m(11, 3, true),
    encode_vsetivli(0, 0U, 0x11U),
    encode_vcpop_m(12, 2, true),
    encode_vfirst_m(13, 2, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // Mask registers pack one predicate bit per element. v2 has bits 2,4,5,7
  // set; v0 narrows masked forms to bit 4 only.
  runner.cpu.write_vreg(2, 0, 0xb4U.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x50U.to_uint64())
  runner.cpu.write_vreg(3, 0, 0U.to_uint64())

  match runner.run(10) {
    Running => ()
    _ => fail("expected vector mask scan sequence to run")
  }

  assert_eq(runner.read_reg_u64(6), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(11), (-1L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13), (-1L).reinterpret_as_uint64())
}

///|
test "rv64fdv vector mask population rejects nonzero vstart" {
  let raw = encode_vcpop_m(1, 2, true)
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(words_to_bytes([encode_vsetivli(0, 8U, 0x11U), raw]), 0U)

  match runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  runner.cpu.write_csr(0x008, 1U.to_uint64())

  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected vcpop.m with nonzero vstart to trap")
  }
}

///|
test "rv64fdv vector mask prefix and only-first operations" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vmsbf_m(6, 2, true),
    encode_vmsif_m(7, 2, true),
    encode_vmsof_m(8, 2, true),
    encode_vmsbf_m(9, 3, true),
    encode_vmsif_m(10, 3, true),
    encode_vmsof_m(11, 3, true),
    encode_vmsbf_m(12, 4, false),
    encode_vmsif_m(13, 4, false),
    encode_vmsof_m(14, 4, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // v2 first active set bit is element 2; v3 has no set bits. v4 and v0
  // exercise masked active-element selection, where masked-off destination bits
  // retain their previous values in this implementation.
  runner.cpu.write_vreg(2, 0, 0xb4U.to_uint64())
  runner.cpu.write_vreg(3, 0, 0U.to_uint64())
  runner.cpu.write_vreg(4, 0, 0xb4U.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x53U.to_uint64())
  runner.cpu.write_vreg(12, 0, 0xf0U.to_uint64())
  runner.cpu.write_vreg(13, 0, 0xf0U.to_uint64())
  runner.cpu.write_vreg(14, 0, 0xf0U.to_uint64())

  match runner.run(10) {
    Running => ()
    _ => fail("expected vector mask prefix sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0) & 0xffU.to_uint64(), 0x03U.to_uint64())
  assert_eq(runner.read_vreg_u64(7, 0) & 0xffU.to_uint64(), 0x07U.to_uint64())
  assert_eq(runner.read_vreg_u64(8, 0) & 0xffU.to_uint64(), 0x04U.to_uint64())
  assert_eq(runner.read_vreg_u64(9, 0) & 0xffU.to_uint64(), 0xffU.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 0) & 0xffU.to_uint64(), 0xffU.to_uint64())
  assert_eq(runner.read_vreg_u64(11, 0) & 0xffU.to_uint64(), 0x00U.to_uint64())
  assert_eq(runner.read_vreg_u64(12, 0) & 0xffU.to_uint64(), 0xa3U.to_uint64())
  assert_eq(runner.read_vreg_u64(13, 0) & 0xffU.to_uint64(), 0xb3U.to_uint64())
  assert_eq(runner.read_vreg_u64(14, 0) & 0xffU.to_uint64(), 0xb0U.to_uint64())
}

///|
test "rv64fdv vector mask prefix rejects overlapping operands" {
  let source_overlap = encode_vmsbf_m(2, 2, true)
  let mask_overlap = encode_vmsif_m(0, 2, false)
  let source_runner = make_runner(rv64fdv_machine_config())
  source_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), source_overlap]),
    0U,
  )
  match source_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match source_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, source_overlap.to_uint64())
    }
    _ => fail("expected vmsbf.m source overlap to trap")
  }

  let mask_runner = make_runner(rv64fdv_machine_config())
  mask_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), mask_overlap]),
    0U,
  )
  match mask_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match mask_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, mask_overlap.to_uint64())
    }
    _ => fail("expected masked vmsif.m v0 overlap to trap")
  }
}

///|
test "rv64fdv vector iota and element index operations" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_viota_m(6, 2, true),
    encode_viota_m(8, 2, false),
    encode_vid_v(10, true),
    encode_vid_v(12, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // e32,m2 destinations span two vector registers. v2 has bits 1,3,4 set,
  // and v0 leaves only elements 0,1,3,6 active for masked forms.
  runner.cpu.write_vreg(2, 0, 0x1aU.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x4bU.to_uint64())
  runner.cpu.write_vreg(8, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(8, 1, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(9, 0, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(9, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(12, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(12, 1, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(13, 0, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(13, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))

  match runner.run(5) {
    Running => ()
    _ => fail("expected vector iota/index sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(1U, 1U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(3U, 2U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(3U, 3U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(0U, 0U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(1U, 0xaaaaaaaaU))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(0xbbbbbbbbU, 2U))
  assert_eq(runner.read_vreg_u64(10, 0), test_join_u64(1U, 0U))
  assert_eq(runner.read_vreg_u64(10, 1), test_join_u64(3U, 2U))
  assert_eq(runner.read_vreg_u64(11, 0), test_join_u64(5U, 4U))
  assert_eq(runner.read_vreg_u64(11, 1), test_join_u64(7U, 6U))
  assert_eq(runner.read_vreg_u64(12, 0), test_join_u64(1U, 0U))
  assert_eq(runner.read_vreg_u64(12, 1), test_join_u64(3U, 0xaaaaaaaaU))
  assert_eq(
    runner.read_vreg_u64(13, 0),
    test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU),
  )
  assert_eq(runner.read_vreg_u64(13, 1), test_join_u64(0xbbbbbbbbU, 6U))
}

///|
test "rv64fdv vector iota rejects overlapping mask sources" {
  let source_overlap = encode_viota_m(2, 2, true)
  let mask_overlap = encode_viota_m(0, 2, false)
  let source_runner = make_runner(rv64fdv_machine_config())
  source_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), source_overlap]),
    0U,
  )
  match source_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match source_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, source_overlap.to_uint64())
    }
    _ => fail("expected viota.m source overlap to trap")
  }

  let mask_runner = make_runner(rv64fdv_machine_config())
  mask_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), mask_overlap]),
    0U,
  )
  match mask_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match mask_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, mask_overlap.to_uint64())
    }
    _ => fail("expected masked viota.m v0 overlap to trap")
  }
}

///|
test "rv64fdv vector compress packs selected source elements" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vcompress_vm(6, 2, 1, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // e32,m2 source elements are [10,11,12,13,14,15,16,17]. The source mask
  // selects elements 0,2,4,5,7, so the destination front becomes
  // [10,12,14,15,17] and the remaining tail slots keep their old contents.
  runner.cpu.write_vreg(1, 0, 0xb5U.to_uint64())
  runner.cpu.write_vreg(2, 0, test_join_u64(11U, 10U))
  runner.cpu.write_vreg(2, 1, test_join_u64(13U, 12U))
  runner.cpu.write_vreg(3, 0, test_join_u64(15U, 14U))
  runner.cpu.write_vreg(3, 1, test_join_u64(17U, 16U))
  runner.cpu.write_vreg(6, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(6, 1, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(7, 0, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(7, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))

  match runner.run(2) {
    Running => ()
    _ => fail("expected vector compress sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(12U, 10U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(15U, 14U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(0xbbbbbbbbU, 17U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
}

///|
test "rv64fdv vector compress rejects reserved overlaps and vstart" {
  let source_overlap = encode_vcompress_vm(2, 2, 1, true)
  let mask_overlap = encode_vcompress_vm(0, 4, 1, true)
  let nonzero_vstart = encode_vcompress_vm(6, 2, 1, true)
  let source_runner = make_runner(rv64fdv_machine_config())
  source_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), source_overlap]),
    0U,
  )
  match source_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match source_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, source_overlap.to_uint64())
    }
    _ => fail("expected vcompress.vm source overlap to trap")
  }

  let mask_runner = make_runner(rv64fdv_machine_config())
  mask_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), mask_overlap]),
    0U,
  )
  match mask_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match mask_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, mask_overlap.to_uint64())
    }
    _ => fail("expected vcompress.vm mask overlap to trap")
  }

  let vstart_runner = make_runner(rv64fdv_machine_config())
  vstart_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), nonzero_vstart]),
    0U,
  )
  match vstart_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  vstart_runner.cpu.write_csr(0x008, 1U.to_uint64())
  match vstart_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, nonzero_vstart.to_uint64())
    }
    _ => fail("expected vcompress.vm nonzero vstart to trap")
  }
}

///|
test "rv64fdv vector gather permutes and splats source elements" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vrgather_vv(6, 2, 4, true),
    encode_vrgather_vx(8, 2, 10, false),
    encode_vrgather_vi(10, 2, 31, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // e32,m2 gives VLMAX=8. The vector-vector gather uses indices
  // [7,0,8,2,4,1,6,3], so index 8 is out of range and returns zero.
  runner.cpu.write_reg(10, 5U.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x4bU.to_uint64())
  runner.cpu.write_vreg(2, 0, test_join_u64(11U, 10U))
  runner.cpu.write_vreg(2, 1, test_join_u64(13U, 12U))
  runner.cpu.write_vreg(3, 0, test_join_u64(15U, 14U))
  runner.cpu.write_vreg(3, 1, test_join_u64(17U, 16U))
  runner.cpu.write_vreg(4, 0, test_join_u64(0U, 7U))
  runner.cpu.write_vreg(4, 1, test_join_u64(2U, 8U))
  runner.cpu.write_vreg(5, 0, test_join_u64(1U, 4U))
  runner.cpu.write_vreg(5, 1, test_join_u64(3U, 6U))
  runner.cpu.write_vreg(8, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(8, 1, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(9, 0, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(9, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(10, 0, test_join_u64(0xccccccccU, 0xccccccccU))
  runner.cpu.write_vreg(10, 1, test_join_u64(0xccccccccU, 0xccccccccU))
  runner.cpu.write_vreg(11, 0, test_join_u64(0xddddddddU, 0xddddddddU))
  runner.cpu.write_vreg(11, 1, test_join_u64(0xddddddddU, 0xddddddddU))

  match runner.run(4) {
    Running => ()
    _ => fail("expected vector gather sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(10U, 17U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(12U, 0U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(11U, 14U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(13U, 16U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(15U, 15U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(15U, 0xaaaaaaaaU))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(0xbbbbbbbbU, 15U))
  assert_eq(runner.read_vreg_u64(10, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 1), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(11, 0), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(11, 1), 0U.to_uint64())
}

///|
test "rv64fdv vector gather rejects overlapping source groups" {
  let data_overlap = encode_vrgather_vv(2, 2, 4, true)
  let index_overlap = encode_vrgather_vv(4, 2, 4, true)
  let scalar_overlap = encode_vrgather_vx(2, 2, 10, true)
  let data_runner = make_runner(rv64fdv_machine_config())
  data_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), data_overlap]),
    0U,
  )
  match data_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match data_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, data_overlap.to_uint64())
    }
    _ => fail("expected vrgather.vv data overlap to trap")
  }

  let index_runner = make_runner(rv64fdv_machine_config())
  index_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), index_overlap]),
    0U,
  )
  match index_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match index_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, index_overlap.to_uint64())
    }
    _ => fail("expected vrgather.vv index overlap to trap")
  }

  let scalar_runner = make_runner(rv64fdv_machine_config())
  scalar_runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), scalar_overlap]),
    0U,
  )
  match scalar_runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match scalar_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, scalar_overlap.to_uint64())
    }
    _ => fail("expected vrgather.vx data overlap to trap")
  }
}

///|
test "rv64fdv vector slideup and slidedown move elements within groups" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vslideup_vi(6, 2, 2, true),
    encode_vslidedown_vi(8, 2, 3, true),
    encode_vslidedown_vx(10, 2, 10, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // e32,m2 source elements are [10,11,12,13,14,15,16,17]. Slideup by two
  // leaves destination elements 0..1 unchanged, while slidedown by three reads
  // source elements 3..7 and returns zero once the source index reaches VLMAX.
  runner.cpu.write_reg(10, 6U.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x4bU.to_uint64())
  runner.cpu.write_vreg(2, 0, test_join_u64(11U, 10U))
  runner.cpu.write_vreg(2, 1, test_join_u64(13U, 12U))
  runner.cpu.write_vreg(3, 0, test_join_u64(15U, 14U))
  runner.cpu.write_vreg(3, 1, test_join_u64(17U, 16U))
  runner.cpu.write_vreg(6, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(6, 1, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(7, 0, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(7, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(10, 0, test_join_u64(0xccccccccU, 0xccccccccU))
  runner.cpu.write_vreg(10, 1, test_join_u64(0xccccccccU, 0xccccccccU))
  runner.cpu.write_vreg(11, 0, test_join_u64(0xddddddddU, 0xddddddddU))
  runner.cpu.write_vreg(11, 1, test_join_u64(0xddddddddU, 0xddddddddU))

  match runner.run(4) {
    Running => ()
    _ => fail("expected vector slide sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(11U, 10U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(13U, 12U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(15U, 14U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(14U, 13U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(16U, 15U))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(0U, 17U))
  assert_eq(runner.read_vreg_u64(9, 1), 0U.to_uint64())
  assert_eq(runner.read_vreg_u64(10, 0), test_join_u64(17U, 16U))
  assert_eq(runner.read_vreg_u64(10, 1), test_join_u64(0U, 0xccccccccU))
  assert_eq(
    runner.read_vreg_u64(11, 0),
    test_join_u64(0xddddddddU, 0xddddddddU),
  )
  assert_eq(runner.read_vreg_u64(11, 1), test_join_u64(0xddddddddU, 0U))
}

///|
test "rv64fdv vector slideup rejects overlapping source groups" {
  let overlap = encode_vslideup_vi(2, 2, 1, true)
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), overlap]),
    0U,
  )
  match runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, overlap.to_uint64())
    }
    _ => fail("expected vslideup.vi source overlap to trap")
  }
}

///|
test "rv64fdv vector slide1 inserts scalar boundary elements" {
  let program = words_to_bytes([
    encode_vsetivli(0, 8U, 0x11U),
    encode_vslide1up_vx(6, 2, 10, true),
    encode_vslide1down_vx(8, 2, 11, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // e32,m2 source elements are [10,11,12,13,14,15,16,17]. Slide1up inserts
  // the scalar at element 0 and shifts source elements upward by one. The
  // masked slide1down keeps inactive lanes undisturbed and inserts its scalar
  // at element vl-1.
  runner.cpu.write_reg(
    10,
    (0xffffffffU.to_uint64() << 32) | 0x12345678U.to_uint64(),
  )
  runner.cpu.write_reg(
    11,
    (0xdeadbeefU.to_uint64() << 32) | 0xcafebabeU.to_uint64(),
  )
  runner.cpu.write_vreg(0, 0, 0xadU.to_uint64())
  runner.cpu.write_vreg(2, 0, test_join_u64(11U, 10U))
  runner.cpu.write_vreg(2, 1, test_join_u64(13U, 12U))
  runner.cpu.write_vreg(3, 0, test_join_u64(15U, 14U))
  runner.cpu.write_vreg(3, 1, test_join_u64(17U, 16U))
  runner.cpu.write_vreg(8, 0, test_join_u64(0xaaaaaaaaU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(8, 1, test_join_u64(0xbbbbbbbbU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(9, 0, test_join_u64(0xccccccccU, 0xccccccccU))
  runner.cpu.write_vreg(9, 1, test_join_u64(0xddddddddU, 0xddddddddU))

  match runner.run(3) {
    Running => ()
    _ => fail("expected vector slide1 sequence to run")
  }

  assert_eq(runner.read_vreg_u64(6, 0), test_join_u64(10U, 0x12345678U))
  assert_eq(runner.read_vreg_u64(6, 1), test_join_u64(12U, 11U))
  assert_eq(runner.read_vreg_u64(7, 0), test_join_u64(14U, 13U))
  assert_eq(runner.read_vreg_u64(7, 1), test_join_u64(16U, 15U))
  assert_eq(runner.read_vreg_u64(8, 0), test_join_u64(0xaaaaaaaaU, 11U))
  assert_eq(runner.read_vreg_u64(8, 1), test_join_u64(14U, 13U))
  assert_eq(runner.read_vreg_u64(9, 0), test_join_u64(16U, 0xccccccccU))
  assert_eq(runner.read_vreg_u64(9, 1), test_join_u64(0xcafebabeU, 0xddddddddU))
}

///|
test "rv64fdv vector slide1up rejects overlapping source groups" {
  let overlap = encode_vslide1up_vx(2, 2, 1, true)
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), overlap]),
    0U,
  )
  match runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, overlap.to_uint64())
    }
    _ => fail("expected vslide1up.vx source overlap to trap")
  }
}

///|
test "rv64fdv vector whole-register moves copy encoded register groups" {
  let program = words_to_bytes([
    encode_vsetivli(0, 1U, 0x11U),
    encode_vmv_nr_r(8, 16, 4, true),
    encode_vmv_nr_r(24, 8, 8, true),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)

  // `vmv<nr>r.v` ignores the current `vl`: even with vl=1 it copies every bit
  // of NREG whole vector registers.
  for reg in 16..<20 {
    runner.cpu.write_vreg(reg, 0, reg.reinterpret_as_uint().to_uint64())
    runner.cpu.write_vreg(reg, 1, (reg + 100).reinterpret_as_uint().to_uint64())
  }
  for reg in 12..<16 {
    runner.cpu.write_vreg(reg, 0, 0xeeeeeeeeU.to_uint64())
    runner.cpu.write_vreg(reg, 1, 0xffffffffU.to_uint64())
  }

  match runner.run(3) {
    Running => ()
    _ => fail("expected whole-register move sequence to run")
  }

  for offset in 0..<4 {
    assert_eq(
      runner.read_vreg_u64(8 + offset, 0),
      (16 + offset).reinterpret_as_uint().to_uint64(),
    )
    assert_eq(
      runner.read_vreg_u64(8 + offset, 1),
      (116 + offset).reinterpret_as_uint().to_uint64(),
    )
  }
  for offset in 0..<4 {
    assert_eq(
      runner.read_vreg_u64(24 + offset, 0),
      (16 + offset).reinterpret_as_uint().to_uint64(),
    )
    assert_eq(
      runner.read_vreg_u64(24 + offset, 1),
      (116 + offset).reinterpret_as_uint().to_uint64(),
    )
  }
  for offset in 4..<8 {
    assert_eq(runner.read_vreg_u64(24 + offset, 0), 0xeeeeeeeeU.to_uint64())
    assert_eq(runner.read_vreg_u64(24 + offset, 1), 0xffffffffU.to_uint64())
  }
}

///|
test "rv64fdv vector whole-register moves reject misaligned groups" {
  let misaligned = encode_vmv_nr_r(10, 16, 4, true)
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([encode_vsetivli(0, 1U, 0x11U), misaligned]),
    0U,
  )
  match runner.step() {
    Running => ()
    _ => fail("expected vsetivli to run")
  }
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, misaligned.to_uint64())
    }
    _ => fail("expected misaligned vmv4r.v to trap")
  }
}

///|
fn test_vector_vtypei_for_sew(sew_bits : Int) -> UInt {
  match sew_bits {
    8 => 0x00U
    16 => 0x08U
    32 => 0x10U
    64 => 0x18U
    _ => abort("unsupported test vector sew")
  }
}

///|
test "rv64fdv first vector memory slice supports unit-stride integer loads" {
  let load8 = make_runner(rv64fdv_machine_config())
  load8.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(8)),
      encode_vle8(3, 10, true),
    ]),
    0U,
  )
  load8.cpu.write_reg(10, 0x100U.to_uint64())
  load8.bus.store_u8(0x100U.to_uint64(), 0x11U.to_uint64())
  load8.bus.store_u8(0x101U.to_uint64(), 0x22U.to_uint64())
  load8.bus.store_u8(0x102U.to_uint64(), 0x33U.to_uint64())
  load8.bus.store_u8(0x103U.to_uint64(), 0x44U.to_uint64())
  match load8.run(2) {
    Running => ()
    _ => fail("expected vle8.v sequence to run")
  }
  assert_eq(load8.read_vreg_u64(3, 0), 0x44332211U.to_uint64())

  let load16 = make_runner(rv64fdv_machine_config())
  load16.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(16)),
      encode_vle16(4, 10, true),
    ]),
    0U,
  )
  load16.cpu.write_reg(10, 0x120U.to_uint64())
  load16.bus.store_u16(0x120U.to_uint64(), 0x0102U.to_uint64())
  load16.bus.store_u16(0x122U.to_uint64(), 0x0304U.to_uint64())
  load16.bus.store_u16(0x124U.to_uint64(), 0x0506U.to_uint64())
  load16.bus.store_u16(0x126U.to_uint64(), 0x0708U.to_uint64())
  match load16.run(2) {
    Running => ()
    _ => fail("expected vle16.v sequence to run")
  }
  assert_eq(load16.read_vreg_u64(4, 0), test_join_u64(0x07080506U, 0x03040102U))
  assert_eq(load16.read_vreg_u64(4, 1), 0U.to_uint64())

  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(32)),
      encode_vle32(5, 10, true),
    ]),
    0U,
  )
  let all_ones = (-1L).reinterpret_as_uint64()
  load32.cpu.write_vreg(5, 0, all_ones)
  load32.cpu.write_vreg(5, 1, all_ones)
  load32.cpu.write_reg(10, 0x140U.to_uint64())
  load32.bus.store_u32(0x140U.to_uint64(), 0x11223344U.to_uint64())
  load32.bus.store_u32(0x144U.to_uint64(), 0x55667788U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected vle32.v sequence to run")
  }
  assert_eq(
    load32.read_vreg_u64(5, 0),
    (0x55667788U.to_uint64() << 32) | 0x11223344U.to_uint64(),
  )
  assert_eq(load32.read_vreg_u64(5, 1), all_ones)

  let load64 = make_runner(rv64fdv_machine_config())
  load64.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(64)),
      encode_vle64(6, 10, true),
    ]),
    0U,
  )
  load64.cpu.write_reg(10, 0x160U.to_uint64())
  let load64_first = test_join_u64(0x01234567U, 0x89abcdefU)
  let load64_second = test_join_u64(0xfedcba98U, 0x76543210U)
  load64.bus.store_u64(0x160U.to_uint64(), load64_first)
  load64.bus.store_u64(0x168U.to_uint64(), load64_second)
  match load64.run(2) {
    Running => ()
    _ => fail("expected vle64.v sequence to run")
  }
  assert_eq(load64.read_vreg_u64(6, 0), load64_first)
  assert_eq(load64.read_vreg_u64(6, 1), load64_second)
}

///|
test "rv64fdv first vector memory slice supports unit-stride integer stores" {
  let store8 = make_runner(rv64fdv_machine_config())
  store8.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(8)),
      encode_vse8(3, 10, true),
    ]),
    0U,
  )
  store8.cpu.write_vreg(3, 0, 0x44332211U.to_uint64())
  store8.cpu.write_reg(10, 0x180U.to_uint64())
  match store8.run(2) {
    Running => ()
    _ => fail("expected vse8.v sequence to run")
  }
  assert_eq(store8.bus.load_u8(0x180U.to_uint64()), 0x11U.to_uint64())
  assert_eq(store8.bus.load_u8(0x181U.to_uint64()), 0x22U.to_uint64())
  assert_eq(store8.bus.load_u8(0x182U.to_uint64()), 0x33U.to_uint64())
  assert_eq(store8.bus.load_u8(0x183U.to_uint64()), 0x44U.to_uint64())

  let store16 = make_runner(rv64fdv_machine_config())
  store16.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(16)),
      encode_vse16(4, 10, true),
    ]),
    0U,
  )
  store16.cpu.write_vreg(4, 0, test_join_u64(0x07080506U, 0x03040102U))
  store16.cpu.write_vreg(4, 1, 0U.to_uint64())
  store16.cpu.write_reg(10, 0x1A0U.to_uint64())
  match store16.run(2) {
    Running => ()
    _ => fail("expected vse16.v sequence to run")
  }
  assert_eq(store16.bus.load_u16(0x1A0U.to_uint64()), 0x0102U.to_uint64())
  assert_eq(store16.bus.load_u16(0x1A2U.to_uint64()), 0x0304U.to_uint64())
  assert_eq(store16.bus.load_u16(0x1A4U.to_uint64()), 0x0506U.to_uint64())
  assert_eq(store16.bus.load_u16(0x1A6U.to_uint64()), 0x0708U.to_uint64())

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(32)),
      encode_vse32(5, 10, true),
    ]),
    0U,
  )
  store32.cpu.write_vreg(
    5,
    0,
    (0x55667788U.to_uint64() << 32) | 0x11223344U.to_uint64(),
  )
  store32.cpu.write_reg(10, 0x1C0U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected vse32.v sequence to run")
  }
  assert_eq(store32.bus.load_u32(0x1C0U.to_uint64()), 0x11223344U.to_uint64())
  assert_eq(store32.bus.load_u32(0x1C4U.to_uint64()), 0x55667788U.to_uint64())

  let store64 = make_runner(rv64fdv_machine_config())
  store64.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(64)),
      encode_vse64(6, 10, true),
    ]),
    0U,
  )
  let store64_first = test_join_u64(0x01234567U, 0x89abcdefU)
  let store64_second = test_join_u64(0xfedcba98U, 0x76543210U)
  store64.cpu.write_vreg(6, 0, store64_first)
  store64.cpu.write_vreg(6, 1, store64_second)
  store64.cpu.write_reg(10, 0x1E0U.to_uint64())
  match store64.run(2) {
    Running => ()
    _ => fail("expected vse64.v sequence to run")
  }
  assert_eq(store64.bus.load_u64(0x1E0U.to_uint64()), store64_first)
  assert_eq(store64.bus.load_u64(0x1E8U.to_uint64()), store64_second)
}

///|
test "rv64fdv vector memory supports lmul2 register groups" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), encode_vle32(2, 10, true)]),
    0U,
  )
  load32.cpu.write_reg(10, 0x200U.to_uint64())
  for elem in 0..<8 {
    load32.bus.store_u32(
      0x200U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      (0x10 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
  match load32.run(2) {
    Running => ()
    _ => fail("expected lmul2 vle32.v sequence to run")
  }
  assert_eq(load32.read_vreg_u64(2, 0), test_join_u64(0x11U, 0x10U))
  assert_eq(load32.read_vreg_u64(2, 1), test_join_u64(0x13U, 0x12U))
  assert_eq(load32.read_vreg_u64(3, 0), test_join_u64(0x15U, 0x14U))
  assert_eq(load32.read_vreg_u64(3, 1), test_join_u64(0x17U, 0x16U))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([encode_vsetivli(0, 8U, 0x11U), encode_vse32(2, 10, true)]),
    0U,
  )
  store32.cpu.write_vreg(2, 0, test_join_u64(0x21U, 0x20U))
  store32.cpu.write_vreg(2, 1, test_join_u64(0x23U, 0x22U))
  store32.cpu.write_vreg(3, 0, test_join_u64(0x25U, 0x24U))
  store32.cpu.write_vreg(3, 1, test_join_u64(0x27U, 0x26U))
  store32.cpu.write_reg(10, 0x240U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected lmul2 vse32.v sequence to run")
  }
  for elem in 0..<8 {
    assert_eq(
      store32.bus.load_u32(
        0x240U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      ),
      (0x20 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
}

///|
test "rv64fdv vector memory supports lmul4 register groups" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([encode_vsetivli(0, 16U, 0x12U), encode_vle32(4, 10, true)]),
    0U,
  )
  load32.cpu.write_reg(10, 0x480U.to_uint64())
  for elem in 0..<16 {
    load32.bus.store_u32(
      0x480U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      (0x90 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
  match load32.run(2) {
    Running => ()
    _ => fail("expected lmul4 vle32.v sequence to run")
  }
  for reg in 4..<8 {
    let first_elem = ((reg - 4) * 4).reinterpret_as_uint()
    assert_eq(
      load32.read_vreg_u64(reg, 0),
      test_join_u64(0x90U + first_elem + 1U, 0x90U + first_elem),
    )
    assert_eq(
      load32.read_vreg_u64(reg, 1),
      test_join_u64(0x90U + first_elem + 3U, 0x90U + first_elem + 2U),
    )
  }

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([encode_vsetivli(0, 16U, 0x12U), encode_vse32(4, 10, true)]),
    0U,
  )
  for reg in 4..<8 {
    let first_elem = ((reg - 4) * 4).reinterpret_as_uint()
    store32.cpu.write_vreg(
      reg,
      0,
      test_join_u64(0xa0U + first_elem + 1U, 0xa0U + first_elem),
    )
    store32.cpu.write_vreg(
      reg,
      1,
      test_join_u64(0xa0U + first_elem + 3U, 0xa0U + first_elem + 2U),
    )
  }
  store32.cpu.write_reg(10, 0x4c0U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected lmul4 vse32.v sequence to run")
  }
  for elem in 0..<16 {
    assert_eq(
      store32.bus.load_u32(
        0x4c0U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      ),
      (0xa0 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
}

///|
test "rv64fdv vector memory supports lmul8 register groups" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([encode_vsetvli(0, 5, 0x13U), encode_vle32(8, 10, true)]),
    0U,
  )
  load32.cpu.write_reg(5, 32U.to_uint64())
  load32.cpu.write_reg(10, 0x540U.to_uint64())
  for elem in 0..<32 {
    load32.bus.store_u32(
      0x540U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      (0xb0 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
  match load32.run(2) {
    Running => ()
    _ => fail("expected lmul8 vle32.v sequence to run")
  }
  for reg in 8..<16 {
    let first_elem = ((reg - 8) * 4).reinterpret_as_uint()
    assert_eq(
      load32.read_vreg_u64(reg, 0),
      test_join_u64(0xb0U + first_elem + 1U, 0xb0U + first_elem),
    )
    assert_eq(
      load32.read_vreg_u64(reg, 1),
      test_join_u64(0xb0U + first_elem + 3U, 0xb0U + first_elem + 2U),
    )
  }

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([encode_vsetvli(0, 5, 0x13U), encode_vse32(8, 10, true)]),
    0U,
  )
  store32.cpu.write_reg(5, 32U.to_uint64())
  for reg in 8..<16 {
    let first_elem = ((reg - 8) * 4).reinterpret_as_uint()
    store32.cpu.write_vreg(
      reg,
      0,
      test_join_u64(0xd0U + first_elem + 1U, 0xd0U + first_elem),
    )
    store32.cpu.write_vreg(
      reg,
      1,
      test_join_u64(0xd0U + first_elem + 3U, 0xd0U + first_elem + 2U),
    )
  }
  store32.cpu.write_reg(10, 0x5c0U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected lmul8 vse32.v sequence to run")
  }
  for elem in 0..<32 {
    assert_eq(
      store32.bus.load_u32(
        0x5c0U.to_uint64() + (elem * 4).reinterpret_as_uint().to_uint64(),
      ),
      (0xd0 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
}

///|
test "rv64fdv vector memory supports fractional lmul register fractions" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([encode_vsetivli(0, 4U, 0x17U), encode_vle32(8, 10, true)]),
    0U,
  )
  load32.cpu.write_reg(10, 0x700U.to_uint64())
  load32.cpu.write_vreg(8, 0, test_join_u64(0xddddddddU, 0xccccccccU))
  load32.cpu.write_vreg(8, 1, test_join_u64(0xffffffffU, 0xeeeeeeeeU))
  load32.bus.store_u32(0x700U.to_uint64(), 0x10111213U.to_uint64())
  load32.bus.store_u32(0x704U.to_uint64(), 0x20212223U.to_uint64())
  load32.bus.store_u32(0x708U.to_uint64(), 0x30313233U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected mf2 vector load sequence to run")
  }
  assert_eq(load32.read_csr_u64(0xC20), 2U.to_uint64())
  assert_eq(load32.read_vreg_u64(8, 0), test_join_u64(0x20212223U, 0x10111213U))
  assert_eq(load32.read_vreg_u64(8, 1), test_join_u64(0xffffffffU, 0xeeeeeeeeU))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([encode_vsetivli(0, 4U, 0x17U), encode_vse32(8, 10, true)]),
    0U,
  )
  store32.cpu.write_reg(10, 0x740U.to_uint64())
  store32.cpu.write_vreg(8, 0, test_join_u64(0x44444444U, 0x33333333U))
  store32.bus.store_u32(0x748U.to_uint64(), 0x55555555U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected mf2 vector store sequence to run")
  }
  assert_eq(store32.read_csr_u64(0xC20), 2U.to_uint64())
  assert_eq(store32.bus.load_u32(0x740U.to_uint64()), 0x33333333U.to_uint64())
  assert_eq(store32.bus.load_u32(0x744U.to_uint64()), 0x44444444U.to_uint64())
  assert_eq(store32.bus.load_u32(0x748U.to_uint64()), 0x55555555U.to_uint64())
}

///|
test "rv64fdv vector memory supports unit-stride segment e32 loads and stores" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 3U, test_vector_vtypei_for_sew(32)),
      encode_vlseg2e32(4, 10, true),
    ]),
    0U,
  )
  load32.cpu.write_reg(10, 0x780U.to_uint64())
  load32.cpu.write_vreg(4, 0, test_join_u64(0xffffffffU, 0xffffffffU))
  load32.cpu.write_vreg(4, 1, test_join_u64(0xffffffffU, 0xffffffffU))
  load32.cpu.write_vreg(5, 0, test_join_u64(0xffffffffU, 0xffffffffU))
  load32.cpu.write_vreg(5, 1, test_join_u64(0xffffffffU, 0xffffffffU))
  load32.bus.store_u32(0x780U.to_uint64(), 0x10U.to_uint64())
  load32.bus.store_u32(0x784U.to_uint64(), 0x20U.to_uint64())
  load32.bus.store_u32(0x788U.to_uint64(), 0x11U.to_uint64())
  load32.bus.store_u32(0x78cU.to_uint64(), 0x21U.to_uint64())
  load32.bus.store_u32(0x790U.to_uint64(), 0x12U.to_uint64())
  load32.bus.store_u32(0x794U.to_uint64(), 0x22U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected vlseg2e32.v sequence to run")
  }
  assert_eq(load32.read_vreg_u64(4, 0), test_join_u64(0x11U, 0x10U))
  assert_eq(load32.read_vreg_u64(4, 1), test_join_u64(0xffffffffU, 0x12U))
  assert_eq(load32.read_vreg_u64(5, 0), test_join_u64(0x21U, 0x20U))
  assert_eq(load32.read_vreg_u64(5, 1), test_join_u64(0xffffffffU, 0x22U))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 3U, test_vector_vtypei_for_sew(32)),
      encode_vsseg2e32(4, 10, true),
    ]),
    0U,
  )
  store32.cpu.write_reg(10, 0x7c0U.to_uint64())
  store32.cpu.write_vreg(4, 0, test_join_u64(0x31U, 0x30U))
  store32.cpu.write_vreg(4, 1, test_join_u64(0xffffffffU, 0x32U))
  store32.cpu.write_vreg(5, 0, test_join_u64(0x41U, 0x40U))
  store32.cpu.write_vreg(5, 1, test_join_u64(0xffffffffU, 0x42U))
  match store32.run(2) {
    Running => ()
    _ => fail("expected vsseg2e32.v sequence to run")
  }
  assert_eq(store32.bus.load_u32(0x7c0U.to_uint64()), 0x30U.to_uint64())
  assert_eq(store32.bus.load_u32(0x7c4U.to_uint64()), 0x40U.to_uint64())
  assert_eq(store32.bus.load_u32(0x7c8U.to_uint64()), 0x31U.to_uint64())
  assert_eq(store32.bus.load_u32(0x7ccU.to_uint64()), 0x41U.to_uint64())
  assert_eq(store32.bus.load_u32(0x7d0U.to_uint64()), 0x32U.to_uint64())
  assert_eq(store32.bus.load_u32(0x7d4U.to_uint64()), 0x42U.to_uint64())
}

///|
test "rv64fdv vector segment memory honors masks and avoids partial load commit" {
  let masked = make_runner(rv64fdv_machine_config())
  masked.load_program(
    words_to_bytes([
      encode_vsetivli(0, 3U, test_vector_vtypei_for_sew(32)),
      encode_vlseg2e32(6, 10, false),
    ]),
    0U,
  )
  masked.cpu.write_reg(10, 0x820U.to_uint64())
  masked.cpu.write_vreg(0, 0, 0x5U.to_uint64())
  masked.cpu.write_vreg(6, 0, test_join_u64(0xffffffffU, 0xffffffffU))
  masked.cpu.write_vreg(6, 1, test_join_u64(0xffffffffU, 0xffffffffU))
  masked.cpu.write_vreg(7, 0, test_join_u64(0xffffffffU, 0xffffffffU))
  masked.cpu.write_vreg(7, 1, test_join_u64(0xffffffffU, 0xffffffffU))
  for i in 0..<6 {
    masked.bus.store_u32(
      0x820U.to_uint64() + (i * 4).reinterpret_as_uint().to_uint64(),
      (0x50 + i).reinterpret_as_uint().to_uint64(),
    )
  }
  match masked.run(2) {
    Running => ()
    _ => fail("expected masked vlseg2e32.v sequence to run")
  }
  assert_eq(masked.read_vreg_u64(6, 0), test_join_u64(0xffffffffU, 0x50U))
  assert_eq(masked.read_vreg_u64(6, 1), test_join_u64(0xffffffffU, 0x54U))
  assert_eq(masked.read_vreg_u64(7, 0), test_join_u64(0xffffffffU, 0x51U))
  assert_eq(masked.read_vreg_u64(7, 1), test_join_u64(0xffffffffU, 0x55U))

  let fault = make_runner(rv64fdv_machine_config())
  fault.load_program(
    words_to_bytes([
      encode_vsetivli(0, 1U, test_vector_vtypei_for_sew(32)),
      encode_vlseg2e32(8, 10, true),
    ]),
    0U,
  )
  let base = fault.config.ram_base +
    fault.config.ram_size.reinterpret_as_uint().to_uint64() -
    4U.to_uint64()
  fault.cpu.write_reg(10, base)
  fault.cpu.write_vreg(8, 0, test_join_u64(0xffffffffU, 0xaaaaaaaaU))
  fault.cpu.write_vreg(9, 0, test_join_u64(0xffffffffU, 0xbbbbbbbbU))
  fault.bus.store_u32(base, 0x77777777U.to_uint64())
  match fault.run(2) {
    Trap(info) =>
      match info.cause {
        LoadAccessFault => ()
        _ => fail("expected segment field load access fault")
      }
    _ => fail("expected vlseg2e32.v field fault to trap")
  }
  assert_eq(fault.read_vreg_u64(8, 0), test_join_u64(0xffffffffU, 0xaaaaaaaaU))
  assert_eq(fault.read_vreg_u64(9, 0), test_join_u64(0xffffffffU, 0xbbbbbbbbU))
}

///|
test "rv64fdv vector memory supports mask loads and stores" {
  let load_mask = make_runner(rv64fdv_machine_config())
  load_mask.load_program(
    words_to_bytes([
      encode_vsetivli(0, 10U, test_vector_vtypei_for_sew(8)),
      encode_vlm(3, 10),
    ]),
    0U,
  )
  load_mask.cpu.write_reg(10, 0x300U.to_uint64())
  load_mask.cpu.write_vreg(3, 0, (-1L).reinterpret_as_uint64())
  load_mask.bus.store_u8(0x300U.to_uint64(), 0xa5U.to_uint64())
  load_mask.bus.store_u8(0x301U.to_uint64(), 0x02U.to_uint64())
  match load_mask.run(2) {
    Running => ()
    _ => fail("expected vlm.v sequence to run")
  }
  assert_eq(
    load_mask.read_vreg_u64(3, 0) & 0xffffU.to_uint64(),
    0x02a5U.to_uint64(),
  )

  let store_mask = make_runner(rv64fdv_machine_config())
  store_mask.load_program(
    words_to_bytes([
      encode_vsetivli(0, 10U, test_vector_vtypei_for_sew(8)),
      encode_vsm(4, 10),
    ]),
    0U,
  )
  store_mask.cpu.write_vreg(4, 0, 0x035aU.to_uint64())
  store_mask.cpu.write_reg(10, 0x320U.to_uint64())
  match store_mask.run(2) {
    Running => ()
    _ => fail("expected vsm.v sequence to run")
  }
  assert_eq(store_mask.bus.load_u8(0x320U.to_uint64()), 0x5aU.to_uint64())
  assert_eq(store_mask.bus.load_u8(0x321U.to_uint64()), 0x03U.to_uint64())
  assert_eq(store_mask.bus.load_u8(0x322U.to_uint64()), 0U.to_uint64())
}

///|
test "rv64fdv vector memory supports strided e32 loads and stores" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vlse32(4, 10, 11, true),
    ]),
    0U,
  )
  load32.cpu.write_reg(10, 0x300U.to_uint64())
  load32.cpu.write_reg(11, 8U.to_uint64())
  for elem in 0..<4 {
    load32.bus.store_u32(
      0x300U.to_uint64() + (elem * 8).reinterpret_as_uint().to_uint64(),
      (0x30 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
  match load32.run(2) {
    Running => ()
    _ => fail("expected vlse32.v sequence to run")
  }
  assert_eq(load32.read_vreg_u64(4, 0), test_join_u64(0x31U, 0x30U))
  assert_eq(load32.read_vreg_u64(4, 1), test_join_u64(0x33U, 0x32U))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vsse32(4, 10, 11, true),
    ]),
    0U,
  )
  store32.cpu.write_vreg(4, 0, test_join_u64(0x41U, 0x40U))
  store32.cpu.write_vreg(4, 1, test_join_u64(0x43U, 0x42U))
  store32.cpu.write_reg(10, 0x340U.to_uint64())
  store32.cpu.write_reg(11, 8U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected vsse32.v sequence to run")
  }
  for elem in 0..<4 {
    assert_eq(
      store32.bus.load_u32(
        0x340U.to_uint64() + (elem * 8).reinterpret_as_uint().to_uint64(),
      ),
      (0x40 + elem).reinterpret_as_uint().to_uint64(),
    )
  }
}

///|
test "rv64fdv vector memory supports indexed unordered e32 loads and stores" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vluxei32(6, 10, 5, true),
    ]),
    0U,
  )
  load32.cpu.write_reg(10, 0x380U.to_uint64())
  load32.cpu.write_vreg(5, 0, test_join_u64(0U, 12U))
  load32.cpu.write_vreg(5, 1, test_join_u64(4U, 8U))
  load32.bus.store_u32(0x380U.to_uint64(), 0x50U.to_uint64())
  load32.bus.store_u32(0x384U.to_uint64(), 0x51U.to_uint64())
  load32.bus.store_u32(0x388U.to_uint64(), 0x52U.to_uint64())
  load32.bus.store_u32(0x38cU.to_uint64(), 0x53U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected vluxei32.v sequence to run")
  }
  assert_eq(load32.read_vreg_u64(6, 0), test_join_u64(0x50U, 0x53U))
  assert_eq(load32.read_vreg_u64(6, 1), test_join_u64(0x51U, 0x52U))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vsuxei32(6, 10, 5, true),
    ]),
    0U,
  )
  store32.cpu.write_vreg(5, 0, test_join_u64(0U, 12U))
  store32.cpu.write_vreg(5, 1, test_join_u64(4U, 8U))
  store32.cpu.write_vreg(6, 0, test_join_u64(0x60U, 0x63U))
  store32.cpu.write_vreg(6, 1, test_join_u64(0x61U, 0x62U))
  store32.cpu.write_reg(10, 0x3c0U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected vsuxei32.v sequence to run")
  }
  assert_eq(store32.bus.load_u32(0x3c0U.to_uint64()), 0x60U.to_uint64())
  assert_eq(store32.bus.load_u32(0x3c4U.to_uint64()), 0x61U.to_uint64())
  assert_eq(store32.bus.load_u32(0x3c8U.to_uint64()), 0x62U.to_uint64())
  assert_eq(store32.bus.load_u32(0x3ccU.to_uint64()), 0x63U.to_uint64())
}

///|
test "rv64fdv vector memory supports indexed ordered e32 loads and stores" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vloxei32(7, 10, 5, true),
    ]),
    0U,
  )
  load32.cpu.write_reg(10, 0x400U.to_uint64())
  load32.cpu.write_vreg(5, 0, test_join_u64(0U, 12U))
  load32.cpu.write_vreg(5, 1, test_join_u64(4U, 8U))
  load32.bus.store_u32(0x400U.to_uint64(), 0x70U.to_uint64())
  load32.bus.store_u32(0x404U.to_uint64(), 0x71U.to_uint64())
  load32.bus.store_u32(0x408U.to_uint64(), 0x72U.to_uint64())
  load32.bus.store_u32(0x40cU.to_uint64(), 0x73U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected vloxei32.v sequence to run")
  }
  assert_eq(load32.read_vreg_u64(7, 0), test_join_u64(0x70U, 0x73U))
  assert_eq(load32.read_vreg_u64(7, 1), test_join_u64(0x71U, 0x72U))

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vsoxei32(7, 10, 5, true),
    ]),
    0U,
  )
  store32.cpu.write_vreg(5, 0, test_join_u64(0U, 0U))
  store32.cpu.write_vreg(5, 1, test_join_u64(0U, 0U))
  store32.cpu.write_vreg(7, 0, test_join_u64(0x81U, 0x80U))
  store32.cpu.write_vreg(7, 1, test_join_u64(0x83U, 0x82U))
  store32.cpu.write_reg(10, 0x440U.to_uint64())
  match store32.run(2) {
    Running => ()
    _ => fail("expected vsoxei32.v sequence to run")
  }
  assert_eq(store32.bus.load_u32(0x440U.to_uint64()), 0x83U.to_uint64())
}

///|
test "rv64fdv masked vector memory skips inactive elements" {
  let load32 = make_runner(rv64fdv_machine_config())
  load32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vle32(9, 10, false),
    ]),
    0U,
  )
  let all_ones = (-1L).reinterpret_as_uint64()
  let base = load32.config.ram_base +
    load32.config.ram_size.reinterpret_as_uint().to_uint64() -
    8U.to_uint64()
  load32.cpu.write_reg(10, base)
  load32.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  load32.cpu.write_vreg(9, 0, all_ones)
  load32.cpu.write_vreg(9, 1, all_ones)
  load32.bus.store_u32(base, 0x11223344U.to_uint64())
  load32.bus.store_u32(base + 4U.to_uint64(), 0x55667788U.to_uint64())
  match load32.run(2) {
    Running => ()
    _ => fail("expected masked vle32.v to skip invalid inactive elements")
  }
  assert_eq(
    load32.read_vreg_u64(9, 0),
    (0x55667788U.to_uint64() << 32) | 0x11223344U.to_uint64(),
  )
  assert_eq(load32.read_vreg_u64(9, 1), all_ones)

  let store32 = make_runner(rv64fdv_machine_config())
  store32.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vse32(9, 10, false),
    ]),
    0U,
  )
  let store_base = store32.config.ram_base +
    store32.config.ram_size.reinterpret_as_uint().to_uint64() -
    8U.to_uint64()
  store32.cpu.write_reg(10, store_base)
  store32.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  store32.cpu.write_vreg(
    9,
    0,
    (0x33445566U.to_uint64() << 32) | 0xaabbccddU.to_uint64(),
  )
  store32.cpu.write_vreg(
    9,
    1,
    (0x778899aaU.to_uint64() << 32) | 0x10203040U.to_uint64(),
  )
  match store32.run(2) {
    Running => ()
    _ => fail("expected masked vse32.v to skip invalid inactive elements")
  }
  assert_eq(store32.bus.load_u32(store_base), 0xaabbccddU.to_uint64())
  assert_eq(
    store32.bus.load_u32(store_base + 4U.to_uint64()),
    0x33445566U.to_uint64(),
  )

  let strided = make_runner(rv64fdv_machine_config())
  strided.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vlse32(12, 10, 11, false),
    ]),
    0U,
  )
  let strided_base = strided.config.ram_base +
    strided.config.ram_size.reinterpret_as_uint().to_uint64() -
    8U.to_uint64()
  strided.cpu.write_reg(10, strided_base)
  strided.cpu.write_reg(11, 4U.to_uint64())
  strided.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  strided.cpu.write_vreg(12, 0, all_ones)
  strided.cpu.write_vreg(12, 1, all_ones)
  strided.bus.store_u32(strided_base, 0x0a0b0c0dU.to_uint64())
  strided.bus.store_u32(strided_base + 4U.to_uint64(), 0x0e0f1011U.to_uint64())
  match strided.run(2) {
    Running => ()
    _ => fail("expected masked strided load to skip invalid inactive addresses")
  }
  assert_eq(
    strided.read_vreg_u64(12, 0),
    (0x0e0f1011U.to_uint64() << 32) | 0x0a0b0c0dU.to_uint64(),
  )
  assert_eq(strided.read_vreg_u64(12, 1), all_ones)

  let strided_store = make_runner(rv64fdv_machine_config())
  strided_store.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vsse32(12, 10, 11, false),
    ]),
    0U,
  )
  let strided_store_base = strided_store.config.ram_base +
    strided_store.config.ram_size.reinterpret_as_uint().to_uint64() -
    8U.to_uint64()
  strided_store.cpu.write_reg(10, strided_store_base)
  strided_store.cpu.write_reg(11, 4U.to_uint64())
  strided_store.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  strided_store.cpu.write_vreg(
    12,
    0,
    (0x1e1f2021U.to_uint64() << 32) | 0x1a1b1c1dU.to_uint64(),
  )
  strided_store.cpu.write_vreg(12, 1, all_ones)
  match strided_store.run(2) {
    Running => ()
    _ =>
      fail("expected masked strided store to skip invalid inactive addresses")
  }
  assert_eq(
    strided_store.bus.load_u32(strided_store_base),
    0x1a1b1c1dU.to_uint64(),
  )
  assert_eq(
    strided_store.bus.load_u32(strided_store_base + 4U.to_uint64()),
    0x1e1f2021U.to_uint64(),
  )

  let indexed = make_runner(rv64fdv_machine_config())
  indexed.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vluxei32(11, 10, 5, false),
    ]),
    0U,
  )
  let indexed_base = 0x680U.to_uint64()
  let invalid_offset = indexed.config.ram_size.reinterpret_as_uint().to_uint64()
  indexed.cpu.write_reg(10, indexed_base)
  indexed.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  indexed.cpu.write_vreg(5, 0, test_join_u64(4U, 0U))
  indexed.cpu.write_vreg(
    5,
    1,
    test_join_u64(invalid_offset.to_uint(), invalid_offset.to_uint()),
  )
  indexed.cpu.write_vreg(11, 0, all_ones)
  indexed.cpu.write_vreg(11, 1, all_ones)
  indexed.bus.store_u32(indexed_base, 0x01020304U.to_uint64())
  indexed.bus.store_u32(indexed_base + 4U.to_uint64(), 0x05060708U.to_uint64())
  assert_eq(indexed.read_vreg_u64(0, 0) & 0x7U.to_uint64(), 0x3U.to_uint64())
  match indexed.step() {
    Running => ()
    _ => fail("expected indexed vsetivli to run")
  }
  assert_eq(indexed.read_csr(0xc20), 4U)
  assert_eq(indexed.read_vreg_u64(0, 0) & 0x7U.to_uint64(), 0x3U.to_uint64())
  match indexed.step() {
    Running => ()
    _ => fail("expected masked indexed memory to skip invalid inactive offsets")
  }
  assert_eq(
    indexed.read_vreg_u64(11, 0),
    (0x05060708U.to_uint64() << 32) | 0x01020304U.to_uint64(),
  )
  assert_eq(indexed.read_vreg_u64(11, 1), all_ones)

  let indexed_store = make_runner(rv64fdv_machine_config())
  indexed_store.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vsuxei32(11, 10, 5, false),
    ]),
    0U,
  )
  indexed_store.cpu.write_reg(10, indexed_base)
  indexed_store.cpu.write_vreg(0, 0, 0x3U.to_uint64())
  indexed_store.cpu.write_vreg(5, 0, test_join_u64(4U, 0U))
  indexed_store.cpu.write_vreg(
    5,
    1,
    test_join_u64(invalid_offset.to_uint(), invalid_offset.to_uint()),
  )
  indexed_store.cpu.write_vreg(
    11,
    0,
    (0x05060708U.to_uint64() << 32) | 0x01020304U.to_uint64(),
  )
  indexed_store.cpu.write_vreg(11, 1, all_ones)
  match indexed_store.run(2) {
    Running => ()
    _ => fail("expected masked indexed store to skip invalid inactive offsets")
  }
  assert_eq(indexed_store.bus.load_u32(indexed_base), 0x01020304U.to_uint64())
  assert_eq(
    indexed_store.bus.load_u32(indexed_base + 4U.to_uint64()),
    0x05060708U.to_uint64(),
  )
}

///|
test "rv64fdv vector memory rejects width-mismatch lmul2 vill and nonzero vstart" {
  let mismatch = make_runner(rv64fdv_machine_config())
  mismatch.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(32)),
      encode_vle8(1, 10, true),
    ]),
    0U,
  )
  mismatch.cpu.write_reg(10, 0x200U.to_uint64())
  match mismatch.step() {
    Running => ()
    _ => fail("expected setup vsetivli to run")
  }
  match mismatch.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected width-mismatch vector load to trap")
  }

  let lmul2 = make_runner(rv64fdv_machine_config())
  lmul2.load_program(
    words_to_bytes([encode_vsetivli(0, 2U, 0x11U), encode_vle32(1, 10, true)]),
    0U,
  )
  lmul2.cpu.write_reg(10, 0x280U.to_uint64())
  match lmul2.step() {
    Running => ()
    _ => fail("expected lmul=2 vsetivli to run")
  }
  match lmul2.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected misaligned lmul=2 vector memory op to trap")
  }

  let vill = make_runner(rv64fdv_machine_config())
  vill.load_program(
    words_to_bytes([encode_vsetivli(0, 2U, 0x04U), encode_vle32(1, 10, true)]),
    0U,
  )
  vill.cpu.write_reg(10, 0x240U.to_uint64())
  match vill.step() {
    Running => ()
    _ => fail("expected vill-producing vsetivli to run")
  }
  match vill.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected vill vector memory op to trap")
  }

  let vstart = make_runner(rv64fdv_machine_config())
  vstart.load_program(words_to_bytes([encode_vle32(1, 10, true)]), 0U)
  vstart.cpu.write_reg(10, 0x260U.to_uint64())
  vstart.cpu.write_csr(0x008, 1U.to_uint64())
  match vstart.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
    _ => fail("expected vstart!=0 vector memory op to trap")
  }
}

///|
test "rv64fd without v rejects first vector memory slice as illegal" {
  let raw = encode_vle32(1, 10, true)
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected vector memory op to trap without v")
  }
}

///|
test "rv64fdv vector memory faults without partial commit" {
  let load_fault = make_runner(rv64fdv_machine_config())
  load_fault.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(32)),
      encode_vle32(7, 10, true),
    ]),
    0U,
  )
  let all_ones = (-1L).reinterpret_as_uint64()
  let load_addr = load_fault.config.ram_base +
    load_fault.config.ram_size.reinterpret_as_uint().to_uint64() -
    4U.to_uint64()
  load_fault.cpu.write_vreg(7, 0, all_ones)
  load_fault.cpu.write_vreg(7, 1, all_ones)
  load_fault.cpu.write_reg(10, load_addr)
  load_fault.bus.store_u32(load_addr, 0x11223344U.to_uint64())
  match load_fault.step() {
    Running => ()
    _ => fail("expected setup vsetivli to run")
  }
  match load_fault.step() {
    Trap(info) =>
      match info.cause {
        LoadAccessFault => ()
        _ => fail("expected load access fault")
      }
    _ => fail("expected vector load fault")
  }
  assert_eq(load_fault.read_vreg_u64(7, 0), all_ones)
  assert_eq(load_fault.read_vreg_u64(7, 1), all_ones)

  let store_fault = make_runner(rv64fdv_machine_config())
  store_fault.load_program(
    words_to_bytes([
      encode_vsetivli(0, 2U, test_vector_vtypei_for_sew(32)),
      encode_vse32(8, 10, true),
    ]),
    0U,
  )
  let store_addr = store_fault.config.ram_base +
    store_fault.config.ram_size.reinterpret_as_uint().to_uint64() -
    4U.to_uint64()
  store_fault.cpu.write_vreg(
    8,
    0,
    (0x55667788U.to_uint64() << 32) | 0x11223344U.to_uint64(),
  )
  store_fault.cpu.write_reg(10, store_addr)
  match store_fault.step() {
    Running => ()
    _ => fail("expected setup vsetivli to run")
  }
  match store_fault.step() {
    Trap(info) =>
      match info.cause {
        StoreAccessFault => ()
        _ => fail("expected store access fault")
      }
    _ => fail("expected vector store fault")
  }
  assert_eq(store_fault.bus.load_u32(store_addr), 0U.to_uint64())
}

///|
test "rv64fdv vector fault-only-first loads trim vl after first element" {
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vle32ff(9, 10, true),
    ]),
    0U,
  )
  let all_ones = (-1L).reinterpret_as_uint64()
  let base = runner.config.ram_base +
    runner.config.ram_size.reinterpret_as_uint().to_uint64() -
    4U.to_uint64()
  runner.cpu.write_vreg(9, 0, all_ones)
  runner.cpu.write_vreg(9, 1, all_ones)
  runner.cpu.write_reg(10, base)
  runner.bus.store_u32(base, 0x88776655U.to_uint64())

  match runner.step() {
    Running => ()
    _ => fail("expected setup vsetivli to run")
  }
  match runner.step() {
    Running => ()
    _ =>
      fail("expected vle32ff.v to trim vl instead of trapping after element 0")
  }

  assert_eq(runner.read_csr(0xc20), 1U)
  assert_eq(
    runner.read_vreg_u64(9, 0),
    (all_ones & 0xffffffff00000000UL) | 0x88776655U.to_uint64(),
  )
  assert_eq(runner.read_vreg_u64(9, 1), all_ones)
}

///|
test "rv64fdv vector fault-only-first loads trap on element zero" {
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
      encode_vle32ff(9, 10, true),
    ]),
    0U,
  )
  let base = runner.config.ram_base +
    runner.config.ram_size.reinterpret_as_uint().to_uint64()
  runner.cpu.write_reg(10, base)

  match runner.step() {
    Running => ()
    _ => fail("expected setup vsetivli to run")
  }
  match runner.step() {
    Trap(info) =>
      match info.cause {
        LoadAccessFault => ()
        _ => fail("expected load access fault")
      }
    _ => fail("expected element-zero vle32ff.v fault to trap")
  }
  assert_eq(runner.read_csr(0xc20), 4U)
}

///|
test "rv64fdv masked vector arithmetic updates only lanes enabled by v0" {
  let program = words_to_bytes([
    encode_vsetivli(0, 4U, test_vector_vtypei_for_sew(32)),
    encode_vadd_vv(3, 1, 2, false),
    encode_vadd_vx(4, 1, 10, false),
    encode_vadd_vi(5, 1, -1, false),
  ])
  let runner = make_runner(rv64fdv_machine_config())
  runner.load_program(program, 0U)
  runner.cpu.write_reg(10, 5U.to_uint64())
  runner.cpu.write_vreg(0, 0, 0x5U.to_uint64())
  runner.cpu.write_vreg(0, 1, 0U.to_uint64())
  runner.cpu.write_vreg(1, 0, test_join_u64(20U, 10U))
  runner.cpu.write_vreg(1, 1, test_join_u64(40U, 30U))
  runner.cpu.write_vreg(2, 0, test_join_u64(2U, 1U))
  runner.cpu.write_vreg(2, 1, test_join_u64(4U, 3U))
  runner.cpu.write_vreg(3, 0, test_join_u64(0xdeadbeefU, 0xaaaaaaaaU))
  runner.cpu.write_vreg(3, 1, test_join_u64(0xcafebabeU, 0xbbbbbbbbU))
  runner.cpu.write_vreg(4, 0, test_join_u64(0x11111111U, 0xccccccccU))
  runner.cpu.write_vreg(4, 1, test_join_u64(0x22222222U, 0xddddddddU))
  runner.cpu.write_vreg(5, 0, test_join_u64(0x33333333U, 0xeeeeeeeeU))
  runner.cpu.write_vreg(5, 1, test_join_u64(0x44444444U, 0xffffffffU))
  match runner.run(4) {
    Running => ()
    _ => fail("expected masked vector arithmetic sequence to run")
  }
  assert_eq(runner.read_vreg_u64(3, 0), test_join_u64(0xdeadbeefU, 11U))
  assert_eq(runner.read_vreg_u64(3, 1), test_join_u64(0xcafebabeU, 33U))
  assert_eq(runner.read_vreg_u64(4, 0), test_join_u64(0x11111111U, 15U))
  assert_eq(runner.read_vreg_u64(4, 1), test_join_u64(0x22222222U, 35U))
  assert_eq(runner.read_vreg_u64(5, 0), test_join_u64(0x33333333U, 9U))
  assert_eq(runner.read_vreg_u64(5, 1), test_join_u64(0x44444444U, 29U))
}

///|
test "virt machine config exposes virt-like platform addresses" {
  let config = virt_machine_config()
  let runner = make_runner(config)
  assert_eq(config.ram_base, 0x80000000U.to_uint64())
  assert_eq(config.entry_point, 0x80000000U.to_uint64())
  assert_eq(config.uart0_base, 0x10000000U.to_uint64())
  assert_eq(config.clint_base, 0x02000000U.to_uint64())
  assert_eq(config.plic_base, 0x0C000000U.to_uint64())
  assert_eq(config.virtio_blk_base, 0U.to_uint64())
  assert_eq(config.dtb_addr, 0x87E00000U.to_uint64())
  assert_eq(runner.read_csr_u64(0x301) & 0x28U.to_uint64(), 0x28U.to_uint64())
}

///|
test "virtio-blk machine config exposes optional mmio transport base" {
  let config = virtio_blk_machine_config()
  assert_eq(config.virtio_blk_base, 0x10001000U.to_uint64())
  assert_eq(config.uart0_base, 0x10000000U.to_uint64())
  assert_eq(config.plic_base, 0x0C000000U.to_uint64())
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
test "uart dlab divisor writes do not emit tx or enable interrupts" {
  let program = words_to_bytes([
    encode_u(0x10000000U, 1, 0x37U),
    encode_i(0x80, 0, 0x0U, 2, 0x13U),
    encode_s(3, 2, 1, 0x0U, 0x23U),
    encode_i(72, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x0U, 0x23U),
    encode_i(2, 0, 0x0U, 2, 0x13U),
    encode_s(1, 2, 1, 0x0U, 0x23U),
    encode_i(1, 1, 0x4U, 3, 0x03U),
    encode_s(3, 0, 1, 0x0U, 0x23U),
    encode_s(1, 2, 1, 0x0U, 0x23U),
    encode_i(1, 1, 0x4U, 4, 0x03U),
    encode_i(2, 1, 0x4U, 5, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(12) {
    Running => ()
    _ => fail("expected running after uart dlab sequence")
  }
  assert_eq(runner.uart_drain(), "")
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0x02U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0x02U.to_uint64())
}

///|
test "uart thre interrupt is claimable through plic" {
  let program = words_to_bytes([
    encode_u(0x0c000000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(40, 2, 1, 0x2U, 0x23U),
    encode_u(0x0c002000U, 3, 0x37U),
    encode_i(1, 0, 0x0U, 4, 0x13U),
    encode_i(10, 4, 0x1U, 4, 0x13U),
    encode_s(128, 4, 3, 0x2U, 0x23U),
    encode_u(0x10000000U, 5, 0x37U),
    encode_i(2, 0, 0x0U, 6, 0x13U),
    encode_s(1, 6, 5, 0x0U, 0x23U),
    encode_u(0x0c201000U, 7, 0x37U),
    encode_i(4, 7, 0x2U, 8, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(12) {
    Running => ()
    _ => fail("expected running after uart plic sequence")
  }
  assert_eq(runner.read_reg_u64(8), 10U.to_uint64())
}

///|
test "uart plic pending cache does not leak through ier reads" {
  let program = words_to_bytes([
    encode_u(0x0c000000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(40, 2, 1, 0x2U, 0x23U),
    encode_u(0x0c002000U, 3, 0x37U),
    encode_i(1, 0, 0x0U, 4, 0x13U),
    encode_i(10, 4, 0x1U, 4, 0x13U),
    encode_s(128, 4, 3, 0x2U, 0x23U),
    encode_u(0x10000000U, 5, 0x37U),
    encode_i(2, 0, 0x0U, 6, 0x13U),
    encode_s(1, 6, 5, 0x0U, 0x23U),
    encode_i(1, 5, 0x4U, 7, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(11) {
    Running => ()
    _ => fail("expected running after uart ier cache sequence")
  }
  assert_eq(runner.read_reg_u64(7), 0x02U.to_uint64())
}

///|
test "uart receive interrupt is claimable through plic and has iir priority" {
  let program = words_to_bytes([
    encode_u(0x0c000000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(40, 2, 1, 0x2U, 0x23U),
    encode_u(0x0c002000U, 3, 0x37U),
    encode_i(1, 0, 0x0U, 4, 0x13U),
    encode_i(10, 4, 0x1U, 4, 0x13U),
    encode_s(128, 4, 3, 0x2U, 0x23U),
    encode_u(0x10000000U, 5, 0x37U),
    encode_i(3, 0, 0x0U, 6, 0x13U),
    encode_s(1, 6, 5, 0x0U, 0x23U),
    encode_i(2, 5, 0x4U, 7, 0x03U),
    encode_u(0x0c201000U, 8, 0x37U),
    encode_i(4, 8, 0x2U, 9, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.uart_push_input("Z")
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(13) {
    Running => ()
    _ => fail("expected running after uart receive plic sequence")
  }
  assert_eq(runner.read_reg_u64(7), 0x04U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 10U.to_uint64())
}

///|
test "virtio-blk mmio skeleton exposes identity capacity and queue registers" {
  let program = words_to_bytes([
    encode_u(0x10001000U, 1, 0x37U),
    encode_i(0, 1, 0x2U, 2, 0x03U),
    encode_i(4, 1, 0x2U, 3, 0x03U),
    encode_i(8, 1, 0x2U, 4, 0x03U),
    encode_i(0x100, 1, 0x2U, 5, 0x03U),
    encode_i(8, 0, 0x0U, 6, 0x13U),
    encode_s(0x38, 6, 1, 0x2U, 0x23U),
    encode_i(0x38, 1, 0x2U, 7, 0x03U),
    encode_i(1, 0, 0x0U, 8, 0x13U),
    encode_s(0x44, 8, 1, 0x2U, 0x23U),
    encode_i(0x44, 1, 0x2U, 9, 0x03U),
    encode_i(1, 0, 0x0U, 10, 0x13U),
    encode_s(0x14, 10, 1, 0x2U, 0x23U),
    encode_i(0x10, 1, 0x2U, 10, 0x03U),
  ])
  let runner = make_runner(virtio_blk_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(14) {
    Running => ()
    _ => fail("expected running after virtio-blk mmio sequence")
  }
  assert_eq(runner.read_reg_u64(2), 0x74726976U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 2048U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 8U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 1U.to_uint64())
}

///|
test "virtio-blk read request copies disk bytes and raises plic interrupt" {
  let runner = make_runner(virtio_blk_machine_config())
  let desc_base = 0x80001000U.to_uint64()
  let avail_base = 0x80002000U.to_uint64()
  let used_base = 0x80003000U.to_uint64()
  let header_addr = 0x80004000U.to_uint64()
  let data_addr = 0x80005000U.to_uint64()
  let status_addr = 0x80006000U.to_uint64()
  let disk : Array[Byte] = []
  for index in 0..<512 {
    disk.push((index & 0xff).reinterpret_as_uint().to_byte())
  }
  runner.load_virtio_blk_disk(Bytes::from_array(disk))
  runner.bus.store_u64(desc_base, header_addr)
  runner.bus.store_u32(desc_base + 8U.to_uint64(), 16U.to_uint64())
  runner.bus.store_u16(desc_base + 12U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 14U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u64(desc_base + 16U.to_uint64(), data_addr)
  runner.bus.store_u32(desc_base + 24U.to_uint64(), 256U.to_uint64())
  runner.bus.store_u16(desc_base + 28U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 30U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u64(
    desc_base + 32U.to_uint64(),
    data_addr + 256U.to_uint64(),
  )
  runner.bus.store_u32(desc_base + 40U.to_uint64(), 256U.to_uint64())
  runner.bus.store_u16(desc_base + 44U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 46U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u64(desc_base + 48U.to_uint64(), status_addr)
  runner.bus.store_u32(desc_base + 56U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 60U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u32(header_addr, 0U.to_uint64())
  runner.bus.store_u64(header_addr + 8U.to_uint64(), 0U.to_uint64())
  runner.bus.store_u16(avail_base + 2U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(avail_base + 4U.to_uint64(), 0U.to_uint64())
  runner.virtio_blk_state[4] = 8U.to_uint64()
  runner.virtio_blk_state[5] = 1U.to_uint64()
  runner.virtio_blk_state[8] = desc_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[9] = desc_base >> 32
  runner.virtio_blk_state[10] = avail_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[11] = avail_base >> 32
  runner.virtio_blk_state[12] = used_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[13] = used_base >> 32
  let program = words_to_bytes([
    encode_u(0x0c000000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(4, 2, 1, 0x2U, 0x23U),
    encode_u(0x0c002000U, 3, 0x37U),
    encode_i(2, 0, 0x0U, 4, 0x13U),
    encode_s(128, 4, 3, 0x2U, 0x23U),
    encode_u(0x10001000U, 5, 0x37U),
    encode_s(0x50, 0, 5, 0x2U, 0x23U),
    encode_i(0x60, 5, 0x2U, 6, 0x03U),
    encode_u(0x0c201000U, 7, 0x37U),
    encode_i(4, 7, 0x2U, 8, 0x03U),
  ])
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(11) {
    Running => ()
    _ => fail("expected running after virtio-blk request sequence")
  }
  assert_eq(runner.bus.load_u8(data_addr), 0U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 1U.to_uint64()), 1U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 255U.to_uint64()), 255U.to_uint64())
  assert_eq(runner.bus.load_u8(status_addr), 0U.to_uint64())
  assert_eq(runner.bus.load_u32(used_base + 4U.to_uint64()), 0U.to_uint64())
  assert_eq(runner.bus.load_u32(used_base + 8U.to_uint64()), 513U.to_uint64())
  assert_eq(runner.bus.load_u16(used_base + 2U.to_uint64()), 1U.to_uint64())
  assert_eq(runner.virtio_blk_state[6], 1U.to_uint64())
  assert_eq(runner.read_csr_u64(0x344) & 0xa00U.to_uint64(), 0xa00U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
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
  let program = words_to_bytes([
    nop, nop, nop, nop, nop, nop, nop, nop, nop, nop,
  ])
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
  let dtb = Bytes::from_array([
    0xD0U.to_byte(),
    0x0DU.to_byte(),
    0xFEU.to_byte(),
    0xEDU.to_byte(),
  ])
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
fn encode_amo(
  funct5 : UInt,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
) -> UInt {
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
test "AMO.W access fault is reported as store/AMO access fault" {
  let runner = make_runner(default_machine_config())
  let addr = 0x20000U.to_uint64()
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 99U.to_uint64())
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo(0x00U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match runner.step() {
    Trap(info) =>
      match info.cause {
        StoreAccessFault => ()
        _ => fail("expected StoreAccessFault for AMO.W")
      }
    _ => fail("expected trap")
  }
}

///|
test "AMO.W operations ignore upper 32 bits of rs2" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 1U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, (1U.to_uint64() << 32) | 2U.to_uint64())
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo(0x00U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), 3U.to_uint64())
}

///|
test "AMOMIN.W compares signed 32-bit operands" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 1U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 0xffffffffU.to_uint64()) // -1 as a 32-bit word
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo(0x10U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), 0xffffffffU.to_uint64())
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
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )
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
  let fw_bytes = @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary() catch {
    _ => {
      // Skip if binary not available
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load DTB — use our generated minimal DTB, or fall back to virt.dtb
  let dtb_bytes = @fs.read_file("_build/minimal.dtb").binary() catch {
    _ =>
      @fs.read_file("_build/virt.dtb").binary() catch {
        _ => {
          println(
            "SKIP: no DTB found (run 'make minimal-dtb' or 'make virt-dtb')",
          )
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
    fail("OpenSBI should print its banner (trapped=\{trapped}, steps=\{steps})")
  }
}

///|
async test "Task 0015: S-mode entry stub via OpenSBI handoff" {
  // Load OpenSBI fw_dynamic binary
  let fw_bytes = @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary() catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load S-mode entry stub
  let stub_bytes = @fs.read_file("_build/smode-entry.bin").binary() catch {
    _ => {
      println(
        "SKIP: smode-entry.bin not found (run scripts/build-smode-entry.sh)",
      )
      return
    }
  }
  // Load DTB
  let dtb_bytes = @fs.read_file("_build/minimal.dtb").binary() catch {
    _ =>
      @fs.read_file("_build/virt.dtb").binary() catch {
        _ => {
          println(
            "SKIP: no DTB found (run 'make minimal-dtb' or 'make virt-dtb')",
          )
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
  println("Task 0015 UART output (\{output.length()} chars, \{steps} steps):")
  println(output)
  // Require OpenSBI banner
  if !output.contains("OpenSBI") {
    fail("OpenSBI should print its banner (trapped=\{trapped}, steps=\{steps})")
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
  let fw_bytes = @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary() catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load Linux kernel Image
  let kernel_bytes = @fs.read_file("_build/linux-kernel-riscv64").binary() catch {
    _ => {
      println(
        "SKIP: _build/linux-kernel-riscv64 not found (copy Debian riscv64 vmlinux)",
      )
      return
    }
  }
  // Load DTB
  let dtb_bytes = @fs.read_file("_build/minimal.dtb").binary() catch {
    _ =>
      @fs.read_file("_build/virt.dtb").binary() catch {
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
  println(
    "Task 0015 cache stats: decode=\{runner.decode_cache_hit_count()} hits/\{runner.decode_cache_miss_count()} misses translate=\{runner.translate_cache_hit_count()} hits/\{runner.translate_cache_miss_count()} misses",
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
  let fw_bytes = @fs.read_file("_build/opensbi-riscv64-fw_dynamic.bin").binary() catch {
    _ => {
      println("SKIP: OpenSBI binary not found")
      return
    }
  }
  // Load Linux kernel Image
  let kernel_bytes = @fs.read_file("_build/linux-kernel-riscv64").binary() catch {
    _ => {
      println("SKIP: _build/linux-kernel-riscv64 not found")
      return
    }
  }
  // Load 2-hart DTB
  let dtb_bytes = @fs.read_file("_build/minimal-smp.dtb").binary() catch {
    _ => {
      println(
        "SKIP: _build/minimal-smp.dtb not found (run: dtc -I dts -O dtb -o _build/minimal-smp.dtb tools/minimal-smp.dts)",
      )
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
  while steps < max_steps && !done {
    // Hart 0 step
    match h0.step() {
      Running => ()
      Trap(_) => done = true
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
    fail("Kernel 'Linux version' not found in SMP boot output (steps=\{steps})")
  }
}
