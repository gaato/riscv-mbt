# Task 0063: RV64GC Spec Compliance

## Background

The active goal is now to implement `RV64GC` correctly against the RISC-V
specifications. In explicit extension terms, this means
`RV64IMAFDC_Zicsr_Zifencei`. Linux and Alpine remain useful integration
pressure, but they are not a substitute for the architectural contract.

Recent Linux-driven work exposed that practical userspace can pass boot and
still hit holes in ordinary scalar `F/D` behavior. The current pass therefore
prioritizes closing the baseline ISA before returning to optional `V` backlog
or more OpenRC-specific probing.

## Scope

- Treat `RV64IMAFDC_Zicsr_Zifencei` as the baseline ISA target.
- Re-check the RISC-V unprivileged and privileged specs when instruction
  encodings, rounding, exception flags, CSR behavior, trap flow, or memory
  ordering rules are subtle.
- Prefer decode and execute regressions for CPU behavior.
- Keep Linux probes as integration evidence, not as the main work product.
- Add documentation-quality comments across MoonBit code as files are touched
  and during long waits.
- When roughly 3000 source lines have been added since the previous
  refactoring/tuning pass, pause feature work for a refactoring and tuning pass
  before continuing instruction or platform expansion.

## Work

- Audit current `RV64IMAFDC_Zicsr_Zifencei` instruction coverage.
- Close missing instruction families in coherent groups rather than one
  illegal instruction at a time.
- Tighten `F/D` behavior beyond the current practical host-IEEE boundary:
  fused single-rounding, `fflags`, signaling-NaN behavior, invalid/overflow
  conversion results, and reserved rounding-mode handling.
- Audit `A`, `C`, `Zicsr`, and `Zifencei` for spec gaps that are masked by
  current Linux probes.
- Promote relevant official `rv64*` riscv-tests from survey to gating when the
  emulator behavior is ready.
- Keep comments close to architectural boundaries: decode shape, execute
  semantics, CSR side effects, trap routing, translation, device interrupts,
  and test support.

## Acceptance Criteria

- `docs/current.md` identifies this task as the active next task.
- The repo has a current, explicit `RV64GC` gap list tied to code or tests.
- Missing `RV64IMAFDC_Zicsr_Zifencei` instruction families are implemented
  with decode and execute tests.
- Known deviations from strict spec behavior are documented in task notes until
  fixed.
- The normal MoonBit validation sequence passes:
  `moon check --target native`, `moon test --target native .`, `moon fmt`,
  `moon info --target native`, and `git diff --check`.

## Status

- `doing`

## Current RV64GC Gap List

This list tracks the known distance from "runs useful Linux" to strict
`RV64IMAFDC_Zicsr_Zifencei` confidence. It should shrink as implementation and
official coverage improve.

- `RV64I/M/C`: curated official `rv64ui`, `rv64um`, `rv64ua`, and `rv64uc`
  rows in
  `tools/riscv-tests-manifest.tsv` are gating through
  `rv32ui_gating_test.mbt`. The gap is broader official-suite coverage and any
  remaining unlisted corner cases, not a known missing Linux-critical
  instruction family.
- `F/D`: `riscv_fp.mbt` now covers instruction availability, NaN-boxing,
  comparisons, min/max, FMA availability, conversion clipping, and the first
  NV/DZ arithmetic flags. The corrected official-test harness now advertises
  manifest arch FP bits, and the passing `rv64uf`/`rv64ud` classification,
  compare, conversion, min/max, load/store, move, recoding, and structural rows
  are gated. The `rv64uf` arithmetic rows are also gated after adding
  single-precision NX accrual. The remaining strict-spec gaps are exact
  double-precision arithmetic result/flag behavior for `rv64ud`
  `fadd`/`fdiv`/`fmadd`.
- `A`: `riscv_decode.mbt` rejects reserved AMO operations and reserved
  `LR.W`/`LR.D` encodings with nonzero `rs2`, gates AMO execution on `MISA.A`,
  and accepts `aq`/`rl` encodings for the current single-hart interpreter.
  `riscv_execute.mbt` implements LR/SC and AMO W/D behavior for the practical
  one-hart path, with regressions for reservation success/failure, store
  invalidation, and RV64 AMO.W sign-extension. The upstream `rv64ua` AMO/LRSC
  cases are now part of the gating manifest. The remaining audit is true
  `aq`/`rl` memory-ordering semantics and multi-hart reservation interference.
- `C`: compressed decode/execute coverage exists in
  `riscv_compressed_test.mbt`, and the upstream `rv64uc-p-rvc` binary is now
  part of the gating manifest. The remaining audit is RV64C-specific
  reserved/hint behavior beyond the official aggregate compressed test.
- `Zicsr`: CSR decode, privilege checks, `fcsr`/`fflags` views, and explicit
  read/write suppression for the standard CSR instruction forms are covered by
  focused execute tests. The remaining audit is a spec pass over WARL behavior,
  read-only/write-ignored fields, and privilege-visible side effects for every
  CSR currently exposed by `riscv_decode.mbt`.
- `Zifencei`: `FENCE.I` decodes, flushes the emulator decode cache, official
  `fence_i` rows are in the gating subset, and
  `riscv_execute_test.mbt` now covers same-hart self-modified instruction
  visibility after an old instruction at the same address was fetched once. The
  remaining audit is broader official coverage and any future instruction-cache
  model beyond the current fetch/decode-cache shape.

## Progress Notes

- `FCLASS.S` and `FCLASS.D` now decode and execute the architectural 10-bit
  classification mask for zero, subnormal, normal, infinity, signaling NaN,
  quiet NaN, and the D-present single-precision NaN-boxing path.
