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
}
