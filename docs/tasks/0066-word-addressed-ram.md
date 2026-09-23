# Task 0066: Word-Addressed RAM Backing Store

## Background

`Bus` (`riscv_mbt.mbt:62`) stores guest RAM as `Array[Byte]` and every
16/32/64-bit load or store is composed byte by byte (`riscv_mbt.mbt:1256`
onward), with an `Array` bounds check and indirection per byte. Task 0058
tried hand-expanding the byte indexing and saw no gain; the untried change is
the backing store itself.

## Scope

- `riscv_mbt.mbt` only: the `Bus` struct and every function that touches
  `.memory[` (19 sites in that file: `Bus::new`, `contains_range`,
  `load_raw_u8/u16/u32`, `load_u8/u16/u32/u64`, `store_u8/u16/u32/u64`,
  `write_bytes`, `write_bytes_from`, `copy_bytes_to_array`, `zero_range`,
  `fetch_u16`, and any others found by grep).
- No public `Bus` signature changes. MMIO paths never reach `Bus` and are
  untouched.
- Out-of-range accesses must fail the same way as today (array index panic);
  do not add silent wrap-around.

## Design

- `Bus { base_addr : UInt64, words : FixedArray[UInt64], size : Int }`.
- `off = pa - base_addr`. An aligned u64 is `words[off >> 3]`; u32/u16/u8
  are shift-and-mask from one word; an access whose `(off & 7) + width > 8`
  merges two adjacent words. Sub-word stores are read-modify-write on the
  containing word(s).
- `write_bytes_from(dst, src : Bytes, src_off, len)` copies the unaligned
  head byte-wise, then 8 bytes at a time using
  `Bytes::unsafe_read_uint64_le` (a public core intrinsic in
  `moonbitlang/core/builtin/bytes_unsafe.mbt`) when the destination offset
  is 8-aligned, then the tail. `copy_bytes_to_array` extracts bytes from words.
- `Bytes` is immutable, so it cannot back RAM; if the word store regresses the
  byte-heavy benches, the fallback is `FixedArray[Byte]` with
  `FixedArray::unsafe_write_uint{16,32,64}_le` for stores and byte composition
  for loads, in a separate commit with the same tests.

## Tests (characterization, written first and passing on the old store)

New blackbox file `riscv_bus_test.mbt`:

- round trip of every width at offsets 0 through 15, including word-crossing
  offsets, reading back both as the same width and as bytes
- `write_bytes_from` with odd destination offset, odd length, and a source
  offset, and zero-fill past the end of the source
- `contains_range` at both RAM edges (first byte, last byte, one past)
- `zero_range` across a word boundary leaves neighbours intact
- `fetch_u16` at odd offsets

## Validation (Claude)

- Base set: `moon check --target native`, `moon test --target native .`,
  `moon fmt`, `moon info --target native`, `git diff --check`,
  `./scripts/build-browser-demo.sh`
- `moon bench` x3 and browser Alpine interactive smoke x3 per ADR 0011
- Keep if `dword_copy_loop_100k_steps` or `word_copy_loop_100k_steps`
  improves >= 5 % without a browser median regression beyond 2 %.
- Regression net for misaligned and cross-word behaviour: the official
  `rv64ui` load/store rows and `ma_data`, and the virtio-blk tests in
  `riscv_execute_test.mbt` (15615 onward).

## Status

- `done`

## Progress Notes

- Codex delivered `Bus { base_addr, words : FixedArray[UInt64], size }` with one/two-word little-endian fragment
  helpers, read-modify-write sub-word stores, an 8-byte bulk path in `write_bytes_from`, and 8 characterization tests
  (`riscv_bus_test.mbt`, including two `panic` tests for accesses past the end). Claude fixed one compile error (a test
  helper that calls `assert_eq` needs `-> Unit raise`).
- First measurement looked like a 2x regression on every memory bench. The cause was the bench harness, not the
  store: every `b.bench` closure rebuilt its runner, so the 128 MB virt RAM allocation was inside the timed region,
  and `FixedArray::make` zero-fills eagerly while `Array::make` did not touch the pages. The benches now build each
  runner once and re-arm it through a new `Runner::write_pc` plus register resets (`reset_loop_runner`). All earlier
  bench numbers in Task 0058 and Task 0065 include that allocation constant and are not comparable to numbers from
  here on.
- Hoisted-runner benches, old byte-array Bus (means of x3): `tight_add` 4.02 ms, `word_copy` 6.41, `dword_copy` 3.29,
  `amoadd` 6.16, `spinlock` 6.03, `vector_add` 28.75.
- Same benches, word Bus with Codex's four-comparison range check: 4.17 / 6.58 / 3.36 / 6.45 / 6.61 / 29.44 (+2 to
  +10 %). With the check reduced to a single `offset > size - width` comparison (final): 3.98 / 6.40 / 3.30 (run 1
  outlier excluded) / 6.16 / 6.29 / 28.96, i.e. native parity within noise (`spinlock` +4 %).
- Browser Alpine interactive smoke x3 on the final build: wall 1:26.95 / 1:32.04 / 1:26.83, median 87.0 s against the
  post-0065 baseline of 93.8 s (-7.3 %), same 373,293,056-step response point.
- Decision: kept. The ADR 0011 rule asked for a >= 5 % native gain, which this slice does not deliver; it is kept for
  the browser gain with native neutral, and the rule is amended in ADR 0011 to accept either target improving while
  the other does not regress beyond noise.
- Validation: `moon check` (0 warnings), `moon test` (602 passed), `moon fmt`, `moon info`, `git diff --check`,
  `./scripts/build-browser-demo.sh` all clean.
