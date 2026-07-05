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
  instruction family. Post-decode profile legality now also rejects M-extension
  multiply/divide/remainder instructions when `MISA.M` is not advertised.
  Focused RV64I regressions now also cover byte and halfword load/store paths
  sign-extending or zero-extending to XLEN, matching the official `lb/lbu/lh/lhu`
  source rows beyond the narrower curated gating subset.
  Taken branch and jump target alignment now follows the active IALIGN:
  non-C profiles trap halfword-only targets as instruction-address-misaligned,
  while C/RV64GC profiles allow them under IALIGN=16.
- `F/D`: `riscv_fp.mbt` now covers instruction availability, NaN-boxing,
  comparisons, min/max, FMA availability, conversion clipping, integer-to-float
  rounding modes, and the first NV/DZ arithmetic flags. The conversion
  regressions now include exact RNE invalid boundaries for `FCVT.L.D` at
  `+2^63`, `FCVT.LU.D` at `+2^64`, and RNE NaN/infinity clipping before any
  host integer cast. Invalid scalar arithmetic coverage now checks both NV and
  canonical-NaN results for representative add, multiply, and divide cases.
  Exact widening `FCVT.D.S` and exact
  RV32-width-to-double `FCVT.D.W[U]` now treat the otherwise unaffected `rm`
  field as architecturally significant for legal/reserved static and dynamic
  encodings. `mstatus.FS` is now part of the execution contract: FP-capable
  reset profiles start with FS enabled, but scalar F/D load/store and arithmetic
  instructions trap as illegal when software sets FS=Off. FP register and
  `fcsr` writes also mark FS Dirty, making the visible `SD` summary track
  modeled FP state changes. The `fflags`, `frm`, and `fcsr` CSR aliases are
  now governed by the same FS state, so both read and write attempts trap when
  FS=Off. Writes to absent `fcsr` bits 31:8 are covered as
  ignored-on-write/read-as-zero. The corrected official-test harness now
  advertises manifest arch FP bits, and the passing `rv64uf`/`rv64ud`
  classification, compare, conversion, min/max, load/store, move, recoding,
  and structural rows are gated. The
  `rv64uf` arithmetic rows are also gated after adding single-precision NX
  accrual, and the `rv64ud` arithmetic rows are gated after adding
  exact-rational double-precision NX checks. Machine profiles now canonicalize
  the architectural dependency that `D` implies `F`, so white-box configs cannot
  expose or execute an impossible `misa.D`-without-`misa.F` profile. The
  remaining strict-spec gaps are broader than the current official rows:
  deeper fused-rounding audits and exception-flag corner cases beyond the
  current `riscv-tests` surface.
- `A`: `riscv_decode.mbt` rejects reserved AMO operations and reserved
  `LR.W`/`LR.D` encodings with nonzero `rs2`, gates AMO execution on `MISA.A`,
  and accepts `aq`/`rl` encodings for the current single-hart interpreter.
  `riscv_execute.mbt` implements LR/SC and AMO W/D behavior with shared
  per-hart physical byte-range reservations, with regressions for
  reservation success/failure, same-hart store invalidation, cross-hart store
  invalidation, overlapping LR.D reservation invalidation, device writes to
  bytes accessed by LR, and RV64 AMO.W sign-extension. Virtio-blk
  guest-visible DMA/status/used-ring writes now use reservation-aware device
  store helpers. The upstream `rv64ua` AMO/LRSC cases are now part of the
  gating manifest. The remaining audit is true `aq`/`rl` memory-ordering
  semantics and broader forward-progress/eventual-success behavior beyond the
  current interpreter scheduling model.
