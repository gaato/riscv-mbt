// White-box characterizations for the allocation-free step-path scratch API.

///|
let hot_path_test_pte_v : UInt64 = 0x1UL

///|
let hot_path_test_pte_r : UInt64 = 0x2UL

///|
let hot_path_test_pte_x : UInt64 = 0x8UL

///|
let hot_path_test_pte_a : UInt64 = 0x40UL

///|
fn hot_path_test_make_pte(ppn : UInt64, flags : UInt64) -> UInt64 {
  (ppn << 10) | flags
}

///|
fn hot_path_test_satp(root_ppn : UInt64) -> UInt64 {
  (8U.to_uint64() << 60) | root_ppn
}

///|
fn hot_path_test_setup_cross_page_fetch(runner : Runner) -> UInt64 {
  let root_ppn = 1U.to_uint64()
  let l1_ppn = 2U.to_uint64()
  let l0_ppn = 3U.to_uint64()
  let low_target_ppn = 4U.to_uint64()
  let high_target_ppn = 6U.to_uint64()
  runner.bus.store_u64(
    root_ppn * 4096U.to_uint64(),
    hot_path_test_make_pte(l1_ppn, hot_path_test_pte_v),
  )
  runner.bus.store_u64(
    l1_ppn * 4096U.to_uint64(),
    hot_path_test_make_pte(l0_ppn, hot_path_test_pte_v),
  )
  let leaf_flags = hot_path_test_pte_v |
    hot_path_test_pte_r |
    hot_path_test_pte_x |
    hot_path_test_pte_a
  runner.bus.store_u64(
    l0_ppn * 4096U.to_uint64(),
    hot_path_test_make_pte(low_target_ppn, leaf_flags),
  )
  runner.bus.store_u64(
    l0_ppn * 4096U.to_uint64() + 8U.to_uint64(),
    hot_path_test_make_pte(high_target_ppn, leaf_flags),
  )
  let pc = 0xffeU.to_uint64()
  runner.bus.store_u16(
    low_target_ppn * 4096U.to_uint64() + 0xffeU.to_uint64(),
    0x0013U.to_uint64(),
  )
  runner.bus.store_u16(high_target_ppn * 4096U.to_uint64(), 0x0050U.to_uint64())
  runner.cpu.privilege = Supervisor
  runner.cpu.write_csr(CSR_SATP, hot_path_test_satp(root_ppn))
  pc
}

///|
test "translate_pa returns the sentinel and records the cause on an Sv39 fault" {
  let runner = make_runner(rv64_machine_config())
  runner.cpu.privilege = Supervisor
  runner.cpu.write_csr(CSR_SATP, hot_path_test_satp(1U.to_uint64()))
  let pa = runner.translate_pa(0U.to_uint64(), Load, Supervisor)
  assert_eq(pa, translate_fault_sentinel)
  match runner.last_translate_fault {
    LoadPageFault => ()
    _ => fail("expected LoadPageFault")
  }
}

///|
test "fetch_into_scratch records an instruction access fault in pending_step_result and leaves scratch untouched" {
  let runner = make_runner(default_machine_config())
  runner.fetch_pa = 0x11U.to_uint64()
  runner.fetch_raw = 0x2233U
  runner.fetch_length = 7
  let addr = runner.config.ram_size.reinterpret_as_uint().to_uint64()
  assert_false(runner.fetch_into_scratch(addr))
  assert_eq(runner.fetch_pa, 0x11U.to_uint64())
  assert_eq(runner.fetch_raw, 0x2233U)
  assert_eq(runner.fetch_length, 7)
  match runner.pending_step_result {
    Trap(info) => {
      match info.cause {
        InstructionAccessFault => ()
        _ => fail("expected InstructionAccessFault")
      }
      assert_eq(info.faulting_pc, addr)
      assert_eq(info.trap_value, addr)
    }
    Running => fail("expected fetch trap")
  }
}

///|
test "load_check returns the sentinel for an unmapped physical address" {
  let runner = make_runner(default_machine_config())
  let addr = runner.config.ram_size.reinterpret_as_uint().to_uint64()
  let faulting_pc = runner.cpu.pc
  assert_eq(runner.load_check(addr, 1), translate_fault_sentinel)
  match runner.pending_step_result {
    Trap(info) => {
      match info.cause {
        LoadAccessFault => ()
        _ => fail("expected LoadAccessFault")
      }
      assert_eq(info.faulting_pc, faulting_pc)
      assert_eq(info.trap_value, addr)
    }
    Running => fail("expected load trap")
  }
}

///|
test "fetch_into_scratch assembles a 32-bit instruction crossing a page from two translations" {
  let runner = make_runner(rv64_machine_config())
  let pc = hot_path_test_setup_cross_page_fetch(runner)
  // Low half at the last halfword of physical page 4, high half at the
  // first halfword of physical page 6: raw = 0x0050_0013 (addi zero, zero, 5).
  assert_true(runner.fetch_into_scratch(pc))
  assert_eq(
    runner.fetch_pa,
    4U.to_uint64() * 4096U.to_uint64() + 0xffeU.to_uint64(),
  )
  assert_eq(runner.fetch_raw, 0x00500013U)
  assert_eq(runner.fetch_length, 4)
}
