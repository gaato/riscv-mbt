// Microbenchmarks for emulator hot-path shapes. These are not correctness
// proofs; they provide direction before validating changes with Linux/browser
// integration tests.

///|
fn make_tight_add_loop_runner() -> Runner {
  let runner = make_runner(default_machine_config())
  let program = words_to_bytes([
    encode_i(1, 1, 0x0U, 1, 0x13U),
    encode_j(-4, 0, 0x6fU),
  ])
  runner.load_program(program, 0U)
  runner
}

///|
fn make_word_copy_loop_runner() -> Runner {
  let runner = make_runner(virt_machine_config())
  let pc = 0x80000000U.to_uint64()
  let src = 0x80100000U.to_uint64()
  let dst = 0x80200000U.to_uint64()
  let words = 20000
  let program = words_to_bytes([
    encode_i(0, 11, 0x2U, 14, 0x03U), // lw a4, 0(a1)
    encode_i(4, 11, 0x0U, 11, 0x13U), // addi a1, a1, 4
    encode_s(0, 14, 31, 0x2U, 0x23U), // sw a4, 0(t6)
    encode_i(4, 31, 0x0U, 31, 0x13U), // addi t6, t6, 4
    encode_b(-16, 13, 11, 0x6U, 0x63U), // bltu a1, a3, loop
  ])
  runner.load_program_u64(program, pc)
  for i in 0..<words {
    let addr = src + (i * 4).reinterpret_as_uint().to_uint64()
    runner.bus.store_u32(addr, i.reinterpret_as_uint().to_uint64())
  }
  runner.cpu.write_reg(11, src)
  runner.cpu.write_reg(13, src + (words * 4).reinterpret_as_uint().to_uint64())
  runner.cpu.write_reg(31, dst)
  runner
}

///|
fn make_dword_copy_loop_runner() -> Runner {
  let runner = make_runner(virt_machine_config())
  let pc = 0x80000000U.to_uint64()
  let src = 0x80100000U.to_uint64()
  let dst = 0x80200000U.to_uint64()
  let words = 10000
  let program = words_to_bytes([
    encode_i(0, 11, 0x3U, 14, 0x03U), // ld a4, 0(a1)
    encode_i(8, 11, 0x0U, 11, 0x13U), // addi a1, a1, 8
    encode_s(0, 14, 31, 0x3U, 0x23U), // sd a4, 0(t6)
    encode_i(8, 31, 0x0U, 31, 0x13U), // addi t6, t6, 8
    encode_b(-16, 13, 11, 0x6U, 0x63U), // bltu a1, a3, loop
  ])
  runner.load_program_u64(program, pc)
  for i in 0..<words {
    let addr = src + (i * 8).reinterpret_as_uint().to_uint64()
    runner.bus.store_u64(addr, i.reinterpret_as_uint().to_uint64())
  }
  runner.cpu.write_reg(11, src)
  runner.cpu.write_reg(13, src + (words * 8).reinterpret_as_uint().to_uint64())
  runner.cpu.write_reg(31, dst)
  runner
}

///|
fn encode_amo_aqrl(
  funct5 : UInt,
  rs2 : Int,
  rs1 : Int,
  funct3 : UInt,
  rd : Int,
) -> UInt {
  encode_r((funct5 << 2) | 0x3U, rs2, rs1, funct3, rd, 0x2fU)
}

///|
fn make_amoadd_word_loop_runner() -> Runner {
  let runner = make_runner(virt_machine_config())
  let pc = 0x80000000U.to_uint64()
  let lock_addr = 0x80100000U.to_uint64()
  let iterations = 33333
  let program = words_to_bytes([
    encode_amo_aqrl(0x00U, 15, 10, 0x2U, 14), // amoadd.w.aqrl a4, a5, (a0)
    encode_i(1, 6, 0x0U, 6, 0x13U), // addi t1, t1, 1
    encode_b(-8, 7, 6, 0x6U, 0x63U), // bltu t1, t2, loop
  ])
  runner.load_program_u64(program, pc)
  runner.bus.store_u32(lock_addr, 0U.to_uint64())
  runner.cpu.write_reg(10, lock_addr)
  runner.cpu.write_reg(15, 1U.to_uint64())
  runner.cpu.write_reg(7, iterations.reinterpret_as_uint().to_uint64())
  runner
}