- `C`: compressed decode/execute coverage exists in
  `riscv_compressed_test.mbt`, and the upstream `rv64uc-p-rvc` binary is now
  part of the gating manifest. The RV64C reserved/hint audit now covers
  `C.EBREAK`, `C.ADDIW rd=x0`, `C.LUI rd=x0`, `C.SLLI rd=x0`, 6-bit RV64
  `C.SLLI` shift amounts, `C.FLDSP f0`, and the RV32C custom-extension
  `shamt[5]=1` space for `C.SLLI`, `C.SRLI`, and `C.SRAI`, including the
  `C.SLLI rd=x0` hint-looking form. `C.ADD rd=x0, rs2!=x0` forms now execute as
  ignored hints, including the `rs2=x2..x5` compressed Zihintntl non-temporal
  locality hint subrange. CR-format coverage now also pins `C.MV rd=x0,
  rs2!=x0` as an ignored hint, `C.JR rs1=x0` as reserved, and the
  `C.JALR rs1=x0` encoding as `C.EBREAK`. Post-decode profile legality now
  rejects all 16-bit compressed encodings when `MISA.C` is not advertised,
  preserving the permissive decoder while making execution obey the active ISA
  profile.
  The remaining audit is broader reserved/hint behavior beyond those focused
  cases and the official aggregate compressed test.
- `Zicsr`: CSR decode, read-side and write-side privilege checks,
  `fcsr`/`fflags` views, and explicit read/write suppression for the standard
  CSR instruction forms are covered by focused execute tests. The write-side
  coverage includes suppressed-read `CSRRW rd=x0` forms, so lower privilege
  modes cannot write higher-privilege CSRs by avoiding the read. `mtvec` and
  `stvec` writes now normalize to the modeled WARL surface: 4-byte-aligned BASE
  plus Direct or Vectored MODE only, with vectored supervisor-timer dispatch
  covered by a focused regression. `mepc` and `sepc` now clear bit 0 on visible
  writes and trap returns, preserving the RV64GC/IALIGN=16 ability to hold bit 1.
  RV64 `mstatus.SXL`/`mstatus.UXL` and `sstatus.UXL` now expose the fixed
  SXLEN=UXLEN=64 profile and normalize writes back to that value.
  The endian-control fields now match the emulator's little-endian-only memory
  system: `mstatus.MBE`, `mstatus.SBE`, and `mstatus.UBE`, plus `sstatus.UBE`,
  are visible where architecturally exposed but normalize to read-only zero.
  `sip` and `sie` now expose only supervisor interrupt bits delegated by
  `mideleg`; `sie` writes update only those delegated enable bits, and `sip`
  writes update only delegated SSIP while STIP/SEIP remain pending bits supplied
  by the machine/platform path.
  `medeleg` and `mideleg` now apply WARL masks on read, write, and internal
  trap-routing paths. `medeleg` exposes the modeled delegatable exception
  causes (`0xb3ae`), while `mideleg` exposes only SSI/STI/SEI (`0x222`).
  `mcounteren` and `scounteren` now expose only the implemented base counter
  enables CY/TM/IR (`0x7`); HPM counter enables are read-only zero because the
  corresponding counter CSRs are absent.
  `mcountinhibit` now controls the exposed architectural counters: CY inhibits
  `cycle`, IR inhibits `instret`, HPM inhibit bits are read-only zero because
  no HPM counters are modeled, and `time` continues to reflect CLINT `mtime`
  because the privileged spec excludes `mtime` from mcountinhibit. The
  unprivileged `cycle` and `instret` CSRs now shadow writable machine `mcycle`
  and `minstret` state instead of aliasing CLINT `mtime`.
  `mie` now exposes only the modeled standard interrupt-enable bits
  MSI/MTI/MEI and SSI/STI/SEI (`0xaaa`), while `mip` readback is masked to the
  same implemented pending-bit surface. Writes to `mip` affect only the
  software-writable S-level pending bits; machine-level pending bits are
  supplied by CLINT/PLIC state.
  `mstatus` now clears unsupported status storage before applying the modeled
  WARL rules. User-interrupt, VS, XS, and other WPRI/reserved bits read back as
  zero, while the implemented interrupt, return, privilege, FP-status,
  memory-access, trap-control, fixed-XLEN, and derived-SD fields remain visible.
  `menvcfg` and `senvcfg` now expose no optional environment-feature bits in
  this RV64GC baseline. FIOM, Svpbmt, Svadu, Sstc, cache-block controls,
  pointer masking, landing-pad, shadow-stack, and double-trap controls read
  back as zero because those extensions are not implemented.
  `pmpcfg0` and `pmpaddr0` now read as zero because PMP access enforcement is
  not implemented. The OpenSBI smoke still boots and reports `PMP Count: 0`,
  avoiding the old mismatch where firmware could configure protection rules the
  emulator would silently ignore.
  `mnstatus` is no longer exposed as compatibility storage. It belongs to the
  optional Smrnmi resumable-NMI extension, which is not implemented in the
  RV64GC baseline, so read and write attempts now trap as illegal instruction.
  `mconfigptr` is now exposed as the mandatory read-only machine information
  CSR and returns zero, indicating that this platform has no standard
  configuration data structure and relies on the existing device-tree path.
  The read-only machine-information CSR trap coverage now samples the whole
  exposed baseline set: `misa`, `mvendorid`, `marchid`, `mimpid`, `mhartid`,
  `mconfigptr`, and the read-only `time` counter.
  `satp` writes with unsupported MODE values now preserve the previous CSR
  value, matching the privileged WARL rule that the whole write has no effect.
  `mstatus.MPP` now rejects the reserved privilege encoding 2 at the CSR write
  boundary. The remaining audit is a spec pass over remaining WARL behavior,
  read-only/write-ignored fields, and privilege-visible side effects for every
  CSR currently exposed by `riscv_decode.mbt`.
