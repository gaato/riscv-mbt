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
let exec_test_instret_csr : Int = 0xC02

///|
fn expect_step_running(runner : Runner, message : String) -> Unit raise {
  match runner.step() {
    Running => ()
    _ => fail(message)
  }
}

///|
fn expect_step_trap(
  runner : Runner,
  expected_cause_name : String,
  expected_trap_value : UInt64,
  message : String,
) -> Unit raise {
  match runner.step() {
    Trap(info) => {
      if trap_cause_name(info.cause) != expected_cause_name {
        fail(message)
      }
      assert_eq(info.trap_value, expected_trap_value)
    }
    _ => fail(message)
  }
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
fn exec_test_supervisor_interrupt_program(
  interrupt_mask : Int,
  stvec_value : Int,
) -> Bytes {
  // Set up one delegated S-mode interrupt, return to S-mode at a body
  // instruction, and let the interrupt redirect to the stvec handler before
  // that body instruction can run.
  words_to_bytes([
    encode_i(stvec_value, 0, 0x0U, 6, 0x13U),
    encode_csr(0x105, 6, 0x1U, 0),
    encode_i(interrupt_mask, 0, 0x0U, 1, 0x13U),
    encode_csr(0x303, 1, 0x1U, 0),
    encode_csr(0x104, 1, 0x1U, 0),
    encode_csr(0x344, 1, 0x1U, 0),
    encode_i(2, 0, 0x0U, 2, 0x13U),
    encode_csr(0x100, 2, 0x1U, 0),
    encode_i(44, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_mret(),
    encode_i(99, 0, 0x0U, 10, 0x13U),
    encode_csr(0x142, 0, 0x2U, 7),
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
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
test "load to x0 still raises access faults" {
  let runner = make_runner(rv64_machine_config())
  let bad_addr = 0x3fd100a308UL
  runner.cpu.write_reg(1, bad_addr)
  runner.load_program(words_to_bytes([encode_i(0, 1, 0x3U, 0, 0x03U)]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        LoadAccessFault => ()
        _ => fail("expected load access fault")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, bad_addr)
    }
    Running => fail("expected load to x0 to fault before discarding the value")
  }
  assert_eq(runner.read_reg_u64(0), 0U.to_uint64())
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
test "jalr clears target bit zero before alignment checks" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_i(9, 0, 0x0U, 1, 0x13U),
      encode_i(0, 1, 0x0U, 5, 0x67U),
      encode_i(1, 0, 0x0U, 6, 0x13U),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    Trap(info) =>
      fail(
        "expected jalr tag-bit clearing to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_reg_u64(5), 8U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 1U.to_uint64())
  assert_eq(runner.pc_u64(), 12U.to_uint64())
}

///|
test "unsupported instruction traps" {
  let runner = make_runner(default_machine_config())
  let raw = 0x0000000bU
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction trap")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
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
test "ebreak traps as breakpoint" {
  let runner = make_runner(default_machine_config())
  runner.load_program(words_to_bytes([encode_ebreak()]), 0U)
  match runner.step() {
    Trap(info) => {
      match info.cause {
        Breakpoint => ()
        _ => fail("expected breakpoint trap")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, 0U.to_uint64())
      assert_eq(runner.read_csr(0x342), 3U)
    }
    _ => fail("expected breakpoint trap")
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
test "rv64fd single move transfer boxes in and ignores upper bits out" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_reg(1, 0x7fc01234U.to_uint64())
  runner.cpu.write_freg(3, 0x0000000080000001UL)
  runner.load_program(
    words_to_bytes([encode_fmv_w_x(1, 2), encode_fmv_x_w(3, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64fd single transfer move path to run")
  }
  assert_eq(runner.read_freg_u64(2), exec_test_nan_box_single(0x7fc01234U))
  assert_eq(runner.read_reg_u64(4), 0xffffffff80000001UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
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
test "rv64f add sub mul honor non-rne rounding modes" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x4b800000U.to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(3, exec_test_f32_bits(-1.0).to_uint64())
  runner.cpu.write_freg(4, 0x3f800001U.to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x1U, 5),
      encode_fp_r(0x00U, 2, 1, 0x3U, 6),
      encode_fp_r(0x04U, 3, 1, 0x1U, 7),
      encode_fp_r(0x04U, 3, 1, 0x3U, 8),
      encode_fp_r(0x08U, 4, 4, 0x1U, 9),
      encode_fp_r(0x08U, 4, 4, 0x3U, 10),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE rv64f add/sub/mul to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x4b800000U.to_uint64())
  assert_eq(runner.read_freg_u64(6), 0x4b800001U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x4b800000U.to_uint64())
  assert_eq(runner.read_freg_u64(8), 0x4b800001U.to_uint64())
  assert_eq(runner.read_freg_u64(9), 0x3f800002U.to_uint64())
  assert_eq(runner.read_freg_u64(10), 0x3f800003U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f add sub mul honor dynamic rounding mode" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // Dynamic RDN reuses the same directed-rounding choices as the static
  // non-RNE test, but proves that rm=111 actually consults frm for ordinary
  // arithmetic and not only for conversions or division/square-root paths.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, 0x4b800000U.to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(3, exec_test_f32_bits(-1.0).to_uint64())
  runner.cpu.write_freg(4, 0x3f800001U.to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x7U, 5),
      encode_fp_r(0x04U, 3, 1, 0x7U, 6),
      encode_fp_r(0x08U, 4, 4, 0x7U, 7),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN rv64f add/sub/mul to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x4b800000U.to_uint64())
  assert_eq(runner.read_freg_u64(6), 0x4b800000U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x3f800002U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f div sqrt honor non-rne rounding modes" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(3.0).to_uint64())
  runner.cpu.write_freg(3, exec_test_f32_bits(2.0).to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 2, 1, 0x1U, 4),
      encode_fp_r(0x0cU, 2, 1, 0x3U, 5),
      encode_fsqrt_s(3, 0x1U, 6),
      encode_fsqrt_s(3, 0x3U, 7),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE rv64f div/sqrt to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(4), 0x3eaaaaaaU.to_uint64())
  assert_eq(runner.read_freg_u64(5), 0x3eaaaaabU.to_uint64())
  assert_eq(runner.read_freg_u64(6), 0x3fb504f3U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x3fb504f4U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f sqrt honors dynamic rounding mode" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // rm=111 delegates rounding to frm. RDN must choose the lower adjacent
  // single for sqrt(2.0), and the inexact root must set NX.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, exec_test_f32_bits(2.0).to_uint64())
  runner.load_program(words_to_bytes([encode_fsqrt_s(1, 0x7U, 2)]), 0U)
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN FSQRT.S to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x3fb504f3U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f div honors dynamic rounding mode" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // Dynamic RDN must select the lower adjacent single quotient for 1.0 / 3.0.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(3.0).to_uint64())
  runner.load_program(words_to_bytes([encode_fp_r(0x0cU, 2, 1, 0x7U, 3)]), 0U)
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN FDIV.S to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), 0x3eaaaaaaU.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f div preserves exact zero signs" {
  let runner = make_runner(rv64f_machine_config())
  runner.cpu.write_freg(1, exec_test_f32_bits(0.0).to_uint64())
  runner.cpu.write_freg(2, 0x80000000U.to_uint64())
  runner.cpu.write_freg(3, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(4, exec_test_f32_bits(-1.0).to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 3, 2, 0x0U, 5),
      encode_fp_r(0x0cU, 4, 1, 0x0U, 6),
      encode_fp_r(0x0cU, 4, 2, 0x0U, 7),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero single division to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x80000000U.to_uint64())
  assert_eq(runner.read_freg_u64(6), 0x80000000U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x00000000U.to_uint64())
}

///|
test "rv64f sqrt exact squares stay flag clean" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_f32_bits(4.0).to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(0.25).to_uint64())
  runner.load_program(
    words_to_bytes([encode_fsqrt_s(1, 0x0U, 3), encode_fsqrt_s(2, 0x4U, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact single square roots to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f32_bits(2.0).to_uint64())
  assert_eq(runner.read_freg_u64(4), exec_test_f32_bits(0.5).to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
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
test "rv64fd min and max handle double signed zero and canonical nan fallback" {
  let neg_zero = 0x8000000000000000UL
  let pos_zero = 0U.to_uint64()
  let quiet_nan = 0x7ff8000000001234UL
  let one = 0x3ff0000000000000UL
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, neg_zero)
  runner.cpu.write_freg(2, pos_zero)
  runner.cpu.write_freg(5, quiet_nan)
  runner.cpu.write_freg(6, one)
  runner.load_program(
    words_to_bytes([
      // FMIN.D must select -0.0 and FMAX.D must select +0.0 when both
      // operands are zero. All-NaN min/max returns the canonical NaN.
      encode_fp_r(0x15U, 2, 1, 0x0U, 3),
      encode_fp_r(0x15U, 2, 1, 0x1U, 4),
      encode_fp_r(0x15U, 6, 5, 0x0U, 7),
      encode_fp_r(0x15U, 6, 5, 0x1U, 8),
      encode_fp_r(0x15U, 5, 5, 0x0U, 9),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    Trap(info) =>
      fail(
        "expected double min/max signed-zero path to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), neg_zero)
  assert_eq(runner.read_freg_u64(4), pos_zero)
  assert_eq(runner.read_freg_u64(7), one)
  assert_eq(runner.read_freg_u64(8), one)
  assert_eq(runner.read_freg_u64(9), 0x7ff8000000000000UL)
  assert_eq(runner.read_csr(0x003) & 0x1fU, 0U)
}

///|
test "rv64fd min and max select numeric operand but flag signaling nan" {
  let csr_fcsr = 0x003
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(4, 0x7ff0000000000001UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x14U, 2, 1, 0x0U, 5),
      encode_csr(csr_fcsr, 0, 0x2U, 6),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x14U, 1, 2, 0x1U, 7),
      encode_csr(csr_fcsr, 0, 0x2U, 8),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x15U, 4, 3, 0x0U, 9),
      encode_csr(csr_fcsr, 0, 0x2U, 10),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x15U, 3, 4, 0x1U, 11),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    Trap(info) =>
      fail(
        "expected min/max signaling-NaN numeric-selection paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // FMIN/FMAX result selection is separate from exception accrual: a numeric
  // operand beats a NaN operand, but a signaling NaN still raises NV.
  assert_eq(
    runner.read_freg_u64(5),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(runner.read_reg_u64(6) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(
    runner.read_freg_u64(7),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(runner.read_reg_u64(8) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(runner.read_freg_u64(9), exec_test_f64_bits(1.0))
  assert_eq(runner.read_reg_u64(10) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(runner.read_freg_u64(11), exec_test_f64_bits(1.0))
  assert_eq(runner.read_reg_u64(12) & 0x1fU.to_uint64(), invalid_only)
}

///|
test "rv64f single comparisons write integer results" {
  let runner = make_runner(rv64f_machine_config())
  runner.cpu.write_freg(1, exec_test_f32_bits(1.0).to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(2.0).to_uint64())
  runner.cpu.write_freg(3, exec_test_f32_bits(2.0).to_uint64())
  runner.cpu.write_freg(4, 0x7fc00000U.to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fle_s(1, 2, 5),
      encode_flt_s(2, 1, 6),
      encode_feq_s(2, 3, 7),
      encode_fle_s(4, 2, 8),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64f compare path to run")
  }
  assert_eq(runner.read_reg_u64(5), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 0U.to_uint64())
}

///|
test "rv64f single sign injection preserves magnitude bits" {
  let runner = make_runner(rv64f_machine_config())
  runner.cpu.write_freg(1, exec_test_f32_bits(1.5).to_uint64())
  runner.cpu.write_freg(2, exec_test_f32_bits(-2.0).to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fsgnj_s(1, 2, 3),
      encode_fsgnjn_s(1, 2, 4),
      encode_fsgnjx_s(1, 2, 5),
      encode_fsgnj_s(1, 1, 6),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64f sign injection path to run")
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f32_bits(-1.5).to_uint64())
  assert_eq(runner.read_freg_u64(4), exec_test_f32_bits(1.5).to_uint64())
  assert_eq(runner.read_freg_u64(5), exec_test_f32_bits(-1.5).to_uint64())
  assert_eq(runner.read_freg_u64(6), exec_test_f32_bits(1.5).to_uint64())
}

///|
test "rv64fd single sign injection validates nan boxing" {
  let runner = make_runner(rv64fd_machine_config())
  // These registers mimic raw double-width payloads written by FMV.D.X. Single
  // FP operations must reject them as malformed NaN boxes instead of treating
  // their low 32 bits like FMV.X.W would.
  runner.cpu.write_freg(1, 0x0000000012345678UL)
  runner.cpu.write_freg(2, 0x0000000080000000UL)
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.5)))
  runner.cpu.write_freg(4, exec_test_nan_box_single(exec_test_f32_bits(-2.0)))
  runner.load_program(
    words_to_bytes([
      encode_fsgnj_s(1, 2, 5),
      encode_fsgnjn_s(1, 2, 6),
      encode_fsgnjx_s(1, 2, 7),
      encode_fsgnj_s(3, 4, 8),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64fd single sign injection path to run")
  }
  assert_eq(runner.read_freg_u64(5), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(6), exec_test_nan_box_single(0xffc00000U))
  assert_eq(runner.read_freg_u64(7), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(
    runner.read_freg_u64(8),
    exec_test_nan_box_single(exec_test_f32_bits(-1.5)),
  )
}

///|
test "rv64fd sign injection preserves nan payloads without flags" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  let single_qnan = 0x7fc12345U
  let single_snan = 0x7fa12345U
  let double_qnan = 0x7ff8000000012345UL
  let double_snan = 0x7ff0000000012345UL
  runner.cpu.write_freg(1, exec_test_nan_box_single(single_qnan))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x80000000U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(single_snan))
  runner.cpu.write_freg(4, double_qnan)
  runner.cpu.write_freg(5, 0x8000000000000000UL)
  runner.cpu.write_freg(6, double_snan)
  runner.load_program(
    words_to_bytes([
      encode_fsgnj_s(1, 2, 10),
      encode_fsgnjn_s(3, 2, 11),
      encode_fsgnjx_s(1, 2, 12),
      encode_fsgnj_d(4, 5, 13),
      encode_fsgnjn_d(6, 5, 14),
      encode_fsgnjx_d(4, 5, 15),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    _ => fail("expected sign-injection nan-payload path to run")
  }
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0xffc12345U))
  assert_eq(runner.read_freg_u64(11), exec_test_nan_box_single(single_snan))
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0xffc12345U))
  assert_eq(runner.read_freg_u64(13), 0xfff8000000012345UL)
  assert_eq(runner.read_freg_u64(14), double_snan)
  assert_eq(runner.read_freg_u64(15), 0xfff8000000012345UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
}

///|
test "rv64f integer and single conversion paths preserve expected values" {
  let runner = make_runner(rv64f_machine_config())
  runner.cpu.write_reg(1, 42U.to_uint64())
  runner.cpu.write_reg(2, 0xffffffffU.to_uint64())
  runner.cpu.write_reg(3, (-17L).reinterpret_as_uint64())
  runner.cpu.write_reg(4, 1024U.to_uint64())
  runner.cpu.write_freg(9, exec_test_f32_bits(4.75).to_uint64())
  runner.cpu.write_freg(10, exec_test_f32_bits(-2.75).to_uint64())
  runner.cpu.write_freg(11, exec_test_f32_bits(2147483648.0).to_uint64())
  runner.cpu.write_freg(12, exec_test_f32_bits(42.75).to_uint64())
  runner.load_program(
    words_to_bytes([
      encode_fcvt_s_w(1, 0x0U, 5),
      encode_fcvt_s_w(2, 0x0U, 6),
      encode_fcvt_s_wu(2, 0x0U, 7),
      encode_fcvt_s_l(3, 0x7U, 8),
      encode_fcvt_s_lu(4, 0x7U, 13),
      encode_fcvt_w_s(9, 0x1U, 14),
      encode_fcvt_w_s(10, 0x1U, 15),
      encode_fcvt_wu_s(11, 0x1U, 16),
      encode_fcvt_l_s(10, 0x1U, 17),
      encode_fcvt_lu_s(12, 0x1U, 18),
    ]),
    0U,
  )
  match runner.run(10) {
    Running => ()
    _ => fail("expected rv64f conversion path to run")
  }
  assert_eq(runner.read_freg_u64(5), exec_test_f32_bits(42.0).to_uint64())
  assert_eq(runner.read_freg_u64(6), exec_test_f32_bits(-1.0).to_uint64())
  assert_eq(
    runner.read_freg_u64(7),
    exec_test_f32_bits(4294967296.0).to_uint64(),
  )
  assert_eq(runner.read_freg_u64(8), exec_test_f32_bits(-17.0).to_uint64())
  assert_eq(runner.read_freg_u64(13), exec_test_f32_bits(1024.0).to_uint64())
  assert_eq(runner.read_reg_u64(14), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(15), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(16), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(17), (-2L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(18), 42U.to_uint64())
}

///|
test "rv64f int to single conversion honors non-rne rounding modes" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_reg(1, 0x01000001U.to_uint64())
  runner.load_program(
    words_to_bytes([encode_fcvt_s_w(1, 0x1U, 2), encode_fcvt_s_wu(1, 0x3U, 3)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE fcvt.s.w paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x4b800000U.to_uint64())
  assert_eq(runner.read_freg_u64(3), 0x4b800001U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64f int to single conversion honors dynamic frm" {
  let runner = make_runner(rv64f_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  runner.cpu.write_reg(1, 0x01000001U.to_uint64())
  runner.cpu.write_csr(csr_fcsr, 0x4U.to_uint64() << fcsr_frm_shift)
  runner.load_program(words_to_bytes([encode_fcvt_s_w(1, 0x7U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RMM fcvt.s.w to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x4b800001U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd integer to float conversions reject reserved rounding modes" {
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let reserved_static_single = encode_fcvt_s_w(1, 0x5U, 2)
  let reserved_dynamic_single = encode_fcvt_s_lu(1, 0x7U, 3)
  let reserved_static_double = encode_fcvt_d_l(1, 0x6U, 4)

  let single_static = make_runner(rv64f_machine_config())
  single_static.cpu.write_reg(1, 42U.to_uint64())
  single_static.load_program(words_to_bytes([reserved_static_single]), 0U)
  match single_static.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static_single.to_uint64())
    }
    _ => fail("expected reserved static fcvt.s.w rounding mode to trap")
  }

  let single_dynamic = make_runner(rv64f_machine_config())
  single_dynamic.cpu.write_reg(1, 42U.to_uint64())
  single_dynamic.cpu.write_csr(csr_fcsr, 0x6U.to_uint64() << fcsr_frm_shift)
  single_dynamic.load_program(words_to_bytes([reserved_dynamic_single]), 0U)
  match single_dynamic.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_dynamic_single.to_uint64())
    }
    _ => fail("expected reserved dynamic fcvt.s.lu rounding mode to trap")
  }

  let double_static = make_runner(rv64fd_machine_config())
  double_static.cpu.write_reg(1, 42U.to_uint64())
  double_static.load_program(words_to_bytes([reserved_static_double]), 0U)
  match double_static.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static_double.to_uint64())
    }
    _ => fail("expected reserved static fcvt.d.l rounding mode to trap")
  }
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
test "rv64f fflags writes preserve frm field" {
  let csr_fflags = 0x001
  let csr_frm = 0x002
  let csr_fcsr = 0x003
  let program = words_to_bytes([
    encode_i(0x9f, 0, 0x0U, 1, 0x13U),
    encode_csr(csr_fcsr, 1, 0x1U, 0),
    encode_i(0x02, 0, 0x0U, 4, 0x13U),
    encode_csr(csr_fflags, 4, 0x1U, 5),
    encode_csr(csr_frm, 0, 0x2U, 6),
    encode_csr(csr_fcsr, 0, 0x2U, 7),
    encode_csr(csr_fflags, 0, 0x1U, 0),
    encode_csr(csr_fcsr, 0, 0x2U, 8),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected fflags alias write path to run")
  }
  // fflags and frm are views into fcsr, not independent storage. A write to
  // fflags replaces only the accrued-exception field, including the zero write
  // software uses to clear flags after inspecting them.
  assert_eq(runner.read_reg_u64(5), 0x1fU.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0x04U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 0x82U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 0x80U.to_uint64())
  assert_eq(runner.read_csr(csr_fflags), 0U)
  assert_eq(runner.read_csr(csr_frm), 0x04U)
  assert_eq(runner.read_csr(csr_fcsr), 0x80U)
}

///|
test "rv64fd arithmetic exception flags accrue until software clears them" {
  let csr_fcsr = 0x003
  let nx = 0x01U.to_uint64()
  let dz = 0x08U.to_uint64()
  let nv = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(
    2,
    exec_test_nan_box_single(exec_test_f32_bits(16777216.0)),
  )
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(0.0)))
  runner.cpu.write_freg(4, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(5, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(7, exec_test_f64_bits(9007199254740992.0))
  runner.cpu.write_freg(8, exec_test_f64_bits(0.0))
  runner.cpu.write_freg(9, 0x7ff0000000000000UL)
  runner.cpu.write_freg(10, 0xfff0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_fp_r(0x0cU, 3, 1, 0x0U, 21),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_fp_r(0x00U, 5, 4, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 7, 6, 0x0U, 23),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_fp_r(0x0dU, 8, 6, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_fp_r(0x01U, 10, 9, 0x0U, 25),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
    ]),
    0U,
  )
  match runner.run(13) {
    Running => ()
    _ => fail("expected arithmetic fflags accumulation path to run")
  }
  // fflags are accrued state, not a per-instruction result register. These
  // reads pin that NX, DZ, and NV remain set until the explicit fcsr write.
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), nx)
  assert_eq(runner.read_reg_u64(12) & 0x1fU.to_uint64(), nx | dz)
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), nx | dz | nv)
  assert_eq(runner.read_reg_u64(14) & 0x1fU.to_uint64(), nx)
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), nx | dz)
  assert_eq(runner.read_reg_u64(16) & 0x1fU.to_uint64(), nx | dz | nv)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, (nx | dz | nv).to_uint())
}

///|
test "rv64f floating-point csr pure reads do not dirty fs" {
  let csr_fflags = 0x001
  let csr_frm = 0x002
  let csr_fcsr = 0x003
  let mstatus = 0x300
  let fs_initial = 0x2000U.to_uint64()
  let fs_dirty = 0x6000U.to_uint64()
  let sd_bit = 1U.to_uint64() << 63
  let runner = make_runner(rv64f_machine_config())
  assert_eq(runner.read_csr_u64(mstatus) & fs_dirty, fs_initial)
  runner.load_program(
    words_to_bytes([
      encode_csr(csr_fflags, 0, 0x2U, 1), // CSRRS x1, fflags, x0
      encode_csr(csr_frm, 0, 0x3U, 2), // CSRRC x2, frm, x0
      encode_csr(csr_fcsr, 0, 0x6U, 3), // CSRRSI x3, fcsr, 0
      encode_csr(csr_fcsr, 0, 0x7U, 4), // CSRRCI x4, fcsr, 0
      encode_csr(mstatus, 0, 0x2U, 5),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected pure FP CSR reads to run")
  }
  // FS=Initial means the FP context is valid but clean. Pure CSR reads and
  // zero-mask set/clear forms must not turn that context into FS=Dirty.
  assert_eq(runner.read_reg_u64(5) & fs_dirty, fs_initial)
  assert_eq(runner.read_reg_u64(5) & sd_bit, 0U.to_uint64())
  assert_eq(runner.read_csr_u64(mstatus) & fs_dirty, fs_initial)
  assert_eq(runner.read_csr_u64(mstatus) & sd_bit, 0U.to_uint64())
}

///|
test "rv64f fcsr reserved high bits read as zero" {
  let csr_fcsr = 0x003
  let program = words_to_bytes([
    encode_u(0xfffff000U, 1, 0x37U),
    encode_i(-1, 1, 0x0U, 1, 0x13U),
    encode_csr(csr_fcsr, 1, 0x1U, 0),
    encode_csr(csr_fcsr, 0, 0x2U, 2),
  ])
  let runner = make_runner(rv64f_machine_config())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected fcsr reserved-bit program to run")
  }
  assert_eq(runner.read_reg(2), 0xffU)
  assert_eq(runner.read_csr(csr_fcsr), 0xffU)
}

///|
test "rv64f traps floating-point csr access when mstatus fs is off" {
  let fp_csrs = [0x001, 0x002, 0x003]
  for csr in fp_csrs {
    let read_raw = encode_csr(csr, 0, 0x2U, 1)
    let read_runner = make_runner(rv64f_machine_config())
    read_runner.cpu.write_csr(0x300, 0U.to_uint64())
    read_runner.load_program(words_to_bytes([read_raw]), 0U)
    match read_runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, read_raw.to_uint64())
      }
      _ => fail("expected floating-point csr read to trap when FS=Off")
    }

    let write_raw = encode_csr(csr, 1, 0x1U, 0)
    let write_runner = make_runner(rv64f_machine_config())
    write_runner.cpu.write_csr(0x300, 0U.to_uint64())
    write_runner.load_program(
      words_to_bytes([encode_i(1, 0, 0x0U, 1, 0x13U), write_raw]),
      0U,
    )
    match write_runner.run(2) {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, write_raw.to_uint64())
      }
      _ => fail("expected floating-point csr write to trap when FS=Off")
    }
  }
}

///|
test "rv64f traps on reserved arithmetic rounding mode" {
  let two = exec_test_f32_bits(2.0)
  let program = words_to_bytes([
    encode_flw(0x100, 0, 2),
    encode_flw(0x104, 0, 3),
    encode_fp_r(0x00U, 3, 2, 0x5U, 4),
  ])
  let raw = encode_fp_r(0x00U, 3, 2, 0x5U, 4)
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
    _ => fail("expected reserved rounding mode to trap")
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
test "rv64f traps floating-point instructions when mstatus fs is off" {
  let fp_words = [
    encode_flw(0x100, 0, 1),
    encode_fp_r(0x00U, 2, 1, 0x0U, 3),
    encode_fclass_s(1, 2),
    encode_fmv_x_w(1, 2),
  ]
  for raw in fp_words {
    let runner = make_runner(rv64f_machine_config())
    runner.cpu.write_csr(0x300, 0U.to_uint64())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected scalar f instruction to trap when FS=Off")
    }
  }
}

///|
test "rv64f fp register writes mark mstatus fs dirty" {
  let runner = make_runner(rv64f_machine_config())
  assert_eq(
    runner.read_csr_u64(0x300) & 0x6000U.to_uint64(),
    0x2000U.to_uint64(),
  )
  runner.load_program(words_to_bytes([0x3f800000U]), 0x100U)
  runner.load_program(words_to_bytes([encode_flw(0x100, 0, 1)]), 0U)
  match runner.step() {
    Running => ()
    _ => fail("expected flw to run with FS enabled")
  }
  let status = runner.read_csr_u64(0x300)
  assert_eq(status & 0x6000U.to_uint64(), 0x6000U.to_uint64())
  assert_eq(status & 0x8000000000000000UL, 0x8000000000000000UL)
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
test "rv64fd fused multiply-add single paths execute" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(2.0)))
  runner.cpu.write_freg(2, exec_test_nan_box_single(exec_test_f32_bits(3.0)))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(4.0)))
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 4, 0x43U),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 5, 0x47U),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 6, 0x4bU),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 7, 0x4fU),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64fd single fma paths to run")
  }
  assert_eq(
    runner.read_freg_u64(4),
    exec_test_nan_box_single(exec_test_f32_bits(10.0)),
  )
  assert_eq(
    runner.read_freg_u64(5),
    exec_test_nan_box_single(exec_test_f32_bits(2.0)),
  )
  assert_eq(
    runner.read_freg_u64(6),
    exec_test_nan_box_single(exec_test_f32_bits(-2.0)),
  )
  assert_eq(
    runner.read_freg_u64(7),
    exec_test_nan_box_single(exec_test_f32_bits(-10.0)),
  )
}

///|
test "rv64fd fused multiply-add single paths honor non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let pos_large = exec_test_nan_box_single(0x4b800000U)
  let neg_large = exec_test_nan_box_single(0xcb800000U)
  let pos_one = exec_test_nan_box_single(exec_test_f32_bits(1.0))
  let neg_one = exec_test_nan_box_single(exec_test_f32_bits(-1.0))
  runner.cpu.write_freg(1, pos_large)
  runner.cpu.write_freg(2, pos_one)
  runner.cpu.write_freg(3, pos_one)
  runner.cpu.write_freg(4, neg_one)
  runner.cpu.write_freg(5, neg_large)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x1U, 8, 0x43U),
      encode_fp_r4(3, 0x0U, 2, 1, 0x3U, 9, 0x43U),
      encode_fp_r4(4, 0x0U, 2, 1, 0x1U, 10, 0x47U),
      encode_fp_r4(4, 0x0U, 2, 1, 0x3U, 11, 0x47U),
      encode_fp_r4(3, 0x0U, 2, 5, 0x1U, 12, 0x4bU),
      encode_fp_r4(3, 0x0U, 2, 5, 0x3U, 13, 0x4bU),
      encode_fp_r4(4, 0x0U, 2, 5, 0x1U, 14, 0x4fU),
      encode_fp_r4(4, 0x0U, 2, 5, 0x3U, 15, 0x4fU),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE single FMA paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(8), exec_test_nan_box_single(0x4b800000U))
  assert_eq(runner.read_freg_u64(9), exec_test_nan_box_single(0x4b800001U))
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x4b800000U))
  assert_eq(runner.read_freg_u64(11), exec_test_nan_box_single(0x4b800001U))
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x4b800000U))
  assert_eq(runner.read_freg_u64(13), exec_test_nan_box_single(0x4b800001U))
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x4b800000U))
  assert_eq(runner.read_freg_u64(15), exec_test_nan_box_single(0x4b800001U))
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd fused multiply-add single path does not round intermediate product" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  // (1 + 2^-23) * (1 - 2^-24) is just below the RNE midpoint above 1.0, so a
  // separately rounded multiply would become exactly 1.0 and then cancel with
  // -1.0. FMADD.S must instead add the exact product and round once, producing
  // the exactly representable positive single just below 2^-24.
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x3f800001U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x3f7fffffU))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.load_program(
    words_to_bytes([encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 4, 0x43U)]),
    0U,
  )
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected fused single-rounding FMADD.S to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(4), exec_test_nan_box_single(0x337ffffeU))
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
}