- `FMADD.S/D`, `FMSUB.S/D`, `FNMSUB.S/D`, and `FNMADD.S/D` now decode and
  execute under the current host-IEEE RNE-only arithmetic boundary. This closes
  the missing FMA instruction family at the instruction-availability level.
  Exact IEEE fused single-rounding and full `fflags` behavior remain open
  spec-compliance work.
- Scalar `F/D` comparisons and min/max now accrue the invalid-operation flag
  for the NaN cases required by the F specification: `FLT`/`FLE` set NV for any
  NaN input, `FEQ` sets NV only for signaling NaNs, and `FMIN`/`FMAX` set NV for
  signaling NaNs while preserving their existing result-selection behavior.
  This starts replacing the old "no FP instruction updates fflags" limitation
  with instruction-family-specific flag handling.
- Fused multiply-add now also accrues NV for the required infinity-times-zero
  multiplicand case, including the spec-called-out path where the addend is a
  quiet NaN. The arithmetic result still follows the current host-IEEE boundary
  and exact fused single-rounding remains open.
- The existing official `rv64ui`, `rv64um`, `rv64ua`, and `rv64uc` manifest
  rows have been promoted from `survey` to `gating`, alongside the older RV32
  gating rows. This makes the already-integrated upstream `riscv-tests` path
  part of the always-green regression floor for the RV64I/M/A/C portion of
  RV64GC.
- `FCVT.W.S`, `FCVT.WU.S`, `FCVT.W.D`, and `FCVT.WU.D` now use a shared
  spec-shaped result helper for NaN/out-of-range clipping and accrued flags.
  The helper sets NV for invalid conversions, sets NX when the rounded valid
  result differs from the source value, and preserves the RV64 rule that
  32-bit conversion results are sign-extended to XLEN.
- `FCVT.L.S`, `FCVT.LU.S`, `FCVT.L.D`, and `FCVT.LU.D` now use the same
  spec-shaped conversion policy for RV64-width results. The helper clips
  invalid signed results to `INT64_MIN`/`INT64_MAX`, invalid unsigned results to
  zero/`UINT64_MAX`, sets NV for invalid conversions, and sets NX for valid
  inexact conversions.
- Scalar `F/D` arithmetic now accrues the first spec-shaped exception flags:
  `FADD`/`FSUB` set NV for opposite-signed infinity addition, `FMUL` and FMA set
  NV for infinity-times-zero, `FDIV` sets NV for zero-over-zero and
  infinity-over-infinity, `FSQRT` sets NV for negative nonzero operands, all
  covered arithmetic paths set NV for signaling NaN inputs, and `FDIV` sets DZ
  for finite nonzero division by zero. Exact non-RNE arithmetic, OF/UF/NX for
  rounded arithmetic results, and exact fused single-rounding remain open.
- `Zifencei` now has an execute regression for the key same-hart contract:
  fetch and decode an instruction, store a different instruction to the same
  address, execute `FENCE.I`, jump back, and require the replacement instruction
  to execute. The test also asserts that the emulator-side decode cache was
  flushed by `FENCE.I`.
- `Zicsr` execution now models the architectural read/write suppression table
  directly: `CSRRW[I]` with `rd=x0` skips the CSR read path, while
  `CSRRS/CSRRC[I]` with a zero register or immediate mask skips the CSR write
  path. Regression coverage keeps zero-mask set/clear legal for read-only CSRs
  and keeps actual write forms illegal for read-only CSRs.
- `A` decode now treats reserved AMO `funct5` values and the reserved
  nonzero-`rs2` LR encoding as illegal, while still accepting the `aq`/`rl`
  ordering bits. AMO W/D execution is also profile-gated on `MISA.A`, and the
  AMO.W regressions now pin the RV64 rule that the loaded word placed in `rd`
  is sign-extended.
- All 19 current upstream `rv64ua-p-*` binaries (`amo{add,and,max,maxu,min,
  minu,or,swap,xor}_{w,d}` plus `lrsc`) pass through `cmd/official_survey` and
  have been promoted to `gating` rows in `tools/riscv-tests-manifest.tsv`.
- The upstream `rv64uc-p-rvc` binary passes through `cmd/official_survey` and
  has been promoted to the `gating` manifest as the first official RV64C floor.
- Official riscv-tests profile selection now derives `misa` extension bits from
  the manifest arch string instead of only selecting XLEN. With `rv64imafdc`
  advertised, 20 of 23 current upstream `rv64uf`/`rv64ud` binaries pass and are
  promoted to `gating`; the remaining failures are `rv64ud` `fadd`, `fdiv`,
  and `fmadd`.
- `FSGNJ.S`, `FSGNJN.S`, and `FSGNJX.S` now use arithmetic single-precision
  operand reads instead of FMV-style transfer reads. This makes D-present
  malformed single NaN boxes become canonical NaNs before sign injection, while
  still writing a boxed single result. The focused execute regression and the
  official `rv64ud-p-move` binary both cover this path, so `rv64ud/move` is now
  part of the gating manifest.
- Single-precision arithmetic now accrues NX when the rounded `Float` result
  differs from the same operation evaluated in `Double` from exactly
  represented single operands. This covers ordinary RNE inexact behavior for
  `FADD.S`, `FSUB.S`, `FMUL.S`, `FDIV.S`, `FSQRT.S`, and the current FMA
  execution paths, and promotes official `rv64uf/fadd`, `rv64uf/fdiv`, and
  `rv64uf/fmadd` to gating. Double-precision NX still needs a separate
  bit-exact strategy rather than host-Double self-comparison.
