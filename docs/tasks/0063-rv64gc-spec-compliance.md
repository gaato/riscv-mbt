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
- Promote every locally available/buildable official `riscv-tests` source row
  applicable to RV64GC into `gating` before claiming this task complete.
- Keep the official-row coverage gate diagnostic enough to name missing
  suite/test rows, so a future upstream checkout expansion is actionable rather
  than a bare count mismatch.
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
  source rows beyond the older curated gating subset. The official `rv64ui`
  `lbu`, `lh`, `sb`, and `sh` binaries now build locally and are promoted to
  `gating`. The official non-word integer ALU rows for logical, compare,
  shift, and `sub` operations have also passed survey and moved to `gating`.
  Base `SLLI` decode now rejects reserved high immediate bits, and RV32 profile
  legality rejects `SLLI`, `SRLI`, and `SRAI` with `shamt[5]=1` instead of
  executing them as six-bit shifts.
  The RV64 word-operation rows `addiw`, `addw`, `subw`, `slliw`, `sllw`,
  `srliw`, `srlw`, `sraiw`, and `sraw` have likewise passed survey and are now
  part of the gating manifest. The remaining local `rv64ui` branch and
  memory-combination rows (`bge`, `bgeu`, `blt`, `bne`, `ld_st`, `st_ld`,
  `simple`, and `ma_data`) now also pass and are gated, so every `rv64ui`
  source row currently built from the local official-test checkout is in the
  regression floor. The remaining local `rv64um` unsigned divide/remainder and
  high-half multiply rows (`divu`, `divuw`, `remu`, `remuw`, `mulh`, `mulhsu`,
  and `mulhu`) also pass and are gated, completing the local official `rv64um`
  source rows. As of this pass, every local official source row for the
  RV64GC-relevant suites (`rv64ui/um/ua/uc/uf/ud`) is in `gating`; remaining
  local official rows are optional non-baseline extensions such as Zba/Zbb/Zfh.
  `rv32ui_gating_test.mbt` now derives the local RV64GC source-row set from
  the checked-out upstream `riscv-tests` tree and fails if any row is missing
  from the manifest's `gating` tier.
  Taken branch and jump target alignment now follows the active IALIGN:
  non-C profiles trap halfword-only targets as instruction-address-misaligned,
  while C/RV64GC profiles allow them under IALIGN=16. `JAL` and `JALR` also
  check that target alignment before writing the link register, so a
  misaligned jump trap leaves the architectural destination register unchanged.
  Base `JALR` now has focused coverage for clearing target bit 0 before that
  alignment check, matching the tagged-function-pointer rule in the
  unprivileged ISA.
- `F/D`: `riscv_fp.mbt` now covers instruction availability, NaN-boxing,
  comparisons, min/max, FMA availability, conversion clipping, integer-to-float
  rounding modes, and the first NV/DZ arithmetic flags. The conversion
  regressions now include exact RNE invalid boundaries for `FCVT.W.S/D` around
  `-2^31` and `+2^31`, `FCVT.WU.S/D` at negative inputs and `+2^32`,
  `FCVT.L.S/D` around `-2^63` and `+2^63`, and `FCVT.LU.S/D` at negative
  inputs and the `+2^64` upper boundary, plus RNE NaN/infinity clipping before
  any host integer cast. The signed exact-minimum edge values `-2^31` and
  `-2^63` are also pinned as valid, flag-clean conversions for both S and D
  sources. The last representable S/D values below the signed and unsigned
  upper boundaries are pinned as flag-clean conversions as well.
  `FCVT.W.D` now also has mode-dependent signed-boundary coverage for
  `+2^31 - 0.5` and `-2^31 - 0.5`, proving that validity is decided after
  tie-to-even or directed rounding chooses the integer result. RMM
  ties-away-from-zero coverage now also pins those signed boundaries, plus the
  unsigned `+2^32 - 0.5` and `-0.5` word boundaries, as invalid after rounding.
  `FCVT.WU.D` also has mode-dependent upper-edge coverage for `+2^32 - 0.5`:
  RTZ remains a valid inexact all-ones result, while RNE and RUP round to
  `+2^32` and then take the invalid-conversion path. The symmetric `-0.5`
  edge is also pinned for both `FCVT.WU.S` and `FCVT.WU.D`: RNE/RTZ produce
  valid inexact zero, while RDN rounds to `-1` and takes the
  invalid-conversion path.
  `FCVT.LU.S/D` now has the same lower-edge rounded-result coverage: RNE/RTZ
  produce valid inexact zero for `-0.5`, while RDN rounds to `-1` and takes the
  unsigned-long invalid-conversion path. RMM long-width coverage now pins
  representable signed ties such as `+9.5`/`-9.5` and the unsigned `-0.5`
  lower edge for both S and D sources.
  Invalid scalar arithmetic coverage now checks both NV and canonical-NaN
  results for representative add, multiply, and divide cases.
  Invalid fused multiply-add coverage now also checks canonical-NaN results for
  `infinity * zero` and signaling-NaN inputs, and the implementation writes
  those results directly instead of depending on host NaN propagation. The same
  invalid-FMA path now handles the infinite-product plus opposite-infinity
  fused-add case by applying the effective term signs for each FMA opcode
  variant before accruing NV, with focused coverage for `FMADD`, `FMSUB`,
  `FNMSUB`, and `FNMADD` in both S and D formats. The FMA family also now has
  all-opcode quiet-vs-signaling NaN operand coverage in S and D: quiet NaN
  addends produce canonical NaNs without flags, while signaling NaN addends
  produce canonical NaNs with NV.
  Exact widening `FCVT.D.S` and exact
  RV32-width-to-double `FCVT.D.W[U]` now treat the otherwise unaffected `rm`
  field as architecturally significant for legal/reserved static and dynamic
  encodings. `FCVT.S.D` now has explicit NaN narrowing coverage: quiet NaNs
  produce the canonical NaN-boxed single result without NV, while signaling
  NaNs produce the same canonical result and accrue NV. `FDIV.S/D` coverage now
  also pins invalid `0/0` and `infinity/infinity` default results to canonical
  NaNs while distinguishing them from finite-nonzero division by zero, so DZ is
  not accrued for those invalid cases. The same divide coverage now checks NaN
  operands directly: quiet NaN inputs canonicalize without flags, while
  signaling NaN inputs canonicalize and accrue NV. `FADD.S/D`, `FSUB.S/D`, and
  `FMUL.S/D` now have matching NaN-operand coverage, keeping ordinary quiet NaN
  arithmetic flag-clean while requiring NV for signaling NaNs and canonical
  results for both cases. `FSQRT.S/D` coverage now also pins negative finite
  inputs to canonical NaN plus NV, while `sqrt(-0)` remains an exact
  negative-zero result without flags. The NaN `FSQRT.S/D` path is covered
  separately: quiet NaNs canonicalize without flags, while signaling NaNs
  canonicalize and accrue NV. `mstatus.FS`
  is now part of the execution contract: FP-capable reset profiles start with
  FS enabled, but scalar F/D load/store, arithmetic, classify, and raw transfer
  instructions trap as illegal when software sets FS=Off. FP register and
  `fcsr` writes also mark FS Dirty, making the visible `SD` summary track
  modeled FP state changes. The
  `fflags`, `frm`, and `fcsr` CSR aliases are now governed by the same FS state,
  so both read and write attempts trap when FS=Off. Writes to absent `fcsr` bits
  31:8 are covered as
  ignored-on-write/read-as-zero. Focused profile coverage now also pins those
  floating-point CSR addresses as absent when `MISA.F` is not advertised, even
  though integer S-mode profiles may keep `mstatus.FS` writable for supervisor
  context-status bookkeeping. The corrected official-test harness now
  advertises manifest arch FP bits, and the passing `rv64uf`/`rv64ud`
  classification, compare, conversion, min/max, load/store, move, recoding,
  and structural rows are gated. The
  `rv64uf` arithmetic rows are also gated after adding single-precision NX
  accrual, and the `rv64ud` arithmetic rows are gated after adding
  exact-rational double-precision NX checks. Machine profiles now canonicalize
  the architectural dependency that `D` depends on `F`: a requested
  `D`-without-`F` profile clears both F/D bits, so white-box configs cannot
  expose or execute an impossible `misa.D`-without-`misa.F` profile. Focused
  `FMIN/FMAX` coverage now pins signed-zero selection in S and D, numeric
  selection against quiet NaNs in S and D, signaling-NaN-with-numeric cases
  that still return the numeric operand while accruing NV, and the all-NaN
  minimumNumber/maximumNumber split: quiet all-NaN inputs produce the canonical
  NaN without NV, while signaling all-NaN inputs produce the canonical NaN and
  accrue NV for both S and D. Focused S/D arithmetic coverage now also pins
  that `fflags` are accrued state across independent FP instructions: NX, DZ,
  and NV remain set until software explicitly clears `fcsr`. The remaining
  strict-spec gaps are broader than the current official rows: deeper
  fused-rounding audits and exception-flag corner cases beyond the current
  `riscv-tests` surface.