///|
test "rv64fd fused multiply-add honors dynamic rounding mode" {
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5

  let single_rup = make_runner(rv64fd_machine_config())
  single_rup.cpu.write_csr(csr_fcsr, 0x3U.to_uint64() << fcsr_frm_shift)
  single_rup.cpu.write_freg(1, exec_test_nan_box_single(0x4b800000U))
  single_rup.cpu.write_freg(
    2,
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  single_rup.cpu.write_freg(
    3,
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  single_rup.load_program(
    words_to_bytes([encode_fp_r4(3, 0x0U, 2, 1, 0x7U, 4, 0x43U)]),
    0U,
  )
  match single_rup.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RUP single FMA to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(single_rup.read_freg_u64(4), exec_test_nan_box_single(0x4b800001U))
  assert_eq(single_rup.read_csr(csr_fcsr) & 0x1U, 0x1U)

  let single_family_rup = make_runner(rv64fd_machine_config())
  single_family_rup.cpu.write_csr(csr_fcsr, 0x3U.to_uint64() << fcsr_frm_shift)
  single_family_rup.cpu.write_freg(1, exec_test_nan_box_single(0x4b800000U))
  single_family_rup.cpu.write_freg(
    2,
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  single_family_rup.cpu.write_freg(
    3,
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  single_family_rup.cpu.write_freg(
    4,
    exec_test_nan_box_single(exec_test_f32_bits(-1.0)),
  )
  single_family_rup.cpu.write_freg(5, exec_test_nan_box_single(0xcb800000U))
  single_family_rup.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x7U, 8, 0x43U),
      encode_fp_r4(4, 0x0U, 2, 1, 0x7U, 9, 0x47U),
      encode_fp_r4(3, 0x0U, 2, 5, 0x7U, 10, 0x4bU),
      encode_fp_r4(4, 0x0U, 2, 5, 0x7U, 11, 0x4fU),
    ]),
    0U,
  )
  match single_family_rup.run(4) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RUP single FMA family to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  for rd in 8..<=11 {
    assert_eq(
      single_family_rup.read_freg_u64(rd),
      exec_test_nan_box_single(0x4b800001U),
    )
  }
  assert_eq(single_family_rup.read_csr(csr_fcsr) & 0x1U, 0x1U)

  let double_rtz = make_runner(rv64fd_machine_config())
  double_rtz.cpu.write_csr(csr_fcsr, 0x1U.to_uint64() << fcsr_frm_shift)
  double_rtz.cpu.write_freg(1, 0x4340000000000000UL)
  double_rtz.cpu.write_freg(2, exec_test_f64_bits(1.0))
  double_rtz.cpu.write_freg(3, exec_test_f64_bits(1.0))
  double_rtz.load_program(
    words_to_bytes([encode_fp_r4(3, 0x1U, 2, 1, 0x7U, 4, 0x43U)]),
    0U,
  )
  match double_rtz.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RTZ double FMA to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(double_rtz.read_freg_u64(4), 0x4340000000000000UL)
  assert_eq(double_rtz.read_csr(csr_fcsr) & 0x1U, 0x1U)

  let double_family_rtz = make_runner(rv64fd_machine_config())
  double_family_rtz.cpu.write_csr(csr_fcsr, 0x1U.to_uint64() << fcsr_frm_shift)
  double_family_rtz.cpu.write_freg(1, 0x4340000000000000UL)
  double_family_rtz.cpu.write_freg(2, exec_test_f64_bits(1.0))
  double_family_rtz.cpu.write_freg(3, exec_test_f64_bits(1.0))
  double_family_rtz.cpu.write_freg(4, exec_test_f64_bits(-1.0))
  double_family_rtz.cpu.write_freg(5, 0xc340000000000000UL)
  double_family_rtz.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x1U, 2, 1, 0x7U, 8, 0x43U),
      encode_fp_r4(4, 0x1U, 2, 1, 0x7U, 9, 0x47U),
      encode_fp_r4(3, 0x1U, 2, 5, 0x7U, 10, 0x4bU),
      encode_fp_r4(4, 0x1U, 2, 5, 0x7U, 11, 0x4fU),
    ]),
    0U,
  )
  match double_family_rtz.run(4) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RTZ double FMA family to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  for rd in 8..<=11 {
    assert_eq(double_family_rtz.read_freg_u64(rd), 0x4340000000000000UL)
  }
  assert_eq(double_family_rtz.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd fused multiply-add rejects reserved rounding modes" {
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let reserved_static_single = encode_fp_r4(3, 0x0U, 2, 1, 0x5U, 4, 0x43U)
  let reserved_dynamic_double = encode_fp_r4(3, 0x1U, 2, 1, 0x7U, 4, 0x4fU)

  let single_static = make_runner(rv64fd_machine_config())
  single_static.load_program(words_to_bytes([reserved_static_single]), 0U)
  match single_static.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static_single.to_uint64())
    }
    _ => fail("expected reserved static single FMA rounding mode to trap")
  }

  let double_dynamic = make_runner(rv64fd_machine_config())
  double_dynamic.cpu.write_csr(csr_fcsr, 0x6U.to_uint64() << fcsr_frm_shift)
  double_dynamic.load_program(words_to_bytes([reserved_dynamic_double]), 0U)
  match double_dynamic.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_dynamic_double.to_uint64())
    }
    _ => fail("expected reserved dynamic double FMA rounding mode to trap")
  }
}

///|
test "rv64fd fused multiply-add single paths preserve exact zero signs" {
  let runner = make_runner(rv64fd_machine_config())
  let pos_one = exec_test_nan_box_single(exec_test_f32_bits(1.0))
  let neg_one = exec_test_nan_box_single(exec_test_f32_bits(-1.0))
  let neg_zero = exec_test_nan_box_single(0x80000000U)
  runner.cpu.write_freg(1, pos_one)
  runner.cpu.write_freg(2, pos_one)
  runner.cpu.write_freg(3, pos_one)
  runner.cpu.write_freg(4, neg_one)
  runner.cpu.write_freg(5, neg_zero)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 6, 0x47U),
      encode_fp_r4(3, 0x0U, 2, 1, 0x2U, 7, 0x47U),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 8, 0x4bU),
      encode_fp_r4(3, 0x0U, 2, 1, 0x2U, 9, 0x4bU),
      encode_fp_r4(3, 0x0U, 2, 4, 0x0U, 10, 0x43U),
      encode_fp_r4(3, 0x0U, 2, 4, 0x2U, 11, 0x43U),
      encode_fp_r4(3, 0x0U, 2, 4, 0x0U, 12, 0x4fU),
      encode_fp_r4(3, 0x0U, 2, 4, 0x2U, 13, 0x4fU),
      encode_fp_r4(5, 0x0U, 5, 1, 0x0U, 14, 0x43U),
    ]),
    0U,
  )
  match runner.run(9) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero single FMA paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(6), exec_test_nan_box_single(0x00000000U))
  assert_eq(runner.read_freg_u64(7), exec_test_nan_box_single(0x80000000U))
  assert_eq(runner.read_freg_u64(8), exec_test_nan_box_single(0x00000000U))
  assert_eq(runner.read_freg_u64(9), exec_test_nan_box_single(0x80000000U))
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x00000000U))
  assert_eq(runner.read_freg_u64(11), exec_test_nan_box_single(0x80000000U))
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x00000000U))
  assert_eq(runner.read_freg_u64(13), exec_test_nan_box_single(0x80000000U))
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x80000000U))
}

///|
test "rv64fd fused multiply-add double paths execute" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(2.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(3.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(4.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 4, 0x43U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 5, 0x47U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 6, 0x4bU),
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 7, 0x4fU),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected rv64fd double fma paths to run")
  }
  assert_eq(runner.read_freg_u64(4), exec_test_f64_bits(10.0))
  assert_eq(runner.read_freg_u64(5), exec_test_f64_bits(2.0))
  assert_eq(runner.read_freg_u64(6), exec_test_f64_bits(-2.0))
  assert_eq(runner.read_freg_u64(7), exec_test_f64_bits(-10.0))
}

///|
test "rv64fd fused multiply-add double paths honor non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x4340000000000000UL)
  runner.cpu.write_freg(2, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(4, 0xc340000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(2, 0x1U, 2, 1, 0x1U, 8, 0x43U),
      encode_fp_r4(2, 0x1U, 2, 1, 0x3U, 9, 0x43U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x1U, 10, 0x47U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x3U, 11, 0x47U),
      encode_fp_r4(2, 0x1U, 2, 4, 0x1U, 12, 0x4bU),
      encode_fp_r4(2, 0x1U, 2, 4, 0x3U, 13, 0x4bU),
      encode_fp_r4(3, 0x1U, 2, 4, 0x1U, 14, 0x4fU),
      encode_fp_r4(3, 0x1U, 2, 4, 0x3U, 15, 0x4fU),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE double FMA paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(8), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(9), 0x4340000000000001UL)
  assert_eq(runner.read_freg_u64(10), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(11), 0x4340000000000001UL)
  assert_eq(runner.read_freg_u64(12), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(13), 0x4340000000000001UL)
  assert_eq(runner.read_freg_u64(14), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(15), 0x4340000000000001UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd fused multiply-add double path does not round intermediate product" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  // This mirrors the single-precision fused-contract regression at binary64
  // precision. Separately rounding the product gives exactly 1.0, which would
  // cancel with -1.0. The fused operation keeps the exact product through the
  // addend and produces the exact positive double just below 2^-53.
  runner.cpu.write_freg(1, 0x3ff0000000000001UL)
  runner.cpu.write_freg(2, 0x3fefffffffffffffUL)
  runner.cpu.write_freg(3, exec_test_f64_bits(-1.0))
  runner.load_program(
    words_to_bytes([encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 4, 0x43U)]),
    0U,
  )
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected fused single-rounding FMADD.D to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(4), 0x3c9ffffffffffffeUL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
}

///|
test "rv64fd fused multiply-add double paths preserve exact zero signs" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(4, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(5, 0x8000000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 6, 0x47U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x2U, 7, 0x47U),
      encode_fp_r4(3, 0x1U, 2, 1, 0x0U, 8, 0x4bU),
      encode_fp_r4(3, 0x1U, 2, 1, 0x2U, 9, 0x4bU),
      encode_fp_r4(3, 0x1U, 2, 4, 0x0U, 10, 0x43U),
      encode_fp_r4(3, 0x1U, 2, 4, 0x2U, 11, 0x43U),
      encode_fp_r4(3, 0x1U, 2, 4, 0x0U, 12, 0x4fU),
      encode_fp_r4(3, 0x1U, 2, 4, 0x2U, 13, 0x4fU),
      encode_fp_r4(5, 0x1U, 5, 1, 0x0U, 14, 0x43U),
    ]),
    0U,
  )
  match runner.run(9) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero double FMA paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(6), 0x0000000000000000UL)
  assert_eq(runner.read_freg_u64(7), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(8), 0x0000000000000000UL)
  assert_eq(runner.read_freg_u64(9), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(10), 0x0000000000000000UL)
  assert_eq(runner.read_freg_u64(11), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(12), 0x0000000000000000UL)
  assert_eq(runner.read_freg_u64(13), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(14), 0x8000000000000000UL)
}

///|
test "rv64fd add sub mul honor non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x4340000000000000UL)
  runner.cpu.write_freg(2, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(4, 0x3ff0000000000001UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x01U, 2, 1, 0x1U, 5),
      encode_fp_r(0x01U, 2, 1, 0x3U, 6),
      encode_fp_r(0x05U, 3, 1, 0x1U, 7),
      encode_fp_r(0x05U, 3, 1, 0x3U, 8),
      encode_fp_r(0x09U, 4, 4, 0x1U, 9),
      encode_fp_r(0x09U, 4, 4, 0x3U, 10),
    ]),
    0U,
  )
  match runner.run(6) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE rv64fd add/sub/mul to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(6), 0x4340000000000001UL)
  assert_eq(runner.read_freg_u64(7), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(8), 0x4340000000000001UL)
  assert_eq(runner.read_freg_u64(9), 0x3ff0000000000002UL)
  assert_eq(runner.read_freg_u64(10), 0x3ff0000000000003UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd add sub mul honor dynamic rounding mode" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // Dynamic RDN must select the lower adjacent double result for each ordinary
  // arithmetic operation when rm=111 delegates the choice to frm.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, 0x4340000000000000UL)
  runner.cpu.write_freg(2, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(4, 0x3ff0000000000001UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x01U, 2, 1, 0x7U, 5),
      encode_fp_r(0x05U, 3, 1, 0x7U, 6),
      encode_fp_r(0x09U, 4, 4, 0x7U, 7),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN rv64fd add/sub/mul to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(6), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(7), 0x3ff0000000000002UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd add sub mul preserve exact zero signs" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(0.0))
  runner.cpu.write_freg(2, 0x8000000000000000UL)
  runner.cpu.write_freg(3, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x01U, 2, 1, 0x2U, 4),
      encode_fp_r(0x01U, 2, 1, 0x3U, 5),
      encode_fp_r(0x01U, 2, 2, 0x3U, 6),
      encode_fp_r(0x05U, 1, 1, 0x2U, 7),
      encode_fp_r(0x09U, 3, 2, 0x0U, 8),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero double arithmetic to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(4), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(5), 0x0000000000000000UL)
  assert_eq(runner.read_freg_u64(6), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(7), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(8), 0x8000000000000000UL)
}

///|
test "rv64fd single add sub mul preserve exact zero signs" {
  let runner = make_runner(rv64fd_machine_config())
  let pos_zero = exec_test_nan_box_single(0x00000000U)
  let neg_zero = exec_test_nan_box_single(0x80000000U)
  let pos_one = exec_test_nan_box_single(exec_test_f32_bits(1.0))
  let neg_one = exec_test_nan_box_single(exec_test_f32_bits(-1.0))
  runner.cpu.write_freg(1, pos_zero)
  runner.cpu.write_freg(2, neg_zero)
  runner.cpu.write_freg(3, pos_one)
  runner.cpu.write_freg(4, neg_one)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x2U, 5),
      encode_fp_r(0x00U, 2, 1, 0x0U, 6),
      encode_fp_r(0x00U, 2, 2, 0x3U, 7),
      encode_fp_r(0x04U, 3, 3, 0x2U, 8),
      encode_fp_r(0x04U, 1, 1, 0x0U, 9),
      encode_fp_r(0x08U, 2, 3, 0x0U, 10),
      encode_fp_r(0x08U, 2, 4, 0x0U, 11),
    ]),
    0U,
  )
  match runner.run(7) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero single arithmetic to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), neg_zero)
  assert_eq(runner.read_freg_u64(6), pos_zero)
  assert_eq(runner.read_freg_u64(7), neg_zero)
  assert_eq(runner.read_freg_u64(8), neg_zero)
  assert_eq(runner.read_freg_u64(9), pos_zero)
  assert_eq(runner.read_freg_u64(10), neg_zero)
  assert_eq(runner.read_freg_u64(11), pos_zero)
}

///|
test "rv64fd div honors non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(3.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0dU, 2, 1, 0x1U, 3),
      encode_fp_r(0x0dU, 2, 1, 0x3U, 4),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE rv64fd div to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), 0x3fd5555555555555UL)
  assert_eq(runner.read_freg_u64(4), 0x3fd5555555555556UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd div honors dynamic rounding mode" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // Dynamic RDN must select the lower adjacent double quotient for 1.0 / 3.0.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(3.0))
  runner.load_program(words_to_bytes([encode_fp_r(0x0dU, 2, 1, 0x7U, 3)]), 0U)
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN FDIV.D to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), 0x3fd5555555555555UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd div preserves exact zero signs" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(0.0))
  runner.cpu.write_freg(2, 0x8000000000000000UL)
  runner.cpu.write_freg(3, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(4, exec_test_f64_bits(-1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0dU, 3, 2, 0x0U, 5),
      encode_fp_r(0x0dU, 4, 1, 0x0U, 6),
      encode_fp_r(0x0dU, 4, 2, 0x0U, 7),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact-zero double division to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(6), 0x8000000000000000UL)
  assert_eq(runner.read_freg_u64(7), 0x0000000000000000UL)
}

///|
test "rv64fd div accrues underflow and inexact for tiny quotients" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x00800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(exec_test_f32_bits(3.0)))
  runner.cpu.write_freg(3, 0x0010000000000000UL)
  runner.cpu.write_freg(4, exec_test_f64_bits(3.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 2, 1, 0x0U, 5),
      encode_csr(csr_fcsr, 0, 0x2U, 6),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 4, 3, 0x0U, 7),
      encode_csr(csr_fcsr, 0, 0x2U, 8),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    Trap(info) =>
      fail(
        "expected tiny quotient divide paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(5), exec_test_nan_box_single(0x002aaaabU))
  assert_eq(runner.read_reg_u64(6) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x0005555555555555UL)
  assert_eq(runner.read_reg_u64(8) & 0x3U.to_uint64(), 0x3U.to_uint64())
}

///|
test "rv64fd mul accrues underflow and inexact for tiny products" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x00800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x3eaaaaabU))
  runner.cpu.write_freg(3, 0x0010000000000000UL)
  runner.cpu.write_freg(4, 0x3fd5555555555555UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x08U, 2, 1, 0x0U, 5),
      encode_csr(csr_fcsr, 0, 0x2U, 6),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 4, 3, 0x0U, 7),
      encode_csr(csr_fcsr, 0, 0x2U, 8),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    Trap(info) =>
      fail(
        "expected tiny product multiply paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // These products are tiny after rounding and inexact, so IEEE/RISC-V
  // tininess-after-rounding requires both UF and NX to become sticky.
  assert_eq(runner.read_freg_u64(5), exec_test_nan_box_single(0x002aaaabU))
  assert_eq(runner.read_reg_u64(6) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(7), 0x0005555555555555UL)
  assert_eq(runner.read_reg_u64(8) & 0x3U.to_uint64(), 0x3U.to_uint64())
}

///|
test "rv64fd fused multiply-add family accrues underflow and inexact for tiny products" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x00800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x3eaaaaabU))
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x00000000U))
  runner.cpu.write_freg(4, 0x0010000000000000UL)
  runner.cpu.write_freg(5, 0x3fd5555555555555UL)
  runner.cpu.write_freg(6, 0x0000000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 7, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 8),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 9, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 10),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 11, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 13, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 5, 4, 0x0U, 15, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 5, 4, 0x0U, 17, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 5, 4, 0x0U, 19, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 20),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 5, 4, 0x0U, 21, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 22),
    ]),
    0U,
  )
  match runner.run(23) {
    Running => ()
    Trap(info) =>
      fail(
        "expected tiny product fused multiply-add family paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // The addend is exact +0, so these cases isolate the fused single-rounding
  // path. FNMSUB/FNMADD negate only the product term, giving a negative tiny
  // result while preserving the same UF|NX sticky-flag requirement.
  assert_eq(runner.read_freg_u64(7), exec_test_nan_box_single(0x002aaaabU))
  assert_eq(runner.read_reg_u64(8) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(9), exec_test_nan_box_single(0x002aaaabU))
  assert_eq(runner.read_reg_u64(10) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(11), exec_test_nan_box_single(0x802aaaabU))
  assert_eq(runner.read_reg_u64(12) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(13), exec_test_nan_box_single(0x802aaaabU))
  assert_eq(runner.read_reg_u64(14) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(15), 0x0005555555555555UL)
  assert_eq(runner.read_reg_u64(16) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(17), 0x0005555555555555UL)
  assert_eq(runner.read_reg_u64(18) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(19), 0x8005555555555555UL)
  assert_eq(runner.read_reg_u64(20) & 0x3U.to_uint64(), 0x3U.to_uint64())
  assert_eq(runner.read_freg_u64(21), 0x8005555555555555UL)
  assert_eq(runner.read_reg_u64(22) & 0x3U.to_uint64(), 0x3U.to_uint64())
}

///|
test "rv64fd sqrt honors non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_f64_bits(2.0))
  runner.load_program(
    words_to_bytes([encode_fsqrt_d(1, 0x1U, 2), encode_fsqrt_d(1, 0x3U, 3)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE rv64fd sqrt to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x3ff6a09e667f3bccUL)
  assert_eq(runner.read_freg_u64(3), 0x3ff6a09e667f3bcdUL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd sqrt honors dynamic rounding mode" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  // rm=111 selects fcsr.frm. Use RDN so sqrt(2.0) must choose the lower
  // adjacent double and still accrue NX for the inexact square root.
  runner.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  runner.cpu.write_freg(1, exec_test_f64_bits(2.0))
  runner.load_program(words_to_bytes([encode_fsqrt_d(1, 0x7U, 2)]), 0U)
  match runner.step() {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN FSQRT.D to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x3ff6a09e667f3bccUL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd sqrt exact squares stay flag clean" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_f64_bits(4.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(0.25))
  runner.load_program(
    words_to_bytes([encode_fsqrt_d(1, 0x0U, 3), encode_fsqrt_d(2, 0x4U, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected exact double square roots to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(2.0))
  assert_eq(runner.read_freg_u64(4), exec_test_f64_bits(0.5))
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
}

///|
test "rv64fd fused multiply-add accrues invalid for infinity times zero" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x00000000U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(4, 0x7ff0000000000000UL)
  runner.cpu.write_freg(5, 0x0000000000000000UL)
  runner.cpu.write_freg(6, 0x7ff8000000000000UL)
  runner.cpu.write_freg(7, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(8, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(9, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(15, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(16, 0xfff0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(3, 0x0U, 2, 1, 0x0U, 10, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 5, 4, 0x0U, 12, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(8, 0x0U, 8, 7, 0x0U, 14, 0x43U),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(9, 0x0U, 8, 1, 0x0U, 20, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(4, 0x1U, 15, 4, 0x0U, 21, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      // FNMSUB/FNMADD negate only the product term in RISC-V. These cases
      // would be missed by a helper that modeled the MIPS-style negated sum.
      encode_fp_r4(1, 0x0U, 8, 1, 0x0U, 22, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(9, 0x0U, 8, 1, 0x0U, 23, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 22),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(4, 0x1U, 15, 4, 0x0U, 24, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(16, 0x1U, 15, 4, 0x0U, 25, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 24),
    ]),
    0U,
  )
  match runner.run(25) {
    Running => ()
    _ => fail("expected fma invalid flag path to run")
  }
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(18) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(19) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(22) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(23) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(24) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x10U, 0x10U)
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(12), 0x7ff8000000000000UL)
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(20), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(21), 0x7ff8000000000000UL)
  assert_eq(runner.read_freg_u64(22), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(23), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_freg_u64(24), 0x7ff8000000000000UL)
  assert_eq(runner.read_freg_u64(25), 0x7ff8000000000000UL)
}

///|
test "rv64fd fused multiply-add nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, exec_test_nan_box_single(exec_test_f32_bits(2.0)))
  runner.cpu.write_freg(5, 0x7ff8000000000001UL)
  runner.cpu.write_freg(6, 0x7ff0000000000001UL)
  runner.cpu.write_freg(7, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(8, exec_test_f64_bits(2.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(1, 0x0U, 4, 3, 0x0U, 10, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 10),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(1, 0x0U, 4, 3, 0x0U, 11, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(1, 0x0U, 4, 3, 0x0U, 12, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(1, 0x0U, 4, 3, 0x0U, 13, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(2, 0x0U, 4, 3, 0x0U, 14, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(2, 0x0U, 4, 3, 0x0U, 15, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(2, 0x0U, 4, 3, 0x0U, 16, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(2, 0x0U, 4, 3, 0x0U, 17, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(5, 0x1U, 8, 7, 0x0U, 18, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(5, 0x1U, 8, 7, 0x0U, 19, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(5, 0x1U, 8, 7, 0x0U, 20, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 20),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(5, 0x1U, 8, 7, 0x0U, 21, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 8, 7, 0x0U, 22, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 22),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 8, 7, 0x0U, 23, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 8, 7, 0x0U, 24, 0x4bU),
      encode_csr(csr_fcsr, 0, 0x2U, 24),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(6, 0x1U, 8, 7, 0x0U, 25, 0x4fU),
      encode_csr(csr_fcsr, 0, 0x2U, 25),
    ]),
    0U,
  )
  match runner.run(47) {
    Running => ()
    _ => fail("expected fma NaN operand cases to retire")
  }
  // Quiet NaN addends use the ordinary canonical-NaN default result without
  // flags. Signaling NaNs enter the invalid-operation path for every FMA
  // opcode, but still write the same canonical NaN result.
  for rd in 10..<=13 {
    assert_eq(runner.read_freg_u64(rd), exec_test_nan_box_single(0x7fc00000U))
    assert_eq(runner.read_reg_u64(rd) & flag_mask, 0U.to_uint64())
  }
  for rd in 14..<=17 {
    assert_eq(runner.read_freg_u64(rd), exec_test_nan_box_single(0x7fc00000U))
    assert_eq(runner.read_reg_u64(rd) & flag_mask, invalid_only)
  }
  for rd in 18..<=21 {
    assert_eq(runner.read_freg_u64(rd), exec_test_f64_canonical_nan_bits())
    assert_eq(runner.read_reg_u64(rd) & flag_mask, 0U.to_uint64())
  }
  for rd in 22..<=25 {
    assert_eq(runner.read_freg_u64(rd), exec_test_f64_canonical_nan_bits())
    assert_eq(runner.read_reg_u64(rd) & flag_mask, invalid_only)
  }
}

///|
test "rv64fd fused multiply-add multiplicand nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f812345U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, exec_test_nan_box_single(exec_test_f32_bits(2.0)))
  runner.cpu.write_freg(5, 0x7ff8000000001234UL)
  runner.cpu.write_freg(6, 0x7ff0000000001234UL)
  runner.cpu.write_freg(7, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(8, exec_test_f64_bits(2.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r4(4, 0x0U, 3, 1, 0x0U, 10, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(4, 0x0U, 2, 3, 0x0U, 12, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(8, 0x1U, 5, 7, 0x0U, 14, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(8, 0x1U, 7, 6, 0x0U, 16, 0x47U),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected fma multiplicand NaN cases to retire")
  }
  // Multiplicand NaNs follow the same default-result rule as NaN addends:
  // quiet NaNs are flag-clean, while signaling NaNs accrue NV.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
}

///|
test "rv64fd scalar arithmetic accrues invalid and divide by zero flags" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x00000000U))
  runner.cpu.write_freg(4, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(5, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.cpu.write_freg(6, 0x7ff0000000000001UL)
  runner.cpu.write_freg(7, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(8, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(9, exec_test_f64_bits(0.0))
  runner.cpu.write_freg(10, 0x7ff0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x04U, 1, 1, 0x0U, 21),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x08U, 3, 1, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 3, 4, 0x0U, 23),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 3, 3, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_s(5, 0x0U, 25),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 7, 6, 0x0U, 26),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 9, 7, 0x0U, 27),
      encode_csr(csr_fcsr, 0, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 10, 10, 0x0U, 28),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(8, 0x0U, 29),
    ]),
    0U,
  )
  match runner.run(28) {
    Running => ()
    _ => fail("expected scalar arithmetic flag path to run")
  }
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(14) & 0x08U.to_uint64(), 0x08U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(18) & 0x08U.to_uint64(), 0x08U.to_uint64())
  assert_eq(runner.read_reg_u64(19) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr) & 0x10U, 0x10U)
}

///|
test "rv64fd invalid scalar arithmetic returns canonical nan results" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(3, 0x7ff0000000000000UL)
  runner.cpu.write_freg(4, 0x0000000000000000UL)
  runner.cpu.write_freg(5, 0x8000000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 4, 3, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 5, 4, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    _ => fail("expected invalid scalar arithmetic to run and accrue flags")
  }
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd invalid divide cases return canonical nan without divide by zero" {
  let csr_fcsr = 0x003
  let invalid_without_dz = 0x10U.to_uint64()
  let invalid_or_dz = 0x18U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x00000000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(3, 0x0000000000000000UL)
  runner.cpu.write_freg(4, 0x7ff0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 1, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 2, 2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 3, 3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 4, 4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected invalid divide cases to retire and accrue flags")
  }
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & invalid_or_dz, invalid_without_dz)
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & invalid_or_dz, invalid_without_dz)
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & invalid_or_dz, invalid_without_dz)
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & invalid_or_dz, invalid_without_dz)
}

///|
test "rv64fd divide nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000001UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 3, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 3, 2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 6, 4, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 6, 5, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected divide NaN operand cases to retire")
  }
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
}

///|
test "rv64fd divide divisor nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000001UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x0cU, 1, 3, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 2, 3, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 4, 6, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 5, 6, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected divide divisor-NaN operand cases to retire")
  }
  // Division has asymmetric numeric rules, but NaN canonicalization and
  // signaling-NaN flagging are independent of whether the NaN is dividend or
  // divisor.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
}

///|
test "rv64fd add mul nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000001UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 3, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x00U, 3, 2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x08U, 3, 1, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x08U, 3, 2, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 6, 4, 0x0U, 18),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 6, 5, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 6, 4, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 6, 5, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 25),
    ]),
    0U,
  )
  match runner.run(23) {
    Running => ()
    _ => fail("expected add/mul NaN operand cases to retire")
  }
  // Ordinary arithmetic canonicalizes NaN results. Only signaling NaN inputs
  // accrue NV; quiet NaN payloads are deliberately not propagated.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(18), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(19) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(20), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(21) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(22), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(23) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(24), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(25) & flag_mask, invalid_only)
}

///|
test "rv64fd add mul rhs nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000001UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 1, 3, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x00U, 2, 3, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x08U, 1, 3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x08U, 2, 3, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 4, 6, 0x0U, 18),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 5, 6, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 4, 6, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x09U, 5, 6, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 25),
    ]),
    0U,
  )
  match runner.run(23) {
    Running => ()
    _ => fail("expected add/mul rhs-NaN operand cases to retire")
  }
  // FADD/FMUL are numerically commutative, but the decoder/executor still
  // reads two source fields. Pin the source-2 NaN path explicitly.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(18), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(19) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(20), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(21) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(22), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(23) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(24), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(25) & flag_mask, invalid_only)
}

///|
test "rv64fd sub nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000001UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x04U, 1, 3, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x04U, 2, 3, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x04U, 3, 1, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x04U, 3, 2, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x05U, 4, 6, 0x0U, 18),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x05U, 5, 6, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x05U, 6, 4, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x05U, 6, 5, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 25),
    ]),
    0U,
  )
  match runner.run(23) {
    Running => ()
    _ => fail("expected sub NaN operand cases to retire")
  }
  // Cover both operand positions. FSUB flips the RHS sign for invalid-infinity
  // detection, but NaN canonicalization and signaling-NaN flagging are the
  // same architectural policy regardless of which source register is NaN.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(18), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(19) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(20), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(21) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(22), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(23) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(24), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(25) & flag_mask, invalid_only)
}

