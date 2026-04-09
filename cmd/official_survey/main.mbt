let default_official_riscv_tests_manifest_path = "tools/riscv-tests-manifest.tsv"
let official_riscv_tests_isa_dir_rv32 = "_build/riscv-tests-src/isa"
let official_riscv_tests_isa_dir_rv64 = "_build/riscv-tests-src-rv64/isa"
let default_suite = "rv32uc"
let default_step_budget = 200000

///|
struct OfficialRiscvTestCase {
  suite : String
  name : String
  arch : String
  tier : String
  path : String
  max_steps : Int
}

///|
enum SurveyOutcome {
  Pass(UInt)
  Fail(UInt)
  Trap(@riscv.TrapInfo)
  Timeout
  LoadError(String)
  MissingTohost
}

///|
async fn read_manifest_text(path : String) -> String {
  try {
    @fs.read_file(path).text()
  } catch {
    _ => abort("missing official riscv-tests manifest: " + path)
  }
}

///|
async fn read_official_test_elf(path : String) -> Bytes {
  try {
    @fs.read_file(path).binary()
  } catch {
    _ =>
      abort(
        "missing official riscv-tests ELF: " + path +
        "; run ./scripts/build-riscv-tests-official.sh first",
      )
  }
}

///|
async fn load_official_riscv_test_cases(
  suite_filter : String,
  manifest_path : String,
) -> Array[OfficialRiscvTestCase] {
  let manifest = read_manifest_text(manifest_path)
  let cases : Array[OfficialRiscvTestCase] = []
  for raw_line in manifest.split("\n") {
    let line = raw_line.to_string().trim().to_string()
    if line == "" || line.has_prefix("#") {
      continue
    }
    let fields : Array[String] = []
    for field in line.split("\t") {
      fields.push(field.to_string())
    }
    if fields.length() != 4 {
      abort("invalid riscv-tests manifest line: " + line)
    }
    let suite = fields[0]
    let name = fields[1]
    let arch = fields[2]
    let tier = fields[3]
    if suite_filter != "all" && suite != suite_filter {
      continue
    }
    let path = official_riscv_tests_isa_dir_for_arch(arch) + "/" + suite + "-p-" + name
    cases.push({ suite, name, arch, tier, path, max_steps: default_step_budget })
  }
  cases
}

///|
fn official_riscv_tests_isa_dir_for_arch(arch : String) -> String {
  if arch.has_prefix("rv64") {
    official_riscv_tests_isa_dir_rv64
  } else {
    official_riscv_tests_isa_dir_rv32
  }
}

///|
fn official_riscv_tests_xlen_for_arch(arch : String) -> @riscv.Xlen {
  if arch.has_prefix("rv64") {
    @riscv.xlen64()
  } else {
    @riscv.xlen32()
  }
}

///|
fn trap_cause_name(cause : @riscv.TrapCause) -> String {
  match cause {
    @riscv.InstructionAccessFault => "instruction access fault"
    @riscv.IllegalInstruction => "illegal instruction"
    @riscv.LoadAccessFault => "load access fault"
    @riscv.StoreAccessFault => "store access fault"
    @riscv.EnvironmentCallFromUMode => "ecall from u-mode"
    @riscv.EnvironmentCallFromSMode => "ecall from s-mode"
    @riscv.EnvironmentCallFromMMode => "ecall from m-mode"
  }
}

///|
async fn run_official_riscv_test_case(
  test_case : OfficialRiscvTestCase,
) -> SurveyOutcome {
  let runner = @riscv.make_runner(
    @riscv.official_riscv_tests_machine_config_for_xlen(
      official_riscv_tests_xlen_for_arch(test_case.arch),
    ),
  )
  let elf = read_official_test_elf(test_case.path)
  let info = match runner.load_elf(elf) {
    @riscv.Loaded(info) => info
    @riscv.LoadError(message) => return LoadError(message)
  }
  let tohost = match info.tohost_addr {
    Some(value) => value
    None => return MissingTohost
  }
  let mut steps = 0
  while steps < test_case.max_steps {
    let value = runner.load_u32_u64(tohost)
    if value != 0U.to_uint64() {
      if value == 1U.to_uint64() {
        return Pass(value.to_uint())
      } else {
        return Fail(value.to_uint())
      }
    }
    match runner.step() {
      @riscv.Running => steps = steps + 1
      @riscv.Trap(info) => return Trap(info)
    }
  }
  Timeout
}

///|
fn parse_suite(args : Array[String]) -> String {
  if args.length() >= 2 {
    args[1]
  } else {
    default_suite
  }
}

///|
fn parse_manifest_path(args : Array[String]) -> String {
  if args.length() >= 3 {
    args[2]
  } else {
    default_official_riscv_tests_manifest_path
  }
}

///|
fn case_label(test_case : OfficialRiscvTestCase) -> String {
  test_case.suite +
  "/" +
  test_case.arch +
  "/" +
  test_case.name +
  " [" +
  test_case.tier +
  "]"
}

///|
fn outcome_line(
  test_case : OfficialRiscvTestCase,
  outcome : SurveyOutcome,
) -> String {
  let label = case_label(test_case)
  match outcome {
    Pass(value) => "PASS  " + label + " tohost=" + value.to_string()
    Fail(value) => "FAIL  " + label + " tohost=" + value.to_string()
    Timeout => "TIMEOUT " + label
    MissingTohost => "ERROR " + label + " missing tohost"
    LoadError(message) => "ERROR " + label + " load=" + message
    Trap(info) =>
      "TRAP  " +
      label +
      " cause=" +
      trap_cause_name(info.cause) +
      " pc=" +
      info.faulting_pc.to_string() +
      " tval=" +
      info.trap_value.to_string()
  }
}

///|
async fn main {
  let args = @env.args()
  let suite = parse_suite(args)
  let manifest_path = parse_manifest_path(args)
  let cases = load_official_riscv_test_cases(suite, manifest_path)
  if cases.is_empty() {
    abort(
      "no official riscv-tests cases found for suite: " + suite +
      " in manifest: " +
      manifest_path,
    )
  }

  let mut pass_count = 0
  let mut nonpass_count = 0
  for test_case in cases {
    let outcome = run_official_riscv_test_case(test_case)
    println(outcome_line(test_case, outcome))
    match outcome {
      Pass(_) => pass_count = pass_count + 1
      _ => nonpass_count = nonpass_count + 1
    }
  }

  println("")
  println("official riscv-tests survey")
  println("suite=" + suite)
  println("manifest=" + manifest_path)
  println("cases=" + cases.length().to_string())
  println("pass=" + pass_count.to_string())
  println("nonpass=" + nonpass_count.to_string())
}