- `A`: `riscv_decode.mbt` rejects reserved AMO operations and reserved
  `LR.W`/`LR.D` encodings with nonzero `rs2`, gates AMO execution on `MISA.A`,
  keeps `AMO.D` RV64-only, and preserves the two-bit `aq`/`rl` ordering field
  in decoded AMO instructions. Focused white-box regressions pin the reserved
  AMO/LR encodings, all four AMO order encodings for both AMO.W and AMO.D,
  LR/SC order-bit execution for W and D reservation pairs, missing-`MISA.A`
  trap, and RV32 `AMO.D` rejection.
  `riscv_execute.mbt` implements LR/SC and AMO W/D behavior with shared
  per-hart physical byte-range reservations, with regressions for
  reservation success/failure for word and doubleword LR/SC, same-hart store
  invalidation, cross-hart store invalidation, overlapping LR.D reservation
  invalidation, device writes to bytes accessed by LR, RV64 AMO.W
  sign-extension, low-word bitwise AMO.W operations, full-width AMOSWAP.D and
  bitwise AMO.D operations, signed AMO.W and signed/unsigned AMO.D min/max
  comparisons, natural-address alignment traps for LR/SC/AMO W/D operations,
  and the architectural rule that a failed, non-trapping SC still consumes the
  hart reservation before any later matching SC can observe it. A later LR also
  replaces the previous hart reservation, so SC cannot pair with an older LR in
  program order. The reservation-set model is documented as the exact physical
  byte range loaded by the most recent LR, and mixed-width SC attempts at the
  same address now have focused regression coverage for deterministic failure.
  The xRET policy is also explicit: `MRET`/`SRET` do not clear live
  reservations, which is permitted by the privileged spec, and `MRET`
  preserving a live LR reservation for a following SC is covered. The A/C
  boundary is now covered as well: a constrained LR/SC-style sequence with
  compressed integer instructions between `LR.W` and `SC.W` preserves the
  single-hart reservation when no store or device write intervenes.
  Virtio-blk
  guest-visible DMA/status/used-ring writes now use reservation-aware device
  store helpers. The upstream `rv64ua` AMO/LRSC cases are now part of the
  gating manifest. The remaining audit is true `aq`/`rl` visibility ordering
  semantics beyond the current in-order single-hart execution model, plus
  broader forward-progress/eventual-success behavior beyond the current
  interpreter scheduling model.
- `C`: compressed decode/execute coverage exists in
  `riscv_compressed_test.mbt`, and the upstream `rv64uc-p-rvc` binary is now
  part of the gating manifest. The RV64C reserved/hint audit now covers
  `C.EBREAK`, `C.ADDIW rd=x0`, nonzero `C.LUI rd=x0`, `C.SLLI rd=x0`,
  6-bit RV64 `C.SLLI` shift amounts, legal `C.ADDIW imm=0` sign-extension
  behavior, `C.FLDSP f0`, and the RV32C custom-extension `shamt[5]=1` space for
  `C.SLLI`, `C.SRLI`, and `C.SRAI`, including the `C.SLLI rd=x0` hint-looking
  form, while RV64C keeps high-shamt `C.SLLI rd=x0` forms as hints. The
  zero-immediate reserved space for
  `C.LUI` and `C.ADDI16SP` is now pinned by focused RV64C regressions, keeping
  reserved traps distinct from the nearby positive and negative nonzero
  `rd=x0` hint encodings.
  Integer stack-load reserved forms for `C.LWSP rd=x0` and `C.LDSP rd=x0` are
  now covered, with adjacent stack stores from `x0` kept legal.
  `C.LUI` now has coverage for positive and negative compressed immediates,
  pinning sign extension from bit 17 through XLEN.
  Shared 6-bit signed compressed immediates now have focused coverage through
  `C.ADDI`, `C.LI`, and `C.ANDI`.
  `C.ADDI4SPN` now has high unsigned stack-offset coverage for the scattered
  CIW immediate path, in addition to the zero-immediate reserved case.
  Register-based `C.LW`/`C.SW` now have high zero-extended offset coverage for
  the scattered CL/CS memory immediate path.
  Stack-pointer `C.LWSP`/`C.SWSP` and `C.LDSP`/`C.SDSP` now have high
  zero-extended offset coverage for the separate CI/CSS memory layouts.
  `C.ADDI16SP` now also has coverage for negative and high positive
  sign-extended stack-pointer adjustments, beyond the zero-immediate reserved
  case.
  Immediate-form HINT coverage now pins canonical `C.NOP`, nonzero `C.NOP`
  hint encodings, zero-immediate `C.ADDI rd!=x0`, and zero/positive/negative
  `C.LI rd=x0` forms as no-ops.
  Zero-shift HINT coverage now pins `C.SLLI`, `C.SRLI`, and `C.SRAI` with
  `shamt=0` as no-ops, including the combined `C.SLLI rd=x0, shamt=0`
  encoding. High-shamt RV64C coverage now pins `C.SLLI`, `C.SRLI`, and
  `C.SRAI` as six-bit shift operations.
  Register-based RV64C integer double load/store coverage now pins
  `C.LD`/`C.SD` as legal RV64C aliases and rejects those integer double aliases
  in the RV32C profile. The same integer double aliases now also have high
  zero-extended offset coverage for the scattered doubleword CL/CS immediate
  path.
  RV32C now rejects the quadrant-2 integer double stack forms
  `C.LDSP`/`C.SDSP`, preserving those encodings as RV64C-only load/store
  aliases instead of widening the 32-bit compressed profile.
  RV64C word-ALU coverage now pins `C.ADDW` and `C.SUBW` as RV64-only
  compressed aliases, including low-32-bit sign extension, rejection of the
  same code points under RV32C, and illegal traps for the adjacent reserved
  RV64C CA funct2 slots.
  `C.ADDIW` now has nonzero signed-immediate coverage around the low-32-bit
  sign boundary, in addition to the existing `imm=0` word sign-extension case.
  The permanently illegal all-zero halfword is now pinned explicitly, alongside
  the existing all-ones sentinel coverage.
  The permanently illegal all-ones halfword is now treated as a 16-bit illegal
  sentinel instead of being widened into an ordinary 32-bit fetch.
  Compressed `C.J`, `C.BEQZ`, and `C.BNEZ` control transfers now have focused
  RV64C coverage for taken targets at halfword-only addresses, preserving the
  C extension's IALIGN=16 contract rather than treating those targets as
  misaligned. The same coverage now also pins sign-extended backward
  compressed control offsets, and RV64C now has focused coverage rejecting the
  RV32C-only `C.JAL` code point.
  `C.ADD rd=x0, rs2!=x0` forms now execute as
  ignored hints, including the `rs2=x2..x5` compressed Zihintntl non-temporal
  locality hint subrange. CR-format coverage now also pins `C.MV rd=x0,
  rs2!=x0` as an ignored hint, `C.JR rs1=x0` as reserved, and the
  `C.JALR rs1=x0` encoding as `C.EBREAK`. The legal `C.JR`/`C.JALR` forms are
  now pinned through execute coverage as `JALR` aliases, including the
  inherited `JALR` target-bit-clearing rule for odd register targets and the
  compressed link rule that `C.JALR` writes `pc + 2` to `x1` while `C.JR` does
  not link. Post-decode profile legality now rejects all 16-bit compressed
  encodings when `MISA.C` is not advertised, preserving the permissive decoder
  while making execution obey the active ISA profile.
  Compressed integer instructions are also covered inside an LR/SC-style
  sequence, pinning the C extension rule that compressed forms of the allowed
  I instructions can appear there without breaking the reservation.
  The compressed floating double load/store aliases are now also pinned as
  RV64DC forms rather than integer-only RV64C forms: `C.FLD`, `C.FSD`,
  `C.FLDSP`, and `C.FSDSP` trap without `MISA.D`, including under
  RV64F-without-D, and execute under the FD profile.
  The same RV64DC aliases now also have high zero-extended offset coverage for
  both register-based and stack-pointer compressed memory layouts.
  The remaining audit is broader reserved/hint behavior beyond those focused
  cases and the official aggregate compressed test.
