let default_sample_path = "_build/c-samples/rv32i-sum/rv32i-sum.elf"
let sample_result_addr = 0x80003000U
let sample_step_budget = 256

///|
async fn load_sample_bytes(path : String) -> Bytes {
  try {
    @fs.read_file(path).binary()
  } catch {
    _ => abort("failed to read sample ELF: " + path)
  }
}

///|
fn parse_sample_path(args : Array[String]) -> String {
  if args.length() >= 2 {
    args[1]
  } else {
    default_sample_path
  }
}

///|
async fn main {
  let args = @env.args()
  let sample_path = parse_sample_path(args)
  let elf = load_sample_bytes(sample_path)
  let runner = @riscv.make_runner(@riscv.official_riscv_tests_machine_config())

  match runner.load_elf(elf) {
    @riscv.LoadError(message) => abort("failed to load sample ELF: " + message)
    @riscv.Loaded(info) => {
      ignore(info)
    }
  }

  match runner.run(sample_step_budget) {
    @riscv.Running => ()
    @riscv.Trap(_) => abort("sample trapped before completing")
  }

  let result = runner.load_u32(sample_result_addr)
  let status = if result == 1U { "pass" } else { "unexpected" }
  println("RV32I freestanding C sample")
  println("elf=" + sample_path)
  println("pc=" + runner.pc().to_string())
  println("result=" + result.to_string())
  println("status=" + status)
}
