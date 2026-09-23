# Task 0065: De-Allocate The Step Hot Path

## Background

`Runner::step` (`riscv_execute.mbt`) allocates on every instruction:
`translate_address` returns a boxed `TranslateResult`, `fetch_instruction`
returns `(FetchedInstruction?, StepResult?)`, and `load_check` /
`store_check` / `checked_load_pa` / `checked_store_pa` return
`(UInt64, StepResult?)` tuples. On `wasm-gc` each is a heap allocation, which
is the leading hypothesis for browser running at about 7 M steps/s against
about 20 M native. This slice removes those allocations from the common path
without changing behavior.

## Scope

- Files: `riscv_sv39.mbt` (`translate_address`, `translate_cached`,
  `fetch_instruction`, `load_check`, `store_check`), `riscv_execute.mbt`
  (`checked_load_pa`, `checked_store_pa`, `execute_load`, `execute_store`,
  AMO / LR / SC callers, the fetch match in `Runner::step`), `riscv_mbt.mbt`
  (new scratch fields on `Runner`, init in `make_runner` and
  `make_smp_runners`), and any callers in `riscv_vector_memory.mbt` and
  `riscv_fp.mbt`.
- Do not touch the decode cache, translation cache, timers, PLIC, or CSR code.
- Do not add closures or higher-order helpers on the hot path.
- Keep the existing `translate_address` and `fetch_instruction` functions so
  existing tests keep compiling; the step path stops using them.

## Design

- `Runner::translate_pa(vaddr : UInt64, access : AccessType, priv : PrivilegeMode) -> UInt64`
  returns the physical address, or the sentinel `translate_fault_sentinel =
  0xffff_ffff_ffff_ffff` on a fault, and records the cause in a new
  `mut last_translate_fault : TrapCause` field. The sentinel can never be a
  valid address for any access of width >= 1.
- `Runner::fetch_into_scratch(pc : UInt64) -> Bool` writes
  `mut fetch_pa : UInt64`, `mut fetch_raw : UInt`, `mut fetch_length : Int`
  on success; on failure it stores the trap result in
  `mut pending_step_result : StepResult` and returns `false`. The
  page-crossing rule is unchanged: a 32-bit instruction still translates
  `pc + 2` separately, and `tval` follows the rules pinned by
  `riscv_fetch_test.mbt`.
- `load_check` / `store_check` / `checked_load_pa` / `checked_store_pa`
  return the physical address or `mem_fault_sentinel` (same value), with the
  trap result in `pending_step_result`. Callers branch on the sentinel.
- `TrapInfo` is allocated only on trap paths.

## Tests (write first, in `riscv_hot_path_wbtest.mbt`)

- `translate_pa returns the sentinel and records the cause on an Sv39 fault`
- `fetch_into_scratch records an instruction access fault in pending_step_result and leaves scratch untouched`
- `load_check returns the sentinel for an unmapped physical address`
- `fetch_into_scratch matches fetch_instruction for a 32-bit instruction crossing a page`

## Validation (Claude)

- `moon check --target native`, `moon test --target native .`, `moon fmt`,
  `moon info --target native`, `git diff --check`
- `./scripts/build-browser-demo.sh`
- `moon bench` three times; browser Alpine interactive smoke three times
- Keep if `tight_add_loop_100k_steps` or `word_copy_loop_100k_steps`
  improves >= 3 %, or browser steps/s improves >= 3 %, with no browser
  median regression beyond 2 %.

## Status

- `todo`