- `Zifencei`: `FENCE.I` decodes, flushes the emulator decode cache, official
  `fence_i` rows are in the gating subset, and
  `riscv_execute_test.mbt` now covers same-hart self-modified instruction
  visibility after an old instruction at the same address was fetched once. The
  remaining audit is broader official coverage and any future instruction-cache
  model beyond the current fetch/decode-cache shape.

## Progress Notes

- Control-flow execution now checks taken branch, `JAL`, and `JALR` targets
  against the active profile's IALIGN. Non-C profiles raise
  instruction-address-misaligned on 2-byte-only targets and report the branch or
  jump as the faulting PC; RV64GC with C keeps those targets legal.
- Sv39 permission checks now keep SUM limited to supervisor data accesses:
  S-mode loads/stores to U pages can proceed when SUM is set, but S-mode
  instruction fetches from U pages raise instruction page faults regardless of
  SUM.
- `FCLASS.S` and `FCLASS.D` now decode and execute the architectural 10-bit
  classification mask for zero, subnormal, normal, infinity, signaling NaN,
  quiet NaN, and the D-present single-precision NaN-boxing path.
- `FMADD.S/D`, `FMSUB.S/D`, `FNMSUB.S/D`, and `FNMADD.S/D` now decode and
  execute with exact-rational finite fused results and explicit exact-zero sign
  handling. Full `fflags` and NaN behavior remain open spec-compliance work.
- Scalar `F/D` comparisons and min/max now accrue the invalid-operation flag
  for the NaN cases required by the F specification: `FLT`/`FLE` set NV for any
  NaN input, `FEQ` sets NV only for signaling NaNs, and `FMIN`/`FMAX` set NV for
  signaling NaNs while preserving their existing result-selection behavior.
  This starts replacing the old "no FP instruction updates fflags" limitation
  with instruction-family-specific flag handling.
