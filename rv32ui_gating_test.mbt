///|
async test "refactored execute path keeps official rv32ui gating subset green" {
  let cases = load_official_riscv_test_cases().filter(fn(test_case) {
    test_case.tier == "gating"
  })
  let mut index = 0
  while index < cases.length() {
    let result = run_official_riscv_test_case(cases[index])
    assert_eq(result, 1U)
    index = index + 1
  }
}