///|
test "rv64fd sqrt preserves negative zero and canonicalizes negative inputs" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.cpu.write_freg(2, exec_test_nan_box_single(exec_test_f32_bits(-0.0)))
  runner.cpu.write_freg(3, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(4, exec_test_f64_bits(-0.0))
  runner.load_program(
    words_to_bytes([
      encode_fsqrt_s(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_s(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    Trap(info) =>
      fail(
        "expected sqrt invalid/negative-zero path to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // Negative finite roots are invalid and produce the canonical NaN. The
  // signed zero roots are legal exact results and preserve their negative sign.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x80000000U))
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_freg_u64(16), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(17), 0U.to_uint64())
}

///|
test "rv64fd sqrt nan operands canonicalize and flag signaling only" {
  let csr_fcsr = 0x003
  let flag_mask = 0x1fU.to_uint64()
  let invalid_only = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0xffc00000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, 0xfff8000000000000UL)
  runner.cpu.write_freg(4, 0x7ff0000000000001UL)
  runner.load_program(
    words_to_bytes([
      encode_fsqrt_s(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_s(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    Trap(info) =>
      fail(
        "expected nan sqrt cases to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // NaN square roots follow the normal NaN rule, not the negative-number
  // invalid rule: quiet NaNs are flag-clean, signaling NaNs accrue NV.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & flag_mask, invalid_only)
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15) & flag_mask, 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & flag_mask, invalid_only)
}

///|
test "rv64fd single arithmetic accrues inexact flag" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(2.5)))
  runner.cpu.write_freg(2, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(
    3,
    exec_test_nan_box_single(exec_test_f32_bits(-1235.1)),
  )
  runner.cpu.write_freg(4, exec_test_nan_box_single(exec_test_f32_bits(1.1)))
  runner.cpu.write_freg(
    5,
    exec_test_nan_box_single(exec_test_f32_bits(3.14159265)),
  )
  runner.cpu.write_freg(
    6,
    exec_test_nan_box_single(exec_test_f32_bits(2.71828182)),
  )
  runner.cpu.write_freg(7, exec_test_nan_box_single(exec_test_f32_bits(171.0)))
  runner.cpu.write_freg(8, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.cpu.write_freg(
    9,
    exec_test_nan_box_single(exec_test_f32_bits(-1235.1)),
  )
  runner.cpu.write_freg(10, exec_test_nan_box_single(exec_test_f32_bits(1.1)))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x00U, 2, 1, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x00U, 4, 3, 0x0U, 21),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0cU, 6, 5, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_s(7, 0x0U, 23),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(10, 0x0U, 9, 8, 0x0U, 24, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(14) {
    Running => ()
    _ => fail("expected single arithmetic inexact path to run")
  }
  assert_eq(runner.read_reg_u64(11) & 0x01U.to_uint64(), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(12) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(14) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x01U.to_uint64(), 0x01U.to_uint64())
}

///|
test "rv64fd double arithmetic accrues inexact flag" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(2.5))
  runner.cpu.write_freg(2, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(-1235.1))
  runner.cpu.write_freg(4, exec_test_f64_bits(1.1))
  runner.cpu.write_freg(5, exec_test_f64_bits(3.14159265))
  runner.cpu.write_freg(6, exec_test_f64_bits(2.71828182))
  runner.cpu.write_freg(7, exec_test_f64_bits(171.0))
  runner.cpu.write_freg(8, exec_test_f64_bits(-1.0))
  runner.cpu.write_freg(9, exec_test_f64_bits(-1235.1))
  runner.cpu.write_freg(10, exec_test_f64_bits(1.1))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x01U, 2, 1, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x01U, 4, 3, 0x0U, 21),
      encode_csr(csr_fcsr, 0, 0x2U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x0dU, 6, 5, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fsqrt_d(7, 0x0U, 23),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r4(10, 0x1U, 9, 8, 0x0U, 24, 0x43U),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(14) {
    Running => ()
    _ => fail("expected double arithmetic inexact path to run")
  }
  assert_eq(runner.read_reg_u64(11) & 0x01U.to_uint64(), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(12) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(14) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x01U.to_uint64(), 0x01U.to_uint64())
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
    encode_fcvt_d_w(5, 0x0U, 6),
    encode_fcvt_d_w(7, 0x0U, 8),
    encode_fcvt_d_wu(9, 0x0U, 10),
    encode_fcvt_d_l(11, 0x7U, 12),
    encode_fcvt_d_lu(13, 0x7U, 14),
  ])
  let runner = make_runner(rv64fd_machine_config())
  runner.load_program(words_to_bytes([single]), 0x100U)
  runner.load_program_u64(exec_test_u64_to_le_bytes(double), 0x108U.to_uint64())
  runner.cpu.write_reg(5, 42U.to_uint64())
  runner.cpu.write_reg(7, 0xffffffffU.to_uint64())
  runner.cpu.write_reg(9, 0xffffffffU.to_uint64())
  runner.cpu.write_reg(11, (-17L).reinterpret_as_uint64())
  runner.cpu.write_reg(13, 1024U.to_uint64())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected rv64fd convert path to run")
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(1.5))
  assert_eq(
    runner.read_freg_u64(4),
    exec_test_nan_box_single(exec_test_f32_bits(Float::from_double(2.25))),
  )
  assert_eq(runner.read_freg_u64(6), exec_test_f64_bits(42.0))
  assert_eq(runner.read_freg_u64(8), exec_test_f64_bits(-1.0))
  assert_eq(runner.read_freg_u64(10), exec_test_f64_bits(4294967295.0))
  assert_eq(runner.read_freg_u64(12), exec_test_f64_bits(-17.0))
  assert_eq(runner.read_freg_u64(14), exec_test_f64_bits(1024.0))
}

///|
test "rv64fd double to single conversion honors non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x4170000010000000UL)
  runner.load_program(
    words_to_bytes([encode_fcvt_s_d(1, 0x1U, 2), encode_fcvt_s_d(1, 0x3U, 3)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE fcvt.s.d paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_nan_box_single(0x4b800000U))
  assert_eq(runner.read_freg_u64(3), exec_test_nan_box_single(0x4b800001U))
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd double to single conversion honors dynamic frm" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  runner.cpu.write_freg(1, 0x3ff0000010000000UL)
  runner.cpu.write_csr(csr_fcsr, 0x4U.to_uint64() << fcsr_frm_shift)
  runner.load_program(words_to_bytes([encode_fcvt_s_d(1, 0x7U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RMM fcvt.s.d to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_nan_box_single(0x3f800001U))
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd double to single conversion handles overflow by rounding mode" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x47f0000000000000UL)
  runner.load_program(
    words_to_bytes([encode_fcvt_s_d(1, 0x0U, 2), encode_fcvt_s_d(1, 0x1U, 3)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected overflowing fcvt.s.d paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_nan_box_single(0x7f800000U))
  assert_eq(runner.read_freg_u64(3), exec_test_nan_box_single(0x7f7fffffU))
  assert_eq(runner.read_csr(csr_fcsr) & 0x5U, 0x5U)
}

///|
test "rv64fd double to single detects tininess after rounding" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, 0x380fffffe0000000UL)
  runner.load_program(words_to_bytes([encode_fcvt_s_d(1, 0x0U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected boundary fcvt.s.d to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_nan_box_single(0x00800000U))
  assert_eq(runner.read_csr(csr_fcsr) & 0x3U, 0x1U)
}

///|
test "rv64fd double to single conversion rejects reserved rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let raw = encode_fcvt_s_d(1, 0x5U, 2)
  runner.cpu.write_freg(1, exec_test_f64_bits(1.0))
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected reserved fcvt.s.d rounding mode to trap")
  }
}

///|
test "rv64fd fcvt.s.d canonicalizes nan inputs and flags signaling nan" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0x7ff8000000012345UL)
  runner.cpu.write_freg(2, 0x7ff0000000012345UL)
  runner.load_program(
    words_to_bytes([
      encode_fcvt_s_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_s_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    Trap(info) =>
      fail(
        "expected fcvt.s.d nan path to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // FCVT.S.D is a narrowing FP operation, so NaN results are canonical single
  // NaNs. Only the signaling input accrues NV; quiet NaNs remain flag-clean.
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd fcvt.d.s accepts legal unaffected rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(1.5)))
  runner.load_program(words_to_bytes([encode_fcvt_d_s(1, 0x1U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected legal RTZ fcvt.d.s to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_f64_bits(1.5))
}

///|
test "rv64fd fcvt.d.s accrues invalid for signaling nan" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7f800001U))
  runner.load_program(words_to_bytes([encode_fcvt_d_s(1, 0x0U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected signaling-nan fcvt.d.s to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_csr(csr_fcsr) & 0x10U, 0x10U)
}

///|
test "rv64fd fcvt.d.s canonicalizes quiet nan payloads without flags" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.load_program(words_to_bytes([encode_fcvt_d_s(1, 0x0U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected quiet-nan fcvt.d.s to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_csr(csr_fcsr) & 0x1fU, 0U)
}

///|
test "rv64fd fcvt.d.s rejects reserved static rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let raw = encode_fcvt_d_s(1, 0x5U, 2)
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(1.5)))
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "rv64fd fcvt.d.s rejects reserved dynamic rounding mode" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let raw = encode_fcvt_d_s(1, 0x7U, 2)
  runner.cpu.write_freg(1, exec_test_nan_box_single(exec_test_f32_bits(1.5)))
  runner.cpu.write_csr(csr_fcsr, 0x7U.to_uint64() << fcsr_frm_shift)
  runner.load_program(words_to_bytes([raw]), 0U)
  match runner.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.faulting_pc, 0U.to_uint64())
      assert_eq(info.trap_value, raw.to_uint64())
    }
    _ => fail("expected illegal instruction trap")
  }
}

///|
test "rv64fd fcvt.d.w exact conversions accept legal unaffected rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_reg(1, 42U.to_uint64())
  runner.cpu.write_reg(2, 0xffffffffU.to_uint64())
  runner.load_program(
    words_to_bytes([encode_fcvt_d_w(1, 0x2U, 3), encode_fcvt_d_wu(2, 0x4U, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected legal exact fcvt.d.w paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(42.0))
  assert_eq(runner.read_freg_u64(4), exec_test_f64_bits(4294967295.0))
}

///|
test "rv64fd fcvt.d.w exact conversions reject reserved rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let reserved_static = encode_fcvt_d_w(1, 0x6U, 2)
  let reserved_dynamic = encode_fcvt_d_wu(1, 0x7U, 3)
  runner.cpu.write_reg(1, 42U.to_uint64())
  runner.load_program(words_to_bytes([reserved_static]), 0U)
  match runner.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static.to_uint64())
    }
    _ => fail("expected reserved static rounding mode to trap")
  }
  let dynamic_runner = make_runner(rv64fd_machine_config())
  dynamic_runner.cpu.write_reg(1, 42U.to_uint64())
  dynamic_runner.cpu.write_csr(csr_fcsr, 0x7U.to_uint64() << fcsr_frm_shift)
  dynamic_runner.load_program(words_to_bytes([reserved_dynamic]), 0U)
  match dynamic_runner.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_dynamic.to_uint64())
    }
    _ => fail("expected reserved dynamic rounding mode to trap")
  }
}

///|
test "rv64fd long to double conversion honors non-rne rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  runner.cpu.write_reg(1, 0x0020000000000001UL)
  runner.load_program(
    words_to_bytes([encode_fcvt_d_l(1, 0x1U, 2), encode_fcvt_d_lu(1, 0x3U, 3)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected non-RNE fcvt.d.l paths to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_freg_u64(2), 0x4340000000000000UL)
  assert_eq(runner.read_freg_u64(3), 0x4340000000000001UL)
  assert_eq(runner.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd long to double conversion honors dynamic directed rounding" {
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let rdn = make_runner(rv64fd_machine_config())
  // -2^53-1 is exactly halfway between adjacent binary64 values. Dynamic RDN
  // must choose the more-negative representable value and accrue NX.
  rdn.cpu.write_reg(1, 0xffdfffffffffffffUL)
  rdn.cpu.write_csr(csr_fcsr, 0x2U.to_uint64() << fcsr_frm_shift)
  rdn.load_program(words_to_bytes([encode_fcvt_d_l(1, 0x7U, 2)]), 0U)
  match rdn.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RDN fcvt.d.l to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(rdn.read_freg_u64(2), 0xc340000000000001UL)
  assert_eq(rdn.read_csr(csr_fcsr) & 0x1U, 0x1U)

  let rmm = make_runner(rv64fd_machine_config())
  // +2^53+1 is the unsigned mirror of that halfway case. Dynamic RMM rounds
  // away from zero, selecting the upper representable double.
  rmm.cpu.write_reg(1, 0x0020000000000001UL)
  rmm.cpu.write_csr(csr_fcsr, 0x4U.to_uint64() << fcsr_frm_shift)
  rmm.load_program(words_to_bytes([encode_fcvt_d_lu(1, 0x7U, 2)]), 0U)
  match rmm.run(1) {
    Running => ()
    Trap(info) =>
      fail(
        "expected dynamic-RMM fcvt.d.lu to run, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(rmm.read_freg_u64(2), 0x4340000000000001UL)
  assert_eq(rmm.read_csr(csr_fcsr) & 0x1U, 0x1U)
}

///|
test "rv64fd double comparisons write integer results" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(2, exec_test_f64_bits(2.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(2.0))
  runner.cpu.write_freg(4, 0x7ff8000000000000UL)
  runner.cpu.write_freg(8, exec_test_f64_bits(2.0))
  runner.cpu.write_freg(10, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fle_d(1, 2, 5),
      encode_flt_d(2, 1, 6),
      encode_feq_d(2, 3, 7),
      encode_fle_d(4, 2, 8),
      encode_fle_d(10, 8, 15),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected rv64fd compare path to run")
  }
  assert_eq(runner.read_reg_u64(5), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15), 1U.to_uint64())
}

///|
test "rv64fd floating comparisons accrue invalid flags for nan inputs" {
  let csr_fcsr = 0x003
  let invalid_only = 0x10U.to_uint64()
  let qnan_s = exec_test_nan_box_single(0x7fc00000U)
  let snan_s = exec_test_nan_box_single(0x7f800001U)
  let qnan_d = 0x7ff8000000000000UL
  let snan_d = 0x7ff0000000000001UL
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, qnan_s)
  runner.cpu.write_freg(2, snan_s)
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, qnan_d)
  runner.cpu.write_freg(5, snan_d)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_feq_s(1, 3, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_flt_s(1, 3, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_feq_s(2, 3, 13),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_feq_d(4, 6, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_fle_d(4, 6, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 20),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_feq_d(5, 6, 17),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
    ]),
    0U,
  )
  match runner.run(15) {
    Running => ()
    _ => fail("expected nan comparison flag path to run")
  }
  // Ordered comparisons are signaling comparisons and set NV for any NaN.
  // FEQ is quiet for quiet NaNs but still signals on signaling NaNs.
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(18) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(19) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(20) & 0x1fU.to_uint64(), invalid_only)
  assert_eq(runner.read_reg_u64(17), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(21) & 0x1fU.to_uint64(), invalid_only)
}

///|
test "rv64fd min max accrue invalid for signaling nan only" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(4, 0x7ff8000000000000UL)
  runner.cpu.write_freg(5, 0x7ff0000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x14U, 3, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_fp_r(0x14U, 3, 2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x15U, 6, 4, 0x1U, 13),
      encode_csr(csr_fcsr, 0, 0x2U, 14),
      encode_fp_r(0x15U, 6, 5, 0x1U, 15),
    ]),
    0U,
  )
  match runner.run(7) {
    Running => ()
    _ => fail("expected nan min/max flag path to run")
  }
  assert_eq(
    runner.read_freg_u64(10),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(
    runner.read_freg_u64(12),
    exec_test_nan_box_single(exec_test_f32_bits(1.0)),
  )
  assert_eq(runner.read_freg_u64(13), exec_test_f64_bits(1.0))
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_freg_u64(15), exec_test_f64_bits(1.0))
  assert_eq(runner.read_csr(csr_fcsr) & 0x10U, 0x10U)
}

///|
test "rv64fd min max canonicalize all nan inputs and flag signaling nan" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc12345U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x7f812345U))
  runner.cpu.write_freg(3, 0x7ff8000000001234UL)
  runner.cpu.write_freg(4, 0x7ff0000000001234UL)
  runner.load_program(
    words_to_bytes([
      encode_fp_r(0x14U, 1, 1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x14U, 1, 2, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x15U, 3, 3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fp_r(0x15U, 3, 4, 0x1U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
    ]),
    0U,
  )
  match runner.run(12) {
    Running => ()
    _ => fail("expected all-nan min/max result path to run")
  }
  assert_eq(runner.read_freg_u64(10), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.read_freg_u64(12), exec_test_nan_box_single(0x7fc00000U))
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_freg_u64(14), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(15), 0U.to_uint64())
  assert_eq(runner.read_freg_u64(16), exec_test_f64_canonical_nan_bits())
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr), 0U)
}

///|
test "rv64fd double sign injection preserves magnitude bits" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(1.5))
  runner.cpu.write_freg(2, exec_test_f64_bits(-2.0))
  runner.load_program(
    words_to_bytes([
      encode_fsgnj_d(1, 2, 3),
      encode_fsgnjn_d(1, 2, 4),
      encode_fsgnjx_d(1, 2, 5),
      encode_fsgnj_d(1, 1, 6),
      encode_fsgnj_d(10, 10, 9),
    ]),
    0U,
  )
  runner.cpu.write_freg(10, exec_test_f64_bits(3.0))
  match runner.run(5) {
    Running => ()
    _ => fail("expected rv64fd sign injection path to run")
  }
  assert_eq(runner.read_freg_u64(3), exec_test_f64_bits(-1.5))
  assert_eq(runner.read_freg_u64(4), exec_test_f64_bits(1.5))
  assert_eq(runner.read_freg_u64(5), exec_test_f64_bits(-1.5))
  assert_eq(runner.read_freg_u64(6), exec_test_f64_bits(1.5))
  assert_eq(runner.read_freg_u64(9), exec_test_f64_bits(3.0))
}

///|
test "rv64fd fclass.s writes one class bit" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0x80000001U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x80000000U))
  runner.cpu.write_freg(4, exec_test_nan_box_single(0x00000000U))
  runner.cpu.write_freg(5, exec_test_nan_box_single(0x00000001U))
  runner.cpu.write_freg(6, exec_test_nan_box_single(exec_test_f32_bits(1.0)))
  runner.cpu.write_freg(7, exec_test_nan_box_single(0x7f800000U))
  runner.cpu.write_freg(8, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(9, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(10, 0x000000003f800000UL)
  runner.load_program(
    words_to_bytes([
      encode_fclass_s(1, 11),
      encode_fclass_s(2, 12),
      encode_fclass_s(3, 13),
      encode_fclass_s(4, 14),
      encode_fclass_s(5, 15),
      encode_fclass_s(6, 16),
      encode_fclass_s(7, 17),
      encode_fclass_s(8, 18),
      encode_fclass_s(9, 19),
      encode_fclass_s(10, 20),
    ]),
    0U,
  )
  match runner.run(10) {
    Running => ()
    _ => fail("expected rv64fd fclass.s path to run")
  }
  assert_eq(runner.read_reg_u64(11), 0x001U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0x004U.to_uint64())
  assert_eq(runner.read_reg_u64(13), 0x008U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x010U.to_uint64())
  assert_eq(runner.read_reg_u64(15), 0x020U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0x040U.to_uint64())
  assert_eq(runner.read_reg_u64(17), 0x080U.to_uint64())
  assert_eq(runner.read_reg_u64(18), 0x100U.to_uint64())
  assert_eq(runner.read_reg_u64(19), 0x200U.to_uint64())
  assert_eq(runner.read_reg_u64(20), 0x200U.to_uint64())
}

///|
test "rv64fd fclass.d writes one class bit" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0xfff0000000000000UL)
  runner.cpu.write_freg(2, 0x8000000000000001UL)
  runner.cpu.write_freg(3, 0x8000000000000000UL)
  runner.cpu.write_freg(4, 0x0000000000000000UL)
  runner.cpu.write_freg(5, 0x0000000000000001UL)
  runner.cpu.write_freg(6, exec_test_f64_bits(1.0))
  runner.cpu.write_freg(7, 0x7ff0000000000000UL)
  runner.cpu.write_freg(8, 0x7ff0000000000001UL)
  runner.cpu.write_freg(9, 0x7ff8000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fclass_d(1, 11),
      encode_fclass_d(2, 12),
      encode_fclass_d(3, 13),
      encode_fclass_d(4, 14),
      encode_fclass_d(5, 15),
      encode_fclass_d(6, 16),
      encode_fclass_d(7, 17),
      encode_fclass_d(8, 18),
      encode_fclass_d(9, 19),
    ]),
    0U,
  )
  match runner.run(9) {
    Running => ()
    _ => fail("expected rv64fd fclass.d path to run")
  }
  assert_eq(runner.read_reg_u64(11), 0x001U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0x004U.to_uint64())
  assert_eq(runner.read_reg_u64(13), 0x008U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x010U.to_uint64())
  assert_eq(runner.read_reg_u64(15), 0x020U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0x040U.to_uint64())
  assert_eq(runner.read_reg_u64(17), 0x080U.to_uint64())
  assert_eq(runner.read_reg_u64(18), 0x100U.to_uint64())
  assert_eq(runner.read_reg_u64(19), 0x200U.to_uint64())
}

///|
test "rv64fd fclass does not update fflags for signaling nan inputs" {
  let fflags = 0x001
  let fcsr = 0x003
  let existing_nx = 0x1U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_csr(fcsr, existing_nx)
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7f800001U))
  runner.cpu.write_freg(2, 0x7ff0000000000001UL)
  runner.load_program(
    words_to_bytes([encode_fclass_s(1, 3), encode_fclass_d(2, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected signaling-nan FCLASS instructions to run")
  }
  assert_eq(runner.read_reg_u64(3), 0x100U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0x100U.to_uint64())
  assert_eq(runner.read_csr_u64(fflags), existing_nx)
}

///|
test "rv64fd double to signed word conversion uses rtz" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(4.75))
  runner.cpu.write_freg(2, exec_test_f64_bits(-2.75))
  runner.load_program(
    words_to_bytes([encode_fcvt_w_d(1, 0x1U, 3), encode_fcvt_w_d(2, 0x1U, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64fd fcvt.w.d path to run")
  }
  assert_eq(runner.read_reg_u64(3), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(4), test_sign_extend_word64(0xfffffffeU))
}

///|
test "rv64fd double to signed word conversion honors rounding modes" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(2.5))
  runner.cpu.write_freg(2, exec_test_f64_bits(-2.5))
  runner.cpu.write_freg(3, exec_test_f64_bits(2.25))
  runner.cpu.write_freg(4, exec_test_f64_bits(-2.25))
  runner.cpu.write_freg(5, exec_test_f64_bits(3.5))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x0U, 10),
      encode_fcvt_w_d(2, 0x0U, 11),
      encode_fcvt_w_d(3, 0x2U, 12),
      encode_fcvt_w_d(4, 0x3U, 13),
      encode_fcvt_w_d(5, 0x4U, 14),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected rounded rv64fd fcvt.w.d path to run")
  }
  assert_eq(runner.read_reg_u64(10), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(11), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(12), 2U.to_uint64())
  assert_eq(runner.read_reg_u64(13), test_sign_extend_word64(0xfffffffeU))
  assert_eq(runner.read_reg_u64(14), 4U.to_uint64())
}

///|
test "rv64fd float to int conversion honors dynamic frm" {
  let runner = make_runner(rv64fd_machine_config())
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  runner.cpu.write_freg(1, exec_test_f64_bits(2.25))
  runner.cpu.write_csr(csr_fcsr, 0x3U.to_uint64() << fcsr_frm_shift)
  runner.load_program(words_to_bytes([encode_fcvt_w_d(1, 0x7U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    _ => fail("expected dynamic rounded rv64fd fcvt.w.d path to run")
  }
  assert_eq(runner.read_reg_u64(2), 3U.to_uint64())
}

///|
test "rv64fd float to integer conversions reject reserved rounding modes" {
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let reserved_static_single = encode_fcvt_w_s(1, 0x6U, 2)
  let reserved_dynamic_double = encode_fcvt_wu_d(1, 0x7U, 3)
  let reserved_static_long = encode_fcvt_l_d(1, 0x5U, 4)

  let single_static = make_runner(rv64fd_machine_config())
  single_static.cpu.write_freg(
    1,
    exec_test_nan_box_single(exec_test_f32_bits(2.0)),
  )
  single_static.load_program(words_to_bytes([reserved_static_single]), 0U)
  match single_static.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static_single.to_uint64())
    }
    _ => fail("expected reserved static fcvt.w.s rounding mode to trap")
  }

  let double_dynamic = make_runner(rv64fd_machine_config())
  double_dynamic.cpu.write_freg(1, exec_test_f64_bits(2.0))
  double_dynamic.cpu.write_csr(csr_fcsr, 0x6U.to_uint64() << fcsr_frm_shift)
  double_dynamic.load_program(words_to_bytes([reserved_dynamic_double]), 0U)
  match double_dynamic.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_dynamic_double.to_uint64())
    }
    _ => fail("expected reserved dynamic fcvt.wu.d rounding mode to trap")
  }

  let long_static = make_runner(rv64fd_machine_config())
  long_static.cpu.write_freg(1, exec_test_f64_bits(2.0))
  long_static.load_program(words_to_bytes([reserved_static_long]), 0U)
  match long_static.run(1) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause")
      }
      assert_eq(info.trap_value, reserved_static_long.to_uint64())
    }
    _ => fail("expected reserved static fcvt.l.d rounding mode to trap")
  }
}

///|
test "rv64fd double to unsigned word conversion sign extends on rv64" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(42.75))
  runner.cpu.write_freg(2, exec_test_f64_bits(4294967295.0))
  runner.cpu.write_freg(3, exec_test_f64_bits(2147483648.0))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_wu_d(1, 0x1U, 4),
      encode_fcvt_wu_d(2, 0x1U, 5),
      encode_fcvt_wu_d(3, 0x1U, 6),
    ]),
    0U,
  )
  match runner.run(3) {
    Running => ()
    _ => fail("expected rv64fd fcvt.wu.d path to run")
  }
  // RV64 FCVT.WU.D writes the unsigned 32-bit conversion result and then
  // sign-extends that 32-bit pattern to XLEN. Pin both high-bit-set edges, not
  // only the all-ones clipping-adjacent value.
  assert_eq(runner.read_reg_u64(4), 42U.to_uint64())
  assert_eq(runner.read_reg_u64(5), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(6), test_sign_extend_word64(0x80000000U))
}