- `Zicsr`: CSR decode, read-side and write-side privilege checks,
  `fcsr`/`fflags` views, and explicit read/write suppression for the standard
  CSR instruction forms are covered by focused execute tests. The `fcsr` alias
  coverage now also pins field preservation in both directions that are easy to
  regress: `frm` writes preserve accrued `fflags`, and `fflags` writes or
  clears preserve `frm`. The write-side coverage includes suppressed-read
  `CSRRW[I] rd=x0` forms, so lower privilege modes cannot write
  higher-privilege CSRs by avoiding the read. `mtvec` and `stvec` writes now
  normalize to the modeled WARL surface: 4-byte-aligned BASE plus Direct or
  Vectored MODE only, with vectored supervisor-timer dispatch covered by a
  focused regression. `mepc` and `sepc` now clear bit 0 on writes,
  preserve bit 1 for RV64GC/IALIGN=16, and mask bit 1 on visible reads plus
  xRET target reads when `MISA.C` is absent and IALIGN=32.
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
  causes (`0xb3fe`), including the modeled load/store/AMO
  address-misaligned causes, while `mideleg` exposes only SSI/STI/SEI
  (`0x222`). Nonzero set/clear CSR forms now also apply those masks while
  returning the old visible value; immediate forms are covered as the
  implemented mask intersected with the architectural low-five immediate field.
  `mcounteren` and `scounteren` now expose only the implemented base counter
  enables CY/TM/IR (`0x7`); HPM counter enables are read-only zero because the
  corresponding counter CSRs are absent. Nonzero `CSRRS/CSRRC` and immediate
  set/clear forms now also return the old visible value and apply the same
  CY/TM/IR write mask instead of retaining unsupported HPM bits. Focused
  coverage now also pins first/last `hpmcounter`, `mhpmcounter`, and
  `mhpmevent` slots as illegal-instruction traps rather than zero-valued
  compatibility storage. The RV64-only CSR support classifier also excludes the
  first/last HPM high-half aliases as RV32-only addresses. In an M+U profile without S-mode,
  `mcounteren` gates U-mode counter reads directly because there is no
  supervisor `scounteren` layer.
  `mcountinhibit` now controls the exposed architectural counters: CY inhibits
  `cycle`, IR inhibits `instret`, HPM inhibit bits are read-only zero because
  no HPM counters are modeled, and nonzero set/clear forms now apply that same
  CY/IR write mask while returning the old visible value. `time` continues to
  reflect CLINT `mtime` because the privileged spec excludes `mtime` from mcountinhibit. The
  unprivileged `cycle` and `instret` CSRs now shadow writable machine `mcycle`
  and `minstret` state instead of aliasing CLINT `mtime`; deterministic
  CY/IR-inhibited coverage now also pins full-XLEN machine-counter set/clear
  forms separately from those read-only unprivileged shadows; focused coverage also
  pins that illegal instructions, `ECALL`, `EBREAK`, and `C.EBREAK` are
  synchronous traps that do not retire into `instret`; machine-timer
  interrupts are also covered as between-instruction events that leave
  `instret` unchanged, and instruction-fetch faults are covered as pre-decode
  traps that do not retire. Trap-vector entry now also suppresses retirement
  when the trap handler address is nonzero and `raise_trap` returns `Running`,
  including both system-instruction traps and execute-stage faults.
  RV32-only high-half counter CSRs are now filtered by the shared CSR support
  classifier on RV64: `cycleh`, `timeh`, `instreth`, `mcycleh`, and
  `minstreth` are readable where modeled for RV32 but absent from the RV64GC
  CSR surface, with focused coverage spanning read, suppressed-read write, and
  nonzero set/clear forms plus the first/last HPM high-half aliases.
  `mie` now exposes only the modeled standard interrupt-enable bits
  MSI/MTI/MEI and SSI/STI/SEI (`0xaaa`), while `mip` readback is masked to the
  same implemented pending-bit surface. Nonzero `mie` set/clear forms now also
  apply that mask while returning the old visible value, including the immediate
  form's low-five source-mask limit. Writes to `mip` affect only the
  software-writable S-level pending bits; machine-level pending bits are
  supplied by CLINT/PLIC state. The mask is now profile-aware: no-`S` profiles
  expose only MSI/MTI/MEI, `mip` writes cannot retain absent S-level pending
  bits, and PLIC supervisor external state is not ORed into `mip` without an
  implemented supervisor mode. `mip.SEIP` now keeps the privileged spec's
  software/external split: the stored CSR bit is the M-mode software-pending
  bit, visible `mip` and delegated `sip` reads OR in the PLIC supervisor
  external signal, and CSRRS/CSRRC use the stored CSR value as their write base
  so the external signal is not copied into the software bit.
  `mstatus` now clears unsupported status storage before applying the modeled
  WARL rules. User-interrupt, VS, XS, and other WPRI/reserved bits read back as
  zero, while the implemented interrupt, return, privilege, FP-status,
  memory-access, trap-control, fixed-XLEN, and derived-SD fields remain visible.
  `sstatus` alias writes now also have focused coverage that only the
  supervisor-visible subset is replaced or modified: M-only `mstatus` fields
  such as `MIE`, `MPIE`, `MPP`, and `MPRV` survive both replacement writes and
  register-source set/clear RMW forms through the supervisor view.
  `menvcfg` and `senvcfg` now expose no optional environment-feature bits in
  this RV64GC baseline. FIOM, Svpbmt, Svadu, Sstc, cache-block controls,
  pointer masking, landing-pad, shadow-stack, and double-trap controls read
  back as zero because those extensions are not implemented. Focused coverage
  now also distinguishes this writable WARL-zero surface from address-encoded
  read-only CSRs: nonzero `CSRRS`/`CSRRC` and immediate set/clear forms retire,
  return the old zero value, and still read back zero after normalization.
  `pmpcfg0` and `pmpaddr0` now read as zero because PMP access enforcement is
  not implemented. The OpenSBI smoke still boots and reports `PMP Count: 0`,
  avoiding the old mismatch where firmware could configure protection rules the
  emulator would silently ignore. The same writable WARL-zero set/clear
  coverage now pins the PMP CSR surface so it is not accidentally handled as
  address-encoded read-only storage.
  `mnstatus` is no longer exposed as compatibility storage. It belongs to the
  optional Smrnmi resumable-NMI extension, which is not implemented in the
  RV64GC baseline, so read and write attempts now trap as illegal instruction.
  `mconfigptr` is now exposed as the mandatory read-only machine information
  CSR and returns zero, indicating that this platform has no standard
  configuration data structure and relies on the existing device-tree path.
  Machine-information readback coverage now pins `mvendorid`, `marchid`,
  `mimpid`, and `mconfigptr` to zero and `mhartid` to the runner hart ID.
  `misa` now behaves as a fixed WARL machine ISA CSR for the current runner
  profile: `CSRRW[I]`, nonzero `CSRRS[I]`, and nonzero `CSRRC[I]` retire but
  read back the configured ISA. The read-only CSR trap coverage samples the
  exposed machine-information read-only set
  (`mvendorid`, `marchid`, `mimpid`, `mhartid`, and `mconfigptr`) and now also
  pins the user-visible read-only counter aliases `cycle`, `time`, and
  `instret`.
  `mcause` and `scause` now expose the modeled WLRL cause surface on explicit
  CSR writes and reads: the interrupt flag and low five exception-code bits are
  retained, while unsupported high platform/custom cause-code storage is masked
  away. Nonzero set/clear CSR forms now also apply the same modeled WLRL mask,
  with immediate forms naturally limited to the low five source-mask bits.
  The plain trap-handling storage CSRs now have focused coverage at the visible
  instruction boundary: `mscratch`/`mtval` preserve full RV64 XLEN values in
  M-mode, and `sscratch`/`stval` preserve full RV64 XLEN values after an
  `MRET` transition into S-mode. Set/clear CSR-form coverage now also proves
  register-source masks preserve full XLEN storage, while immediate forms
  affect only the low five source bits. This keeps the scratch/trap-value path
  separate from the WARL-filtered status, vector, counter, delegation, and
  trap-vector CSRs.
  `satp` writes with unsupported MODE values now preserve the previous CSR
  value, matching the privileged WARL rule that the whole write has no effect.
  RV64 Bare-mode `satp` writes now also canonicalize bits 59:0 to zero, so the
  supported no-translation mode does not expose reserved future-standard
  patterns as ordinary stored state.
  `mstatus.MPP` now treats reserved privilege encoding 2 as a WARL value and
  normalizes it to U-mode in this implemented U/S/M profile. Optional vector
  CSRs are also pinned as absent from the non-`V` RV64FD/RV64GC baseline: the
  modeled `vstart`, `vxsat`, `vxrm`, `vcsr`, `vl`, `vtype`, and `vlenb`
  addresses all trap unless the configured profile advertises `MISA.V`.
  In the optional vector profile, the read-only `vl`, `vtype`, and `vlenb`
  CSRs now reject both direct write and nonzero set/clear CSR forms.
  Zicsr suppression is also pinned against absent CSRs: `CSRRW[I] rd=x0`
  still traps when the write side names an unsupported CSR, and zero-mask
  `CSRRS/CSRRC[I]` still traps when the read side names an unsupported CSR.
  Profile legality now also makes supervisor state conditional on `MISA.S`:
  no-`S` profiles reject supervisor CSRs, `SRET`, and `SFENCE.VMA`, and
  `mstatus` WARL normalization clears supervisor return state instead of
  accepting `MPP=S` or `SPP=1`. `misa` profile canonicalization now also
  applies the privileged dependency that `S` depends on `U`, and no-`U`
  profiles clear `mstatus.UXL`, clear `MPRV` because U-mode is absent, clear
  `TW` because there are no modes below M after `S` is also absent, and
  normalize `MPP=U` back to M-mode. Profiles with neither `F` nor `S` now keep
  `mstatus.FS` read-only zero, so the derived `SD` summary also reads as zero;
  S-mode integer profiles keep the emulator's existing writable `FS` path for
  supervisor context-status coverage.
  Supervisor-dependent compatibility CSRs now follow the same profile surface:
  no-`S` profiles reject `satp`, `medeleg`, `mideleg`, `scounteren`, and
  `senvcfg`, while no-`U` profiles reject `mcounteren`. `MRET` now also resets
  the stored `MPP` stack-bottom field to the least implemented privilege mode
  for the active profile, so M-only profiles no longer leave a raw `MPP=U`
  encoding behind after returning to M-mode.
  The standard debug-mode-only CSR range is now sampled explicitly:
  `0x7B0`, `0x7B7`, and `0x7BF` read, suppressed-read write, and nonzero
  set/clear forms trap as illegal instruction from M-mode because this RV64GC
  baseline does not implement Debug Mode or expose those addresses as ordinary
  machine storage.
  The remaining audit is a spec pass over remaining WARL behavior,
  read-only/write-ignored fields, and privilege-visible side effects for every
  CSR currently exposed by `riscv_decode.mbt`.