- Fused multiply-add now also accrues NV for the required infinity-times-zero
  multiplicand case, including the spec-called-out path where the addend is a
  quiet NaN. Finite fused results now avoid the old host-IEEE arithmetic
  boundary; deeper NaN and exception-flag audits remain open.
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
- `FCVT.S.W`, `FCVT.S.WU`, `FCVT.S.L`, `FCVT.S.LU`, `FCVT.D.L`, and
  `FCVT.D.LU` now construct IEEE result bits through a shared integer-magnitude
  rounding helper instead of relying on host-default conversion. The helper
  supports RNE, RTZ, RDN, RUP, RMM, valid dynamic `frm`, and NX accrual when
  discarded integer bits make the conversion inexact.
- `FCVT.S.D` now rounds double-precision source bits to single precision inside
  the emulator instead of relying on host-default conversion. The helper handles
  legal static/dynamic rounding modes, canonical NaN results, NX for inexact
  narrowing, OF/NX result selection for overflow, and UF only when the rounded
  result remains tiny after rounding.
- Scalar `F/D` arithmetic now accrues the first spec-shaped exception flags:
  `FADD`/`FSUB` set NV for opposite-signed infinity addition, `FMUL` and FMA set
  NV for infinity-times-zero, `FDIV` sets NV for zero-over-zero and
  infinity-over-infinity, `FSQRT` sets NV for negative nonzero numeric
  operands, all covered arithmetic paths set NV for signaling NaN inputs, and
  `FDIV` sets DZ for finite nonzero division by zero. Quiet NaN `FSQRT.S/D`
  inputs now produce canonical NaNs without accruing NV. Deeper NaN payload
  behavior, broader flag corner cases, and full official-suite promotion remain
  open.
- `FADD.S`, `FSUB.S`, and `FMUL.S` now round their exact single-precision
  operand results through the emulator-side double-to-single helper. Legal
  static non-RNE modes are accepted where they change the result, reserved
  rounding modes still trap, and inexact results accrue NX.
- `FDIV.S` and `FSQRT.S` now also accept legal static non-RNE modes and use the
  same double-to-single result helper, retiring the previous RNE-only trap
  boundary for the scalar single-precision arithmetic family. Exact quotient
  and square-root rounding audits remain part of the broader strict FP work.
- The single-precision fused multiply-add family now accepts legal static
  non-RNE modes and rounds finite nonzero fused results through an exact
  rational-to-single helper. This closes the old RNE-only legality boundary for
  `FMADD.S`, `FMSUB.S`, `FNMSUB.S`, and `FNMADD.S` without introducing a
  rounded host-Double product-plus-addend. Exact-zero result signs are now
  handled explicitly for cancellation and zero-product inputs.
- `FADD.D`, `FSUB.D`, and `FMUL.D` now round finite exact-rational results back
  to double precision inside the emulator. Legal static non-RNE modes execute
  where they change the result, and the helper accrues NX plus overflow and
  tininess-after-rounding underflow flags for rounded finite results. Exact
  zero signs are handled explicitly for add/sub cancellation and multiplication
  by zero.
- `FDIV.D` now uses the same exact-rational-to-double rounding path for finite
  nonzero divisors. Legal static non-RNE quotients execute where they change the
  result, NX/OF/UF come from the shared helper, and exact zero quotient signs are
  handled explicitly.
- The double-precision fused multiply-add family now accepts legal static
  non-RNE modes and routes finite nonzero exact fused results through the
  exact-rational-to-double helper. This covers `FMADD.D`, `FMSUB.D`,
  `FNMSUB.D`, and `FNMADD.D` without using an intermediate rounded product;
  exact-zero result signs remain a separate follow-up audit.
- `FSQRT.D` now accepts legal static/dynamic non-RNE modes. For finite positive
  operands it uses the host square root only as an RNE candidate, compares the
  candidate square against the exact operand, and selects the adjacent lower or
  upper double for directed rounding while accruing NX for inexact roots.
- `mstatus.FS` is now enforced for scalar F/D execution. The emulator keeps
  FP-capable reset and official-test profiles in an enabled FS state, while a
  focused regression clears FS and requires both FP load/store and FP arithmetic
  to raise illegal-instruction traps before touching FP state.