///|
test "rv64fd float to word conversions clip invalid inputs and set flags" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.cpu.write_freg(4, 0x7ff0000000000000UL)
  runner.cpu.write_freg(5, exec_test_f64_bits(1.5))
  runner.cpu.write_freg(6, exec_test_f64_bits(2.0))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_s(1, 0x1U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_s(2, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(3, 0x1U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(4, 0x1U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(5, 0x1U, 15),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(6, 0x1U, 17),
    ]),
    0U,
  )
  match runner.run(13) {
    Running => ()
    _ => fail("expected fcvt word flag path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(14), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(15), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(16) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(17), 2U.to_uint64())
  assert_eq(runner.read_csr(csr_fcsr), 0U)
}

///|
test "rv64fd word conversions clip exact upper rne boundaries" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0x41e0000000000000UL) // double +2^31, first invalid signed-word result.
  runner.cpu.write_freg(2, 0x41f0000000000000UL) // double +2^32, first invalid unsigned-word result.
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x4f000000U)) // single +2^31.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0x4f800000U)) // single +2^32.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_s(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected exact upper-bound fcvt word path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd signed word conversion checks range after rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // These double inputs sit exactly half a unit outside the signed 32-bit
  // integer endpoints. The RISC-V conversion rule checks the integer after
  // rounding, so the same source bit pattern can be either valid+NX or
  // invalid+NV depending on rm.
  runner.cpu.write_freg(1, 0x41dfffffffe00000UL) // +2^31 - 0.5.
  runner.cpu.write_freg(2, 0xc1e0000000100000UL) // -2^31 - 0.5.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x1U, 10), // RTZ: +2^31 - 1, valid.
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(1, 0x0U, 12), // RNE: ties to +2^31, invalid.
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(1, 0x2U, 14), // RDN: +2^31 - 1, valid.
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(1, 0x3U, 16), // RUP: +2^31, invalid.
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(2, 0x0U, 18), // RNE: ties to -2^31, valid.
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(2, 0x2U, 20), // RDN: -2^31 - 1, invalid.
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(2, 0x3U, 22), // RUP: -2^31, valid.
      encode_csr(csr_fcsr, 0, 0x2U, 23),
    ]),
    0U,
  )
  match runner.run(20) {
    Running => ()
    _ => fail("expected mode-dependent fcvt.w.d signed-boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(14), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(16), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(18), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(19) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(20), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(21) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(22), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(23) & 0x1fU.to_uint64(), inexact)
}

///|
test "rv64fd rmm word conversion checks range after ties-away rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // RMM rounds half-way cases away from zero. At the signed and unsigned
  // integer boundaries that means the rounded integer crosses out of range,
  // so the result must be the clipped invalid value and only NV may be set.
  runner.cpu.write_freg(1, 0x41dfffffffe00000UL) // +2^31 - 0.5.
  runner.cpu.write_freg(2, 0xc1e0000000100000UL) // -2^31 - 0.5.
  runner.cpu.write_freg(3, 0x41effffffff00000UL) // +2^32 - 0.5.
  runner.cpu.write_freg(4, 0xbfe0000000000000UL) // -0.5.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x4U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_d(2, 0x4U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(3, 0x4U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(4, 0x4U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected RMM fcvt word boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(14), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64fd dynamic frm word conversion checks range after rounding" {
  let csr_fflags = 0x001
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let frm_mask = 0x7U << fcsr_frm_shift
  let rdn_frm = 0x2U << fcsr_frm_shift
  let rmm_frm = 0x4U << fcsr_frm_shift

  let rdn = make_runner(rv64fd_machine_config())
  // Dynamic rm=111 must read fcsr.frm at execution time and then apply the
  // same round-before-range-check rule as a static rm. Clearing only fflags
  // between conversions keeps frm live, which catches accidental fcsr clears.
  rdn.cpu.write_freg(1, 0x41dfffffffe00000UL) // +2^31 - 0.5.
  rdn.cpu.write_freg(2, 0xc1e0000000100000UL) // -2^31 - 0.5.
  rdn.cpu.write_csr(csr_fcsr, rdn_frm.to_uint64())
  rdn.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_w_d(2, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
    ]),
    0U,
  )
  match rdn.run(5) {
    Running => ()
    _ => fail("expected dynamic RDN fcvt.w.d boundary path to run")
  }
  assert_eq(rdn.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(rdn.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(rdn.read_reg_u64(12), test_sign_extend_word64(0x80000000U))
  assert_eq(rdn.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(rdn.read_csr(csr_fcsr) & frm_mask, rdn_frm)

  let rmm = make_runner(rv64fd_machine_config())
  // RMM ties away from zero, so both unsigned-word half-unit boundary inputs
  // round outside the valid range and report NV without also reporting NX.
  rmm.cpu.write_freg(1, 0x41effffffff00000UL) // +2^32 - 0.5.
  rmm.cpu.write_freg(2, 0xbfe0000000000000UL) // -0.5.
  rmm.cpu.write_csr(csr_fcsr, rmm_frm.to_uint64())
  rmm.load_program(
    words_to_bytes([
      encode_fcvt_wu_d(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_wu_d(2, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
    ]),
    0U,
  )
  match rmm.run(5) {
    Running => ()
    _ => fail("expected dynamic RMM fcvt.wu.d boundary path to run")
  }
  assert_eq(rmm.read_reg_u64(10), test_sign_extend_word64(0xffffffffU))
  assert_eq(rmm.read_reg_u64(11) & 0x1fU.to_uint64(), invalid)
  assert_eq(rmm.read_reg_u64(12), 0U.to_uint64())
  assert_eq(rmm.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(rmm.read_csr(csr_fcsr) & frm_mask, rmm_frm)
}

///|
test "rv64fd unsigned word conversion checks range after rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // The source is exactly +2^32 - 0.5.  It is still in range for FCVT.WU.D
  // under RTZ, but RNE and RUP round it to +2^32 before the unsigned-word
  // range check. This pins the spec ordering: round first, then decide whether
  // the integer result is invalid.
  runner.cpu.write_freg(1, 0x41effffffff00000UL)
  runner.load_program(
    words_to_bytes([
      encode_fcvt_wu_d(1, 0x1U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(1, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(1, 0x3U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    _ => fail("expected mode-dependent fcvt.wu.d boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(14), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64fd unsigned word conversion checks negative half after rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // The source is exactly -0.5. RNE ties to signed zero and RTZ truncates to
  // signed zero, so both are valid unsigned-word zero results with NX. RDN
  // rounds before the range check, producing -1 and therefore NV.
  runner.cpu.write_freg(1, 0xbfe0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fcvt_wu_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(1, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(1, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    _ => fail("expected negative-half fcvt.wu.d boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64f unsigned word conversion checks negative half after rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64f_machine_config())
  // Keep the same lower-boundary contract covered for the F-only profile.
  // NaN-boxing is still required because single-precision values live in the
  // low 32 bits of the architectural floating-point register.
  runner.cpu.write_freg(1, exec_test_nan_box_single(0xbf000000U))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_wu_s(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(1, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(1, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
    ]),
    0U,
  )
  match runner.run(8) {
    Running => ()
    _ => fail("expected F-only negative-half fcvt.wu.s boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64fd word conversions clip exact lower rne boundaries" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0xc1e0000000200000UL) // double -2^31 - 1.
  runner.cpu.write_freg(2, 0xbff0000000000000UL) // double -1, invalid for unsigned word.
  runner.cpu.write_freg(3, exec_test_nan_box_single(0xcf000001U)) // single just below -2^31.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0xbf800000U)) // single -1.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_s(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected exact lower-bound fcvt word path to run")
  }
  assert_eq(runner.read_reg_u64(10), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(14), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd double to signed long conversion uses rtz" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(1024.75))
  runner.cpu.write_freg(2, exec_test_f64_bits(-9.5))
  runner.load_program(
    words_to_bytes([encode_fcvt_l_d(1, 0x1U, 3), encode_fcvt_l_d(2, 0x1U, 4)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected rv64fd fcvt.l.d path to run")
  }
  assert_eq(runner.read_reg_u64(3), 1024U.to_uint64())
  assert_eq(runner.read_reg_u64(4), (-9L).reinterpret_as_uint64())
}

///|
test "rv64fd double to unsigned long conversion uses rtz" {
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_f64_bits(42.75))
  runner.load_program(words_to_bytes([encode_fcvt_lu_d(1, 0x1U, 2)]), 0U)
  match runner.run(1) {
    Running => ()
    _ => fail("expected rv64fd fcvt.lu.d path to run")
  }
  assert_eq(runner.read_reg_u64(2), 42U.to_uint64())
}

///|
test "rv64fd float to long conversions clip invalid inputs and set flags" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xff800000U))
  runner.cpu.write_freg(3, exec_test_nan_box_single(exec_test_f32_bits(-1.0)))
  runner.cpu.write_freg(4, 0x7ff0000000000000UL)
  runner.cpu.write_freg(5, exec_test_f64_bits(42.75))
  runner.cpu.write_freg(6, exec_test_f64_bits(-9.0))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_l_s(1, 0x1U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_s(2, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(3, 0x1U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(4, 0x1U, 14),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_d(5, 0x1U, 15),
      encode_csr(csr_fcsr, 0, 0x2U, 16),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_d(6, 0x1U, 17),
    ]),
    0U,
  )
  match runner.run(13) {
    Running => ()
    _ => fail("expected fcvt long flag path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffffffffffUL)
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0xffffffffffffffffUL)
  assert_eq(runner.read_reg_u64(15), 42U.to_uint64())
  assert_eq(runner.read_reg_u64(16) & 0x01U.to_uint64(), 0x01U.to_uint64())
  assert_eq(runner.read_reg_u64(17), (-9L).reinterpret_as_uint64())
  assert_eq(runner.read_csr(csr_fcsr), 0U)
}

///|
test "rv64fd long conversions clip exact upper rne boundaries" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0x43e0000000000000UL) // +2^63, first invalid signed-long result.
  runner.cpu.write_freg(2, 0x43f0000000000000UL) // +2^64, first invalid unsigned-long result.
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x5f000000U)) // single +2^63.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0x5f800000U)) // single +2^64.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_l_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_s(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected exact upper-bound fcvt long path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffffffffffUL)
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0xffffffffffffffffUL)
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x7fffffffffffffffUL)
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0xffffffffffffffffUL)
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd rmm long conversion handles ties and unsigned lower edge" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // At the 64-bit upper endpoints, binary64 spacing is larger than one, so
  // `2^63 - 0.5`-style sources are not real double values. Use small exact
  // half-way inputs to pin RMM ties-away behavior on FCVT.L.D, and use -0.5
  // to pin the unsigned lower edge for both D and S sources.
  runner.cpu.write_freg(1, exec_test_f64_bits(9.5))
  runner.cpu.write_freg(2, exec_test_f64_bits(-9.5))
  runner.cpu.write_freg(3, 0xbfe0000000000000UL)
  runner.cpu.write_freg(4, exec_test_nan_box_single(0xbf000000U))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_l_d(1, 0x4U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_d(2, 0x4U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(3, 0x4U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(4, 0x4U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected RMM fcvt long path to run")
  }
  assert_eq(runner.read_reg_u64(10), 10U.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), (-10L).reinterpret_as_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64fd dynamic frm long conversion uses fcsr rounding" {
  let csr_fflags = 0x001
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let frm_mask = 0x7U << fcsr_frm_shift
  let rdn_frm = 0x2U << fcsr_frm_shift
  let rmm_frm = 0x4U << fcsr_frm_shift

  let rdn = make_runner(rv64fd_machine_config())
  // Use exact small ties for signed long conversions because binary64 cannot
  // represent a useful `2^63 - 0.5` boundary. The unsigned -0.5 edge still
  // proves the RV64-width invalid path after dynamic directed rounding.
  rdn.cpu.write_freg(1, exec_test_f64_bits(9.5))
  rdn.cpu.write_freg(2, 0xbfe0000000000000UL)
  rdn.cpu.write_csr(csr_fcsr, rdn_frm.to_uint64())
  rdn.load_program(
    words_to_bytes([
      encode_fcvt_l_d(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_lu_d(2, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
    ]),
    0U,
  )
  match rdn.run(5) {
    Running => ()
    _ => fail("expected dynamic RDN fcvt long path to run")
  }
  assert_eq(rdn.read_reg_u64(10), 9U.to_uint64())
  assert_eq(rdn.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(rdn.read_reg_u64(12), 0U.to_uint64())
  assert_eq(rdn.read_reg_u64(13) & 0x1fU.to_uint64(), invalid)
  assert_eq(rdn.read_csr(csr_fcsr) & frm_mask, rdn_frm)

  let rmm = make_runner(rv64fd_machine_config())
  // RMM is the non-IEEE rounding mode where ties move away from zero. Check
  // both signed long ties and the unsigned lower edge through dynamic rm=111.
  rmm.cpu.write_freg(1, exec_test_f64_bits(9.5))
  rmm.cpu.write_freg(2, exec_test_f64_bits(-9.5))
  rmm.cpu.write_freg(3, exec_test_nan_box_single(0xbf000000U))
  rmm.cpu.write_csr(csr_fcsr, rmm_frm.to_uint64())
  rmm.load_program(
    words_to_bytes([
      encode_fcvt_l_d(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_l_d(2, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_lu_s(3, 0x7U, 14),
      encode_csr(csr_fflags, 0, 0x2U, 15),
    ]),
    0U,
  )
  match rmm.run(8) {
    Running => ()
    _ => fail("expected dynamic RMM fcvt long path to run")
  }
  assert_eq(rmm.read_reg_u64(10), 10U.to_uint64())
  assert_eq(rmm.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(rmm.read_reg_u64(12), (-10L).reinterpret_as_uint64())
  assert_eq(rmm.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(rmm.read_reg_u64(14), 0U.to_uint64())
  assert_eq(rmm.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(rmm.read_csr(csr_fcsr) & frm_mask, rmm_frm)
}

///|
test "rv64f dynamic frm single-source integer conversions use fcsr rounding" {
  let csr_fflags = 0x001
  let csr_fcsr = 0x003
  let fcsr_frm_shift = 5
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let frm_mask = 0x7U << fcsr_frm_shift
  let rdn_frm = 0x2U << fcsr_frm_shift
  let rmm_frm = 0x4U << fcsr_frm_shift

  let rdn = make_runner(rv64f_machine_config())
  // This is the F-only version of the dynamic conversion contract. Single
  // precision cannot represent useful half-unit values near the 32/64-bit
  // upper integer limits, so exact small ties prove the rounding-mode source
  // while -0.5 proves the unsigned invalid path after dynamic directed rounding.
  rdn.cpu.write_freg(1, exec_test_nan_box_single(0x41180000U)) // +9.5f.
  rdn.cpu.write_freg(2, exec_test_nan_box_single(0xbf000000U)) // -0.5f.
  rdn.cpu.write_csr(csr_fcsr, rdn_frm.to_uint64())
  rdn.load_program(
    words_to_bytes([
      encode_fcvt_w_s(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_l_s(1, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_wu_s(2, 0x7U, 14),
      encode_csr(csr_fflags, 0, 0x2U, 15),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_lu_s(2, 0x7U, 16),
      encode_csr(csr_fflags, 0, 0x2U, 17),
    ]),
    0U,
  )
  match rdn.run(11) {
    Running => ()
    _ => fail("expected dynamic RDN single-source conversion path to run")
  }
  assert_eq(rdn.read_reg_u64(10), 9U.to_uint64())
  assert_eq(rdn.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(rdn.read_reg_u64(12), 9U.to_uint64())
  assert_eq(rdn.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(rdn.read_reg_u64(14), 0U.to_uint64())
  assert_eq(rdn.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(rdn.read_reg_u64(16), 0U.to_uint64())
  assert_eq(rdn.read_reg_u64(17) & 0x1fU.to_uint64(), invalid)
  assert_eq(rdn.read_csr(csr_fcsr) & frm_mask, rdn_frm)

  let rmm = make_runner(rv64f_machine_config())
  // RMM is easy to miss because it is encoded beside the IEEE rounding modes
  // but has different half-way behavior. Cover both word and long outputs from
  // single-precision sources through dynamic rm=111.
  rmm.cpu.write_freg(1, exec_test_nan_box_single(0x41180000U)) // +9.5f.
  rmm.cpu.write_freg(2, exec_test_nan_box_single(0xc1180000U)) // -9.5f.
  rmm.cpu.write_freg(3, exec_test_nan_box_single(0xbf000000U)) // -0.5f.
  rmm.cpu.write_csr(csr_fcsr, rmm_frm.to_uint64())
  rmm.load_program(
    words_to_bytes([
      encode_fcvt_w_s(1, 0x7U, 10),
      encode_csr(csr_fflags, 0, 0x2U, 11),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_l_s(2, 0x7U, 12),
      encode_csr(csr_fflags, 0, 0x2U, 13),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_wu_s(3, 0x7U, 14),
      encode_csr(csr_fflags, 0, 0x2U, 15),
      encode_csr(csr_fflags, 0, 0x1U, 0),
      encode_fcvt_lu_s(3, 0x7U, 16),
      encode_csr(csr_fflags, 0, 0x2U, 17),
    ]),
    0U,
  )
  match rmm.run(11) {
    Running => ()
    _ => fail("expected dynamic RMM single-source conversion path to run")
  }
  assert_eq(rmm.read_reg_u64(10), 10U.to_uint64())
  assert_eq(rmm.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(rmm.read_reg_u64(12), (-10L).reinterpret_as_uint64())
  assert_eq(rmm.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(rmm.read_reg_u64(14), 0U.to_uint64())
  assert_eq(rmm.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(rmm.read_reg_u64(16), 0U.to_uint64())
  assert_eq(rmm.read_reg_u64(17) & 0x1fU.to_uint64(), invalid)
  assert_eq(rmm.read_csr(csr_fcsr) & frm_mask, rmm_frm)
}

///|
test "rv64fd unsigned long conversion checks negative half after rounding" {
  let csr_fcsr = 0x003
  let invalid = 0x10U.to_uint64()
  let inexact = 0x01U.to_uint64()
  let runner = make_runner(rv64fd_machine_config())
  // The unsigned-long lower boundary follows the same rounded-result rule as
  // FCVT.WU, but it exercises the RV64-width output path. RNE and RTZ keep
  // -0.5 at signed zero, while RDN rounds to -1 and therefore clips to zero
  // with NV instead of NX.
  runner.cpu.write_freg(1, 0xbfe0000000000000UL)
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xbf000000U))
  runner.load_program(
    words_to_bytes([
      encode_fcvt_lu_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(1, 0x1U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(1, 0x2U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(2, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(2, 0x2U, 18),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
    ]),
    0U,
  )
  match runner.run(14) {
    Running => ()
    _ => fail("expected negative-half fcvt.lu boundary path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(14), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(15) & 0x1fU.to_uint64(), invalid)
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x1fU.to_uint64(), inexact)
  assert_eq(runner.read_reg_u64(18), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(19) & 0x1fU.to_uint64(), invalid)
}

///|
test "rv64fd long conversions clip exact lower rne boundaries" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0xc3e0000000000001UL) // double just below -2^63.
  runner.cpu.write_freg(2, 0xbff0000000000000UL) // double -1, invalid for unsigned long.
  runner.cpu.write_freg(3, exec_test_nan_box_single(0xdf000001U)) // single just below -2^63.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0xbf800000U)) // single -1.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_l_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_s(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected exact lower-bound fcvt long path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(15) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(17) & 0x10U.to_uint64(), 0x10U.to_uint64())
}

///|
test "rv64fd signed integer conversions keep exact minima valid" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0xc1e0000000000000UL) // double -2^31, valid for FCVT.W.D.
  runner.cpu.write_freg(2, exec_test_nan_box_single(0xcf000000U)) // single -2^31.
  runner.cpu.write_freg(3, 0xc3e0000000000000UL) // double -2^63, valid for FCVT.L.D.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0xdf000000U)) // single -2^63.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_s(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_d(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
    ]),
    0U,
  )
  match runner.run(11) {
    Running => ()
    _ => fail("expected exact signed minimum conversion path to run")
  }
  assert_eq(runner.read_reg_u64(10), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0x80000000U))
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(15), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(16), 0x8000000000000000UL)
  assert_eq(runner.read_reg_u64(17), 0U.to_uint64())
}

///|
test "rv64fd integer conversions keep upper valid edges flag clean" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, 0x41dfffffffc00000UL) // double 2^31 - 1.
  runner.cpu.write_freg(2, 0x41efffffffe00000UL) // double 2^32 - 1.
  runner.cpu.write_freg(3, exec_test_nan_box_single(0x4effffffU)) // largest single below 2^31.
  runner.cpu.write_freg(4, exec_test_nan_box_single(0x4f7fffffU)) // largest single below 2^32.
  runner.cpu.write_freg(5, 0x43dfffffffffffffUL) // largest double below 2^63.
  runner.cpu.write_freg(6, 0x43efffffffffffffUL) // largest double below 2^64.
  runner.cpu.write_freg(7, exec_test_nan_box_single(0x5effffffU)) // largest single below 2^63.
  runner.cpu.write_freg(8, exec_test_nan_box_single(0x5f7fffffU)) // largest single below 2^64.
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_d(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_w_s(3, 0x0U, 14),
      encode_csr(csr_fcsr, 0, 0x2U, 15),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_wu_s(4, 0x0U, 16),
      encode_csr(csr_fcsr, 0, 0x2U, 17),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_d(5, 0x0U, 18),
      encode_csr(csr_fcsr, 0, 0x2U, 19),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(6, 0x0U, 20),
      encode_csr(csr_fcsr, 0, 0x2U, 21),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_l_s(7, 0x0U, 22),
      encode_csr(csr_fcsr, 0, 0x2U, 23),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_s(8, 0x0U, 24),
      encode_csr(csr_fcsr, 0, 0x2U, 25),
    ]),
    0U,
  )
  match runner.run(23) {
    Running => ()
    _ => fail("expected upper valid-edge conversion path to run")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(12), test_sign_extend_word64(0xffffffffU))
  assert_eq(runner.read_reg_u64(13), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(14), 0x7fffff80U.to_uint64())
  assert_eq(runner.read_reg_u64(15), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(16), test_sign_extend_word64(0xffffff00U))
  assert_eq(runner.read_reg_u64(17), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(18), 0x7ffffffffffffc00UL)
  assert_eq(runner.read_reg_u64(19), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(20), 0xfffffffffffff800UL)
  assert_eq(runner.read_reg_u64(21), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(22), 0x7fffff8000000000UL)
  assert_eq(runner.read_reg_u64(23), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(24), 0xffffff0000000000UL)
  assert_eq(runner.read_reg_u64(25), 0U.to_uint64())
}

///|
test "rv64fd rne integer conversions clip nan and infinity before host integer casts" {
  let csr_fcsr = 0x003
  let runner = make_runner(rv64fd_machine_config())
  runner.cpu.write_freg(1, exec_test_nan_box_single(0x7fc00000U))
  runner.cpu.write_freg(2, 0x7ff0000000000000UL)
  runner.load_program(
    words_to_bytes([
      encode_fcvt_w_s(1, 0x0U, 10),
      encode_csr(csr_fcsr, 0, 0x2U, 11),
      encode_csr(csr_fcsr, 0, 0x1U, 0),
      encode_fcvt_lu_d(2, 0x0U, 12),
      encode_csr(csr_fcsr, 0, 0x2U, 13),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected RNE invalid fcvt inputs to clip without trapping")
  }
  assert_eq(runner.read_reg_u64(10), 0x7fffffffU.to_uint64())
  assert_eq(runner.read_reg_u64(11) & 0x10U.to_uint64(), 0x10U.to_uint64())
  assert_eq(runner.read_reg_u64(12), 0xffffffffffffffffUL)
  assert_eq(runner.read_reg_u64(13) & 0x10U.to_uint64(), 0x10U.to_uint64())
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
test "rv64 mprv does not affect machine instruction fetch privilege" {
  let program = words_to_bytes([
    encode_i(8, 0, 0x0U, 2, 0x13U),
    encode_i(60, 2, 0x1U, 2, 0x13U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_csr(0x180, 2, 0x1U, 0),
    encode_u(0x00021000U, 3, 0x37U),
    encode_i(-2048, 3, 0x0U, 3, 0x13U),
    encode_csr(0x300, 3, 0x1U, 0),
    encode_j(228, 0, 0x6fU),
  ])
  let runner = make_runner(rv64_machine_config())
  exec_test_setup_basic_sv39_map(runner)
  runner.bus.store_u32(
    0x100U.to_uint64(),
    encode_i(1, 0, 0x0U, 5, 0x13U).to_uint64(),
  )
  runner.bus.store_u32(
    0x104U.to_uint64(),
    encode_i(3, 0, 0x0U, 6, 0x13U).to_uint64(),
  )
  runner.bus.store_u32(
    0x4100U.to_uint64(),
    encode_i(2, 0, 0x0U, 5, 0x13U).to_uint64(),
  )
  runner.bus.store_u32(
    0x4104U.to_uint64(),
    encode_i(4, 0, 0x0U, 6, 0x13U).to_uint64(),
  )
  runner.load_program(program, 0U)
  match runner.run(10) {
    Running => ()
    _ => fail("expected M-mode fetch to ignore MPRV")
  }
  // The Sv39 fixture maps virtual 0x100 to physical 0x4100. If MPRV leaked
  // into instruction fetch, this jump would execute the x5=2/x6=4 pair. The
  // privileged rule keeps MPRV scoped to data accesses, so M-mode fetches the
  // physical code at 0x100 instead.
  assert_eq(runner.read_reg_u64(5), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 3U.to_uint64())
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
test "sfence.vma traps as illegal from user mode" {
  let program = words_to_bytes([
    encode_i(20, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_i(128, 0, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_sfence_vma(0, 0),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for sfence.vma from user mode")
      }
    _ => fail("expected sfence.vma from user mode to trap")
  }
  assert_eq(runner.pc(), 20U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal sfence.vma trap to enter machine mode")
  }
}

///|
test "sfence.vma traps as illegal from supervisor mode when tvm is set" {
  let program = words_to_bytes([
    encode_i(24, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00101000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_sfence_vma(0, 0),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for sfence.vma with tvm")
      }
    _ => fail("expected sfence.vma with tvm to trap")
  }
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal sfence.vma trap to enter machine mode")
  }
}

///|
test "satp read traps as illegal from supervisor mode when tvm is set" {
  let program = words_to_bytes([
    encode_i(24, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00101000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_csr(0x180, 0, 0x2U, 2),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for satp read with tvm")
      }
    _ => fail("expected satp read with tvm to trap")
  }
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal satp read trap to enter machine mode")
  }
}

///|
test "satp write traps as illegal from supervisor mode when tvm is set" {
  let program = words_to_bytes([
    encode_i(28, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00101000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_mret(),
    encode_csr(0x180, 2, 0x1U, 0),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for satp write with tvm")
      }
    _ => fail("expected satp write with tvm to trap")
  }
  assert_eq(runner.pc(), 28U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal satp write trap to enter machine mode")
  }
}

///|
test "satp write with unsupported mode preserves previous value" {
  let runner = make_runner(rv64_machine_config())
  let csr_satp = 0x180
  let initial = exec_test_sv39_satp(0x123U.to_uint64())
  let unsupported_sv48 = (9U.to_uint64() << 60) | 0x456U.to_uint64()
  runner.cpu.write_csr(csr_satp, initial)
  runner.cpu.write_reg(1, unsupported_sv48)
  runner.load_program(
    words_to_bytes([
      encode_csr(csr_satp, 1, 0x1U, 0),
      encode_csr(csr_satp, 0, 0x2U, 2),
    ]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    Trap(info) =>
      fail(
        "expected unsupported satp mode write to be ignored, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_reg_u64(2), initial)
  assert_eq(runner.read_csr_u64(csr_satp), initial)
}

///|
test "satp set and clear forms use whole csr warl behavior" {
  let runner = make_runner(rv64_machine_config())
  let csr_satp = 0x180
  let initial = exec_test_sv39_satp(0x123U.to_uint64())
  let set_sv48_mode_bit = 1U.to_uint64() << 60
  let clear_sv39_mode_bit = 8U.to_uint64() << 60
  runner.cpu.write_csr(csr_satp, initial)
  runner.cpu.write_reg(1, set_sv48_mode_bit)
  runner.cpu.write_reg(2, clear_sv39_mode_bit)
  runner.load_program(
    words_to_bytes([
      encode_csr(csr_satp, 1, 0x2U, 3),
      encode_csr(csr_satp, 0, 0x2U, 4),
      encode_csr(csr_satp, 2, 0x3U, 5),
      encode_csr(csr_satp, 0, 0x2U, 6),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    Trap(info) =>
      fail(
        "expected satp RMW WARL writes to retire, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  // `satp` WARL filtering applies to the whole address-space selector produced
  // by CSRRS/CSRRC, not just to CSRRW inputs. Setting mode bit 60 would turn
  // Sv39 into unsupported Sv48 and must preserve the old value; clearing the
  // Sv39 mode bit produces Bare with reserved ASID/PPN fields and canonicalizes
  // to the supported Bare value zero.
  assert_eq(runner.read_reg_u64(3), initial)
  assert_eq(runner.read_reg_u64(4), initial)
  assert_eq(runner.read_reg_u64(5), initial)
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(csr_satp), 0U.to_uint64())
}

///|
test "satp bare mode write canonicalizes reserved fields" {
  let runner = make_runner(rv64_machine_config())
  let csr_satp = 0x180
  let bare_with_reserved_fields = 0x00ff000000000001UL
  let sv39 = exec_test_sv39_satp(0x456U.to_uint64())
  runner.cpu.write_reg(1, bare_with_reserved_fields)
  runner.cpu.write_reg(2, sv39)
  runner.load_program(
    words_to_bytes([
      encode_csr(csr_satp, 1, 0x1U, 0),
      encode_csr(csr_satp, 0, 0x2U, 3),
      encode_csr(csr_satp, 2, 0x1U, 0),
      encode_csr(csr_satp, 0, 0x2U, 4),
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    Trap(info) =>
      fail(
        "expected satp Bare normalization and Sv39 write to retire, got trap cause=\{trap_cause_name(info.cause)} pc=\{info.faulting_pc.to_string()} tv=\{info.trap_value.to_string()}",
      )
  }
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), sv39)
  assert_eq(runner.read_csr_u64(csr_satp), sv39)
}

///|
test "wfi traps as illegal from user mode" {
  let wfi_raw = encode_wfi()
  let base = 0x80000000U.to_uint64()
  let runner = make_runner(virt_machine_config())
  runner.cpu.write_csr(0x341, base + 4U.to_uint64()) // mepc after MRET
  runner.cpu.write_csr(0x300, 0U.to_uint64()) // mstatus.MPP=U
  runner.all_mtimecmp[0] = 100U.to_uint64()
  runner.load_program_u64(words_to_bytes([encode_mret(), wfi_raw]), base)
  match runner.run(2) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for wfi from user mode")
      }
      assert_eq(info.trap_value, wfi_raw.to_uint64())
    }
    _ => fail("expected wfi from user mode to trap")
  }
  // The privilege failure must happen before the interpreter's legal-WFI timer
  // fast-forward hint; only the normal per-step timer ticks are visible.
  assert_eq(runner.clint_mtime(), 2U.to_uint64())
  assert_eq(runner.pc_u64(), base + 4U.to_uint64())
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal wfi trap to enter machine mode")
  }
}

///|
test "wfi traps as illegal from supervisor mode when tw is set" {
  let wfi_raw = encode_wfi()
  let base = 0x80000000U.to_uint64()
  let runner = make_runner(virt_machine_config())
  runner.cpu.write_csr(0x341, base + 4U.to_uint64()) // mepc after MRET
  runner.cpu.write_csr(0x300, 0x800U.to_uint64() | 0x200000U.to_uint64()) // mstatus.MPP=S, TW=1
  runner.all_mtimecmp[0] = 100U.to_uint64()
  runner.load_program_u64(words_to_bytes([encode_mret(), wfi_raw]), base)
  match runner.run(2) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for wfi with tw")
      }
      assert_eq(info.trap_value, wfi_raw.to_uint64())
    }
    _ => fail("expected wfi with tw to trap")
  }
  assert_eq(runner.clint_mtime(), 2U.to_uint64())
  assert_eq(runner.pc_u64(), base + 4U.to_uint64())
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal wfi trap to enter machine mode")
  }
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
  assert_eq(runner.read_csr(0x141), 12U)
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
test "sstatus exposes and writes FS bits through the alias mask" {
  let program = words_to_bytes([
    encode_i(3, 0, 0x0U, 1, 0x13U),
    encode_i(13, 1, 0x1U, 1, 0x13U),
    encode_csr(0x100, 1, 0x1U, 0),
    encode_csr(0x100, 0, 0x2U, 2),
    encode_csr(0x300, 0, 0x2U, 3),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected sstatus FS aliasing program to run")
  }
  assert_eq(runner.read_reg(2), 0x6000U)
  assert_eq(runner.read_reg(3), 0x6000U)
  assert_eq(runner.read_csr(0x100), 0x6000U)
  assert_eq(runner.read_csr(0x300), 0x6000U)
}

///|
test "sstatus writes preserve machine only mstatus fields" {
  let mstatus = 0x300
  let sstatus = 0x100
  let machine_only = 0x21888U.to_uint64() // MIE | MPIE | MPP=M | MPRV
  let supervisor_visible = 0xC0122U.to_uint64() // SIE | SPIE | SPP | SUM | MXR
  let program = words_to_bytes([
    encode_u(0x00022000U, 1, 0x37U),
    encode_i(-1912, 1, 0x0U, 1, 0x13U),
    encode_csr(mstatus, 1, 0x1U, 0),
    encode_u(0x000C0000U, 2, 0x37U),
    encode_i(0x122, 2, 0x0U, 2, 0x13U),
    encode_csr(sstatus, 2, 0x1U, 0),
    encode_csr(mstatus, 0, 0x2U, 3),
    encode_csr(sstatus, 0, 0x2U, 4),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected sstatus machine-field preservation program to run")
  }
  // `sstatus` is a filtered alias, not a replacement for the whole backing
  // `mstatus` CSR. Writes through the supervisor view may update visible
  // S-mode fields, but must leave M-only interrupt, return, and MPRV state
  // untouched.
  assert_eq(runner.read_reg_u64(3) & machine_only, machine_only)
  assert_eq(runner.read_csr_u64(mstatus) & machine_only, machine_only)
  assert_eq(runner.read_reg_u64(3) & supervisor_visible, supervisor_visible)
  assert_eq(runner.read_reg_u64(4) & supervisor_visible, supervisor_visible)
}

///|
test "sstatus set and clear forms preserve machine only mstatus fields" {
  let mstatus = 0x300
  let sstatus = 0x100
  let machine_only = 0x21888U.to_uint64() // MIE | MPIE | MPP=M | MPRV
  let supervisor_visible = 0xC0122U.to_uint64() // SIE | SPIE | SPP | SUM | MXR
  let program = words_to_bytes([
    encode_csr(mstatus, 1, 0x1U, 0),
    encode_csr(sstatus, 2, 0x2U, 3),
    encode_csr(mstatus, 0, 0x2U, 4),
    encode_csr(sstatus, 0, 0x2U, 5),
    encode_csr(sstatus, 2, 0x3U, 6),
    encode_csr(mstatus, 0, 0x2U, 7),
    encode_csr(sstatus, 0, 0x2U, 8),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(1, machine_only)
  runner.cpu.write_reg(2, supervisor_visible)
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected sstatus RMW preservation program to run")
  }
  // CSRRS/CSRRC are read-modify-write operations on the visible alias. They
  // must merge through the same backing `mstatus` mask as CSRRW rather than
  // treating `sstatus` as independent storage or clearing machine-only state.
  assert_eq(runner.read_reg_u64(4) & machine_only, machine_only)
  assert_eq(runner.read_reg_u64(4) & supervisor_visible, supervisor_visible)
  assert_eq(runner.read_reg_u64(5) & supervisor_visible, supervisor_visible)
  assert_eq(runner.read_reg_u64(6) & supervisor_visible, supervisor_visible)
  assert_eq(runner.read_reg_u64(7) & machine_only, machine_only)
  assert_eq(runner.read_reg_u64(7) & supervisor_visible, 0U.to_uint64())
  assert_eq(runner.read_reg_u64(8) & supervisor_visible, 0U.to_uint64())
  assert_eq(runner.read_csr_u64(mstatus) & machine_only, machine_only)
  assert_eq(runner.read_csr_u64(mstatus) & supervisor_visible, 0U.to_uint64())
}

///|
test "mstatus sd is derived from dirty FS instead of writable storage" {
  let sd_bit = 1U.to_uint64() << 63
  let mstatus_xlen_bits = 0xa00000000UL
  let sstatus_xlen_bits = 0x200000000UL
  let write_mstatus_then_read_views = words_to_bytes([
    encode_csr(0x300, 1, 0x1U, 0),
    encode_csr(0x300, 0, 0x2U, 2),
    encode_csr(0x100, 0, 0x2U, 3),
  ])

  let sd_only = make_runner(rv64_machine_config())
  sd_only.cpu.write_reg(1, sd_bit)
  sd_only.load_program(write_mstatus_then_read_views, 0U)
  match sd_only.run(3) {
    Running => ()
    _ => fail("expected mstatus SD-only write test to run")
  }
  assert_eq(sd_only.read_reg_u64(2), mstatus_xlen_bits)
  assert_eq(sd_only.read_reg_u64(3), sstatus_xlen_bits)
  assert_eq(sd_only.read_csr_u64(0x300), mstatus_xlen_bits)
  assert_eq(sd_only.read_csr_u64(0x100), sstatus_xlen_bits)

  let fs_dirty = make_runner(rv64_machine_config())
  fs_dirty.cpu.write_reg(1, 0x6000U.to_uint64())
  fs_dirty.load_program(write_mstatus_then_read_views, 0U)
  match fs_dirty.run(3) {
    Running => ()
    _ => fail("expected mstatus dirty-FS write test to run")
  }
  assert_eq(
    fs_dirty.read_reg_u64(2),
    sd_bit | mstatus_xlen_bits | 0x6000U.to_uint64(),
  )
  assert_eq(
    fs_dirty.read_reg_u64(3),
    sd_bit | sstatus_xlen_bits | 0x6000U.to_uint64(),
  )
  assert_eq(
    fs_dirty.read_csr_u64(0x300),
    sd_bit | mstatus_xlen_bits | 0x6000U.to_uint64(),
  )
  assert_eq(
    fs_dirty.read_csr_u64(0x100),
    sd_bit | sstatus_xlen_bits | 0x6000U.to_uint64(),
  )
}

///|
test "rv64 status exposes fixed lower privilege xlen fields" {
  let mstatus = 0x300
  let sstatus = 0x100
  let sxl_uxl_64 = 0xa00000000UL
  let uxl_64 = 0x200000000UL
  let runner = make_runner(rv64_machine_config())
  assert_eq(runner.read_csr_u64(mstatus) & sxl_uxl_64, sxl_uxl_64)
  assert_eq(runner.read_csr_u64(sstatus) & uxl_64, uxl_64)
  assert_eq(runner.read_csr_u64(sstatus) & 0x800000000UL, 0U.to_uint64())

  let program = words_to_bytes([
    encode_csr(mstatus, 0, 0x1U, 0),
    encode_csr(sstatus, 0, 0x1U, 0),
    encode_csr(mstatus, 0, 0x2U, 1),
    encode_csr(sstatus, 0, 0x2U, 2),
  ])
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected status xlen csr program to run")
  }
  assert_eq(runner.read_reg_u64(1) & sxl_uxl_64, sxl_uxl_64)
  assert_eq(runner.read_reg_u64(2) & uxl_64, uxl_64)
  assert_eq(runner.read_csr_u64(mstatus) & sxl_uxl_64, sxl_uxl_64)
  assert_eq(runner.read_csr_u64(sstatus) & uxl_64, uxl_64)
}

///|
test "status endian control fields are read only zero" {
  let mstatus = 0x300
  let sstatus = 0x100
  let ube = 0x40U.to_uint64()
  let sbe = 0x1000000000UL
  let mbe = 0x2000000000UL
  let endian_bits = ube | sbe | mbe
  let runner = make_runner(rv64_machine_config())

  let mstatus_program = words_to_bytes([
    encode_i(1, 0, 0x0U, 1, 0x13U),
    encode_i(6, 1, 0x1U, 1, 0x13U),
    encode_u(0x30000000U, 2, 0x37U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_i(36, 2, 0x1U, 2, 0x13U),
    encode_i(1, 2, 0x0U, 2, 0x13U),
    encode_i(37, 2, 0x1U, 2, 0x13U),
    encode_r(0x00U, 2, 1, 0x6U, 3, 0x33U),
    encode_csr(mstatus, 3, 0x1U, 0),
    encode_csr(mstatus, 0, 0x2U, 4),
    encode_csr(sstatus, 0, 0x2U, 5),
  ])
  runner.load_program(mstatus_program, 0U)
  match runner.run(11) {
    Running => ()
    _ => fail("expected endian-control mstatus program to run")
  }
  assert_eq(runner.read_reg_u64(4) & endian_bits, 0U.to_uint64())
  assert_eq(runner.read_reg_u64(5) & ube, 0U.to_uint64())
  assert_eq(runner.read_csr_u64(mstatus) & endian_bits, 0U.to_uint64())
  assert_eq(runner.read_csr_u64(sstatus) & ube, 0U.to_uint64())

  let sstatus_runner = make_runner(rv64_machine_config())
  sstatus_runner.load_program(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      encode_i(6, 1, 0x1U, 1, 0x13U),
      encode_csr(sstatus, 1, 0x1U, 0),
      encode_csr(sstatus, 0, 0x2U, 2),
    ]),
    0U,
  )
  match sstatus_runner.run(4) {
    Running => ()
    _ => fail("expected endian-control sstatus program to run")
  }
  assert_eq(sstatus_runner.read_reg_u64(2) & ube, 0U.to_uint64())
  assert_eq(sstatus_runner.read_csr_u64(sstatus) & ube, 0U.to_uint64())
}

///|
test "mstatus clears unsupported status bits" {
  let mstatus = 0x300
  let sstatus = 0x100
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(mstatus, 1, 0x1U, 0),
    encode_csr(mstatus, 0, 0x2U, 2),
    encode_csr(sstatus, 0, 0x2U, 3),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected mstatus supported-bit program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0x8000000a007e79aaUL)
  assert_eq(runner.read_reg_u64(3), 0x80000002000c6122UL)
  assert_eq(runner.read_csr_u64(mstatus), 0x8000000a007e79aaUL)
  assert_eq(runner.read_csr_u64(sstatus), 0x80000002000c6122UL)
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
test "delegated supervisor timer interrupt traps to stvec from supervisor mode" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(exec_test_supervisor_interrupt_program(32, 48), 0U)
  let expected_scause = (1U.to_uint64() << 63) | 5U.to_uint64()
  match runner.run(14) {
    Running => ()
    _ => fail("expected delegated supervisor timer handler to run")
  }
  assert_eq(runner.read_reg_u64(7), expected_scause)
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x141), 44U.to_uint64())
  assert_eq(runner.read_csr_u64(0x142), expected_scause)
  assert_eq(runner.pc(), 56U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode in delegated timer handler")
  }
}

///|
test "delegated supervisor timer interrupt honors stvec vectored mode" {
  let runner = make_runner(rv64_machine_config())
  // BASE=28 with MODE=1 vectors supervisor timer cause 5 to byte 48, the same
  // handler slot used by the direct-mode helper path.
  runner.load_program(exec_test_supervisor_interrupt_program(32, 29), 0U)
  let expected_scause = (1U.to_uint64() << 63) | 5U.to_uint64()
  match runner.run(14) {
    Running => ()
    _ => fail("expected delegated supervisor timer vector handler to run")
  }
  assert_eq(runner.read_reg_u64(7), expected_scause)
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x105), 29U.to_uint64())
  assert_eq(runner.pc_u64(), 56U.to_uint64())
}

///|
test "delegated supervisor external interrupt traps to stvec from supervisor mode" {
  let runner = make_runner(rv64_machine_config())
  runner.load_program(exec_test_supervisor_interrupt_program(512, 48), 0U)
  let expected_scause = (1U.to_uint64() << 63) | 9U.to_uint64()
  match runner.run(14) {
    Running => ()
    _ => fail("expected delegated supervisor external handler to run")
  }
  assert_eq(runner.read_reg_u64(7), expected_scause)
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x141), 44U.to_uint64())
  assert_eq(runner.read_csr_u64(0x142), expected_scause)
  assert_eq(runner.pc(), 56U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode in delegated external handler")
  }
}

///|
test "virtio-blk plic external interrupt traps to supervisor mode" {
  let runner = make_runner(virtio_blk_machine_config())
  let base = 0x80000000U.to_uint64()
  runner.cpu.write_csr(0x105, base + 8U.to_uint64())
  runner.cpu.write_csr(0x303, 512U.to_uint64())
  runner.cpu.write_csr(0x304, 0xa00U.to_uint64())
  runner.cpu.write_csr(0x300, 0x802U.to_uint64())
  runner.cpu.write_csr(0x341, base + 4U.to_uint64())
  runner.plic_regs[4] = 1U.to_byte()
  runner.plic_regs[0x2080] = 2U.to_byte()
  runner.virtio_blk_state[6] = 1U.to_uint64()
  runner.load_program_u64(
    words_to_bytes([
      encode_mret(),
      encode_i(99, 0, 0x0U, 10, 0x13U),
      encode_csr(0x142, 0, 0x2U, 7),
      encode_i(1, 0, 0x0U, 8, 0x13U),
    ]),
    base,
  )
  let expected_scause = (1U.to_uint64() << 63) | 9U.to_uint64()
  match runner.run(4) {
    Running => ()
    _ => fail("expected virtio-blk PLIC external handler to run")
  }
  assert_eq(runner.read_csr_u64(0x141), base + 4U.to_uint64())
  assert_eq(runner.read_csr_u64(0x142), expected_scause)
  assert_eq(runner.read_reg_u64(7), expected_scause)
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.cpu.pc, base + 16U.to_uint64())
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode in virtio-blk external handler")
  }
}

///|
test "uart plic external interrupt traps to supervisor mode" {
  let runner = make_runner(virt_machine_config())
  let base = 0x80000000U.to_uint64()
  runner.cpu.write_csr(0x105, base + 8U.to_uint64())
  runner.cpu.write_csr(0x303, 512U.to_uint64())
  runner.cpu.write_csr(0x304, 0xa00U.to_uint64())
  runner.cpu.write_csr(0x300, 0x802U.to_uint64())
  runner.cpu.write_csr(0x341, base + 4U.to_uint64())
  // UART is PLIC source 10. Enable it only for context 1, the S-mode context,
  // while leaving both MEIE and SEIE globally enabled to catch wrong routing.
  runner.plic_regs[40] = 1U.to_byte()
  runner.plic_regs[0x2081] = 4U.to_byte()
  runner.uart_ier[0] = 1U.to_byte()
  runner.uart_push_input("Q")
  runner.load_program_u64(
    words_to_bytes([
      encode_mret(),
      encode_i(99, 0, 0x0U, 10, 0x13U),
      encode_csr(0x142, 0, 0x2U, 7),
      encode_i(1, 0, 0x0U, 8, 0x13U),
    ]),
    base,
  )
  let expected_scause = (1U.to_uint64() << 63) | 9U.to_uint64()
  match runner.run(4) {
    Running => ()
    _ => fail("expected UART PLIC external handler to run")
  }
  assert_eq(runner.read_csr_u64(0x141), base + 4U.to_uint64())
  assert_eq(runner.read_csr_u64(0x142), expected_scause)
  assert_eq(runner.read_reg_u64(7), expected_scause)
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0U.to_uint64())
  assert_eq(runner.cpu.pc, base + 16U.to_uint64())
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode in UART external handler")
  }
}

///|
test "PLIC claim chooses highest priority and lower source ID on ties" {
  let claim_context1 = words_to_bytes([
    encode_u(0x0c201000U, 1, 0x37U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
  ])
  let higher_uart = make_runner(virtio_blk_machine_config())
  // Source 1 is virtio-blk and source 10 is UART. Enable both in context 1.
  higher_uart.plic_regs[4] = 1U.to_byte()
  higher_uart.plic_regs[40] = 3U.to_byte()
  higher_uart.plic_regs[0x2080] = 2U.to_byte()
  higher_uart.plic_regs[0x2081] = 4U.to_byte()
  higher_uart.virtio_blk_state[6] = 1U.to_uint64()
  higher_uart.uart_ier[0] = 1U.to_byte()
  higher_uart.uart_push_input("P")
  higher_uart.load_program_u64(claim_context1, 0x80000000U.to_uint64())
  match higher_uart.run(2) {
    Running => ()
    _ => fail("expected running after high-priority UART claim")
  }
  assert_eq(higher_uart.read_reg_u64(2), 10U.to_uint64())
  let tie = make_runner(virtio_blk_machine_config())
  tie.plic_regs[4] = 2U.to_byte()
  tie.plic_regs[40] = 2U.to_byte()
  tie.plic_regs[0x2080] = 2U.to_byte()
  tie.plic_regs[0x2081] = 4U.to_byte()
  tie.virtio_blk_state[6] = 1U.to_uint64()
  tie.uart_ier[0] = 1U.to_byte()
  tie.uart_push_input("T")
  tie.load_program_u64(claim_context1, 0x80000000U.to_uint64())
  match tie.run(2) {
    Running => ()
    _ => fail("expected running after tied-priority PLIC claim")
  }
  assert_eq(tie.read_reg_u64(2), 1U.to_uint64())
  let masked_notification = make_runner(virtio_blk_machine_config())
  masked_notification.plic_regs[4] = 1U.to_byte()
  masked_notification.plic_regs[0x2080] = 2U.to_byte()
  masked_notification.plic_regs[0x201000] = 7U.to_byte()
  masked_notification.virtio_blk_state[6] = 1U.to_uint64()
  masked_notification.load_program_u64(claim_context1, 0x80000000U.to_uint64())
  match masked_notification.run(2) {
    Running => ()
    _ => fail("expected running after threshold-masked PLIC claim")
  }
  assert_eq(masked_notification.read_reg_u64(2), 1U.to_uint64())
}

///|
test "PLIC claim clears pending until completion" {
  let claim_twice_then_complete = words_to_bytes([
    encode_u(0x0c201000U, 1, 0x37U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
    encode_i(4, 1, 0x2U, 3, 0x03U),
    encode_s(4, 2, 1, 0x2U, 0x23U),
    encode_i(4, 1, 0x2U, 4, 0x03U),
  ])
  let runner = make_runner(virtio_blk_machine_config())
  runner.plic_regs[4] = 1U.to_byte()
  runner.plic_regs[0x2080] = 2U.to_byte()
  runner.virtio_blk_state[6] = 1U.to_uint64()
  runner.load_program_u64(claim_twice_then_complete, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected running after PLIC claim/complete sequence")
  }
  assert_eq(runner.read_reg_u64(2), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  let wrong_context_complete = words_to_bytes([
    encode_u(0x0c201000U, 1, 0x37U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
    encode_u(0x0c200000U, 3, 0x37U),
    encode_s(4, 2, 3, 0x2U, 0x23U),
    encode_i(4, 1, 0x2U, 4, 0x03U),
  ])
  let context_runner = make_runner(virtio_blk_machine_config())
  context_runner.plic_regs[4] = 1U.to_byte()
  context_runner.plic_regs[0x2080] = 2U.to_byte()
  context_runner.virtio_blk_state[6] = 1U.to_uint64()
  context_runner.load_program_u64(
    wrong_context_complete,
    0x80000000U.to_uint64(),
  )
  match context_runner.run(5) {
    Running => ()
    _ => fail("expected running after wrong-context PLIC completion")
  }
  assert_eq(context_runner.read_reg_u64(2), 1U.to_uint64())
  assert_eq(context_runner.read_reg_u64(4), 0U.to_uint64())
}

///|
test "load to x0 still performs PLIC claim side effects" {
  let claim_x0_then_claim_x2 = words_to_bytes([
    encode_u(0x0c201000U, 1, 0x37U),
    encode_i(4, 1, 0x2U, 0, 0x03U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
  ])
  let runner = make_runner(virtio_blk_machine_config())
  runner.plic_regs[4] = 1U.to_byte()
  runner.plic_regs[0x2080] = 2U.to_byte()
  runner.virtio_blk_state[6] = 1U.to_uint64()
  runner.load_program_u64(claim_x0_then_claim_x2, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected PLIC claim sequence to retire")
  }
  assert_eq(runner.read_reg_u64(0), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
}

///|
test "PLIC UART claim stays claimed while receiver drains input" {
  let claim_read_complete_claim = words_to_bytes([
    encode_u(0x0c201000U, 1, 0x37U),
    encode_u(0x10000000U, 5, 0x37U),
    encode_i(4, 1, 0x2U, 2, 0x03U),
    encode_i(0, 5, 0x0U, 6, 0x03U),
    encode_i(4, 1, 0x2U, 3, 0x03U),
    encode_s(4, 2, 1, 0x2U, 0x23U),
    encode_i(4, 1, 0x2U, 4, 0x03U),
  ])
  let runner = make_runner(virt_machine_config())
  runner.plic_regs[40] = 1U.to_byte()
  runner.plic_regs[0x2081] = 4U.to_byte()
  runner.uart_ier[0] = 1U.to_byte()
  runner.uart_push_input("U")
  runner.load_program_u64(claim_read_complete_claim, 0x80000000U.to_uint64())
  match runner.run(7) {
    Running => ()
    _ => fail("expected running after UART claim/read/complete sequence")
  }
  assert_eq(runner.read_reg_u64(2), 10U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 85U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64())
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
test "sret clears sie from spie zero and resets spie and spp" {
  let program = words_to_bytes([
    encode_i(0x100, 0, 0x0U, 1, 0x13U),
    encode_csr(0x100, 1, 0x1U, 0), // sstatus.SPP=1, SPIE=0, SIE=0
    encode_i(52, 0, 0x0U, 2, 0x13U),
    encode_csr(0x141, 2, 0x1U, 0), // sepc after SRET
    encode_i(44, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0), // mepc at SRET
    encode_u(0x00001000U, 3, 0x37U),
    encode_i(-1792, 3, 0x0U, 3, 0x13U),
    encode_csr(0x300, 3, 0x1U, 0), // enter S-mode through MRET
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
    _ => fail("expected sret zero-SPIE supervisor return path to run")
  }
  assert_eq(runner.read_reg(15), 1U)
  assert_eq(runner.read_csr(0x100), 0x20U)
  assert_eq(runner.read_csr(0x141), 52U)
  assert_eq(runner.pc(), 56U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode after sret with spp=1")
  }
}

///|
test "mstatus tsr traps supervisor sret as illegal instruction" {
  let mstatus = 0x300
  let mepc = 0x341
  let mcause = 0x342
  let mtval = 0x343
  let mstatus_mpp_s = 0x800U.to_uint64()
  let mstatus_tsr = 0x400000U.to_uint64()
  let sret_raw = encode_sret()
  let runner = make_runner(default_machine_config())
  runner.cpu.write_csr(mstatus, mstatus_mpp_s | mstatus_tsr)
  runner.cpu.write_csr(mepc, 4U.to_uint64())
  runner.load_program(words_to_bytes([encode_mret(), sret_raw]), 0U)

  match runner.step() {
    Running => ()
    _ => fail("expected mret to enter supervisor mode")
  }
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode before trapped sret")
  }

  match runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction cause for TSR-trapped sret")
      }
      assert_eq(info.faulting_pc, 4U.to_uint64())
      assert_eq(info.trap_value, sret_raw.to_uint64())
    }
    _ => fail("expected trapped sret to report a trap event")
  }
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal sret trap to enter machine mode")
  }
  assert_eq(runner.read_csr_u64(mcause), 2U.to_uint64())
  assert_eq(runner.read_csr_u64(mepc), 4U.to_uint64())
  assert_eq(runner.read_csr_u64(mtval), sret_raw.to_uint64())
  assert_eq(runner.pc_u64(), 4U.to_uint64())
}

///|
test "machine mode sret is not intercepted by tsr" {
  let sret_raw = encode_sret()
  let runner = make_runner(default_machine_config())
  runner.cpu.write_csr(0x300, 0x400000U.to_uint64()) // mstatus.TSR=1
  runner.cpu.write_csr(0x141, 4U.to_uint64()) // sepc after SRET
  runner.load_program(
    words_to_bytes([sret_raw, encode_i(1, 0, 0x0U, 2, 0x13U)]),
    0U,
  )
  match runner.run(2) {
    Running => ()
    _ => fail("expected M-mode sret with TSR set to run")
  }
  assert_eq(runner.read_reg(2), 1U)
  assert_eq(runner.read_csr(0x100), 0x20U)
  assert_eq(runner.pc(), 8U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected M-mode sret to restore SPP=0 target")
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
test "mret clears mprv when returning below machine mode" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(28, 5, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00020000U, 1, 0x37U),
    encode_i(128, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_i(1, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected mret to user mode to run")
  }
  assert_eq(runner.read_reg(2), 1U)
  match runner.privilege_mode() {
    User => ()
    _ => fail("expected user privilege restored from mpp")
  }
  assert_eq(runner.read_csr(0x300), 0x88U)
}

///|
test "mret preserves mprv when returning to machine mode" {
  let program = words_to_bytes([
    encode_u(0U, 5, 0x17U),
    encode_i(28, 5, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00022000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_i(1, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(8) {
    Running => ()
    _ => fail("expected mret to machine mode to run")
  }
  assert_eq(runner.read_reg(2), 1U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected machine privilege restored from mpp")
  }
  assert_eq(runner.read_csr(0x300), 0x20088U)
}

///|
test "mret preserves live LR reservation for following SC" {
  // xRET is allowed, but not required, to clear LR reservations. This emulator
  // keeps the reservation live across MRET, matching debugger-friendly
  // implementations where software uses an explicit dummy SC when it needs to
  // force-clear reservation state.
  let runner = make_runner(rv64_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  let original = 0x11223344U.to_uint64()
  let replacement = 0x55667788U.to_uint64()
  runner.bus.store_u32(addr, original)
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, replacement)
  runner.cpu.write_csr(0x341, runner.cpu.pc + 8U.to_uint64())
  runner.cpu.write_csr(0x300, 0x1800U.to_uint64())
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(pc0 + 4U.to_uint64(), encode_mret().to_uint64())
  runner.bus.store_u32(
    pc0 + 8U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )

  match runner.step() {
    Running => ()
    _ => fail("expected lr.w to run before mret")
  }
  assert_eq(runner.read_reg_u64(3), original)
  match runner.step() {
    Running => ()
    _ => fail("expected mret to run")
  }
  assert_eq(runner.pc_u64(), pc0 + 8U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected sc.w after mret to run")
  }
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), replacement)
}

///|
test "sret clears mprv when returning below machine mode" {
  let program = words_to_bytes([
    encode_i(24, 0, 0x0U, 5, 0x13U),
    encode_csr(0x141, 5, 0x1U, 0),
    encode_u(0x00020000U, 1, 0x37U),
    encode_i(288, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_sret(),
    encode_i(1, 0, 0x0U, 2, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Running => ()
    _ => fail("expected sret to supervisor mode to run")
  }
  assert_eq(runner.read_reg(2), 1U)
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor privilege restored from spp")
  }
  assert_eq(runner.read_csr(0x300), 0x22U)
}

///|
test "mret traps as illegal below machine mode" {
  let program = words_to_bytes([
    encode_i(24, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00001000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_mret(),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for mret below machine mode")
      }
    _ => fail("expected mret below machine mode to trap")
  }
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal mret trap to enter machine mode")
  }
}

///|
test "sret traps as illegal from user mode" {
  let program = words_to_bytes([
    encode_i(20, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_i(128, 0, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_sret(),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(6) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for sret from user mode")
      }
    _ => fail("expected sret from user mode to trap")
  }
  assert_eq(runner.pc(), 20U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal sret trap to enter machine mode")
  }
}

///|
test "sret traps as illegal from supervisor mode when tsr is set" {
  let program = words_to_bytes([
    encode_i(24, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_u(0x00401000U, 1, 0x37U),
    encode_i(-1920, 1, 0x0U, 1, 0x13U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_mret(),
    encode_sret(),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected illegal instruction for sret with tsr")
      }
    _ => fail("expected sret with tsr to trap")
  }
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected illegal sret trap to enter machine mode")
  }
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
    encode_csr(0x301, 0, 0x6U, 10),
    encode_csr(0x301, 0, 0x7U, 11),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(11) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(2), 0U)
  assert_eq(runner.read_reg(3), 5U)
  assert_eq(runner.read_reg(4), 5U)
  assert_eq(runner.read_reg(5), 5U)
  assert_eq(runner.read_reg(6), 4U)
  assert_eq(runner.read_reg(7), 4U)
  assert_eq(runner.read_reg(8), 0x40141105U)
  assert_eq(runner.read_reg(9), 0x40141105U)
  assert_eq(runner.read_reg(10), 0x40141105U)
  assert_eq(runner.read_reg(11), 0x40141105U)
  assert_eq(runner.read_csr(0x305), 4U)
}

///|
test "trap vector csrs legalize base alignment and reserved modes" {
  let program = words_to_bytes([
    encode_i(7, 0, 0x0U, 1, 0x13U),
    encode_csr(0x305, 1, 0x1U, 2),
    encode_csr(0x305, 0, 0x2U, 3),
    encode_csr(0x105, 1, 0x1U, 4),
    encode_csr(0x105, 0, 0x2U, 5),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected trap-vector csr writes to run")
  }
  assert_eq(runner.read_reg(2), 0U)
  assert_eq(runner.read_reg(3), 4U)
  assert_eq(runner.read_reg(4), 0U)
  assert_eq(runner.read_reg(5), 4U)
  assert_eq(runner.read_csr(0x305), 4U)
  assert_eq(runner.read_csr(0x105), 4U)
}

///|
test "epc csrs clear bit zero on write and trap return" {
  let program = words_to_bytes([
    encode_i(13, 0, 0x0U, 1, 0x13U),
    encode_csr(0x341, 1, 0x1U, 0),
    encode_csr(0x341, 0, 0x2U, 2),
    encode_csr(0x141, 1, 0x1U, 0),
    encode_csr(0x141, 0, 0x2U, 3),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected epc csr write/read program to run")
  }
  assert_eq(runner.read_reg(2), 12U)
  assert_eq(runner.read_reg(3), 12U)
  assert_eq(runner.read_csr(0x341), 12U)
  assert_eq(runner.read_csr(0x141), 12U)

  let mret_runner = make_runner(default_machine_config())
  mret_runner.cpu.write_csr(0x341, 13U.to_uint64())
  mret_runner.load_program(words_to_bytes([encode_mret()]), 0U)
  match mret_runner.step() {
    Running => ()
    _ => fail("expected mret with odd internal mepc to run")
  }
  assert_eq(mret_runner.pc_u64(), 12U.to_uint64())

  let sret_program = words_to_bytes([
    encode_i(41, 0, 0x0U, 1, 0x13U),
    encode_csr(0x141, 1, 0x1U, 0),
    encode_i(36, 0, 0x0U, 5, 0x13U),
    encode_csr(0x341, 5, 0x1U, 0),
    encode_i(1, 0, 0x0U, 6, 0x13U),
    encode_i(11, 6, 0x1U, 6, 0x13U),
    encode_csr(0x300, 6, 0x1U, 0),
    encode_mret(),
    encode_i(99, 0, 0x0U, 7, 0x13U),
    encode_sret(),
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
  let sret_runner = make_runner(default_machine_config())
  sret_runner.load_program(sret_program, 0U)
  match sret_runner.run(10) {
    Running => ()
    _ => fail("expected sret with odd written sepc to run")
  }
  assert_eq(sret_runner.read_reg(7), 0U)
  assert_eq(sret_runner.read_reg(8), 1U)
  assert_eq(sret_runner.read_csr(0x141), 40U)
  assert_eq(sret_runner.pc_u64(), 44U.to_uint64())
}

///|
test "mstatus mpp normalizes reserved privilege encoding" {
  let program = words_to_bytes([
    encode_u(0x00001000U, 1, 0x37U),
    encode_csr(0x300, 1, 0x1U, 0),
    encode_csr(0x300, 0, 0x2U, 2),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected reserved-mpp csr program to run")
  }
  assert_eq(runner.read_reg(2) & 0x1800U, 0U)
  assert_eq(runner.read_csr(0x300) & 0x1800U, 0U)
}

///|
test "csr write forms still trap on read-only csrs even when old value is suppressed" {
  let mvendorid = 0xF11
  let csrrw_mvendorid = encode_csr(mvendorid, 1, 0x1U, 0)
  let csrrs_mvendorid = encode_csr(mvendorid, 1, 0x2U, 0)
  let csrrc_mvendorid = encode_csr(mvendorid, 1, 0x3U, 0)
  let csrrwi_mvendorid = encode_csr(mvendorid, 1, 0x5U, 0)
  let csrrsi_mvendorid = encode_csr(mvendorid, 1, 0x6U, 0)
  let csrrci_mvendorid = encode_csr(mvendorid, 1, 0x7U, 0)
  let words = [
    csrrw_mvendorid, csrrs_mvendorid, csrrc_mvendorid, csrrwi_mvendorid, csrrsi_mvendorid,
    csrrci_mvendorid,
  ]
  for raw in words {
    let runner = make_runner(default_machine_config())
    runner.cpu.write_reg(1, 0U.to_uint64())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected read-only csr write to trap")
    }
  }
}

///|
test "misa writes preserve the fixed WARL ISA profile" {
  let misa = 0x301
  let runner = make_runner(rv64fd_machine_config())
  let original = runner.read_csr_u64(misa)
  runner.load_program(
    words_to_bytes([
      encode_i(-1, 0, 0x0U, 1, 0x13U),
      encode_csr(misa, 1, 0x1U, 3),
      encode_csr(misa, 0, 0x2U, 2),
      encode_csr(misa, 1, 0x2U, 4),
      encode_csr(misa, 0, 0x2U, 7),
      encode_csr(misa, 1, 0x3U, 5),
      encode_csr(misa, 0, 0x2U, 8),
      encode_csr(misa, 0, 0x5U, 6),
      encode_csr(misa, 0, 0x2U, 9),
      encode_csr(misa, 0x1f, 0x6U, 10),
      encode_csr(misa, 0, 0x2U, 11),
      encode_csr(misa, 0x1f, 0x7U, 12),
      encode_csr(misa, 0, 0x2U, 13),
    ]),
    0U,
  )
  match runner.run(13) {
    Running => ()
    _ => fail("expected fixed-WARL misa writes to retire")
  }
  for rd in 2..<=13 {
    assert_eq(runner.read_reg_u64(rd), original)
  }
  assert_eq(runner.read_csr_u64(misa), original)
}

///|
test "cause csrs keep modeled WLRL interrupt and exception-code bits" {
  let mcause = 0x342
  let scause = 0x142
  let interrupt_software_external = (1U.to_uint64() << 63) | 9U.to_uint64()
  let modeled_all_ones = (1U.to_uint64() << 63) | 0x1fU.to_uint64()
  let runner = make_runner(virt_machine_config())
  runner.cpu.write_reg(4, interrupt_software_external)
  runner.load_program_u64(
    words_to_bytes([
      encode_i(-1, 0, 0x0U, 1, 0x13U),
      encode_csr(mcause, 1, 0x1U, 0),
      encode_csr(mcause, 0, 0x2U, 2),
      encode_csr(scause, 1, 0x1U, 0),
      encode_csr(scause, 0, 0x2U, 3),
      encode_csr(mcause, 4, 0x1U, 0),
      encode_csr(mcause, 0, 0x2U, 5),
      encode_csr(scause, 4, 0x1U, 0),
      encode_csr(scause, 0, 0x2U, 6),
    ]),
    0x80000000U.to_uint64(),
  )
  match runner.run(9) {
    Running => ()
    _ => fail("expected cause CSR WLRL writes to retire")
  }
  assert_eq(runner.read_reg_u64(2), modeled_all_ones)
  assert_eq(runner.read_reg_u64(3), modeled_all_ones)
  assert_eq(runner.read_reg_u64(5), interrupt_software_external)
  assert_eq(runner.read_reg_u64(6), interrupt_software_external)
  assert_eq(runner.read_csr_u64(mcause), interrupt_software_external)
  assert_eq(runner.read_csr_u64(scause), interrupt_software_external)
}

///|
test "csr read forms may read read-only csrs without writing them" {
  let read_misa_csrrs = encode_csr(0x301, 0, 0x2U, 2)
  let read_misa_csrrc = encode_csr(0x301, 0, 0x3U, 3)
  let read_misa_csrrsi = encode_csr(0x301, 0, 0x6U, 4)
  let read_misa_csrrci = encode_csr(0x301, 0, 0x7U, 5)
  let runner = make_runner(default_machine_config())
  runner.load_program(
    words_to_bytes([
      read_misa_csrrs, read_misa_csrrc, read_misa_csrrsi, read_misa_csrrci,
    ]),
    0U,
  )
  match runner.run(4) {
    Running => ()
    _ => fail("expected read-only csr read forms to run")
  }
  let misa = runner.read_csr_u64(0x301)
  assert_eq(runner.read_reg_u64(2), misa)
  assert_eq(runner.read_reg_u64(3), misa)
  assert_eq(runner.read_reg_u64(4), misa)
  assert_eq(runner.read_reg_u64(5), misa)
}

///|
test "zero-mask set and clear forms read address-read-only csrs" {
  // CSRRS/CSRRC with x0, and their immediate forms with uimm=0, suppress the
  // write side entirely. Address-encoded read-only CSRs are therefore legal
  // operands for these pure-read forms even though every nonzero mask traps.
  let mhartid = 0xF14
  let mconfigptr = 0xF15
  let time = 0xC01
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(
    words_to_bytes([
      encode_csr(mhartid, 0, 0x2U, 2),
      encode_csr(mhartid, 0, 0x3U, 3),
      encode_csr(mconfigptr, 0, 0x6U, 4),
      encode_csr(mconfigptr, 0, 0x7U, 5),
      encode_csr(0xC00, 0, 0x2U, 6), // CSRRS x6, cycle, x0
      encode_csr(time, 0, 0x7U, 7), // CSRRCI x7, time, 0
      encode_csr(0xC02, 0, 0x3U, 8), // CSRRC x8, instret, x0
    ]),
    0x80000000U.to_uint64(),
  )
  match runner.run(7) {
    Running => ()
    _ => fail("expected zero-mask read-only CSR forms to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0U.to_uint64())
  assert_true(runner.read_reg_u64(6) > 0U.to_uint64())
  assert_true(runner.read_reg_u64(7) >= runner.read_reg_u64(6))
  assert_true(runner.read_reg_u64(8) >= runner.read_reg_u64(6))
}

///|
test "read-only counter csrs reject every non-suppressed write form" {
  // cycle/time/instret are user-visible counter aliases. They may be read when
  // privilege and counteren permit it, but writes must target the machine
  // backing CSRs instead. This is also the Zicsr suppression edge: CSRRW with
  // rd=x0 skips the read, but it is still a write and must trap.
  let cases = [
    encode_csr(0xC00, 1, 0x1U, 0), // CSRRW x0, cycle, x1
    encode_csr(0xC01, 1, 0x2U, 2), // CSRRS x2, time, x1
    encode_csr(0xC02, 1, 0x3U, 3), // CSRRC x3, instret, x1
    encode_csr(0xC00, 1, 0x5U, 0), // CSRRWI x0, cycle, 1
    encode_csr(0xC01, 1, 0x6U, 4), // CSRRSI x4, time, 1
    encode_csr(0xC02, 1, 0x7U, 5), // CSRRCI x5, instret, 1
  ]
  for raw in cases {
    let runner = make_runner(virt_machine_config())
    runner.cpu.write_reg(1, 1U.to_uint64())
    runner.load_program_u64(words_to_bytes([raw]), 0x80000000U.to_uint64())
    expect_step_trap(
      runner,
      "illegal instruction",
      raw.to_uint64(),
      "expected read-only counter CSR write to trap",
    )
  }
}

///|
test "mip writes affect only supervisor pending software bits" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
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
  assert_eq(runner.read_reg(3), 0x222U)
  assert_eq(runner.read_reg(4), 0x222U)
  assert_eq(runner.read_reg(5), 0U)
  assert_eq(runner.read_reg(6), 2U)
  assert_eq(runner.read_csr(0x344), 2U)
  assert_eq(runner.pc(), 24U)
  match runner.privilege_mode() {
    Machine => ()
    _ => fail("expected privilege mode to remain machine")
  }
}

///|
test "mie exposes only modeled interrupt enable bits" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(0x304, 1, 0x1U, 0),
    encode_csr(0x304, 0, 0x2U, 2),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected mie WARL program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0xaaaU.to_uint64())
  assert_eq(runner.read_csr_u64(0x304), 0xaaaU.to_uint64())
}

///|
test "mie masks unsupported interrupt enables across set and clear forms" {
  expect_masked_csr_set_clear_forms(0x304, 0xaaaU.to_uint64(), "mie")
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
  assert_eq(runner.read_csr(0x344), 0U)
  assert_eq(runner.read_csr(0x302), 4U)
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
test "delegation csrs expose only supported writable bits" {
  let medeleg = 0x302
  let mideleg = 0x303
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(medeleg, 1, 0x1U, 0),
    encode_csr(mideleg, 1, 0x1U, 0),
    encode_csr(medeleg, 0, 0x2U, 2),
    encode_csr(mideleg, 0, 0x2U, 3),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected delegation WARL program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0xb3feU.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0x222U.to_uint64())
  assert_eq(runner.read_csr_u64(medeleg), 0xb3feU.to_uint64())
  assert_eq(runner.read_csr_u64(mideleg), 0x222U.to_uint64())
}

///|
test "delegation csrs mask unsupported causes across set and clear forms" {
  expect_masked_csr_set_clear_forms(0x302, 0xb3feU.to_uint64(), "medeleg")
  expect_masked_csr_set_clear_forms(0x303, 0x222U.to_uint64(), "mideleg")
}

///|
test "delegated atomic address-misaligned traps enter supervisor mode" {
  let program = words_to_bytes([
    encode_i(52, 0, 0x0U, 6, 0x13U), // handler address
    encode_csr(0x105, 6, 0x1U, 0), // stvec
    encode_i(0x50, 0, 0x0U, 1, 0x13U), // delegate causes 4 and 6
    encode_csr(0x302, 1, 0x1U, 0), // medeleg
    encode_i(40, 0, 0x0U, 5, 0x13U), // S-mode entry
    encode_csr(0x341, 5, 0x1U, 0), // mepc
    encode_u(0x00001000U, 3, 0x37U),
    encode_i(-2048, 3, 0x0U, 3, 0x13U),
    encode_csr(0x300, 3, 0x1U, 0), // mstatus.MPP=S
    encode_mret(),
    encode_i(0x102, 0, 0x0U, 1, 0x13U), // misaligned word address
    encode_amo(0x02U, 0, 1, 0x2U, 3), // lr.w x3, (x1)
    encode_i(99, 0, 0x0U, 9, 0x13U),
    encode_csr(0x142, 0, 0x2U, 7), // scause
    encode_i(1, 0, 0x0U, 8, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(14) {
    Running => ()
    _ => fail("expected delegated misaligned atomic handler to run")
  }
  assert_eq(runner.read_reg_u64(7), 4U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(9), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x141), 44U.to_uint64())
  assert_eq(runner.read_csr_u64(0x142), 4U.to_uint64())
  assert_eq(runner.read_csr_u64(0x143), 0x102U.to_uint64())
  match runner.privilege_mode() {
    Supervisor => ()
    _ => fail("expected delegated atomic misalignment to enter supervisor mode")
  }
}

///|
test "counter csrs expose monotonic Linux-visible reads" {
  let program = words_to_bytes([
    encode_csr(0xC00, 0, 0x2U, 1), // cycle
    encode_csr(0xC01, 0, 0x2U, 2), // time
    encode_csr(0xC02, 0, 0x2U, 3), // instret
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected counter CSR reads to run")
  }
  assert_true(runner.read_reg_u64(1) > 0U.to_uint64())
  assert_true(runner.read_reg_u64(2) >= runner.read_reg_u64(1))
  assert_true(runner.read_reg_u64(3) >= runner.read_reg_u64(2))
}

///|
test "rv32 counter high-half csrs are readable" {
  let program = words_to_bytes([
    encode_csr(0xC80, 0, 0x2U, 1), // cycleh
    encode_csr(0xC81, 0, 0x2U, 2), // timeh
    encode_csr(0xC82, 0, 0x2U, 3), // instreth
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(3) {
    Running => ()
    _ => fail("expected rv32 counter high-half CSR reads to run")
  }
  assert_eq(runner.read_reg_u64(1), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
}

///|
test "rv64 counter high-half csrs are absent across csr forms" {
  // cycleh/timeh/instreth, machine high-half aliases, and the HPM high-half
  // ranges are RV32-only. On RV64 the architectural counters are already
  // XLEN-wide, so these CSR numbers are not implemented read aliases or
  // suppressed-read write targets.
  let cases = [
    0xC80, // cycleh
     0xC81, // timeh
     0xC82, // instreth
     0xB80, // mcycleh
     0xB82, // minstreth
     0xC83, // hpmcounter3h
     0xC9F, // hpmcounter31h
     0xB83, // mhpmcounter3h
     0xB9F, // mhpmcounter31h
     0x723, // mhpmevent3h
     0x73F, // mhpmevent31h
  ]
  for csr in cases {
    let forms = [
      encode_csr(csr, 0, 0x2U, 1),
      encode_csr(csr, 1, 0x1U, 0),
      encode_csr(csr, 1, 0x5U, 0),
      encode_csr(csr, 1, 0x2U, 2),
      encode_csr(csr, 1, 0x3U, 3),
      encode_csr(csr, 1, 0x6U, 4),
      encode_csr(csr, 1, 0x7U, 5),
    ]
    for raw in forms {
      let runner = make_runner(rv64_machine_config())
      runner.cpu.write_reg(1, 1U.to_uint64())
      runner.load_program(words_to_bytes([raw]), 0U)
      match runner.step() {
        Trap(info) => {
          match info.cause {
            IllegalInstruction => ()
            _ => fail("expected rv64 high-half counter CSR form to trap")
          }
          assert_eq(info.trap_value, raw.to_uint64())
        }
        _ => fail("expected rv64 high-half counter CSR form to trap")
      }
    }
  }
}

///|
test "counter csr reads obey mcounteren and scounteren privilege gates" {
  let read_time = encode_csr(0xC01, 0, 0x2U, 1)

  let machine = make_runner(rv64_machine_config())
  machine.load_program(words_to_bytes([read_time]), 0U)
  match machine.step() {
    Running => ()
    _ => fail("machine mode counter read should not need counteren")
  }

  let supervisor_denied = make_runner(rv64_machine_config())
  supervisor_denied.load_program(
    words_to_bytes([
      encode_i(24, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      read_time,
    ]),
    0U,
  )
  match supervisor_denied.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected supervisor counter read to trap without mcounteren")
      }
    _ => fail("expected supervisor counter read trap without mcounteren")
  }

  let supervisor_allowed = make_runner(rv64_machine_config())
  supervisor_allowed.load_program(
    words_to_bytes([
      encode_i(2, 0, 0x0U, 2, 0x13U),
      encode_csr(0x306, 2, 0x1U, 0),
      encode_i(32, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      read_time,
    ]),
    0U,
  )
  match supervisor_allowed.run(9) {
    Running => ()
    _ => fail("expected supervisor counter read with mcounteren")
  }
  match supervisor_allowed.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode after mret")
  }

  let user_denied_by_scounteren = make_runner(rv64_machine_config())
  user_denied_by_scounteren.load_program(
    words_to_bytes([
      encode_i(2, 0, 0x0U, 2, 0x13U),
      encode_csr(0x306, 2, 0x1U, 0),
      encode_i(24, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_csr(0x300, 0, 0x5U, 0),
      encode_mret(),
      read_time,
    ]),
    0U,
  )
  match user_denied_by_scounteren.run(7) {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected user counter read to trap without scounteren")
      }
    _ => fail("expected user counter read trap without scounteren")
  }

  let user_allowed = make_runner(rv64_machine_config())
  user_allowed.load_program(
    words_to_bytes([
      encode_i(2, 0, 0x0U, 2, 0x13U),
      encode_csr(0x306, 2, 0x1U, 0),
      encode_csr(0x106, 2, 0x1U, 0),
      encode_i(28, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_csr(0x300, 0, 0x5U, 0),
      encode_mret(),
      read_time,
    ]),
    0U,
  )
  match user_allowed.run(8) {
    Running => ()
    _ => fail("expected user counter read with both counteren CSRs")
  }
  match user_allowed.privilege_mode() {
    User => ()
    _ => fail("expected user mode after mret")
  }
}

///|
test "counteren csrs expose only base counter enable bits" {
  let mcounteren = 0x306
  let scounteren = 0x106
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(mcounteren, 1, 0x1U, 0),
    encode_csr(scounteren, 1, 0x1U, 0),
    encode_csr(mcounteren, 0, 0x2U, 2),
    encode_csr(scounteren, 0, 0x2U, 3),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected counteren WARL program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0x7U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0x7U.to_uint64())
  assert_eq(runner.read_csr_u64(mcounteren), 0x7U.to_uint64())
  assert_eq(runner.read_csr_u64(scounteren), 0x7U.to_uint64())
}

///|
fn expect_masked_csr_set_clear_forms(
  csr : Int,
  writable_mask : UInt64,
  label : String,
) -> Unit raise {
  let immediate_mask = writable_mask & 0x1fU.to_uint64()
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    // Masked WARL CSRs still use ordinary Zicsr read-modify-write flow. The
    // old visible value is returned to rd, while unsupported bits disappear at
    // the write boundary. Immediate forms can only request the low five bits,
    // so their expected visible write is the implemented mask intersected with
    // that immediate field.
    encode_csr(csr, 1, 0x2U, 2),
    encode_csr(csr, 0, 0x2U, 3),
    encode_csr(csr, 1, 0x3U, 4),
    encode_csr(csr, 0, 0x2U, 5),
    encode_csr(csr, 0x1f, 0x6U, 6),
    encode_csr(csr, 0, 0x2U, 7),
    encode_csr(csr, 0x1f, 0x7U, 8),
    encode_csr(csr, 0, 0x2U, 9),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected masked WARL CSR set/clear program to run for " + label)
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), writable_mask)
  assert_eq(runner.read_reg_u64(4), writable_mask)
  assert_eq(runner.read_reg_u64(5), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(7), immediate_mask)
  assert_eq(runner.read_reg_u64(8), immediate_mask)
  assert_eq(runner.read_reg_u64(9), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(csr), 0U.to_uint64())
}

///|
test "counteren csrs mask unsupported hpm bits across set and clear forms" {
  expect_masked_csr_set_clear_forms(0x306, 0x7U.to_uint64(), "mcounteren")
  expect_masked_csr_set_clear_forms(0x106, 0x7U.to_uint64(), "scounteren")
}

///|
test "hpm counter csrs trap when hpm counters are not implemented" {
  // mcounteren/scounteren expose HPM enable bits as read-only zero because the
  // matching hpmcounter, mhpmcounter, and mhpmevent CSR surface is absent in
  // this RV64GC profile. Check both ends of each family so the emulator cannot
  // accidentally implement only the first slot as zero-valued compatibility
  // storage.
  let representative_hpm_csrs = [
    0xC03, // hpmcounter3
     0xC1F, // hpmcounter31
     0xB03, // mhpmcounter3
     0xB1F, // mhpmcounter31
     0x323, // mhpmevent3
     0x33F, // mhpmevent31
  ]
  for csr in representative_hpm_csrs {
    let read_raw = encode_csr(csr, 0, 0x2U, 1)
    let write_raw = encode_csr(csr, 1, 0x1U, 0)
    for raw in [read_raw, write_raw] {
      let runner = make_runner(rv64_machine_config())
      runner.cpu.write_reg(1, 1U.to_uint64())
      runner.load_program(words_to_bytes([raw]), 0U)
      expect_step_trap(
        runner,
        "illegal instruction",
        raw.to_uint64(),
        "expected absent HPM CSR access to trap",
      )
    }
  }
}

///|
test "mcountinhibit gates cycle and instret but not time" {
  let mcountinhibit = 0x320
  let program = words_to_bytes([
    encode_csr(0xC00, 0, 0x2U, 1), // cycle
    encode_csr(0xC02, 0, 0x2U, 2), // instret
    encode_i(-1, 0, 0x0U, 5, 0x13U),
    encode_csr(mcountinhibit, 5, 0x1U, 0),
    encode_csr(mcountinhibit, 0, 0x2U, 10),
    encode_csr(0xC00, 0, 0x2U, 3), // inhibited cycle
    encode_csr(0xC02, 0, 0x2U, 4), // inhibited instret
    encode_csr(0xC01, 0, 0x2U, 8), // uninhibited time
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_csr(0xC00, 0, 0x2U, 6), // still inhibited cycle
    encode_csr(0xC02, 0, 0x2U, 7), // still inhibited instret
    encode_csr(0xC01, 0, 0x2U, 9), // time still advances
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(12) {
    Running => ()
    _ => fail("expected mcountinhibit program to run")
  }
  assert_true(runner.read_reg_u64(1) > 0U.to_uint64())
  assert_true(runner.read_reg_u64(2) > 0U.to_uint64())
  assert_eq(runner.read_reg_u64(10), 0x5U.to_uint64())
  assert_eq(runner.read_csr_u64(mcountinhibit), 0x5U.to_uint64())
  assert_eq(runner.read_reg_u64(4), runner.read_reg_u64(2) + 3U.to_uint64())
  assert_eq(runner.read_reg_u64(6), runner.read_reg_u64(3))
  assert_eq(runner.read_reg_u64(7), runner.read_reg_u64(4))
  assert_true(runner.read_reg_u64(9) > runner.read_reg_u64(8))
}

///|
test "mcountinhibit masks unsupported hpm bits across set and clear forms" {
  expect_masked_csr_set_clear_forms(0x320, 0x5U.to_uint64(), "mcountinhibit")
}

///|
test "synchronous traps do not retire into instret" {
  let illegal_runner = make_runner(virt_machine_config())
  illegal_runner.load_program_u64(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      0x0000000bU, // Unknown 32-bit instruction: traps before retirement.
    ]),
    0x80000000U.to_uint64(),
  )
  expect_step_running(illegal_runner, "expected first instruction to retire")
  assert_eq(illegal_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
  expect_step_trap(
    illegal_runner,
    "illegal instruction",
    0x0000000bU.to_uint64(),
    "expected illegal instruction trap",
  )
  // minstret counts retired instructions only; a synchronous exception updates
  // trap CSRs and control flow, but the faulting instruction does not retire.
  assert_eq(illegal_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())

  let ecall_runner = make_runner(virt_machine_config())
  ecall_runner.load_program_u64(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      0x00000073U, // ECALL is a synchronous environment-call exception.
    ]),
    0x80000000U.to_uint64(),
  )
  expect_step_running(
    ecall_runner, "expected first instruction before ecall to retire",
  )
  assert_eq(ecall_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
  expect_step_trap(
    ecall_runner,
    "ecall from m-mode",
    0U.to_uint64(),
    "expected ecall trap",
  )
  assert_eq(ecall_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())

  let ebreak_runner = make_runner(virt_machine_config())
  ebreak_runner.load_program_u64(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      0x00100073U, // EBREAK is a synchronous breakpoint exception.
    ]),
    0x80000000U.to_uint64(),
  )
  expect_step_running(
    ebreak_runner, "expected first instruction before ebreak to retire",
  )
  assert_eq(ebreak_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
  expect_step_trap(
    ebreak_runner,
    "breakpoint",
    0U.to_uint64(),
    "expected ebreak trap",
  )
  assert_eq(ebreak_runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
}

///|
test "trap-vector entry does not retire into instret" {
  let mtvec = 0x305
  let handler = 16
  let program = words_to_bytes([
    encode_i(handler, 0, 0x0U, 1, 0x13U),
    encode_csr(mtvec, 1, 0x1U, 0),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_ecall(),
    encode_csr(exec_test_instret_csr, 0, 0x2U, 3),
    encode_i(1, 0, 0x0U, 4, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected ecall to enter mtvec and continue")
  }
  // The handler sees three retired setup instructions. The ECALL itself
  // entered the trap vector but did not retire.
  assert_eq(runner.read_reg(3), 3U)
  assert_eq(runner.read_csr(exec_test_instret_csr), 4U)
  assert_eq(runner.read_csr(0x341), 12U)
  assert_eq(runner.read_csr(0x342), 11U)
  assert_eq(runner.pc(), 20U)
  assert_eq(runner.read_reg(4), 0U)
}

///|
test "execute fault trap-vector entry does not retire into instret" {
  let mtvec = 0x305
  let handler = 24
  let program = words_to_bytes([
    encode_i(handler, 0, 0x0U, 1, 0x13U),
    encode_csr(mtvec, 1, 0x1U, 0),
    encode_u(0x50000000U, 5, 0x37U),
    encode_i(0, 5, 0x2U, 6, 0x03U),
    encode_i(99, 0, 0x0U, 7, 0x13U),
    encode_i(99, 0, 0x0U, 8, 0x13U),
    encode_csr(exec_test_instret_csr, 0, 0x2U, 3),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected load fault to enter mtvec and continue")
  }
  // ADDI, CSRRW, and LUI retired. The faulting LW entered the handler but did
  // not retire, so the handler's CSR read observes 3.
  assert_eq(runner.read_reg(3), 3U)
  assert_eq(runner.read_csr(exec_test_instret_csr), 4U)
  assert_eq(runner.read_csr(0x341), 12U)
  assert_eq(runner.read_csr(0x342), 5U)
  assert_eq(runner.read_csr(0x343), 0x50000000U)
  assert_eq(runner.read_reg(6), 0U)
  assert_eq(runner.read_reg(7), 0U)
  assert_eq(runner.pc(), 28U)
}

///|
test "interrupts do not retire into instret" {
  let base = 0x80000000U.to_uint64()
  let runner = make_runner(virt_machine_config())
  runner.cpu.write_csr(0x300, 0x8U.to_uint64()) // mstatus.MIE
  runner.cpu.write_csr(0x304, 0x80U.to_uint64()) // mie.MTIE
  runner.all_mtimecmp[0] = 0U.to_uint64()
  runner.load_program_u64(
    words_to_bytes([encode_i(1, 0, 0x0U, 1, 0x13U)]),
    base,
  )
  match runner.step() {
    Trap(info) => {
      match info.cause {
        MachineTimerInterrupt => ()
        _ => fail("expected machine timer interrupt")
      }
      assert_eq(info.faulting_pc, base)
      assert_eq(info.trap_value, 0U.to_uint64())
    }
    _ => fail("expected pending interrupt before instruction execution")
  }
  // Interrupts are observed between instructions. The ADDI at `base` was never
  // fetched or retired, so minstret and the destination register stay unchanged.
  assert_eq(runner.read_csr_u64(exec_test_instret_csr), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(1), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(0x341), base)
  assert_eq(runner.read_csr_u64(0x342), (1U.to_uint64() << 63) | 7U.to_uint64())
}

///|
test "interrupt trap-vector entry does not retire into instret" {
  let base = 0x80000000U.to_uint64()
  let runner = make_runner(virt_machine_config())
  runner.cpu.write_csr(0x300, 0x8U.to_uint64()) // mstatus.MIE
  runner.cpu.write_csr(0x304, 0x80U.to_uint64()) // mie.MTIE
  runner.cpu.write_csr(0x305, base + 8U.to_uint64()) // mtvec direct
  runner.all_mtimecmp[0] = 0U.to_uint64()
  runner.load_program_u64(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      encode_i(0, 0, 0x0U, 0, 0x13U),
      encode_csr(exec_test_instret_csr, 0, 0x2U, 3),
    ]),
    base,
  )
  match runner.step() {
    Running => ()
    _ => fail("expected interrupt to enter mtvec")
  }
  assert_eq(runner.pc_u64(), base + 8U.to_uint64())
  assert_eq(runner.read_reg_u64(1), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(exec_test_instret_csr), 0U.to_uint64())
  expect_step_running(
    runner, "expected interrupt handler instruction to retire",
  )
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
  assert_eq(runner.read_csr_u64(0x341), base)
  assert_eq(runner.read_csr_u64(0x342), (1U.to_uint64() << 63) | 7U.to_uint64())
}

///|
test "instruction fetch faults do not retire into instret" {
  let fault_pc = 0x10000U.to_uint64()
  let runner = make_runner(rv64_machine_config())
  runner.load_program(words_to_bytes([encode_j(0x10000, 0, 0x6fU)]), 0U)
  expect_step_running(runner, "expected jump to retire before fetch fault")
  assert_eq(runner.pc_u64(), fault_pc)
  assert_eq(runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
  match runner.step() {
    Trap(info) => {
      match info.cause {
        InstructionAccessFault => ()
        _ => fail("expected instruction access fault")
      }
      assert_eq(info.faulting_pc, fault_pc)
      assert_eq(info.trap_value, fault_pc)
    }
    _ => fail("expected instruction fetch fault")
  }
  // The jump retired, but the failed fetch at the target did not.
  assert_eq(runner.read_csr_u64(exec_test_instret_csr), 1U.to_uint64())
}

///|
test "machine counter csrs back unprivileged counter shadows" {
  let mcountinhibit = 0x320
  let mcycle = 0xB00
  let minstret = 0xB02
  let program = words_to_bytes([
    encode_i(5, 0, 0x0U, 5, 0x13U),
    encode_csr(mcountinhibit, 5, 0x1U, 0),
    encode_i(123, 0, 0x0U, 6, 0x13U),
    encode_csr(mcycle, 6, 0x1U, 0),
    encode_csr(minstret, 6, 0x1U, 0),
    encode_csr(0xC00, 0, 0x2U, 2),
    encode_csr(0xC02, 0, 0x2U, 3),
    encode_csr(mcycle, 0, 0x2U, 4),
    encode_csr(minstret, 0, 0x2U, 7),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(9) {
    Running => ()
    _ => fail("expected machine counter CSR program to run")
  }
  assert_eq(runner.read_reg_u64(2), 123U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 123U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 123U.to_uint64())
  assert_eq(runner.read_reg_u64(7), 123U.to_uint64())
  assert_eq(runner.read_csr_u64(0xC00), runner.read_csr_u64(mcycle))
  assert_eq(runner.read_csr_u64(0xC02), runner.read_csr_u64(minstret))

  let write_mcycleh = encode_csr(0xB80, 1, 0x1U, 0)
  let rv64_high = make_runner(rv64_machine_config())
  rv64_high.cpu.write_reg(1, 1U.to_uint64())
  rv64_high.load_program(words_to_bytes([write_mcycleh]), 0U)
  match rv64_high.step() {
    Trap(info) =>
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected rv64 mcycleh write to trap")
      }
    _ => fail("expected rv64 mcycleh write to trap")
  }
}

///|
test "environment config csrs expose no optional feature bits" {
  let menvcfg = 0x30A
  let senvcfg = 0x10A
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(menvcfg, 1, 0x1U, 0),
    encode_csr(senvcfg, 1, 0x1U, 0),
    encode_csr(menvcfg, 0, 0x2U, 2),
    encode_csr(senvcfg, 0, 0x2U, 3),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected environment config CSR program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(menvcfg), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(senvcfg), 0U.to_uint64())
}

///|
fn expect_warl_zero_csr_set_clear_forms(
  csr : Int,
  label : String,
) -> Unit raise {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    // Writable WARL-zero CSRs are not read-only CSRs. Set/clear forms with a
    // nonzero source must execute and report the old value, even though every
    // attempted written bit is normalized away at the visible CSR boundary.
    encode_csr(csr, 1, 0x2U, 2),
    encode_csr(csr, 0, 0x2U, 3),
    encode_csr(csr, 1, 0x3U, 4),
    encode_csr(csr, 0, 0x2U, 5),
    encode_csr(csr, 0x1f, 0x6U, 6),
    encode_csr(csr, 0, 0x2U, 7),
    encode_csr(csr, 0x1f, 0x7U, 8),
    encode_csr(csr, 0, 0x2U, 9),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected WARL-zero CSR set/clear program to run for " + label)
  }
  for rd in 2..<=9 {
    assert_eq(runner.read_reg_u64(rd), 0U.to_uint64())
  }
  assert_eq(runner.read_csr_u64(csr), 0U.to_uint64())
}

///|
test "environment config csrs stay WARL zero across set and clear forms" {
  expect_warl_zero_csr_set_clear_forms(0x30A, "menvcfg")
  expect_warl_zero_csr_set_clear_forms(0x10A, "senvcfg")
}

///|
test "pmp csrs are warl zero without pmp enforcement" {
  let pmpcfg0 = 0x3A0
  let pmpaddr0 = 0x3B0
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(pmpcfg0, 1, 0x1U, 0),
    encode_csr(pmpaddr0, 1, 0x1U, 0),
    encode_csr(pmpcfg0, 0, 0x2U, 2),
    encode_csr(pmpaddr0, 0, 0x2U, 3),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(5) {
    Running => ()
    _ => fail("expected PMP CSR program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(pmpcfg0), 0U.to_uint64())
  assert_eq(runner.read_csr_u64(pmpaddr0), 0U.to_uint64())
}

///|
test "pmp csrs stay WARL zero across set and clear forms" {
  expect_warl_zero_csr_set_clear_forms(0x3A0, "pmpcfg0")
  expect_warl_zero_csr_set_clear_forms(0x3B0, "pmpaddr0")
}

///|
test "mnstatus traps when Smrnmi is absent" {
  let mnstatus = 0x744
  let read_raw = encode_csr(mnstatus, 0, 0x2U, 1)
  let write_raw = encode_csr(mnstatus, 1, 0x1U, 0)
  for raw in [read_raw, write_raw] {
    let runner = make_runner(rv64_machine_config())
    runner.cpu.write_reg(1, 1U.to_uint64())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause for absent Smrnmi CSR")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected absent Smrnmi CSR access to trap")
    }
  }
}

///|
test "mconfigptr is mandatory read only zero" {
  let mconfigptr = 0xF15
  let read_raw = encode_csr(mconfigptr, 0, 0x2U, 2)
  let write_raw = encode_csr(mconfigptr, 1, 0x1U, 0)
  let reader = make_runner(rv64_machine_config())
  reader.load_program(words_to_bytes([read_raw]), 0U)
  match reader.step() {
    Running => ()
    _ => fail("expected mconfigptr read to run")
  }
  assert_eq(reader.read_reg_u64(2), 0U.to_uint64())
  assert_eq(reader.read_csr_u64(mconfigptr), 0U.to_uint64())

  let writer = make_runner(rv64_machine_config())
  writer.cpu.write_reg(1, 1U.to_uint64())
  writer.load_program(words_to_bytes([write_raw]), 0U)
  match writer.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected mconfigptr write to trap as read-only")
      }
      assert_eq(info.trap_value, write_raw.to_uint64())
    }
    _ => fail("expected mconfigptr write to trap")
  }
}

///|
test "scratch and trap value csrs preserve full xlen storage" {
  let mscratch = 0x340
  let mtval = 0x343
  let sscratch = 0x140
  let stval = 0x143
  let machine_scratch_value = 0xfedcba9876543210UL
  let machine_tval_value = 0x0123456789abcdefUL
  let supervisor_scratch_value = 0x8877665544332211UL
  let supervisor_tval_value = 0x1122334455667788UL

  let machine = make_runner(rv64_machine_config())
  machine.cpu.write_reg(1, machine_scratch_value)
  machine.cpu.write_reg(3, machine_tval_value)
  machine.load_program(
    words_to_bytes([
      encode_csr(mscratch, 1, 0x1U, 2),
      encode_csr(mtval, 3, 0x1U, 4),
      encode_csr(mscratch, 0, 0x2U, 5),
      encode_csr(mtval, 0, 0x2U, 6),
    ]),
    0U,
  )
  match machine.run(4) {
    Running => ()
    _ => fail("expected machine scratch/tval CSR program to run")
  }
  assert_eq(machine.read_reg_u64(2), 0U.to_uint64())
  assert_eq(machine.read_reg_u64(4), 0U.to_uint64())
  assert_eq(machine.read_reg_u64(5), machine_scratch_value)
  assert_eq(machine.read_reg_u64(6), machine_tval_value)
  assert_eq(machine.read_csr_u64(mscratch), machine_scratch_value)
  assert_eq(machine.read_csr_u64(mtval), machine_tval_value)

  let supervisor = make_runner(rv64_machine_config())
  supervisor.cpu.write_reg(1, supervisor_scratch_value)
  supervisor.cpu.write_reg(3, supervisor_tval_value)
  supervisor.load_program(
    words_to_bytes([
      encode_i(32, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 7, 0x37U),
      encode_i(-2048, 7, 0x0U, 7, 0x13U),
      encode_csr(0x300, 7, 0x1U, 0),
      encode_mret(),
      encode_i(0, 0, 0x0U, 0, 0x13U),
      encode_i(0, 0, 0x0U, 0, 0x13U),
      encode_csr(sscratch, 1, 0x1U, 2),
      encode_csr(stval, 3, 0x1U, 4),
      encode_csr(sscratch, 0, 0x2U, 5),
      encode_csr(stval, 0, 0x2U, 6),
    ]),
    0U,
  )
  match supervisor.run(10) {
    Running => ()
    _ => fail("expected supervisor scratch/stval CSR program to run")
  }
  match supervisor.privilege_mode() {
    Supervisor => ()
    _ => fail("expected scratch/stval program to remain in supervisor mode")
  }
  assert_eq(supervisor.read_reg_u64(2), 0U.to_uint64())
  assert_eq(supervisor.read_reg_u64(4), 0U.to_uint64())
  assert_eq(supervisor.read_reg_u64(5), supervisor_scratch_value)
  assert_eq(supervisor.read_reg_u64(6), supervisor_tval_value)
  assert_eq(supervisor.read_csr_u64(sscratch), supervisor_scratch_value)
  assert_eq(supervisor.read_csr_u64(stval), supervisor_tval_value)
}

///|
test "machine information csrs expose stable read only identifiers" {
  let mvendorid = 0xF11
  let marchid = 0xF12
  let mimpid = 0xF13
  let mhartid = 0xF14
  let mconfigptr = 0xF15
  let runner = make_runner(rv64_machine_config())
  runner.load_program(
    words_to_bytes([
      encode_csr(mvendorid, 0, 0x2U, 2),
      encode_csr(marchid, 0, 0x2U, 3),
      encode_csr(mimpid, 0, 0x2U, 4),
      encode_csr(mhartid, 0, 0x2U, 5),
      encode_csr(mconfigptr, 0, 0x2U, 6),
    ]),
    0U,
  )
  match runner.run(5) {
    Running => ()
    _ => fail("expected machine information CSR reads to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 0U.to_uint64())
}

///|
test "csr address privilege bits gate supervisor and machine csrs" {
  let read_mstatus = encode_csr(0x300, 0, 0x2U, 1)
  let supervisor_machine_denied = make_runner(rv64_machine_config())
  supervisor_machine_denied.load_program(
    words_to_bytes([
      encode_i(24, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      read_mstatus,
    ]),
    0U,
  )
  match supervisor_machine_denied.run(7) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected supervisor access to machine CSR to trap")
      }
      assert_eq(info.trap_value, read_mstatus.to_uint64())
    }
    _ => fail("expected supervisor access to machine CSR trap")
  }

  let read_sstatus = encode_csr(0x100, 0, 0x2U, 1)
  let supervisor_allowed = make_runner(rv64_machine_config())
  supervisor_allowed.load_program(
    words_to_bytes([
      encode_i(24, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      read_sstatus,
    ]),
    0U,
  )
  match supervisor_allowed.run(7) {
    Running => ()
    _ => fail("expected supervisor access to supervisor CSR")
  }
  match supervisor_allowed.privilege_mode() {
    Supervisor => ()
    _ => fail("expected supervisor mode after mret")
  }

  let user_supervisor_denied = make_runner(rv64_machine_config())
  user_supervisor_denied.load_program(
    words_to_bytes([
      encode_i(16, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_csr(0x300, 0, 0x5U, 0),
      encode_mret(),
      read_sstatus,
    ]),
    0U,
  )
  match user_supervisor_denied.run(5) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected user access to supervisor CSR to trap")
      }
      assert_eq(info.trap_value, read_sstatus.to_uint64())
    }
    _ => fail("expected user access to supervisor CSR trap")
  }

  let write_mstatus_without_read = encode_csr(0x300, 1, 0x1U, 0)
  let writei_mstatus_without_read = encode_csr(0x300, 1, 0x5U, 0)
  let supervisor_machine_write_denied = make_runner(rv64_machine_config())
  supervisor_machine_write_denied.load_program(
    words_to_bytes([
      encode_i(1, 0, 0x0U, 1, 0x13U),
      encode_i(28, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      write_mstatus_without_read,
    ]),
    0U,
  )
  match supervisor_machine_write_denied.run(8) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected supervisor write to machine CSR to trap")
      }
      assert_eq(info.trap_value, write_mstatus_without_read.to_uint64())
    }
    _ => fail("expected suppressed-read machine CSR write trap")
  }

  let supervisor_machine_writei_denied = make_runner(rv64_machine_config())
  supervisor_machine_writei_denied.load_program(
    words_to_bytes([
      encode_i(24, 0, 0x0U, 5, 0x13U),
      encode_csr(0x341, 5, 0x1U, 0),
      encode_u(0x00001000U, 3, 0x37U),
      encode_i(-2048, 3, 0x0U, 3, 0x13U),
      encode_csr(0x300, 3, 0x1U, 0),
      encode_mret(),
      writei_mstatus_without_read,
    ]),
    0U,
  )
  match supervisor_machine_writei_denied.run(7) {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected supervisor immediate write to machine CSR to trap")
      }
      assert_eq(info.trap_value, writei_mstatus_without_read.to_uint64())
    }
    _ => fail("expected suppressed-read immediate machine CSR write trap")
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
test "debug mode only csrs trap from machine mode" {
  // The standard CSR map reserves 0x7B0..0x7BF for debug-mode-only CSRs. This
  // emulator has no Debug Mode, so even M-mode software must see these
  // addresses as illegal rather than as generic machine storage. Cover the
  // endpoints and an interior address across read, suppressed-read write, and
  // set/clear forms so the whole reserved nibble stays classified as
  // debug-only, not just the first CSR or the direct-write path.
  for debug_only in [0x7B0, 0x7B7, 0x7BF] {
    for
      raw in [
        encode_csr(debug_only, 0, 0x2U, 1),
        encode_csr(debug_only, 1, 0x1U, 0),
        encode_csr(debug_only, 1, 0x5U, 0),
        encode_csr(debug_only, 1, 0x2U, 2),
        encode_csr(debug_only, 1, 0x3U, 3),
        encode_csr(debug_only, 1, 0x6U, 4),
        encode_csr(debug_only, 1, 0x7U, 5),
      ] {
      let runner = make_runner(rv64_machine_config())
      runner.cpu.write_reg(1, 1U.to_uint64())
      runner.load_program(words_to_bytes([raw]), 0U)
      match runner.step() {
        Trap(info) => {
          match info.cause {
            IllegalInstruction => ()
            _ => fail("expected illegal instruction cause")
          }
          assert_eq(info.faulting_pc, 0U.to_uint64())
          assert_eq(info.trap_value, raw.to_uint64())
        }
        _ => fail("expected debug-mode-only CSR access to trap")
      }
    }
  }
}

///|
test "zicsr suppression does not make unsupported csrs legal" {
  // Zicsr suppression selects which side effects are skipped, not whether an
  // absent CSR exists. Suppressed-read write forms still need a writable CSR,
  // and zero-mask set/clear forms still need a readable CSR.
  let unsupported = 0x7A0
  let forms = [
    encode_csr(unsupported, 1, 0x1U, 0), // CSRRW rd=x0 suppresses read only
    encode_csr(unsupported, 1, 0x5U, 0), // CSRRWI rd=x0 suppresses read only
    encode_csr(unsupported, 0, 0x2U, 2), // CSRRS rs1=x0 suppresses write only
    encode_csr(unsupported, 0, 0x3U, 3), // CSRRC rs1=x0 suppresses write only
    encode_csr(unsupported, 0, 0x6U, 4), // CSRRSI uimm=0 suppresses write only
    encode_csr(unsupported, 0, 0x7U, 5), // CSRRCI uimm=0 suppresses write only
  ]
  for raw in forms {
    let runner = make_runner(default_machine_config())
    runner.cpu.write_reg(1, 1U.to_uint64())
    runner.load_program(words_to_bytes([raw]), 0U)
    match runner.step() {
      Trap(info) => {
        match info.cause {
          IllegalInstruction => ()
          _ => fail("expected illegal instruction cause")
        }
        assert_eq(info.trap_value, raw.to_uint64())
      }
      _ => fail("expected unsupported CSR suppression form to trap")
    }
  }
}

///|
test "writes to read-only csrs trap as illegal instruction" {
  // The CSR address encoding marks these baseline CSRs read-only. Any CSR
  // instruction form that would write them must trap, even when the backing
  // value is otherwise readable and useful to firmware.
  let read_only_csrs = [
    0xF11, // mvendorid
     0xF12, // marchid
     0xF13, // mimpid
     0xF14, // mhartid
     0xF15, // mconfigptr
     0xC00, // cycle
     0xC01, // time
     0xC02, // instret
  ]
  for csr in read_only_csrs {
    let raw = encode_csr(csr, 1, 0x1U, 0)
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
}

///|
test "nonzero set and clear writes to read-only csrs trap" {
  // CSRRS/CSRRC are legal pure reads only when their source mask is zero.
  // A nonzero register or immediate mask is still an architectural write
  // attempt, so read-only CSRs must reject the instruction after the read side
  // has been proven accessible.
  let mvendorid = 0xF11
  let marchid = 0xF12
  let mimpid = 0xF13
  let mhartid = 0xF14
  let mconfigptr = 0xF15
  let cycle = 0xC00
  let time = 0xC01
  let instret = 0xC02
  let read_only_csrs = [
    mvendorid, marchid, mimpid, mhartid, mconfigptr, cycle, time, instret,
  ]
  for csr in read_only_csrs {
    let raws = [
      encode_csr(csr, 1, 0x2U, 2), // CSRRS with rs1=x1
      encode_csr(csr, 1, 0x3U, 2), // CSRRC with rs1=x1
      encode_csr(csr, 1, 0x6U, 2), // CSRRSI with uimm=1
      encode_csr(csr, 1, 0x7U, 2), // CSRRCI with uimm=1
    ]
    for raw in raws {
      let runner = make_runner(default_machine_config())
      runner.cpu.write_reg(1, 1U.to_uint64())
      runner.load_program(words_to_bytes([raw]), 0U)
      match runner.step() {
        Trap(info) => {
          match info.cause {
            IllegalInstruction => ()
            _ => fail("expected illegal instruction cause")
          }
          assert_eq(info.trap_value, raw.to_uint64())
        }
        _ => fail("expected read-only CSR set/clear write to trap")
      }
    }
  }
}

///|
test "fence.i makes same-hart self-modified instruction fetch visible" {
  let replacement = encode_i(7, 0, 0x0U, 5, 0x13U)
  let program = words_to_bytes([
    encode_j(0x34, 1, 0x6fU),
    encode_u(0x00700000U, 3, 0x37U),
    encode_i(0x293, 3, 0x0U, 3, 0x13U),
    encode_s(0x34, 3, 0, 0x2U, 0x23U),
    encode_fence_i(),
    encode_j(0x20, 0, 0x6fU),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
    encode_i(1, 0, 0x0U, 5, 0x13U),
    encode_i(0, 1, 0x0U, 0, 0x67U),
    encode_i(0, 0, 0x0U, 0, 0x13U),
  ])
  let runner = make_runner(default_machine_config())
  runner.load_program(program, 0U)
  let flushes_after_load = runner.decode_cache_flush_count()
  match runner.run(9) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg(1), 4U)
  assert_eq(runner.read_reg(5), 7U)
  assert_eq(runner.load_u32(0x34U), replacement)
  assert_eq(
    runner.decode_cache_flush_count(),
    flushes_after_load + 1U.to_uint64(),
  )
}

///|
test "fence.i flushes only the executing hart fetch state" {
  let harts = make_smp_runners(virt_machine_config(), 2)
  let hart0 = harts[0]
  let hart1 = harts[1]
  let base = hart1.cpu.pc
  let old_inst = encode_i(1, 0, 0x0U, 2, 0x13U)
  let replacement = encode_i(2, 0, 0x0U, 2, 0x13U)

  hart0.bus.store_u32(base, old_inst.to_uint64())
  hart0.bus.store_u32(base + 4U.to_uint64(), encode_j(-4, 0, 0x6fU).to_uint64())
  match hart1.step() {
    Running => ()
    _ => fail("expected hart1 to fetch and cache the original instruction")
  }
  assert_eq(hart1.read_reg_u64(2), 1U.to_uint64())

  // A FENCE.I orders only the issuing hart's subsequent instruction fetches.
  // The shared memory model may still make the replacement visible to hart 1,
  // but hart 0's FENCE.I must not be implemented as a global decode-cache
  // shootdown.
  hart0.bus.store_u32(base, replacement.to_uint64())
  let hart0_fence_pc = base + 0x100U.to_uint64()
  hart0.load_program_u64(words_to_bytes([encode_fence_i()]), hart0_fence_pc)
  let hart0_flushes_before = hart0.decode_cache_flush_count()
  let hart1_flushes_before = hart1.decode_cache_flush_count()
  match hart0.step() {
    Running => ()
    _ => fail("expected hart0 fence.i to retire")
  }
  assert_eq(
    hart0.decode_cache_flush_count(),
    hart0_flushes_before + 1U.to_uint64(),
  )
  assert_eq(hart1.decode_cache_flush_count(), hart1_flushes_before)

  match hart1.step() {
    Running => ()
    _ => fail("expected hart1 branch to return to the patched instruction")
  }
  match hart1.step() {
    Running => ()
    _ => fail("expected hart1 to refetch after raw instruction changed")
  }
  assert_eq(hart1.read_reg_u64(2), 2U.to_uint64())
}

///|
test "fence reserved fields retire as conservative fences" {
  let program = words_to_bytes([
    encode_i(11, 0, 0x0U, 2, 0x13U),
    encode_fence_fields(0x8U, 0x3U, 0x3U, 2, 3),
    encode_fence_fields(0x7U, 0x5U, 0xaU, 4, 5),
    encode_i(13, 0, 0x0U, 6, 0x13U),
  ])
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(4) {
    Running => ()
    _ => fail("expected reserved fence field sequence to retire")
  }
  assert_eq(runner.read_reg_u64(2), 11U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 13U.to_uint64())
  assert_eq(runner.pc_u64(), 16U.to_uint64())
}

///|
test "fence.i unused fields are ignored while flushing fetch state" {
  let raw = encode_fence_i_fields(0xfffU, 1, 2)
  let runner = make_runner(rv64_machine_config())
  runner.cpu.write_reg(1, 0x1234U.to_uint64())
  runner.cpu.write_reg(2, 0x5678U.to_uint64())
  runner.load_program(words_to_bytes([raw]), 0U)
  let flushes_before = runner.decode_cache_flush_count()
  match runner.step() {
    Running => ()
    _ => fail("expected fence.i with unused fields to retire")
  }
  assert_eq(runner.read_reg_u64(1), 0x1234U.to_uint64())
  assert_eq(runner.read_reg_u64(2), 0x5678U.to_uint64())
  assert_eq(runner.pc_u64(), 4U.to_uint64())
  assert_eq(runner.decode_cache_flush_count(), flushes_before + 1U.to_uint64())
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
  // `vl`, `vtype`, and `vlenb` are read-only in the vector CSR surface.
  // CSRRW is not the only write form: nonzero CSRRS/CSRRC masks also attempt
  // to modify the destination CSR and must be rejected after read legality.
  let read_only_vector_csrs = [0xC20, 0xC21, 0xC22]
  for csr in read_only_vector_csrs {
    let raws = [
      encode_csr(csr, 1, 0x1U, 0), // CSRRW
      encode_csr(csr, 1, 0x2U, 2), // CSRRS with rs1=x1
      encode_csr(csr, 1, 0x3U, 2), // CSRRC with rs1=x1
      encode_csr(csr, 1, 0x6U, 2), // CSRRSI with uimm=1
      encode_csr(csr, 1, 0x7U, 2), // CSRRCI with uimm=1
    ]
    for raw in raws {
      let runner = make_runner(rv64fdv_machine_config())
      runner.cpu.write_reg(1, 1U.to_uint64())
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
}

///|
test "rv64fd without v rejects the vector csr surface as illegal" {
  let vector_csrs = [
    0x008, // vstart
     0x009, // vxsat
     0x00A, // vxrm
     0x00F, // vcsr
     0xC20, // vl
     0xC21, // vtype
     0xC22, // vlenb
  ]
  for csr in vector_csrs {
    let raw = encode_csr(csr, 0, 0x2U, 1)
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
      _ => fail("expected vector csr read to trap without v")
    }
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
test "rv64 byte and halfword loads and stores extend to xlen" {
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
  let runner = make_runner(rv64_machine_config())
  runner.load_program(program, 0U)
  match runner.run(9) {
    Running => ()
    _ => fail("expected rv64 byte/halfword program to run")
  }
  assert_eq(runner.read_reg_u64(2), 0xffffffffffffff80UL)
  assert_eq(runner.read_reg_u64(3), 0x80U.to_uint64())
  assert_eq(runner.read_reg_u64(5), 0xffffffffffffa678UL)
  assert_eq(runner.read_reg_u64(6), 0xa678U.to_uint64())
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
test "base shift-immediate reserved encodings trap" {
  let rv64_reserved = encode_i(0x400, 1, 0x1U, 2, 0x13U)
  let rv64_runner = make_runner(rv64_machine_config())
  rv64_runner.load_program(words_to_bytes([rv64_reserved]), 0U)
  match rv64_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected rv64 reserved slli to raise illegal instruction")
      }
      assert_eq(info.trap_value, rv64_reserved.to_uint64())
    }
    _ => fail("expected rv64 reserved slli to trap")
  }

  let rv32_reserved = encode_i(0x020, 1, 0x1U, 2, 0x13U)
  let rv32_runner = make_runner(default_machine_config())
  rv32_runner.load_program(words_to_bytes([rv32_reserved]), 0U)
  match rv32_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected rv32 reserved slli to raise illegal instruction")
      }
      assert_eq(info.trap_value, rv32_reserved.to_uint64())
    }
    _ => fail("expected rv32 reserved slli to trap")
  }

  let rv32_srli_reserved = encode_i(0x020, 1, 0x5U, 2, 0x13U)
  let rv32_srli_runner = make_runner(default_machine_config())
  rv32_srli_runner.load_program(words_to_bytes([rv32_srli_reserved]), 0U)
  match rv32_srli_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected rv32 reserved srli to raise illegal instruction")
      }
      assert_eq(info.trap_value, rv32_srli_reserved.to_uint64())
    }
    _ => fail("expected rv32 reserved srli to trap")
  }

  let rv32_srai_reserved = encode_i(0x420, 1, 0x5U, 2, 0x13U)
  let rv32_srai_runner = make_runner(default_machine_config())
  rv32_srai_runner.load_program(words_to_bytes([rv32_srai_reserved]), 0U)
  match rv32_srai_runner.step() {
    Trap(info) => {
      match info.cause {
        IllegalInstruction => ()
        _ => fail("expected rv32 reserved srai to raise illegal instruction")
      }
      assert_eq(info.trap_value, rv32_srai_reserved.to_uint64())
    }
    _ => fail("expected rv32 reserved srai to trap")
  }
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

  let misa_raw = encode_csr(0x301, 0, 0x5U, 0)
  let misa_runner = make_runner(rv64_machine_config())
  let original = misa_runner.read_csr_u64(0x301)
  misa_runner.load_program(words_to_bytes([misa_raw]), 0U)
  match misa_runner.step() {
    Running => ()
    _ => fail("expected fixed-WARL misa write to retire")
  }
  assert_eq(misa_runner.read_csr_u64(0x301), original)
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
    encode_csr(0x344, 0, 0x2U, 9),
    encode_i(4, 7, 0x2U, 8, 0x03U),
  ])
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(12) {
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
  assert_eq(runner.read_reg_u64(9) & 0xa00U.to_uint64(), 0x200U.to_uint64())
  assert_eq(runner.read_csr_u64(0x344) & 0xa00U.to_uint64(), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(6), 1U.to_uint64())
  assert_eq(runner.read_reg_u64(8), 1U.to_uint64())
  assert_eq(runner.virtio_blk_read_request_count(), 1U.to_uint64())
  assert_eq(runner.virtio_blk_read_byte_count(), 512U.to_uint64())
  assert_eq(runner.virtio_blk_write_request_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_write_byte_count(), 0U.to_uint64())
}

///|
test "virtio-blk read request zero-fills past disk image" {
  let runner = make_runner(virtio_blk_machine_config())
  let desc_base = 0x80001000U.to_uint64()
  let avail_base = 0x80002000U.to_uint64()
  let used_base = 0x80003000U.to_uint64()
  let header_addr = 0x80004000U.to_uint64()
  let data_addr = 0x80005000U.to_uint64()
  let status_addr = 0x80006000U.to_uint64()
  runner.load_virtio_blk_disk(
    Bytes::from_array([0x11U.to_byte(), 0x22U.to_byte()]),
  )
  runner.bus.store_u64(desc_base, header_addr)
  runner.bus.store_u32(desc_base + 8U.to_uint64(), 16U.to_uint64())
  runner.bus.store_u16(desc_base + 12U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 14U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u64(desc_base + 16U.to_uint64(), data_addr)
  runner.bus.store_u32(desc_base + 24U.to_uint64(), 4U.to_uint64())
  runner.bus.store_u16(desc_base + 28U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 30U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u64(desc_base + 32U.to_uint64(), status_addr)
  runner.bus.store_u32(desc_base + 40U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 44U.to_uint64(), 2U.to_uint64())
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
    encode_u(0x10001000U, 5, 0x37U),
    encode_s(0x50, 0, 5, 0x2U, 0x23U),
  ])
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after zero-fill virtio-blk read")
  }
  assert_eq(runner.bus.load_u8(data_addr), 0x11U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 1U.to_uint64()), 0x22U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 2U.to_uint64()), 0U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr + 3U.to_uint64()), 0U.to_uint64())
  assert_eq(runner.bus.load_u8(status_addr), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_byte_count(), 4U.to_uint64())
}

///|
test "virtio-blk read-ahead cache serves repeated reads and invalidates on disk load" {
  let runner = make_runner(virtio_blk_machine_config())
  let desc_base = 0x80001000U.to_uint64()
  let avail_base = 0x80002000U.to_uint64()
  let used_base = 0x80003000U.to_uint64()
  let header_addr = 0x80004000U.to_uint64()
  let data_addr = 0x80005000U.to_uint64()
  let status_addr = 0x80006000U.to_uint64()
  let disk : Array[Byte] = []
  for index in 0..<1024 {
    disk.push((index & 0xff).reinterpret_as_uint().to_byte())
  }
  runner.load_virtio_blk_disk(Bytes::from_array(disk))
  runner.bus.store_u64(desc_base, header_addr)
  runner.bus.store_u32(desc_base + 8U.to_uint64(), 16U.to_uint64())
  runner.bus.store_u16(desc_base + 12U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 14U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u64(desc_base + 16U.to_uint64(), data_addr)
  runner.bus.store_u32(desc_base + 24U.to_uint64(), 4U.to_uint64())
  runner.bus.store_u16(desc_base + 28U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(desc_base + 30U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u64(desc_base + 32U.to_uint64(), status_addr)
  runner.bus.store_u32(desc_base + 40U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 44U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u32(header_addr, 0U.to_uint64())
  runner.bus.store_u64(header_addr + 8U.to_uint64(), 0U.to_uint64())
  runner.bus.store_u16(avail_base + 4U.to_uint64(), 0U.to_uint64())
  runner.virtio_blk_state[4] = 8U.to_uint64()
  runner.virtio_blk_state[5] = 1U.to_uint64()
  runner.virtio_blk_state[8] = desc_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[9] = desc_base >> 32
  runner.virtio_blk_state[10] = avail_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[11] = avail_base >> 32
  runner.virtio_blk_state[12] = used_base & 0xffffffffU.to_uint64()
  runner.virtio_blk_state[13] = used_base >> 32
  let notify_program = words_to_bytes([
    encode_u(0x10001000U, 5, 0x37U),
    encode_s(0x50, 0, 5, 0x2U, 0x23U),
  ])
  runner.load_program_u64(notify_program, 0x80000000U.to_uint64())
  runner.bus.store_u16(avail_base + 2U.to_uint64(), 1U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after first cached virtio-blk read")
  }
  assert_eq(runner.bus.load_u8(data_addr), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_hit_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_miss_count(), 1U.to_uint64())
  runner.load_program_u64(notify_program, 0x80000000U.to_uint64())
  runner.bus.store_u16(avail_base + 2U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u16(avail_base + 6U.to_uint64(), 0U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after repeated cached virtio-blk read")
  }
  assert_eq(runner.virtio_blk_read_cache_hit_count(), 1U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_miss_count(), 1U.to_uint64())
  let new_disk = Bytes::from_array([
    0xaaU.to_byte(),
    0xbbU.to_byte(),
    0xccU.to_byte(),
    0xddU.to_byte(),
  ])
  runner.load_virtio_blk_disk(new_disk)
  runner.load_program_u64(notify_program, 0x80000000U.to_uint64())
  runner.bus.store_u16(avail_base + 2U.to_uint64(), 3U.to_uint64())
  runner.bus.store_u16(avail_base + 8U.to_uint64(), 0U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after disk reload cached virtio-blk read")
  }
  assert_eq(runner.virtio_blk_read_cache_hit_count(), 1U.to_uint64())
  assert_eq(runner.virtio_blk_read_cache_miss_count(), 2U.to_uint64())
  assert_eq(runner.bus.load_u8(data_addr), 0xaaU.to_uint64())
}

///|
test "virtio-blk write request copies guest bytes into disk backing" {
  let runner = make_runner(virtio_blk_machine_config())
  let desc_base = 0x80001000U.to_uint64()
  let avail_base = 0x80002000U.to_uint64()
  let used_base = 0x80003000U.to_uint64()
  let header_addr = 0x80004000U.to_uint64()
  let data_addr = 0x80005000U.to_uint64()
  let status_addr = 0x80006000U.to_uint64()
  let disk = Bytes::make(512, 0U.to_byte())
  runner.load_virtio_blk_disk(disk)
  runner.bus.store_u64(desc_base, header_addr)
  runner.bus.store_u32(desc_base + 8U.to_uint64(), 16U.to_uint64())
  runner.bus.store_u16(desc_base + 12U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 14U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u64(desc_base + 16U.to_uint64(), data_addr)
  runner.bus.store_u32(desc_base + 24U.to_uint64(), 4U.to_uint64())
  runner.bus.store_u16(desc_base + 28U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 30U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u64(desc_base + 32U.to_uint64(), status_addr)
  runner.bus.store_u32(desc_base + 40U.to_uint64(), 1U.to_uint64())
  runner.bus.store_u16(desc_base + 44U.to_uint64(), 2U.to_uint64())
  runner.bus.store_u32(header_addr, 1U.to_uint64())
  runner.bus.store_u64(header_addr + 8U.to_uint64(), 0U.to_uint64())
  runner.bus.store_u8(data_addr, 0xaaU.to_uint64())
  runner.bus.store_u8(data_addr + 1U.to_uint64(), 0xbbU.to_uint64())
  runner.bus.store_u8(data_addr + 2U.to_uint64(), 0xccU.to_uint64())
  runner.bus.store_u8(data_addr + 3U.to_uint64(), 0xddU.to_uint64())
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
    encode_u(0x10001000U, 5, 0x37U),
    encode_s(0x50, 0, 5, 0x2U, 0x23U),
  ])
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(2) {
    Running => ()
    _ => fail("expected running after virtio-blk write request")
  }
  assert_eq(runner.bus.load_u8(status_addr), 0U.to_uint64())
  assert_eq(runner.bus.load_u32(used_base + 8U.to_uint64()), 5U.to_uint64())
  assert_eq(runner.virtio_blk_disk[0].to_uint64(), 0xaaU.to_uint64())
  assert_eq(runner.virtio_blk_disk[1].to_uint64(), 0xbbU.to_uint64())
  assert_eq(runner.virtio_blk_disk[2].to_uint64(), 0xccU.to_uint64())
  assert_eq(runner.virtio_blk_disk[3].to_uint64(), 0xddU.to_uint64())
  assert_eq(runner.virtio_blk_read_request_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_read_byte_count(), 0U.to_uint64())
  assert_eq(runner.virtio_blk_write_request_count(), 1U.to_uint64())
  assert_eq(runner.virtio_blk_write_byte_count(), 4U.to_uint64())
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
test "SIE is masked by delegated supervisor interrupt bits" {
  // Write 0xFFFF to MIE directly. Without mideleg, SIE reads as zero; after
  // delegating SSI/STI/SEI, SIE exposes the matching bits 1,5,9.
  // 1. ADDI x1, x0, -1   → x1 = 0xFFFF...FFFF
  // 2. CSRRW x0, MIE, x1 → MIE = 0xFFFF...FFFF
  // 3. CSRRS x2, SIE, x0 → x2 = 0, because no S interrupts are delegated
  // 4. CSRRW x0, MIDELEG, x1
  // 5. CSRRS x3, SIE, x0 → x3 = MIE & MIDELEG & 0x222
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(0x304, 1, 0x1U, 0),
    encode_csr(0x104, 0, 0x2U, 2),
    encode_csr(0x303, 1, 0x1U, 0),
    encode_csr(0x104, 0, 0x2U, 3),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0x222U.to_uint64())
  // MIE should keep only modeled interrupt-enable bits.
  let mie = runner.cpu.read_csr(0x304)
  assert_eq(mie & 0xFFFU.to_uint64(), 0xAAAU.to_uint64())
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
    encode_csr(0x303, 1, 0x1U, 0),
    encode_csr(0x304, 1, 0x1U, 0),
    encode_csr(0x104, 0, 0x1U, 3),
    encode_csr(0x304, 0, 0x2U, 4),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected running")
  }
  // x3 = old SIE = 0x222
  assert_eq(runner.read_reg_u64(3), 0x222U.to_uint64())
  // MIE should have bits 1,5,9 cleared, leaving modeled M-level enables.
  let mie = runner.cpu.read_csr(0x304)
  assert_eq(mie & 0xFFFU.to_uint64(), 0x888U.to_uint64())
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
    encode_i(2, 0, 0x0U, 5, 0x13U),
    encode_csr(0x303, 5, 0x1U, 0),
    encode_u(0x02004000U, 1, 0x37U),
    encode_i(1, 0, 0x0U, 2, 0x13U),
    encode_s(0, 2, 1, 0x3U, 0x23U),
    nop,
    encode_csr(0x144, 0x2, 0x6U, 3),
    encode_csr(0x144, 0, 0x2U, 4),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(8) {
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
test "SIP writes affect only delegated SSIP through supervisor view" {
  let program = words_to_bytes([
    encode_i(-1, 0, 0x0U, 1, 0x13U),
    encode_csr(0x303, 1, 0x1U, 0),
    encode_csr(0x144, 1, 0x1U, 2),
    encode_csr(0x144, 0, 0x2U, 3),
    encode_csr(0x344, 0, 0x2U, 4),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(5) {
    Running => ()
    _ => fail("expected SIP read-only pending bits test to run")
  }
  assert_eq(runner.read_reg_u64(2), 0U.to_uint64())
  assert_eq(runner.read_reg_u64(3), 0x2U.to_uint64())
  assert_eq(runner.read_reg_u64(4) & 0x222U.to_uint64(), 0x2U.to_uint64())
}

///|
test "mip software SEIP survives platform interrupt refresh" {
  let program = words_to_bytes([
    encode_i(0x200, 0, 0x0U, 1, 0x13U),
    encode_csr(0x344, 1, 0x1U, 0),
    encode_csr(0x344, 0, 0x2U, 2),
  ])
  let runner = make_runner(virt_machine_config())
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.run(3) {
    Running => ()
    _ => fail("expected software SEIP program to run")
  }
  assert_eq(runner.read_reg_u64(2) & 0x200U.to_uint64(), 0x200U.to_uint64())
  assert_eq(runner.cpu.read_csr(0x344) & 0x200U.to_uint64(), 0x200U.to_uint64())
}

///|
test "mip CSRRS does not copy external SEIP into software SEIP" {
  let program = words_to_bytes([
    encode_i(2, 0, 0x0U, 1, 0x13U),
    encode_csr(0x344, 1, 0x2U, 2),
    encode_csr(0x344, 0, 0x2U, 3),
  ])
  let runner = make_runner(virtio_blk_machine_config())
  // Source 1 is virtio-blk. Keep it claimable for supervisor context 1 so
  // visible mip.SEIP reads as B||E while the CSRRS write side should update
  // only the software bit B.
  runner.plic_regs[4] = 1U.to_byte()
  runner.plic_regs[0x2080] = 2U.to_byte()
  runner.virtio_blk_state[6] = 1U.to_uint64()
  runner.load_program_u64(program, 0x80000000U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected addi before mip CSRRS")
  }
  match runner.step() {
    Running => ()
    _ => fail("expected mip CSRRS with external SEIP")
  }
  assert_eq(runner.read_reg_u64(2) & 0x200U.to_uint64(), 0x200U.to_uint64())
  runner.virtio_blk_state[6] = 0U.to_uint64()
  match runner.step() {
    Running => ()
    _ => fail("expected mip read after external SEIP clears")
  }
  assert_eq(runner.read_reg_u64(3) & 0x202U.to_uint64(), 0x2U.to_uint64())
  assert_eq(runner.cpu.read_csr(0x344) & 0x200U.to_uint64(), 0U.to_uint64())
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
test "WFI fast-forwards to the next CLINT timer event" {
  let runner = make_runner(virt_machine_config())
  let pc = runner.cpu.pc
  runner.cpu.write_csr(0x300, 0x8U.to_uint64())
  runner.cpu.write_csr(0x304, 0x80U.to_uint64())
  runner.cpu.write_csr(0x305, pc + 8U.to_uint64())
  runner.all_mtimecmp[0] = 100U.to_uint64()
  runner.bus.store_u32(pc, 0x10500073U.to_uint64())
  runner.bus.store_u32(
    pc + 4U.to_uint64(),
    encode_i(1, 0, 0x0U, 1, 0x13U).to_uint64(),
  )
  runner.bus.store_u32(
    pc + 8U.to_uint64(),
    encode_i(2, 0, 0x0U, 2, 0x13U).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected WFI to run")
  }
  assert_eq(runner.cpu.pc, pc + 4U.to_uint64())
  assert_eq(runner.clint_mtime(), 99U.to_uint64())
  assert_eq(runner.cpu.read_csr(0x344) & 0x80U.to_uint64(), 0U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected timer interrupt delivery after WFI")
  }
  assert_eq(runner.clint_mtime(), 100U.to_uint64())
  assert_eq(runner.cpu.read_csr(0x342), (1U.to_uint64() << 63) | 7U.to_uint64())
  assert_eq(runner.read_reg_u64(1), 0U.to_uint64())
  assert_eq(runner.cpu.pc, pc + 8U.to_uint64())
}

///|
test "WFI does not fast-forward when CLINT timer compare is unset" {
  let runner = make_runner(virt_machine_config())
  let pc = runner.cpu.pc
  runner.bus.store_u32(pc, 0x10500073U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected WFI to run")
  }
  assert_eq(runner.cpu.pc, pc + 4U.to_uint64())
  assert_eq(runner.clint_mtime(), 1U.to_uint64())
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
fn encode_amo_ordered(
  funct5 : UInt,
  order : UInt,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
) -> UInt {
  encode_r((funct5 << 2) | (order & 0x3U), rs2, rs1, funct3, rd, 0x2fU)
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
test "AMOSWAP.D and bitwise AMO.D operate on full doublewords" {
  // AMO.D uses the full XLEN source and memory value. This separates the
  // doubleword operations from AMO.W, whose result is computed from low words
  // and then sign-extended on RV64.
  let swap_runner = make_runner(virt_machine_config())
  let swap_addr = swap_runner.cpu.pc + 0x100U.to_uint64()
  swap_runner.bus.store_u64(swap_addr, 0x0123456789abcdefUL)
  swap_runner.cpu.write_reg(1, swap_addr)
  swap_runner.cpu.write_reg(2, 0xfedcba9876543210UL)
  swap_runner.bus.store_u32(
    swap_runner.cpu.pc,
    encode_amo(0x01U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match swap_runner.step() {
    Running => ()
    _ => fail("expected amoswap.d to run")
  }
  assert_eq(swap_runner.read_reg_u64(3), 0x0123456789abcdefUL)
  assert_eq(swap_runner.bus.load_u64(swap_addr), 0xfedcba9876543210UL)

  let xor_runner = make_runner(virt_machine_config())
  let xor_addr = xor_runner.cpu.pc + 0x100U.to_uint64()
  xor_runner.bus.store_u64(xor_addr, 0xff00ff00ff00ff00UL)
  xor_runner.cpu.write_reg(1, xor_addr)
  xor_runner.cpu.write_reg(2, 0x0f0f0f0f0f0f0f0fUL)
  xor_runner.bus.store_u32(
    xor_runner.cpu.pc,
    encode_amo(0x04U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match xor_runner.step() {
    Running => ()
    _ => fail("expected amoxor.d to run")
  }
  assert_eq(xor_runner.read_reg_u64(3), 0xff00ff00ff00ff00UL)
  assert_eq(xor_runner.bus.load_u64(xor_addr), 0xf00ff00ff00ff00fUL)

  let and_runner = make_runner(virt_machine_config())
  let and_addr = and_runner.cpu.pc + 0x100U.to_uint64()
  and_runner.bus.store_u64(and_addr, 0xf0f0ffff0000ffffUL)
  and_runner.cpu.write_reg(1, and_addr)
  and_runner.cpu.write_reg(2, 0xffff0f0fffff0000UL)
  and_runner.bus.store_u32(
    and_runner.cpu.pc,
    encode_amo(0x0cU, 2, 1, 0x3U, 3).to_uint64(),
  )
  match and_runner.step() {
    Running => ()
    _ => fail("expected amoand.d to run")
  }
  assert_eq(and_runner.read_reg_u64(3), 0xf0f0ffff0000ffffUL)
  assert_eq(and_runner.bus.load_u64(and_addr), 0xf0f00f0f00000000UL)

  let or_runner = make_runner(virt_machine_config())
  let or_addr = or_runner.cpu.pc + 0x100U.to_uint64()
  or_runner.bus.store_u64(or_addr, 0xf00000000000000fUL)
  or_runner.cpu.write_reg(1, or_addr)
  or_runner.cpu.write_reg(2, 0x0fff00000000fff0UL)
  or_runner.bus.store_u32(
    or_runner.cpu.pc,
    encode_amo(0x08U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match or_runner.step() {
    Running => ()
    _ => fail("expected amoor.d to run")
  }
  assert_eq(or_runner.read_reg_u64(3), 0xf00000000000000fUL)
  assert_eq(or_runner.bus.load_u64(or_addr), 0xffff00000000ffffUL)
}

///|
test "AMO.W sign-extends the loaded word on RV64" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 0xffffffffU.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(2, 2U.to_uint64())
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo_ordered(0x00U, 0x3U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(3), 0xffffffffffffffffUL)
  assert_eq(runner.bus.load_u32(addr), 1U.to_uint64())
}

///|
test "AMO.W aq rl encodings execute ordinary atomic operation" {
  for order in [0U, 1U, 2U, 3U] {
    let runner = make_runner(virt_machine_config())
    let addr = runner.cpu.pc + 0x100U.to_uint64()
    let old_word = 0x20U + order
    runner.bus.store_u32(addr, old_word.to_uint64())
    runner.cpu.write_reg(1, addr)
    runner.cpu.write_reg(2, 5U.to_uint64())
    // The single-hart interpreter does not yet model cross-hart visibility
    // differences for aq/rl, but every architectural order encoding must still
    // decode and execute the underlying atomic read-modify-write operation.
    runner.bus.store_u32(
      runner.cpu.pc,
      encode_amo_ordered(0x00U, order, 2, 1, 0x2U, 3).to_uint64(),
    )
    match runner.step() {
      Running => ()
      _ => fail("expected ordered AMOADD.W form to run")
    }
    assert_eq(runner.read_reg_u64(3), old_word.to_uint64())
    assert_eq(runner.bus.load_u32(addr), (old_word + 5U).to_uint64())
  }
}

///|
test "AMO.D aq rl encodings execute ordinary atomic operation" {
  for order in [0U, 1U, 2U, 3U] {
    let runner = make_runner(virt_machine_config())
    let addr = runner.cpu.pc + 0x100U.to_uint64()
    let old_doubleword = 0x2000000000000020UL + order.to_uint64()
    runner.bus.store_u64(addr, old_doubleword)
    runner.cpu.write_reg(1, addr)
    runner.cpu.write_reg(2, 5U.to_uint64())
    // AMO.D has the same architectural aq/rl encoding surface as AMO.W. The
    // current interpreter still executes memory operations in program order,
    // so this pins decode and ordinary doubleword RMW behavior while leaving
    // cross-hart visibility ordering as the documented remaining audit.
    runner.bus.store_u32(
      runner.cpu.pc,
      encode_amo_ordered(0x00U, order, 2, 1, 0x3U, 3).to_uint64(),
    )
    match runner.step() {
      Running => ()
      _ => fail("expected ordered AMOADD.D form to run")
    }
    assert_eq(runner.read_reg_u64(3), old_doubleword)
    assert_eq(runner.bus.load_u64(addr), old_doubleword + 5U.to_uint64())
  }
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
test "bitwise AMO.W operations store low-word results and sign-extend rd" {
  // AMO.W performs the read-modify-write in word width even on RV64. The
  // memory result is the low 32 bits, while rd receives the old word
  // sign-extended to XLEN.
  let xor_runner = make_runner(virt_machine_config())
  let xor_addr = xor_runner.cpu.pc + 0x100U.to_uint64()
  xor_runner.bus.store_u32(xor_addr, 0x800000f0U.to_uint64())
  xor_runner.cpu.write_reg(1, xor_addr)
  xor_runner.cpu.write_reg(2, 0xffffffff0000000fUL)
  xor_runner.bus.store_u32(
    xor_runner.cpu.pc,
    encode_amo(0x04U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match xor_runner.step() {
    Running => ()
    _ => fail("expected amoxor.w to run")
  }
  assert_eq(xor_runner.read_reg_u64(3), 0xffffffff800000f0UL)
  assert_eq(xor_runner.bus.load_u32(xor_addr), 0x800000ffU.to_uint64())

  let and_runner = make_runner(virt_machine_config())
  let and_addr = and_runner.cpu.pc + 0x100U.to_uint64()
  and_runner.bus.store_u32(and_addr, 0xffff00ffU.to_uint64())
  and_runner.cpu.write_reg(1, and_addr)
  and_runner.cpu.write_reg(2, 0x123456780f0fff00UL)
  and_runner.bus.store_u32(
    and_runner.cpu.pc,
    encode_amo(0x0cU, 2, 1, 0x2U, 3).to_uint64(),
  )
  match and_runner.step() {
    Running => ()
    _ => fail("expected amoand.w to run")
  }
  assert_eq(and_runner.read_reg_u64(3), 0xffffffffffff00ffUL)
  assert_eq(and_runner.bus.load_u32(and_addr), 0x0f0f0000U.to_uint64())

  let or_runner = make_runner(virt_machine_config())
  let or_addr = or_runner.cpu.pc + 0x100U.to_uint64()
  or_runner.bus.store_u32(or_addr, 0x80000000U.to_uint64())
  or_runner.cpu.write_reg(1, or_addr)
  or_runner.cpu.write_reg(2, 0x0000000100000001UL)
  or_runner.bus.store_u32(
    or_runner.cpu.pc,
    encode_amo(0x08U, 2, 1, 0x2U, 3).to_uint64(),
  )
  match or_runner.step() {
    Running => ()
    _ => fail("expected amoor.w to run")
  }
  assert_eq(or_runner.read_reg_u64(3), 0xffffffff80000000UL)
  assert_eq(or_runner.bus.load_u32(or_addr), 0x80000001U.to_uint64())
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
test "AMOMIN.D and AMOMAX.D compare signed 64-bit operands" {
  // AMO.D min/max use full XLEN signed comparison, unlike AMO.W which first
  // narrows to 32 bits. Pin both directions across the sign boundary.
  let min_runner = make_runner(virt_machine_config())
  let min_addr = min_runner.cpu.pc + 0x100U.to_uint64()
  min_runner.bus.store_u64(min_addr, 1U.to_uint64())
  min_runner.cpu.write_reg(1, min_addr)
  min_runner.cpu.write_reg(2, 0xffffffffffffffffUL) // -1 as a 64-bit value
  min_runner.bus.store_u32(
    min_runner.cpu.pc,
    encode_amo(0x10U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match min_runner.step() {
    Running => ()
    _ => fail("expected amomin.d to run")
  }
  assert_eq(min_runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(min_runner.bus.load_u64(min_addr), 0xffffffffffffffffUL)

  let max_runner = make_runner(virt_machine_config())
  let max_addr = max_runner.cpu.pc + 0x100U.to_uint64()
  max_runner.bus.store_u64(max_addr, 0xffffffffffffffffUL)
  max_runner.cpu.write_reg(1, max_addr)
  max_runner.cpu.write_reg(2, 1U.to_uint64())
  max_runner.bus.store_u32(
    max_runner.cpu.pc,
    encode_amo(0x14U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match max_runner.step() {
    Running => ()
    _ => fail("expected amomax.d to run")
  }
  assert_eq(max_runner.read_reg_u64(3), 0xffffffffffffffffUL)
  assert_eq(max_runner.bus.load_u64(max_addr), 1U.to_uint64())
}

///|
test "AMOMINU.D and AMOMAXU.D compare unsigned 64-bit operands" {
  // Use the same bit patterns as the signed test but require unsigned
  // ordering: all-ones is greater than 1 for AMOMAXU.D and not chosen by
  // AMOMINU.D.
  let min_runner = make_runner(virt_machine_config())
  let min_addr = min_runner.cpu.pc + 0x100U.to_uint64()
  min_runner.bus.store_u64(min_addr, 1U.to_uint64())
  min_runner.cpu.write_reg(1, min_addr)
  min_runner.cpu.write_reg(2, 0xffffffffffffffffUL)
  min_runner.bus.store_u32(
    min_runner.cpu.pc,
    encode_amo(0x18U, 2, 1, 0x3U, 3).to_uint64(),
  )
  match min_runner.step() {
    Running => ()
    _ => fail("expected amominu.d to run")
  }
  assert_eq(min_runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(min_runner.bus.load_u64(min_addr), 1U.to_uint64())

  let max_runner = make_runner(virt_machine_config())
  let max_addr = max_runner.cpu.pc + 0x100U.to_uint64()
  max_runner.bus.store_u64(max_addr, 1U.to_uint64())
  max_runner.cpu.write_reg(1, max_addr)
  max_runner.cpu.write_reg(2, 0xffffffffffffffffUL)
  max_runner.bus.store_u32(
    max_runner.cpu.pc,
    encode_amo(0x1cU, 2, 1, 0x3U, 3).to_uint64(),
  )
  match max_runner.step() {
    Running => ()
    _ => fail("expected amomaxu.d to run")
  }
  assert_eq(max_runner.read_reg_u64(3), 1U.to_uint64())
  assert_eq(max_runner.bus.load_u64(max_addr), 0xffffffffffffffffUL)
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
test "LR.W and SC.W aq rl encodings execute ordinary reservation pair" {
  for order in [0U, 1U, 2U, 3U] {
    let lr_runner = make_runner(virt_machine_config())
    let lr_addr = lr_runner.cpu.pc + 0x100U.to_uint64()
    lr_runner.bus.store_u32(lr_addr, 77U.to_uint64())
    lr_runner.cpu.write_reg(1, lr_addr)
    lr_runner.cpu.write_reg(5, 88U.to_uint64())
    let lr_pc = lr_runner.cpu.pc
    // The A extension assigns aq/rl bits to LR/SC too. Some combinations are
    // only recommendations for useful acquire/release mappings, but they are
    // still instruction encodings that must reach the normal LR/SC executor.
    lr_runner.bus.store_u32(
      lr_pc,
      encode_amo_ordered(0x02U, order, 0, 1, 0x2U, 3).to_uint64(),
    )
    lr_runner.bus.store_u32(
      lr_pc + 4U.to_uint64(),
      encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
    )
    match lr_runner.step() {
      Running => ()
      _ => fail("expected ordered LR.W form to run")
    }
    assert_eq(lr_runner.read_reg_u64(3), 77U.to_uint64())
    match lr_runner.step() {
      Running => ()
      _ => fail("expected following SC.W to run")
    }
    assert_eq(lr_runner.read_reg_u64(4), 0U.to_uint64())
    assert_eq(lr_runner.bus.load_u32(lr_addr), 88U.to_uint64())

    let sc_runner = make_runner(virt_machine_config())
    let sc_addr = sc_runner.cpu.pc + 0x100U.to_uint64()
    sc_runner.bus.store_u32(sc_addr, 91U.to_uint64())
    sc_runner.cpu.write_reg(1, sc_addr)
    sc_runner.cpu.write_reg(5, 123U.to_uint64())
    let sc_pc = sc_runner.cpu.pc
    sc_runner.bus.store_u32(sc_pc, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
    sc_runner.bus.store_u32(
      sc_pc + 4U.to_uint64(),
      encode_amo_ordered(0x03U, order, 5, 1, 0x2U, 4).to_uint64(),
    )
    match sc_runner.step() {
      Running => ()
      _ => fail("expected LR.W before ordered SC.W to run")
    }
    assert_eq(sc_runner.read_reg_u64(3), 91U.to_uint64())
    match sc_runner.step() {
      Running => ()
      _ => fail("expected ordered SC.W form to run")
    }
    assert_eq(sc_runner.read_reg_u64(4), 0U.to_uint64())
    assert_eq(sc_runner.bus.load_u32(sc_addr), 123U.to_uint64())
  }
}

///|
test "LR.D/SC.D pair succeeds on single hart" {
  // Doubleword LR/SC is part of RV64A. Pin both the 64-bit load-reserved value
  // and the successful store-conditional status/result path.
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  let original = 0x1122334455667788UL
  let replacement = 0x8877665544332211UL
  runner.bus.store_u64(addr, original)
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, replacement)
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x3U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x3U, 4).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected lr.d to run")
  }
  assert_eq(runner.read_reg_u64(3), original)
  match runner.step() {
    Running => ()
    _ => fail("expected sc.d to run")
  }
  assert_eq(runner.read_reg_u64(4), 0U.to_uint64())
  assert_eq(runner.bus.load_u64(addr), replacement)
}

///|
test "LR.D and SC.D aq rl encodings execute ordinary reservation pair" {
  for order in [0U, 1U, 2U, 3U] {
    let lr_runner = make_runner(virt_machine_config())
    let lr_addr = lr_runner.cpu.pc + 0x100U.to_uint64()
    let lr_original = 0x1122334455667788UL + order.to_uint64()
    let lr_replacement = 0x8877665544332211UL
    lr_runner.bus.store_u64(lr_addr, lr_original)
    lr_runner.cpu.write_reg(1, lr_addr)
    lr_runner.cpu.write_reg(5, lr_replacement)
    let lr_pc = lr_runner.cpu.pc
    lr_runner.bus.store_u32(
      lr_pc,
      encode_amo_ordered(0x02U, order, 0, 1, 0x3U, 3).to_uint64(),
    )
    lr_runner.bus.store_u32(
      lr_pc + 4U.to_uint64(),
      encode_amo(0x03U, 5, 1, 0x3U, 4).to_uint64(),
    )
    match lr_runner.step() {
      Running => ()
      _ => fail("expected ordered LR.D form to run")
    }
    assert_eq(lr_runner.read_reg_u64(3), lr_original)
    match lr_runner.step() {
      Running => ()
      _ => fail("expected following SC.D to run")
    }
    assert_eq(lr_runner.read_reg_u64(4), 0U.to_uint64())
    assert_eq(lr_runner.bus.load_u64(lr_addr), lr_replacement)

    let sc_runner = make_runner(virt_machine_config())
    let sc_addr = sc_runner.cpu.pc + 0x100U.to_uint64()
    let sc_original = 0x0123456789abcdefUL + order.to_uint64()
    let sc_replacement = 0xfedcba9876543210UL
    sc_runner.bus.store_u64(sc_addr, sc_original)
    sc_runner.cpu.write_reg(1, sc_addr)
    sc_runner.cpu.write_reg(5, sc_replacement)
    let sc_pc = sc_runner.cpu.pc
    sc_runner.bus.store_u32(sc_pc, encode_amo(0x02U, 0, 1, 0x3U, 3).to_uint64())
    sc_runner.bus.store_u32(
      sc_pc + 4U.to_uint64(),
      encode_amo_ordered(0x03U, order, 5, 1, 0x3U, 4).to_uint64(),
    )
    match sc_runner.step() {
      Running => ()
      _ => fail("expected LR.D before ordered SC.D to run")
    }
    assert_eq(sc_runner.read_reg_u64(3), sc_original)
    match sc_runner.step() {
      Running => ()
      _ => fail("expected ordered SC.D form to run")
    }
    assert_eq(sc_runner.read_reg_u64(4), 0U.to_uint64())
    assert_eq(sc_runner.bus.load_u64(sc_addr), sc_replacement)
  }
}

///|
test "SC.W without a live reservation fails and does not store" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 77U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, 88U.to_uint64())
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected running")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), 77U.to_uint64())
}

///|
test "SC.D without a live reservation fails and does not store" {
  // RV64GC includes doubleword LR/SC. A failed SC.D reports a nonzero status
  // in rd and leaves memory unchanged, matching the word-sized failure path.
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  let original = 0x1122334455667788UL
  let replacement = 0x8877665544332211UL
  runner.bus.store_u64(addr, original)
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, replacement)
  runner.bus.store_u32(
    runner.cpu.pc,
    encode_amo(0x03U, 5, 1, 0x3U, 4).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected failed sc.d to retire")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u64(addr), original)
}

///|
test "failed SC clears the hart reservation before a later matching SC" {
  // The A-extension contract consumes the hart reservation on every executed
  // SC, not only on successful stores. This catches stale-reservation bugs
  // where a failed SC to a different address would accidentally leave a prior
  // LR live for a later SC.
  let runner = make_runner(virt_machine_config())
  let addr_a = runner.cpu.pc + 0x100U.to_uint64()
  let addr_b = runner.cpu.pc + 0x108U.to_uint64()
  runner.bus.store_u32(addr_a, 11U.to_uint64())
  runner.bus.store_u32(addr_b, 22U.to_uint64())
  runner.cpu.write_reg(1, addr_a)
  runner.cpu.write_reg(2, addr_b)
  runner.cpu.write_reg(5, 33U.to_uint64())
  runner.cpu.write_reg(6, 44U.to_uint64())
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 2, 0x2U, 4).to_uint64(),
  )
  runner.bus.store_u32(
    pc0 + 8U.to_uint64(),
    encode_amo(0x03U, 6, 1, 0x2U, 7).to_uint64(),
  )

  match runner.step() {
    Running => ()
    _ => fail("expected lr.w to run")
  }
  assert_eq(runner.read_reg_u64(3), 11U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected mismatched sc.w to retire as failure")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr_b), 22U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected later sc.w to retire as failure")
  }
  assert_eq(runner.read_reg_u64(7), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr_a), 11U.to_uint64())
}

///|
test "a later LR replaces the reservation used by SC" {
  // SC pairs with the most recent LR in program order. A later LR to a
  // different address makes the older address unreserved even when no store or
  // device write has touched either location.
  let runner = make_runner(virt_machine_config())
  let addr_a = runner.cpu.pc + 0x100U.to_uint64()
  let addr_b = runner.cpu.pc + 0x108U.to_uint64()
  runner.bus.store_u32(addr_a, 55U.to_uint64())
  runner.bus.store_u32(addr_b, 66U.to_uint64())
  runner.cpu.write_reg(1, addr_a)
  runner.cpu.write_reg(2, addr_b)
  runner.cpu.write_reg(5, 77U.to_uint64())
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x02U, 0, 2, 0x2U, 4).to_uint64(),
  )
  runner.bus.store_u32(
    pc0 + 8U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 6).to_uint64(),
  )

  match runner.step() {
    Running => ()
    _ => fail("expected first lr.w to run")
  }
  assert_eq(runner.read_reg_u64(3), 55U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected second lr.w to run")
  }
  assert_eq(runner.read_reg_u64(4), 66U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected sc.w to older address to retire as failure")
  }
  assert_eq(runner.read_reg_u64(6), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr_a), 55U.to_uint64())
  assert_eq(runner.bus.load_u32(addr_b), 66U.to_uint64())
}

///|
test "SC fails when its width does not match the LR reservation" {
  // The runner models each reservation set as the exact LR byte range. A
  // mixed-width SC at the same physical address is therefore outside the
  // reservation shape this implementation exposes, even though the broader
  // ISA leaves reservation-set size implementation-defined.
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  let original = 0x1122334455667788UL
  let replacement = 0x8877665544332211UL
  runner.bus.store_u64(addr, original)
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, replacement)
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x3U, 4).to_uint64(),
  )
  runner.bus.store_u32(
    pc0 + 8U.to_uint64(),
    encode_amo(0x02U, 0, 1, 0x3U, 6).to_uint64(),
  )
  runner.bus.store_u32(
    pc0 + 12U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 7).to_uint64(),
  )

  match runner.step() {
    Running => ()
    _ => fail("expected lr.w to run")
  }
  assert_eq(runner.read_reg_u64(3), 0x55667788U.to_uint64())
  match runner.step() {
    Running => ()
    _ => fail("expected mixed-width sc.d to retire as failure")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u64(addr), original)
  match runner.step() {
    Running => ()
    _ => fail("expected lr.d to run")
  }
  assert_eq(runner.read_reg_u64(6), original)
  match runner.step() {
    Running => ()
    _ => fail("expected mixed-width sc.w to retire as failure")
  }
  assert_eq(runner.read_reg_u64(7), 1U.to_uint64())
  assert_eq(runner.bus.load_u64(addr), original)
}

///|
test "atomic operations require natural address alignment" {
  fn expect_atomic_misaligned_trap(
    name : String,
    raw : UInt,
    offset : UInt,
    expect_load_cause : Bool,
  ) raise {
    let runner = make_runner(virt_machine_config())
    let addr = runner.cpu.pc + offset.to_uint64()
    runner.cpu.write_reg(1, addr)
    runner.cpu.write_reg(5, 0xa5a5U.to_uint64())
    runner.bus.store_u64(runner.cpu.pc + 0x100U.to_uint64(), 0U.to_uint64())
    runner.bus.store_u32(runner.cpu.pc, raw.to_uint64())
    match runner.step() {
      Trap(info) => {
        if expect_load_cause {
          match info.cause {
            LoadAddressMisaligned => ()
            _ =>
              fail(
                "expected \{name} to trap with load address misaligned, got \{trap_cause_name(info.cause)}",
              )
          }
        } else {
          match info.cause {
            StoreAddressMisaligned => ()
            _ =>
              fail(
                "expected \{name} to trap with store address misaligned, got \{trap_cause_name(info.cause)}",
              )
          }
        }
        assert_eq(info.trap_value, addr)
      }
      _ => fail("expected \{name} to trap on a misaligned atomic address")
    }
  }
  expect_atomic_misaligned_trap(
    "lr.w",
    encode_amo(0x02U, 0, 1, 0x2U, 3),
    0x102U,
    true,
  )
  expect_atomic_misaligned_trap(
    "sc.w",
    encode_amo(0x03U, 5, 1, 0x2U, 4),
    0x102U,
    false,
  )
  expect_atomic_misaligned_trap(
    "amoadd.w",
    encode_amo(0x00U, 5, 1, 0x2U, 4),
    0x102U,
    false,
  )
  expect_atomic_misaligned_trap(
    "lr.d",
    encode_amo(0x02U, 0, 1, 0x3U, 3),
    0x104U,
    true,
  )
  expect_atomic_misaligned_trap(
    "sc.d",
    encode_amo(0x03U, 5, 1, 0x3U, 4),
    0x104U,
    false,
  )
  expect_atomic_misaligned_trap(
    "amoadd.d",
    encode_amo(0x00U, 5, 1, 0x3U, 4),
    0x104U,
    false,
  )
}

///|
test "store between LR.W and SC.W invalidates the reservation" {
  let runner = make_runner(virt_machine_config())
  let addr = runner.cpu.pc + 0x100U.to_uint64()
  runner.bus.store_u32(addr, 77U.to_uint64())
  runner.cpu.write_reg(1, addr)
  runner.cpu.write_reg(5, 88U.to_uint64())
  runner.cpu.write_reg(6, 99U.to_uint64())
  let pc0 = runner.cpu.pc
  runner.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  runner.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_s(0, 6, 1, 0x2U, 0x23U).to_uint64(),
  )
  runner.bus.store_u32(
    pc0 + 8U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )
  match runner.step() {
    Running => ()
    _ => fail("expected LR.W to run")
  }
  match runner.step() {
    Running => ()
    _ => fail("expected SW to run")
  }
  match runner.step() {
    Running => ()
    _ => fail("expected SC.W to run")
  }
  assert_eq(runner.read_reg_u64(4), 1U.to_uint64())
  assert_eq(runner.bus.load_u32(addr), 99U.to_uint64())
}

///|
test "store from another hart invalidates LR.W reservation" {
  let harts = make_smp_runners(virt_machine_config(), 2)
  let hart0 = harts[0]
  let hart1 = harts[1]
  let pc0 = hart0.cpu.pc
  let addr = pc0 + 0x100U.to_uint64()
  hart0.bus.store_u32(addr, 77U.to_uint64())
  hart0.cpu.write_reg(1, addr)
  hart0.cpu.write_reg(5, 88U.to_uint64())
  hart1.cpu.write_reg(1, addr)
  hart1.cpu.write_reg(6, 99U.to_uint64())
  hart0.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x2U, 3).to_uint64())
  hart0.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x2U, 4).to_uint64(),
  )
  match hart0.step() {
    Running => ()
    _ => fail("expected hart0 LR.W to run")
  }
  // Hart 1 starts at the same reset PC. After hart 0 has consumed the LR
  // instruction, replace that slot with a plain store for hart 1; hart 0's
  // next instruction is already the SC at pc+4.
  hart1.bus.store_u32(pc0, encode_s(0, 6, 1, 0x2U, 0x23U).to_uint64())
  match hart1.step() {
    Running => ()
    _ => fail("expected hart1 SW to run")
  }
  match hart0.step() {
    Running => ()
    _ => fail("expected hart0 SC.W to run")
  }
  assert_eq(hart0.read_reg_u64(4), 1U.to_uint64())
  assert_eq(hart0.bus.load_u32(addr), 99U.to_uint64())
}

///|
test "overlapping store from another hart invalidates LR.D reservation" {
  let harts = make_smp_runners(virt_machine_config(), 2)
  let hart0 = harts[0]
  let hart1 = harts[1]
  let pc0 = hart0.cpu.pc
  let addr = pc0 + 0x100U.to_uint64()
  hart0.bus.store_u64(
    addr,
    (0x11223344U.to_uint64() << 32) | 0x55667788U.to_uint64(),
  )
  hart0.cpu.write_reg(1, addr)
  hart0.cpu.write_reg(5, 123U.to_uint64())
  hart1.cpu.write_reg(1, addr)
  hart1.cpu.write_reg(6, 0x99aabbccU.to_uint64())
  hart0.bus.store_u32(pc0, encode_amo(0x02U, 0, 1, 0x3U, 3).to_uint64())
  hart0.bus.store_u32(
    pc0 + 4U.to_uint64(),
    encode_amo(0x03U, 5, 1, 0x3U, 4).to_uint64(),
  )
  match hart0.step() {
    Running => ()
    _ => fail("expected hart0 LR.D to run")
  }
  // A store to addr+4 overlaps the LR.D byte range even though it starts at a
  // different physical address than the LR itself.
  hart1.bus.store_u32(pc0, encode_s(4, 6, 1, 0x2U, 0x23U).to_uint64())
  match hart1.step() {
    Running => ()
    _ => fail("expected hart1 SW to run")
  }
  match hart0.step() {
    Running => ()
    _ => fail("expected hart0 SC.D to run")
  }
  assert_eq(hart0.read_reg_u64(4), 1U.to_uint64())
  assert_eq(hart0.bus.load_u32(addr), 0x55667788U.to_uint64())
  assert_eq(hart0.bus.load_u32(addr + 4U.to_uint64()), 0x99aabbccU.to_uint64())
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
