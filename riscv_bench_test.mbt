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
test (b : @bench.T) {
  b.bench(name="tight_add_loop_100k_steps", fn() {
    let runner = make_tight_add_loop_runner()
    b.keep(runner.run(100000))
    b.keep(runner.decode_cache_hit_count())
    b.keep(runner.decode_cache_miss_count())
  })
}