- FP state writes now dirty `mstatus.FS`. The shared FP register and `fcsr`
  write helpers perform the transition, and a regression confirms an FP load
  moves the visible status from FS=Initial to FS=Dirty with `SD` set.
- Floating-point CSR access is now FS-gated. Focused regressions cover both
  read forms and write-only `CSRRW rd=x0` forms for `fflags`, `frm`, and
  `fcsr`, preserving Zicsr read suppression while still trapping writes to
  FS-governed state when FS=Off.
- `fcsr` reserved high bits now have focused regression coverage. A CSR write
  of all ones leaves only visible bits 7:0 readable, matching the F extension
  rule for absent standard-extension fields in bits 31:8.
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
  advertised, all 23 current upstream `rv64uf`/`rv64ud` binaries pass and are
  promoted to `gating`.
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
  `rv64uf/fmadd` to gating.
- Double-precision arithmetic now accrues NX by representing finite operands
  and rounded results as exact `BigInt` rationals and comparing the exact
  add/sub/mul/div/sqrt/FMA rational against the rounded result bits. This
  promotes official `rv64ud/fadd`, `rv64ud/fdiv`, and `rv64ud/fmadd` to gating.
- Exact widening `FCVT.D.S` now validates the `rm` field even though the numeric
  conversion never rounds. Legal non-RNE static encodings continue to execute,
  while reserved static `rm=101/110` and dynamic `rm=111` with reserved `frm`
  trap as illegal instructions. This follows the F/D spec rule that unaffected
  rounding-mode fields still participate in legal-vs-reserved encoding checks.
  `FCVT.D.S` also accrues NV for signaling single-precision NaNs before writing
  the canonical double-precision NaN result.
- `FCVT.D.W` and `FCVT.D.WU` now use the same legal-vs-reserved `rm` check
  instead of the current RNE-only rounded-arithmetic support gate. Signed and
  unsigned 32-bit integer inputs are exactly representable in double precision,
  so legal non-RNE encodings execute while reserved static or dynamic rounding
  modes still trap.
- Integer-to-float conversions now support legal non-RNE rounding where the mode
  changes the result: focused regressions cover single-precision rounding at
  `2^24+1`, double-precision rounding at `2^53+1`, dynamic `frm=RMM`, and NX
  accrual for inexact integer inputs.
- Double-to-single narrowing now supports legal non-RNE rounding where the mode
  changes the result. Focused regressions cover `FCVT.S.D` at the single
  precision boundary, dynamic `frm=RMM`, overflow result selection for RNE vs
  RTZ, OF/NX accrual, tininess-after-rounding at the minimum normal boundary,
  and reserved rounding-mode traps.
- Single-precision add/sub/mul now support legal non-RNE arithmetic rounding.
  Focused regressions cover positive inexact `FADD.S`, `FSUB.S`, and `FMUL.S`
  cases where RTZ and RUP select adjacent single-precision results, plus
  reserved arithmetic rounding-mode traps.
- Single-precision div/sqrt now have the same first non-RNE coverage. Focused
  regressions cover `FDIV.S` `1.0 / 3.0` and `FSQRT.S` `sqrt(2.0)` cases where
  directed rounding selects adjacent single-precision results and accrues NX.
- Single-precision FMA now has matching non-RNE coverage for finite nonzero
  exact results. Focused regressions cover all four FMA opcodes at `2^24 + 1`,
  where RTZ and RUP select adjacent single-precision results and accrue NX.
  A separate regression pins exact-zero signs for finite cancellation and
  negative-zero product/addend inputs.
- Double-precision add/sub/mul now have corresponding non-RNE coverage.
  Focused regressions cover `2^53 + 1` add/sub and `(1 + 2^-52)^2` multiply,
  where RTZ and RUP select adjacent double-precision results and accrue NX.
  A separate regression pins exact-zero signs for `FADD.D`, `FSUB.D`, and
  `FMUL.D`, including the round-down cancellation case.