///|
fn make_spinlock_shape_loop_runner() -> Runner {
  let runner = make_runner(virt_machine_config())
  let pc = 0x80000000U.to_uint64()
  let table_addr = 0x80100000U.to_uint64()
  let halfword_addr = 0x80200000U.to_uint64()
  let tp_addr = 0x80300000U.to_uint64()
  let lock_addr = 0x80400000U.to_uint64()
  let iterations = 6250
  let program = words_to_bytes([
    encode_fence(), // fence rw,rw
    encode_i(32, 4, 0x2U, 13, 0x03U), // lw a3, 32(tp)
    encode_u(0x80100000U, 14, 0x37U), // lui a4, table high bits
    encode_i(3, 13, 0x1U, 13, 0x13U), // slli a3, a3, 3
    encode_r(0x00U, 13, 14, 0x0U, 14, 0x33U), // add a4, a4, a3
    encode_i(0, 14, 0x3U, 14, 0x03U), // ld a4, 0(a4)
    encode_u(0x80200000U, 15, 0x37U), // lui a5, halfword table high bits
    encode_r(0x00U, 14, 15, 0x0U, 15, 0x33U), // add a5, a5, a4
    encode_i(0, 15, 0x5U, 14, 0x03U), // lhu a4, 0(a5)
    encode_u(0x00010000U, 14, 0x37U), // lui a4, 0x10
    encode_amo_aqrl(0x00U, 14, 10, 0x2U, 14), // amoadd.w.aqrl a4, a4, (a0)
    encode_i(48, 14, 0x1U, 15, 0x13U), // slli a5, a4, 48
    encode_i(48, 15, 0x5U, 15, 0x13U), // srli a5, a5, 48
    encode_i(16, 14, 0x5U, 14, 0x1bU), // srliw a4, a4, 16
    encode_i(1, 6, 0x0U, 6, 0x13U), // addi t1, t1, 1
    encode_b(-60, 7, 6, 0x6U, 0x63U), // bltu t1, t2, loop
  ])
  runner.load_program_u64(program, pc)
  runner.bus.store_u32(tp_addr + 32U.to_uint64(), 0U.to_uint64())
  runner.bus.store_u64(table_addr, 0U.to_uint64())
  runner.bus.store_u16(halfword_addr, 0U.to_uint64())
  runner.bus.store_u32(lock_addr, 0U.to_uint64())
  runner.cpu.write_reg(4, tp_addr)
  runner.cpu.write_reg(10, lock_addr)
  runner.cpu.write_reg(7, iterations.reinterpret_as_uint().to_uint64())
  runner
}

///|
test (b : @bench.T) {
  b.bench(name="tight_add_loop_100k_steps", fn() {
    let runner = make_tight_add_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
  b.bench(name="word_copy_loop_100k_steps", fn() {
    let runner = make_word_copy_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.bus.load_u32(0x80200000U.to_uint64()))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
  b.bench(name="dword_copy_loop_100k_steps", fn() {
    let runner = make_dword_copy_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.bus.load_u64(0x80200000U.to_uint64()))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
  b.bench(name="amoadd_word_loop_100k_steps", fn() {
    let runner = make_amoadd_word_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.bus.load_u32(0x80100000U.to_uint64()))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
  b.bench(name="spinlock_shape_loop_100k_steps", fn() {
    let runner = make_spinlock_shape_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.bus.load_u32(0x80400000U.to_uint64()))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
}
