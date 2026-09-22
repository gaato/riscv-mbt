// Official riscv-tests gating rows keep the execute path honest against
// upstream-style pass/fail binaries. The manifest decides which RV32/RV64 rows
// are ready to be always-green.

///|
fn assert_unique_official_manifest_keys(
  keys : Array[String],
  label : String,
) -> Unit {
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
    let mut message = "duplicate official riscv-tests \{label} rows:"
    for key in duplicates {
      message = message + "\n" + key
    }
    abort(message)
  }
}

///|
async test "refactored execute path keeps official riscv-tests gating subset green" {
  let cases = load_official_riscv_test_cases().filter(fn(test_case) {
    test_case.tier == "gating"
  })
  let mut index = 0
  while index < cases.length() {
    let test_case = cases[index]
    let result = run_official_riscv_test_case(test_case)
    if result != 1U {
      // Name the row: a bare `5 != 1` cannot tell a reviewer which of the
      // 140-plus gating binaries regressed or which TEST_CASE number failed
      // (tohost = case * 2 + 1).
      abort(
        "official riscv-tests gating row failed: \{test_case.suite}/\{test_case.name} tohost=\{result}",
      )
    }
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
async test "official RV64GC riscv-tests gating rows have local sources" {
  let source_keys = load_local_rv64gc_source_keys()
  let gating_keys = load_manifest_rv64gc_gating_keys()
  let stale : Array[String] = []
  for key in gating_keys {
    if !source_keys.contains(key) {
      stale.push(key)
    }
  }
  stale.sort()
  if stale.length() != 0 {
    let mut message = "stale \{stale.length()} of \{gating_keys.length()} RV64GC official riscv-tests gating rows without local source files:"
    for key in stale {
      message = message + "\n" + key
    }
    abort(message)
  }
}

///|
async test "official RV64GC riscv-tests source suites are populated" {
  let counts = count_local_rv64gc_source_rows_by_suite()
  let empty : Array[String] = []
  for count in counts {
    let fields : Array[String] = []
    for field in count.split("=") {
      fields.push(field.to_owned())
    }
    if fields.length() != 2 {
      abort("malformed RV64GC source suite count: \{count}")
    }
    if fields[1] == "0" {
      empty.push(count)
    }
  }
  if empty.length() != 0 {
    let mut message = "empty local RV64GC official riscv-tests source suites:"
    for count in empty {
      message = message + "\n" + count
    }
    abort(message)
  }
}

///|
async test "official riscv-tests gating manifest has unique rows" {
  assert_unique_official_manifest_keys(load_manifest_gating_keys(), "gating")
}

///|
async test "official riscv-tests manifest has no duplicate rows across tiers" {
  assert_unique_official_manifest_keys(load_manifest_keys(), "manifest")
}