- `Zifencei`: `FENCE.I` decodes, flushes the emulator decode cache, official
  `fence_i` rows are in the gating subset, and
  `riscv_execute_test.mbt` now covers same-hart self-modified instruction
  visibility after an old instruction at the same address was fetched once. The
  base FENCE/Zifencei reserved-field contract is also pinned: reserved
  `FENCE` fm/pred/succ configurations retire as conservative base fences, and
  `FENCE.I` ignores its unused imm/rs1/rd fields while still flushing local
  fetch state. SMP coverage now also pins that the flush is local to the
  executing hart rather than a global decode-cache shootdown. The remaining
  audit is broader official coverage and any future instruction-cache model
  beyond the current fetch/decode-cache shape.

## Progress Notes

- Refactor/tuning checkpoint `c07f9b0` consolidated compressed
  illegal-instruction trap assertions behind a local `riscv_compressed_test.mbt`
  helper. The pass preserves the raw-halfword trap metadata checks while
  reducing repeated reserved/profile-gate boilerplate; measure the next
  roughly-3000-line feature-growth window from this checkpoint.
- Refactor/tuning checkpoint `ea90bac` consolidated retirement-accounting test
  helpers and the shared `instret` CSR constant in `riscv_execute_test.mbt`.
  The pass preserves the trap-cause/trap-value assertions while reducing
  repeated `runner.step()` boilerplate around synchronous exception,
  fetch-fault, execute-fault, and interrupt non-retirement coverage; measure
  the next roughly-3000-line feature-growth window from this checkpoint.
- Control-flow execution now checks taken branch, `JAL`, and `JALR` targets
  against the active profile's IALIGN. Non-C profiles raise
  instruction-address-misaligned on 2-byte-only targets and report the branch or
  jump as the faulting PC; RV64GC with C keeps those targets legal, including
  taken compressed `C.J`, `C.BEQZ`, and `C.BNEZ` halfword targets and
  sign-extended backward compressed control offsets. RV64C also rejects the
  RV32C-only `C.JAL` code point instead of letting the shared `JAL x1`
  expansion execute. Jump-link writeback is ordered after that target check,
  preserving the non-retirement side-effect rule for misaligned `JAL`/`JALR`
  traps. `JALR` now also has focused coverage that the computed `rs1 + imm`
  target clears bit 0 before alignment validation and link-register writeback.
- A-extension LR/SC and AMO W/D execution now enforces natural address
  alignment before translation or memory side effects. LR misalignment raises
  load-address-misaligned; SC and AMO misalignment raise
  store-address-misaligned. Ordinary non-atomic load/store misalignment remains
  governed by the emulator's existing EEI behavior.
- A-extension failed-SC coverage now includes both `SC.W` and `SC.D` without a
  live reservation, proving the nonzero status result and no-store behavior.
- A-extension successful LR/SC coverage now includes both `LR.W`/`SC.W` and
  `LR.D`/`SC.D`, proving full-width load-reserved results, zero success status,
  and the committed store-conditional value.
- A-extension reservation-set coverage now documents the interpreter's exact
  physical byte-range reservation model and pins mixed-width SC attempts at the
  same address as deterministic failures under that model.
- A-extension/privileged interaction coverage now pins the implementation's
  legal xRET policy: `MRET` preserves a live LR reservation for a following SC
  instead of implicitly clearing it.
- A-extension signed min/max coverage now includes `AMOMIN.W` plus full-width
  `AMOMIN.D`/`AMOMAX.D` comparisons across the 64-bit sign boundary.
- A-extension unsigned min/max coverage now includes full-width
  `AMOMINU.D`/`AMOMAXU.D` comparisons on the same sign-boundary bit patterns.
- Sv39 permission checks now keep SUM limited to supervisor data accesses:
  S-mode loads/stores to U pages can proceed when SUM is set, but S-mode
  instruction fetches from U pages raise instruction page faults regardless of
  SUM.
- Sv39 PTE bits 63:54 now raise page faults when set. The current RV64GC
  baseline does not implement Svnapot, Svpbmt, or future reserved PTE metadata,
  so both the walker and cache-walk bookkeeping reject those bits rather than
  treating them as ignored metadata.
- Sv39 non-leaf PTEs now raise page faults when D, A, or U is set. Those bits
  are reserved for pointer PTEs in this baseline and are checked before the
  walker descends to the next page-table level.
- `FCLASS.S` and `FCLASS.D` now decode and execute the architectural 10-bit
  classification mask for zero, subnormal, normal, infinity, signaling NaN,
  quiet NaN, and the D-present single-precision NaN-boxing path. Focused
  coverage now also pins the spec rule that FCLASS does not update `fflags`,
  including when classifying signaling NaNs.
- `FMADD.S/D`, `FMSUB.S/D`, `FNMSUB.S/D`, and `FNMADD.S/D` now decode and
  execute with exact-rational finite fused results and explicit exact-zero sign
  handling. Quiet and signaling NaN operands are covered for addends and
  multiplicands, with canonical default NaN results and NV only for signaling
  NaNs.
