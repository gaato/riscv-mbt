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

- `done`

## Progress Notes

- 2026-09-23 baseline on this host (no concurrent load, `moon bench --target native` x3, means):
  `tight_add_loop_100k_steps` 6.82 / 6.85 / 6.87 ms, `dword_copy_loop_100k_steps` 8.69 / 8.73 / 8.74 ms,
  `amoadd_word_loop_100k_steps` 15.60 / 15.67 / 15.61 ms, `spinlock_shape_loop_100k_steps` 15.78 / 15.54 / 15.71 ms,
  `vector_add_lmul2_loop_100k_steps` 31.32 / 31.62 / 31.17 ms. `word_copy_loop_100k_steps` is bimodal on this host
  (13.5 to 56 ms within one run, mean about 24 ms); compare its minimum, not its mean.
- 2026-09-23 browser baseline (`--alpine-interactive-smoke --budget-ms 30000 --wall-timeout 180`, x3):
  shell response at 373,293,056 guest steps; wall 1:35.45 / 1:36.08 / 1:35.18 (median 95.5 s, about 3.9 M steps/s).
  The first run overlapped a `moon bench` run; runs 2 and 3 did not and agree, so 95.5 s is the baseline.
- A `moon bench` run that overlapped the browser build measured `tight_add_loop_100k_steps` at 7.1 ms; never run the
  two concurrently.
- Handed to Codex (`gpt-5.6-sol`, write mode) with the design above.
- Codex delivered `translate_pa`, `fetch_into_scratch`, sentinel-returning `load_check` / `store_check` /
  `checked_load_pa` / `checked_store_pa`, converted all scalar, AMO, LR/SC, and vector-memory callers, and the four
  tests. Claude fixed two compile issues (`const` names must be uppercase in MoonBit; both became top-level `let`),
  deleted the now-unused `translate_address` / `fetch_instruction` wrappers and `FetchedInstruction`, and rewrote the
  cross-page test against literal expected values.
- Result (`moon bench --target native` x3, means): `tight_add_loop_100k_steps` 3.94 / 4.12 / 3.92 ms (baseline 6.85,
  -42 %), `dword_copy_loop_100k_steps` 6.57 / 6.82 / 6.54 ms (8.72, -24 %), `amoadd_word_loop_100k_steps`
  9.41 / 9.41 / 9.43 ms (15.63, -40 %), `spinlock_shape_loop_100k_steps` 9.43 / 9.53 / 9.37 ms (15.68, -40 %),
  `word_copy_loop_100k_steps` minimum 9.13 ms (13.51, -32 %), `vector_add_lmul2_loop_100k_steps` 28.9 / 28.9 / 29.3 ms
  (31.4, -8 %).
- Browser Alpine interactive smoke x3: wall 1:33.18 / 1:33.80 / 1:33.76 (median 93.8 s vs baseline 95.5 s, -1.8 %),
  same 373,293,056-step response point. Kept under the ADR 0011 rule (native >= 3 % and browser not worse).
- The browser gain is far smaller than the native gain, so per-instruction allocation was not the main browser cost;
  Task 0066 (RAM backing store) is the next candidate, and browser-side profiling should follow if it also moves
  native much more than browser.
- Validation: `moon check` (0 warnings), `moon test` (594 passed), `moon fmt`, `moon info`, `git diff --check`,
  `./scripts/build-browser-demo.sh` all clean.