- Double-precision division now has matching non-RNE coverage. Focused
  regressions cover `1.0 / 3.0`, where RTZ and RUP select adjacent
  double-precision quotients and accrue NX, plus exact zero quotient signs.
- Double-precision FMA now has matching non-RNE coverage for finite nonzero
  exact results. Focused regressions cover all four FMA opcodes at `2^53 + 1`,
  where RTZ and RUP select adjacent double-precision results and accrue NX.
  A separate regression pins exact-zero signs for finite cancellation and
  negative-zero product/addend inputs.
- Double-precision sqrt now has matching non-RNE coverage. A focused regression
  covers `FSQRT.D sqrt(2.0)`, where RTZ and RUP select adjacent
  double-precision results and accrue NX.
- The first RV64C reserved/hint correction slice is in place. `EBREAK` and
  `C.EBREAK` now trap as architectural breakpoint exceptions instead of illegal
  instructions, RV64C rejects reserved `C.ADDIW rd=x0`, `C.LUI rd=x0` and
  `C.SLLI rd=x0` execute as ignored hints, `C.SLLI` uses the unsigned 6-bit
  RV64 shift amount, and `C.FLDSP` can target valid floating-point register
  `f0`. Focused decode/execute regressions cover each case.
- RV32C compressed shift decode now rejects the standard-reserved/custom
  `shamt[5]=1` code points for `C.SLLI`, `C.SRLI`, and `C.SRAI`, while
  preserving the existing RV64C 6-bit shift behavior.
- Compressed `C.ADD` now distinguishes the standard hint space from the custom
  subrange: `rd=x0, rs2=x2..x5` traps as an unimplemented custom code point,
  while neighboring `rd=x0` add hints continue to execute as no-ops.
- Zicsr write-side privilege checks now run even when the instruction form
  suppresses the CSR read. This closes the `CSRRW rd=x0` hole where a lower
  privilege mode could otherwise write a higher-privilege CSR because no read
  was attempted first.
- Trap-vector CSR writes now normalize `mtvec` and `stvec` at the visible CSR
  boundary. The modeled WARL surface preserves the aligned BASE, stores MODE=1
  for Vectored, maps Direct and reserved MODE values to MODE=0, and keeps
  vectored interrupt dispatch covered with a delegated supervisor-timer
  regression.
- EPC CSR writes now normalize `mepc[0]` and `sepc[0]` to zero, and `MRET`/`SRET`
  also mask bit 0 when consuming internally prepared EPC values. Focused
  regressions cover visible CSR writes plus return paths while leaving bit 1
  representable for the compressed-instruction baseline.
- `mstatus.MPP` now treats reserved privilege encoding 2 as a WARL value and
  normalizes it to U-mode on visible `mstatus`/`sstatus` writes. A focused CSR
  regression covers readback of the normalized field.
- RV64 `mstatus.SXL`/`mstatus.UXL` and `sstatus.UXL` now behave as fixed
  lower-mode XLEN fields for this emulator profile. Focused regressions cover
  reset visibility and write normalization through both `mstatus` and
  `sstatus`, while RV32 status behavior remains unchanged.
- `mstatus.MBE`/`SBE`/`UBE` and `sstatus.UBE` now behave as read-only-zero WARL
  fields for the current little-endian-only profile. A focused CSR regression
  covers writes through both `mstatus` and `sstatus`.
- `sip`/`sie` are now delegated views of `mip`/`mie` instead of unconditional
  aliases for SSI/STI/SEI. Focused regressions cover non-delegated readback,
  delegated `sie` writes, and `sip` writes that affect only SSIP.
- `medeleg`/`mideleg` no longer store arbitrary compatibility bits. Focused
  coverage writes all ones and verifies the supported delegatable exception and
  interrupt bit surfaces are the only values that read back or affect routing.