- Scalar `F/D` comparisons and min/max now accrue the invalid-operation flag
  for the NaN cases required by the F specification: `FLT`/`FLE` set NV for any
  NaN input, `FEQ` sets NV only for signaling NaNs, and `FMIN`/`FMAX` set NV for
  signaling NaNs while preserving their existing result-selection behavior.
  The comparison regression now snapshots each quiet/signaling NaN case
  independently for S and D so sticky flag behavior is not hidden by a later
  case in the same program. This replaces the old "no FP instruction updates
  fflags" limitation
  with instruction-family-specific flag handling.
- `D` min/max now has matching signed-zero and quiet-NaN result-selection
  coverage: `FMIN.D` selects `-0.0`, `FMAX.D` selects `+0.0`, numeric operands
  beat quiet NaNs, and quiet all-NaN inputs produce the canonical double NaN
  without accruing `fflags`.
- Fused multiply-add now also accrues NV for the required infinity-times-zero
  multiplicand case, including the spec-called-out path where the addend is a
  quiet NaN. Finite fused results now avoid the old host-IEEE arithmetic
  boundary; deeper NaN and exception-flag audits remain open.
- The existing official `rv64ui`, `rv64um`, `rv64ua`, and `rv64uc` manifest
  rows have been promoted from `survey` to `gating`, alongside the older RV32
  gating rows. This makes the already-integrated upstream `riscv-tests` path
  part of the always-green regression floor for the RV64I/M/A/C portion of
  RV64GC.
- The official-test gate now includes a source-tree completeness check: every
  `.S` row under the local upstream RV64GC source suites
  `rv64ui/um/ua/uc/uf/ud` must have a matching manifest row in the `gating`
  tier, not merely a passing handwritten or survey-only equivalent.
- `FCVT.W.S`, `FCVT.WU.S`, `FCVT.W.D`, and `FCVT.WU.D` now use a shared
  spec-shaped result helper for NaN/out-of-range clipping and accrued flags.
  The helper sets NV for invalid conversions, sets NX when the rounded valid
  result differs from the source value, and preserves the RV64 rule that
  32-bit conversion results are sign-extended to XLEN. Focused coverage now
  also pins exact RNE invalid boundaries for `FCVT.W.S/D` below `-2^31` and at
  `+2^31`, exact `-2^31` as a valid flag-clean signed result, flag-clean
  high valid values below `+2^31`/`+2^32`, plus unsigned negative-input
  clipping, the `FCVT.WU.S/D` `+2^32` upper boundary, and the RV64
  sign-extension of the valid high-bit `FCVT.WU.D` result `0x80000000`.
  The signed double-to-word half-unit boundary now also checks validity after
  rounding: `+2^31 - 0.5` is valid under RTZ/RDN but invalid under RNE/RUP,
  while `-2^31 - 0.5` is valid under RNE/RUP but invalid under RDN. RMM is
  covered separately for the same signed boundaries and for the unsigned
  `+2^32 - 0.5`/`-0.5` word boundaries, where ties away from zero produce
  invalid rounded results.
  The unsigned double-to-word upper edge now also checks validity after
  rounding, proving that `+2^32 - 0.5` is valid with NX under RTZ but invalid
  with NV under RNE/RUP. The lower edge likewise checks that `-0.5` is valid
  with NX under RNE/RTZ but invalid with NV under RDN for both S and D sources.
  Dynamic `rm=111` coverage now repeats the word-boundary check through
  `fcsr.frm` for signed RDN and unsigned RMM cases, and uses `fflags` clears so
  the test also proves the selected dynamic rounding mode is preserved. The
  F-only single-source conversion paths now also have dynamic `frm` coverage
  for `FCVT.W.S`, `FCVT.WU.S`, `FCVT.L.S`, and `FCVT.LU.S`, using exact small
  ties for the rounding-source check and `-0.5` for unsigned invalid rounding.
  Float-to-integer conversions now also have explicit reserved-rounding
  regressions for representative word, unsigned-word, and long forms,
  including dynamic `rm=111` with a reserved `frm`.
- `FCVT.L.S`, `FCVT.LU.S`, `FCVT.L.D`, and `FCVT.LU.D` now use the same
  spec-shaped conversion policy for RV64-width results. The helper clips
  invalid signed results to `INT64_MIN`/`INT64_MAX`, invalid unsigned results to
  zero/`UINT64_MAX`, sets NV for invalid conversions, and sets NX for valid
  inexact conversions. Focused RNE coverage now pins both lower and upper
  invalid boundaries for signed long conversions plus the unsigned negative and
  `+2^64` boundaries, while exact `-2^63` remains a valid flag-clean signed
  result and the last representable values below `+2^63`/`+2^64` remain valid
  flag-clean results. The shared RNE round-to-integer helper now returns exact
  integral doubles before tie-breaking, avoiding any host `Int64` evenness cast
  for large exact boundary values such as `2^64`. The unsigned-long lower edge
  now also checks validity after rounding for both S and D sources, proving
  that `-0.5` is valid with NX under RNE/RTZ but invalid with NV under RDN.
  RMM coverage now also checks FCVT.L.D ties-away behavior on representable
  `+9.5`/`-9.5` inputs and the FCVT.LU.S/D `-0.5` lower edge, where ties away
  from zero produce an invalid rounded result. Dynamic `rm=111` coverage now
  mirrors those long-width RDN and RMM paths through `fcsr.frm`, with `fflags`
  clears that preserve the selected rounding mode.
- `FCVT.S.W`, `FCVT.S.WU`, `FCVT.S.L`, `FCVT.S.LU`, `FCVT.D.L`, and
  `FCVT.D.LU` now construct IEEE result bits through a shared integer-magnitude
  rounding helper instead of relying on host-default conversion. The helper
  supports RNE, RTZ, RDN, RUP, RMM, valid dynamic `frm`, and NX accrual when
  discarded integer bits make the conversion inexact. The RV64 long-to-double
  path now also has dynamic-`frm` coverage at the binary64 precision boundary:
  signed negative RDN and unsigned positive RMM halfway cases select the
  directed result and accrue NX. Rounded integer-to-float conversions now also
  have explicit reserved-rounding regressions: static `rm=101/110` and dynamic
  `rm=111` with reserved `frm` trap before executing `FCVT.S.W`,
  `FCVT.S.LU`, or `FCVT.D.L`.
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
  `FDIV` sets DZ for finite nonzero division by zero. The invalid `FDIV.S/D`
  zero-over-zero and infinity-over-infinity cases now also have focused
  default-result coverage: they write canonical NaNs and accrue NV without DZ.
  `FDIV.S/D` NaN operand coverage now keeps quiet NaNs flag-clean and raises NV
  only for signaling NaNs while writing canonical NaN results; focused
  regressions cover both dividend and divisor positions. `FADD.S/D`,
  `FSUB.S/D`, and `FMUL.S/D` now have the same quiet-vs-signaling NaN operand
  regression coverage, with both source positions pinned for add/mul and sub.
  `FSQRT.S/D` NaN operands now have matching coverage:
  quiet NaNs produce canonical NaNs without accruing NV, and signaling NaNs
  produce canonical NaNs with NV. Fused multiply-add regressions now pin both
  the RISC-V-specific `FNMSUB`/`FNMADD` rule that only the product term is
  negated before detecting opposite-infinity fused additions, and the
  all-opcode S/D quiet-vs-signaling NaN default-result split for addends.
  Multiplicand NaN regressions now separately pin that quiet NaNs are
  flag-clean while signaling NaNs accrue NV. S/D arithmetic now also has a
  direct sticky-flag regression proving that NX, DZ, and NV accumulate across
  separate FP instructions until a software `fcsr` write clears them. Deeper
  NaN payload behavior, broader flag corner cases, and full official-suite
  promotion remain open.
- `FADD.S`, `FSUB.S`, and `FMUL.S` now round their exact single-precision
  operand results through the emulator-side exact-rational helper. Legal
  static non-RNE modes are accepted where they change the result, reserved
  rounding modes still trap, inexact results accrue NX, and exact-zero result
  signs are selected explicitly instead of inheriting host signed-zero behavior.
