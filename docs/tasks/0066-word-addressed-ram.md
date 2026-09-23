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

- `doing`