- `mcounteren`/`scounteren` are now WARL-filtered to CY/TM/IR. The existing
  privilege-gate tests still cover access behavior, and a new readback
  regression pins HPM enable bits as read-only zero.
- `mcountinhibit` is now modeled for the base architectural counters. Focused
  coverage writes all ones, verifies only CY/IR read back, proves inhibited
  `cycle` and `instret` stay stable, proves `time` still advances, and verifies
  writable `mcycle`/`minstret` back the unprivileged counter shadows.
- `mip`/`mie` no longer retain arbitrary interrupt bits. Focused regressions
  cover write-all-ones `mie` readback, `mip` writes limited to S-level pending
  bits, and the existing delegated `sie`/`sip` view behavior after masking.
- `MRET` and `SRET` now apply the privileged-spec `MPRV` return rule: when the
  return target is below M-mode, `mstatus.MPRV` is cleared so later data
  accesses cannot continue using the old MPP override. Focused regressions cover
  MRET-to-U, SRET-to-S, and the MRET-to-M preservation case.
- Return-instruction privilege checks now match the modeled privileged surface:
  `MRET` raises illegal instruction outside M-mode, `SRET` raises illegal
  instruction from U-mode, and S-mode `SRET` raises illegal instruction when
  `mstatus.TSR` is set. Focused regressions cover all three cases.
- `SFENCE.VMA` now enforces the privileged legality checks before flushing the
  emulator translation cache: U-mode raises illegal instruction, and S-mode
  raises illegal instruction when `mstatus.TVM` is set. M-mode execution keeps
  the existing translation-cache flush behavior.
- `satp` now shares that `TVM` interception rule at the CSR access layer:
  S-mode reads and writes raise illegal instruction when `mstatus.TVM` is set,
  including write forms that suppress the old-value read. Focused regressions
  cover both read and write attempts.
- Unsupported `satp.MODE` writes are now ignored as a whole write. The focused
  RV64 regression seeds a valid Sv39 `satp`, attempts to write unsupported
  Sv48 MODE on the current Sv39-only implementation, and verifies the old value
  is still visible.
- `WFI` now enforces the modeled privilege/TW legality rule before applying the
  interpreter's CLINT timer fast-forward hint: U-mode raises illegal
  instruction, and S-mode raises illegal instruction when `mstatus.TW` is set.
  Legal WFI keeps the existing timer fast-forward behavior.
- `sstatus` now exposes and writes the shared `mstatus.FS` field. This keeps
  the RV64GC F/D context-status control path visible through the supervisor
  status CSR instead of only through machine `mstatus`.
- `mstatus.SD` / `sstatus.SD` now behave as visible summary bits for the
  modeled extension status rather than writable storage: direct SD writes are
  ignored, and FS=Dirty derives SD=1 on the RV64 status views.
- `mstatus` writes now retain only the implemented status field surface. A
  write-all-ones regression verifies that unsupported user-interrupt, VS, XS,
  and WPRI/reserved storage is cleared before the existing endian, fixed-XLEN,
  MPP, and SD-derived normalization runs.
- `menvcfg`/`senvcfg` no longer retain arbitrary compatibility storage bits.
  A write-all-ones regression pins the current baseline behavior: all optional
  environment controls read as zero until their corresponding extensions are
  implemented.
- `pmpcfg0`/`pmpaddr0` no longer retain arbitrary compatibility storage bits.
  A write-all-ones regression pins the current no-PMP-enforcement profile as
  read-only zero, and the native OpenSBI smoke confirms the firmware-visible
  PMP count is zero.
- `mnstatus` is no longer part of the supported CSR table. Focused regressions
  cover both read and suppressed-read write forms trapping when Smrnmi is absent.
- `mconfigptr` is now part of the supported read-only CSR table. Focused
  regressions cover zero readback and illegal-instruction traps for write forms.