- `FDIV.S` and `FSQRT.S` now also accept legal static non-RNE modes, retiring
  the previous RNE-only trap boundary for the scalar single-precision
  arithmetic family. `FDIV.S` now rounds finite nonzero-divisor quotients
  through the emulator-side exact-rational helper and selects exact-zero
  quotient signs explicitly. `FSQRT.S` now selects finite square-root results by
  exact candidate comparison for RNE, RTZ, RDN, RUP, and RMM instead of
  inheriting host double-to-single rounding.
- The single-precision fused multiply-add family now accepts legal static and
  dynamic non-RNE modes and rounds finite nonzero fused results through an exact
  rational-to-single helper. This closes the old RNE-only legality boundary for
  `FMADD.S`, `FMSUB.S`, `FNMSUB.S`, and `FNMADD.S` without introducing a
  rounded host-Double product-plus-addend. Exact-zero result signs are now
  handled explicitly for cancellation and zero-product inputs. Representative
  reserved static `rm` encodings are now covered as illegal instructions.
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
- Scalar `FDIV.S/D` now has focused underflow flag coverage: minimum-normal
  operands divided by three round to subnormal quotients and accrue both UF and
  NX under tininess-after-rounding.
- Scalar `FMUL.S/D` now has matching underflow flag coverage: minimum-normal
  operands multiplied by the nearest encoded one-third round to subnormal
  products and accrue both UF and NX under tininess-after-rounding.
- The fused multiply-add family now has matching underflow flag coverage with
  an exact +0 addend: the tests isolate the fused single-rounding path while
  requiring the same subnormal tiny-product UF and NX sticky flags for
  `FMADD`, `FMSUB`, `FNMSUB`, and `FNMADD` in both S and D formats.
- The double-precision fused multiply-add family now accepts legal static and
  dynamic non-RNE modes and routes finite nonzero exact fused results through the
  exact-rational-to-double helper. This covers `FMADD.D`, `FMSUB.D`,
  `FNMSUB.D`, and `FNMADD.D` without using an intermediate rounded product.
  Exact-zero result signs are also handled explicitly for finite cancellation
  and zero-product inputs. Representative dynamic `rm=111` cases with a
  reserved `frm` value are now covered as illegal instructions.
- `FSQRT.D` now accepts legal static/dynamic non-RNE modes. For finite positive
  operands it uses the host square root only as an initial candidate, compares
  the candidate square against the exact operand, and selects the adjacent lower
  or upper double for RNE, RTZ, RDN, RUP, and RMM while accruing NX for inexact
  roots.
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
  FS-governed state when FS=Off. Pure reads and zero-mask set/clear forms over
  those FP CSRs now also have coverage that they leave an Initial FP context
  clean instead of incorrectly promoting `mstatus.FS` to Dirty. The alias
  field split is now pinned more directly: writes through the `fflags` view
  replace only accrued exception flags and leave the current `frm` intact,
  including the zero write used to clear flags.
- `fcsr` reserved high bits now have focused regression coverage. A CSR write
  of all ones leaves only visible bits 7:0 readable, matching the F extension
  rule for absent standard-extension fields in bits 31:8.
- `Zifencei` now has an execute regression for the key same-hart contract:
  fetch and decode an instruction, store a different instruction to the same
  address, execute `FENCE.I`, jump back, and require the replacement instruction
  to execute. The test also asserts that the emulator-side decode cache was
  flushed by `FENCE.I`. A separate SMP regression covers the complementary
  scope rule: another hart's decode cache is not flushed by the issuing hart's
  `FENCE.I`, even though the current coherent raw-fetch model can still observe
  changed memory through a normal cache miss.
- Base FENCE and Zifencei reserved-field behavior now has focused decode and
  execute coverage. This protects the spec rule that base implementations
  treat reserved `FENCE` configurations as normal fences and ignore FENCE.I's
  unused fields for forward compatibility.
- `Zicsr` execution now models the architectural read/write suppression table
  directly: `CSRRW[I]` with `rd=x0` skips the CSR read path, while
  `CSRRS/CSRRC[I]` with a zero register or immediate mask skips the CSR write
  path. Regression coverage keeps zero-mask set/clear legal for
  address-encoded read-only CSRs and keeps all nonzero-source write forms
  (`CSRRW[I]`, `CSRRS[I]`, and `CSRRC[I]`) illegal for read-only CSRs. The
  read-only set/clear coverage now explicitly exercises both register-source
  and immediate-source zero and nonzero masks across the exposed
  machine-information CSRs and the read-only counter aliases `cycle`, `time`,
  and `instret`. The executor now also keeps `CSRRS/CSRRC[I]`
  read-modify-write paths single-read: the old CSR value returned to `rd` is
  the same value used to derive the writeback value, avoiding a second visible
  CSR read when the form has already performed the architectural read side.
- Zicsr suppression no longer has an untested absent-CSR edge: suppressed-read
  write forms still require a supported writable CSR, and zero-mask set/clear
  forms still require a supported readable CSR.
- `A` decode now treats reserved AMO `funct5` values and the reserved
  nonzero-`rs2` LR encoding as illegal, while preserving the `aq`/`rl` ordering
  bits in the decoded instruction value. AMO W/D execution is also
  profile-gated on `MISA.A`, and the AMO.W regressions now pin both ordinary
  execution for all four order encodings and the RV64 rule that the loaded word
  placed in `rd` is sign-extended.
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
- `FSGNJ.S/D`, `FSGNJN.S/D`, and `FSGNJX.S/D` now also have focused
  regressions for the sign-injection-specific NaN rule: valid quiet and
  signaling NaN payload bits are preserved, and signaling NaN operands do not
  accrue `fflags`. This keeps the sign-injection "do not canonicalize NaNs"
  rule separate from the D-present malformed NaN-box input rule.
- `FMV.W.X` / `FMV.X.W` now have RV64FD transfer-boundary coverage:
  `FMV.W.X` NaN-boxes the raw low word on entry to the 64-bit FP register file,
  while `FMV.X.W` ignores upper FP-register bits and sign-extends only the low
  word. This pins the transfer exception to the normal NaN-box input rule.
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
  `FCVT.D.S` now handles NaNs before host widening: quiet single-precision NaNs
  write the canonical double-precision NaN without flags, while signaling
  single-precision NaNs write the same canonical result and accrue NV.
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
  cases where RTZ and RUP select adjacent single-precision results. Dynamic
  `rm=111` coverage now also verifies that `frm=RDN` selects the lower adjacent
  single for the same arithmetic family, plus reserved arithmetic rounding-mode
  traps. A separate regression now pins exact-zero signs for `FADD.S`,
  `FSUB.S`, and `FMUL.S`, including the round-down cancellation case.
- Single-precision div/sqrt now have the same first non-RNE coverage. Focused
  regressions cover `FDIV.S` `1.0 / 3.0` and `FSQRT.S` `sqrt(2.0)` cases where
  directed rounding selects adjacent single-precision results and accrues NX.
  A dynamic `rm=111` regression now also verifies that `frm=RDN` selects the
  lower adjacent single for both `FDIV.S` and `FSQRT.S`. `FDIV.S` now also has
  exact-zero quotient sign coverage, and `FSQRT.S` exact square roots are
  covered as flag-clean results.
- Single-precision FMA now has matching non-RNE coverage for finite nonzero
  exact results. Focused regressions cover all four FMA opcodes at `2^24 + 1`,
  where RTZ and RUP select adjacent single-precision results and accrue NX.
  Dynamic `rm=111` with `frm=RUP` now covers all four single-precision FMA
  opcodes, not only a representative `FMADD.S`.
  A separate regression pins exact-zero signs for finite cancellation and
  negative-zero product/addend inputs. Another regression now pins the core
  fused contract directly: an `FMADD.S` case whose separately rounded product
  would cancel to zero instead produces the exact positive nonzero fused result.
- Double-precision add/sub/mul now have corresponding non-RNE coverage.
  Focused regressions cover `2^53 + 1` add/sub and `(1 + 2^-52)^2` multiply,
  where RTZ and RUP select adjacent double-precision results and accrue NX.
  Dynamic `rm=111` coverage now verifies that `frm=RDN` selects the lower
  adjacent double for the same arithmetic family. A separate regression pins
  exact-zero signs for `FADD.D`, `FSUB.D`, and `FMUL.D`, including the
  round-down cancellation case.
