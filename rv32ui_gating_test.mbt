// Official riscv-tests gating rows keep the execute path honest against
// upstream-style pass/fail binaries. The manifest decides which RV32/RV64 rows
// are ready to be always-green.

///|
async test "refactored execute path keeps official riscv-tests gating subset green" {
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

///|
async test "official RV64GC riscv-tests source rows are all gated" {
  let source_keys = load_local_rv64gc_source_keys()
  let gating_keys = load_manifest_gating_keys()
  let missing : Array[String] = []
  for key in source_keys {
    if !gating_keys.contains(key) {
      missing.push(key)
    }
  }
  missing.sort()
  if missing.length() != 0 {
    let mut message = "missing \{missing.length()} of \{source_keys.length()} local RV64GC official riscv-tests gating rows:"
    for key in missing {
      message = message + "\n" + key
    }
    abort(message)
  }
}

///|
async test "official riscv-tests gating manifest has unique rows" {
  let keys = load_manifest_gating_keys()
  keys.sort()
  let duplicates : Array[String] = []
  let mut index = 1
  while index < keys.length() {
    if keys[index] == keys[index - 1] {
      duplicates.push(keys[index])
    }
    index = index + 1
  }
  if duplicates.length() != 0 {
    let mut message = "duplicate official riscv-tests gating rows:"
    for key in duplicates {
      message = message + "\n" + key
    }
    abort(message)
  }
}
