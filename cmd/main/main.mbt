///|
fn main {
  let runner = @riscv.make_runner(@riscv.default_machine_config())
  runner.load_program(@riscv.words_to_bytes(@riscv.demo_program_words()), 0U)
  ignore(runner.run(5))
  println("RV32I bootstrap demo")
  println("pc=" + runner.pc().to_string())
  println("x1=" + runner.read_reg(1).to_string())
  println("x2=" + runner.read_reg(2).to_string())
  println("x3=" + runner.read_reg(3).to_string())
  println("x4=" + runner.read_reg(4).to_string())
}