- Double-precision division now has matching non-RNE coverage. Focused
  regressions cover `1.0 / 3.0`, where RTZ and RUP select adjacent
  double-precision quotients and accrue NX. A dynamic `rm=111` regression now
  also verifies that `frm=RDN` selects the lower adjacent double quotient. Exact
  zero quotient signs are covered separately.
- Double-precision FMA now has matching non-RNE coverage for finite nonzero
  exact results. Focused regressions cover all four FMA opcodes at `2^53 + 1`,
  where RTZ and RUP select adjacent double-precision results and accrue NX.
  Dynamic `rm=111` with `frm=RTZ` now covers all four double-precision FMA
  opcodes, not only a representative `FMADD.D`.
  Separate regressions pin exact-zero signs for finite cancellation and
  negative-zero product/addend inputs, plus the core fused contract where a
  separately rounded product would cancel to zero but `FMADD.D` produces the
  exact positive nonzero fused result.
- Double-precision sqrt now has matching non-RNE coverage. A focused regression
  covers `FSQRT.D sqrt(2.0)`, where RTZ and RUP select adjacent
  double-precision results and accrue NX. A dynamic `rm=111` regression now
  also verifies that `frm=RDN` selects the lower adjacent double and accrues NX.
  Exact double square roots are now covered as flag-clean results.
- Base shift-immediate decode now treats `SLLI` as a shift-immediate
  specialization rather than a generic 12-bit immediate. RV64 reserved high
  immediate bits decode as illegal, and RV32 `SLLI`, `SRLI`, and `SRAI`
  encodings with `shamt[5]=1` trap through the profile legality gate.
- Base load execution now has focused coverage for `rd=x0` destinations. The
  regression pins the unprivileged rule that a load into the zero register still
  performs address checks, raises access faults, and triggers device-visible
  read side effects such as PLIC interrupt claims before the loaded value is
  discarded.
- The first RV64C reserved/hint correction slice is in place. `EBREAK` and
  `C.EBREAK` now trap as architectural breakpoint exceptions instead of illegal
  instructions, RV64C rejects reserved `C.ADDIW rd=x0`, `C.LUI rd=x0` and
  `C.SLLI rd=x0` execute as ignored hints, legal `C.ADDIW imm=0` executes as
  `sext.w rd`, `C.SLLI` uses the unsigned 6-bit RV64 shift amount, and
  `C.FLDSP` can target valid floating-point register `f0`. Focused
  decode/execute regressions cover each case.
- RV32C compressed shift decode now rejects the standard-reserved/custom
  `shamt[5]=1` code points for `C.SLLI`, `C.SRLI`, and `C.SRAI`, while
  preserving the existing RV64C 6-bit shift behavior.
- RV64C zero-immediate coverage now keeps the reserved `C.LUI` and
  `C.ADDI16SP` code points illegal while leaving nearby positive and negative
  nonzero `C.LUI rd=x0` hint forms as no-ops.
- RV64C `C.LUI` coverage now pins the positive and negative compressed
  immediate paths, including sign extension from bit 17 through XLEN.
- Shared RV64C 6-bit signed immediate coverage now pins `C.ADDI`, `C.LI`, and
  `C.ANDI`, keeping the CI and CB immediate decode paths from regressing into
  zero-extension.
- RV64C `C.ADDI4SPN` coverage now pins the high unsigned `nzuimm=1020`
  stack-offset path through the scattered CIW immediate decoder.
- RV64C `C.LW`/`C.SW` coverage now pins the high unsigned `uimm=124`
  register-based memory offset through the scattered CL/CS decoder while
  preserving the ordinary RV64 `LW` sign-extension result.
- RV64C stack-pointer memory coverage now pins the high unsigned
  `C.LWSP`/`C.SWSP` `uimm=252` path and the high unsigned
  `C.LDSP`/`C.SDSP` `uimm=504` path through the separate CI/CSS layouts.
- RV64C `C.ADDI16SP` coverage now pins the scattered signed immediate path for
  both a negative stack adjustment and the high positive `+496` adjustment.
- RV64C integer stack-load coverage now keeps `C.LWSP rd=x0` and
  `C.LDSP rd=x0` illegal while leaving neighboring stack stores from `x0`
  legal.
- RV64C immediate-form HINT coverage now executes canonical `C.NOP`, nonzero
  `C.NOP` hint encodings, zero-immediate `C.ADDI rd!=x0`, and
  zero/positive/negative `C.LI rd=x0` forms as no-ops.
- RV64C zero-shift HINT coverage now executes `C.SLLI shamt=0`,
  `C.SRLI shamt=0`, and `C.SRAI shamt=0` as no-ops, including the
  overlapping `C.SLLI rd=x0, shamt=0` hint spelling.
- RV64C high-shift coverage now executes `C.SLLI`, `C.SRLI`, and `C.SRAI`
  with `shamt[5]=1` as legal six-bit shifts, while the RV32C profile keeps the
  same encodings reserved.
- RV64C high-shamt hint coverage now keeps `C.SLLI rd=x0, shamt[5]=1` as a
  no-op, paired with the existing RV32C rejection of the same custom-extension
  code points.
- RV64C register-based integer double memory coverage now round-trips
  `C.SD`/`C.LD`, while the same integer double aliases trap in the RV32C
  profile. High-offset coverage now pins the unsigned `uimm=248` path through
  the scattered doubleword CL/CS decoder.
- RV64C compressed floating double memory coverage now keeps `C.FLD`,
  `C.FSD`, `C.FLDSP`, and `C.FSDSP` tied to the D extension. The decoder still
  expands them to their ordinary F/D operations, but the execute profile gate
  rejects them under integer-only RV64C and RV64F-without-D while allowing them
  under RV64FD.
- RV64DC compressed floating double memory coverage now also pins the high
  unsigned `C.FLD`/`C.FSD` `uimm=248` path and the high unsigned
  `C.FLDSP`/`C.FSDSP` `uimm=504` path through the floating aliases.
- RV32C quadrant-2 integer double stack coverage now keeps `C.LDSP` and
  `C.SDSP` reserved in the 32-bit profile while preserving their RV64C
  expansion path.
- RV64C compressed word-ALU coverage now round-trips `C.ADDW` and `C.SUBW`
  through the existing RV64 word-operation helpers and proves the same code
  points remain illegal in RV32C. The adjacent RV64C CA word-ALU slots with no
  standard compressed operation now trap as reserved encodings.
- RV64C `C.ADDIW` coverage now includes nonzero signed immediates that cross
  the low-32-bit sign boundary, proving both CI immediate sign extension and
  ADDIW-style word-result sign extension.
- Fetch/decode now treats the all-ones halfword as the C extension's
  permanently illegal sentinel. The regression keeps trap value `0xffff`
  visible and prevents the fetch path from widening that sentinel into an
  ordinary 32-bit instruction.
- Fetch/decode now also pins the all-zero halfword as the C extension's other
  permanently illegal sentinel, while keeping the broader `C.ADDI4SPN`
  zero-immediate reserved behavior intact.
- Compressed `C.ADD rd=x0, rs2!=x0` now executes as an architectural hint
  across the whole nonzero source range. The `rs2=x2..x5` encodings are the
  compressed Zihintntl locality hints, so they remain no-ops in this RV64GC
  baseline instead of trapping as custom code points.
- Zicsr write-side privilege checks now run even when the instruction form
  suppresses the CSR read. This closes the `CSRRW rd=x0` hole where a lower
  privilege mode could otherwise write a higher-privilege CSR because no read
  was attempted first. The same read-only CSR coverage now spans nonzero-source
  `CSRRS[I]` and `CSRRC[I]` for both machine-information CSRs and the
  user-visible base counter aliases `cycle`, `time`, and `instret`, while
  zero-mask variants remain legal pure reads.
- Trap-vector CSR writes now normalize `mtvec` and `stvec` at the visible CSR
  boundary. The modeled WARL surface preserves the aligned BASE, stores MODE=1
  for Vectored, maps Direct and reserved MODE values to MODE=0, and keeps
  vectored interrupt dispatch covered with a delegated supervisor-timer
  regression. Focused set/clear CSR-form coverage now also proves that
  candidate values derived by `CSRRS`/`CSRRC` pass through the same WARL
  boundary for both `mtvec` and `stvec`.
- EPC CSR writes now normalize `mepc[0]` and `sepc[0]` to zero, and EPC
  visibility follows the active IALIGN. The compressed baseline keeps bit 1
  visible and usable as a return target, while non-`C` profiles mask bit 1 on
  CSR reads and on the implicit `MRET`/`SRET` EPC read. Focused coverage now
  also pins `CSRRS`/`CSRRSI` set forms, which can derive an odd candidate EPC
  from an aligned stored value before the hardwired-zero bit is cleared.
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
  Nonzero register-source and immediate set/clear forms now prove the same
  masks apply to RMW writeback.
  The exception surface now includes load/store/AMO address-misaligned causes,
  and an S-mode misaligned LR regression verifies routing through `stvec`.
- `mcounteren`/`scounteren` are now WARL-filtered to CY/TM/IR. The existing
  privilege-gate tests still cover access behavior, and a new readback
  regression pins HPM enable bits as read-only zero. Nonzero register-source
  and immediate set/clear forms now also prove those HPM bits are masked at
  writeback while returning the old visible value. A no-`S` profile regression
  now also proves that `mcounteren` alone permits U-mode `cycle` reads in M+U
  configurations where `scounteren` is absent.
- `mcountinhibit` is now modeled for the base architectural counters. Focused
  coverage writes all ones, verifies only CY/IR read back, proves inhibited
  `cycle` and `instret` stay stable, proves `time` still advances, and verifies
  writable `mcycle`/`minstret` back the unprivileged counter shadows. Nonzero
  set/clear CSR forms now also prove the same CY/IR mask is applied to RMW
  writeback. Machine `mcycle` and `minstret` now also have deterministic
  set/clear CSR-form coverage with CY/IR inhibited, proving register-source
  forms preserve full XLEN state and immediate forms affect only low source
  bits. A separate regression verifies that illegal-instruction, `ECALL`, `EBREAK`, and
  `C.EBREAK` synchronous traps update trap state without incrementing
  `instret`. Another regression verifies that a pending machine-timer
  interrupt enters the trap path before fetching the next instruction and does
  not increment `instret`. Instruction-fetch fault coverage also pins the
  pre-decode fault path as non-retiring. A trap-vector regression verifies that
  synchronous trap entry through nonzero `mtvec` is not counted as a retired
  instruction even though execution continues at the handler. The same
  non-retiring rule is covered for execute-stage load faults and for
  machine-timer interrupt entry through nonzero `mtvec`.
- RV32-only high-half counter CSR legality is now centralized in the CSR
  support classifier. Focused coverage keeps `cycleh`, `timeh`, and `instreth`
  readable on RV32, and verifies `cycleh`, `timeh`, `instreth`, `mcycleh`, and
  `minstreth` trap as absent CSRs on RV64 across read, suppressed-read write,
  and nonzero set/clear forms. The same RV64 absence coverage now includes the
  first/last HPM high-half counter and event-selector aliases.
- `mip`/`mie` no longer retain arbitrary interrupt bits. Focused regressions
  cover write-all-ones `mie` readback, `mip` writes limited to S-level pending
  bits, nonzero `mie` set/clear writeback masking, no-`S` profiles exposing
  only machine interrupt bits, and the existing delegated `sie`/`sip` view
  behavior after masking.
- `mip.SEIP` now separates the software-writable pending bit from the PLIC
  supervisor external interrupt signal. Focused regressions cover software
  `SEIP` surviving platform refresh with no external interrupt and CSRRS
  reading `B||E` while writing back only `B||source`.
- `MRET` and `SRET` now apply the privileged-spec `MPRV` return rule: when the
  return target is below M-mode, `mstatus.MPRV` is cleared so later data
  accesses cannot continue using the old MPP override. Focused regressions cover
  MRET-to-U, SRET-to-S, and the MRET-to-M preservation case. MPRV coverage now
  also pins the complementary fetch rule: M-mode instruction fetch keeps using
  M privilege even when MPRV redirects loads/stores through MPP.
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
  is still visible. Register-source set/clear forms now have matching
  whole-CSR WARL coverage: `CSRRS` cannot partially install unsupported Sv48,
  and `CSRRC` canonicalizes a derived Bare selector with reserved fields back
  to zero.
- RV64 Bare-mode `satp` writes now normalize the remaining fields to zero.
  This gives the emulator a deterministic WARL choice for the spec's reserved
  Bare encodings instead of leaking nonzero ASID/PPN fields into readback.
- `WFI` now enforces the modeled privilege/TW legality rule before applying the
  interpreter's CLINT timer fast-forward hint: U-mode raises illegal
  instruction, and S-mode raises illegal instruction when `mstatus.TW` is set.
  The illegal-path regressions now also arm a CLINT timer compare and verify
  that the legal-WFI fast-forward side effect does not run before the
  privilege/TW trap. Legal WFI keeps the existing timer fast-forward behavior.
- `SRET` now has focused `mstatus.TSR` coverage. A regression enters S-mode via
  `MRET`, attempts `SRET` with TSR set, and verifies an illegal-instruction trap
  to M-mode with the raw SRET instruction recorded in `mtval`. `SRET` status
  restoration now also has focused zero-`SPIE` coverage, pinning
  `SIE <- SPIE`, `SPIE <- 1`, and `SPP` reset to the least-privileged
  implemented mode independently of the ordinary S-mode return target. A
  separate M-mode regression keeps `TSR` interception scoped to S-mode
  execution by allowing M-mode `SRET` to return through `sepc` even when
  `mstatus.TSR` is set.
- Supervisor profile resources now obey `MISA.S` instead of only the current
  Linux-oriented default configs. White-box profile coverage removes `S` from
  the RV64 config and pins supervisor CSR reads/writes, `SRET`, and
  `SFENCE.VMA` as illegal, while `mstatus` writes normalize away supervisor
  return state in that profile.
- User-mode profile state now participates in the same canonicalization pass:
  clearing `U` from a requested RV64 config also clears `S`, and focused
  coverage pins no-`U` `mstatus` writes so `UXL`, `MPRV`, and `TW` read as
  zero, `FS` remains read-only zero when the profile has neither `F` nor `S`,
  derived `SD` stays zero, and `MPP=U` normalizes to the only implemented
  return target, M-mode.
- Compatibility CSR classification is now split by the privilege mode it
  serves. `satp`, `medeleg`, `mideleg`, `scounteren`, and `senvcfg` are absent
  when `S` is absent, while `mcounteren` is absent when `U` is absent. Counter
  access follows the implemented privilege stack, so no-`S` M+U profiles gate
  U-mode counter reads directly with `mcounteren` instead of consulting absent
  `scounteren`.
- `MRET` now resets the saved previous-privilege field to the least
  implemented mode for the active profile. This keeps the raw `mstatus.MPP`
  storage at M after no-`U` MRET-to-M, instead of depending on visible CSR
  WARL normalization to hide an unimplemented U encoding.
- `sstatus` now exposes and writes the shared `mstatus.FS` field. This keeps
  the RV64GC F/D context-status control path visible through the supervisor
  status CSR instead of only through machine `mstatus`; focused alias coverage
  also pins replacement and register-source set/clear writes so M-only
  `mstatus` fields survive supervisor-view updates.
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
  implemented. The set/clear CSR forms now also have focused coverage proving
  they retire as writable WARL-zero CSRs instead of trapping like read-only
  CSRs.
- `pmpcfg0`/`pmpaddr0` no longer retain arbitrary compatibility storage bits.
  A write-all-ones regression pins the current no-PMP-enforcement profile as
  writable WARL-zero, the set/clear CSR forms now retire and still read back
  zero, and the native OpenSBI smoke confirms the firmware-visible PMP count is
  zero.
- `mnstatus` is no longer part of the supported CSR table. Focused regressions
  cover both read and suppressed-read write forms trapping when Smrnmi is absent.
- `mconfigptr` is now part of the supported read-only CSR table. Focused
  regressions cover zero readback and illegal-instruction traps for write forms.
  The full machine-information CSR readback set is now pinned as stable:
  implementation IDs and `mconfigptr` read as zero, while `mhartid` reports the
  current runner hart ID.
- `misa` is no longer treated as address-encoded read-only. Focused regressions
  cover fixed WARL behavior across `CSRRW[I]`, nonzero `CSRRS[I]`, and nonzero
  `CSRRC[I]`: writes retire and preserve the runner's configured ISA bits.
