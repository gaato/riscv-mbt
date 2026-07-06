# Current State

## Current Milestone

- `Extensions: A, F/D, V, H`

## Current Tasks

- [Bootstrap the repo operating system](tasks/0001-bootstrap-operating-system.md) — `done`
- [Implement the RV32I bootstrap subset](tasks/0002-rv32i-bootstrap-subset.md) — `done`
- [Finish remaining RV32I base instruction coverage](tasks/0003-rv32i-complete-base-core.md) — `done`
- [Introduce riscv-tests for RV32I regression](tasks/0004-riscv-tests-integration.md) — `done`
- [Implement RV32IM](tasks/0005-rv32im.md) — `done`
- [Implement RV32IMC](tasks/0006-rv32imc.md) — `done`
- [Add Zicsr and Zifencei](tasks/0007-rv32imc-zicsr-zifencei.md) — `done`
- [Add minimal M-mode](tasks/0008-minimal-m-mode.md) — `done`
- [Machine reset and trap-entry invariants](tasks/0028-machine-reset-and-trap-entry.md) — `done`
- [Machine return and `mstatus` semantics](tasks/0029-machine-return-and-mstatus.md) — `done`
- [Add `mip` skeleton and machine CSR contract](tasks/0030-mip-skeleton-and-machine-csr-contract.md) — `done`
- [Optional RV32 supervisor + Sv32 path](tasks/0009-rv32-supervisor-sv32.md) — `todo`
- [Establish RV64 sign-extension invariants](tasks/0010-rv64-transition.md) — `done`
- [XLEN plumbing and RV64 state](tasks/0031-xlen-plumbing-and-rv64-state.md) — `done`
- [RV64I sign extension and word ops](tasks/0032-rv64i-sign-extension-and-word-ops.md) — `done`
- [RV64M word ops and transition closure](tasks/0033-rv64m-word-ops-and-transition-closure.md) — `done`
- [Stabilize the practical RV64 core](tasks/0011-rv64-practical-core.md) — `done`
- [RV64 carry-forward of `C`, `Zicsr`, and `Zifencei`](tasks/0034-rv64-carry-forward-of-c-zicsr-zifencei.md) — `done`
- [ELF64 loader and RV64 official plumbing](tasks/0035-elf64-loader-and-rv64-official-plumbing.md) — `done`
- [RV64 official survey and practical-core closure](tasks/0036-rv64-official-survey-and-practical-core-closure.md) — `done`
- [Add S-mode and delegation](tasks/0012-s-mode-and-delegation.md) — `done`
- [Supervisor CSR surface and trap entry](tasks/0037-supervisor-csr-surface-and-trap-entry.md) — `done`
- [Delegation routing and `SRET`](tasks/0038-delegation-routing-and-sret.md) — `done`
- [S-mode closure before `Sv39`](tasks/0039-s-mode-closure-before-sv39.md) — `done`
- [Add Sv39 and SFENCE.VMA](tasks/0013-sv39-and-sfence-vma.md) — `done`
- [Integrate OpenSBI and a virt-like platform](tasks/0014-opensbi-and-virt-platform.md) — `done`
- [Meet the Linux boot ABI on one hart](tasks/0015-linux-boot-abi-single-hart.md) — `done`
- [Add SMP after single-hart boot](tasks/0016-smp-after-single-hart.md) — `done`
- [Load official `riscv-tests` binaries](tasks/0024-official-riscv-tests-loader.md) — `done`
- [Add minimal `env/p` support](tasks/0025-minimal-env-p-support.md) — `done`
- [Run an official `rv32ui-p-*` subset](tasks/0026-official-rv32ui-runner.md) — `done`
- [Cross-check official `rv32ui-p-*` with a system emulator](tasks/0027-qemu-cross-check-official-rv32ui.md) — `done`
- [Browser demo host](tasks/0020-browser-demo.md) — `done`
- [Decide the browser demo hosting target](tasks/0021-browser-hosting-decision.md) — `done`
- [Deploy the first browser smoke demo](tasks/0022-browser-smoke-demo-deploy.md) — `done`
- [Enable preview deploys for browser work](tasks/0023-browser-preview-deploys.md) — `done`
- [Define the post-Linux compatibility target](tasks/0017-post-linux-compatibility.md) — `done`
- [Add post-Linux extensions in priority order](tasks/0018-extensions-a-fd-v-h.md) — `doing`
- [Bring up scalar `F`](tasks/0040-f-scalar-bring-up.md) — `done`
- [Bring up `D`](tasks/0041-d-extension-bring-up.md) — `done`
- [Close the post-`F/D` phase](tasks/0042-post-fd-closure.md) — `done`
- [Evaluate the first `V` slice](tasks/0043-vector-extension-evaluation.md) — `done`
- [Bring up `vsetvl*` and the first vector execute slice](tasks/0044-vsetvl-and-first-vector-execute-slice.md) — `done`
- [Implement the first vector arithmetic slice](tasks/0045-first-vector-arithmetic-slice.md) — `done`
- [Implement the first vector memory slice](tasks/0046-first-vector-memory-slice.md) — `done`
- [Implement the first masked and broader vector execute slice](tasks/0047-masked-and-broader-vector-execute-slice.md) — `done`
- [Implement the next broader vector memory and `LMUL` slice](tasks/0048-broader-vector-memory-and-lmul-slice.md) — `doing`
- [Move the browser smoke host to Wasm](tasks/0049-browser-wasm-smoke-host.md) — `done`
- [Refactor the browser runtime boundary](tasks/0050-browser-runtime-boundary-refactor.md) — `done`
- [Add a browser Linux artifact loader](tasks/0051-browser-linux-artifact-loader.md) — `done`
- [Refactor browser long-run behavior](tasks/0052-browser-long-run-refactor.md) — `done`
- [Boot Linux on one hart in browser Wasm](tasks/0053-browser-one-hart-linux-boot.md) — `done`
- [Refactor browser Linux observability](tasks/0054-browser-linux-observability-refactor.md) — `done`
- [Move the browser host to the plain Wasm backend](tasks/0055-browser-plain-wasm-backend.md) — `done`
- [Add simmerv-inspired cache performance improvements](tasks/0056-simmerv-inspired-cache-performance.md) — `done`
- [Refactor MoonBit execution surfaces before the next vector slice](tasks/0057-moonbit-refactoring-pre-0048.md) — `done`
- [Boot an Alpine rootfs in browser Wasm](tasks/0058-alpine-rootfs-browser-boot.md) — `doing`
- [Add a console Alpine Linux probe](tasks/0059-console-alpine-linux-probe.md) — `done`
- [Choose the full-rootfs I/O strategy](tasks/0060-full-rootfs-io-strategy.md) — `done`
- [Harden full-rootfs Linux usability](tasks/0061-full-rootfs-usability-hardening.md) — `done`
- [Harden rootfs init and service usability](tasks/0062-rootfs-init-service-usability.md) — `doing`
- [Complete RV64GC spec compliance](tasks/0063-rv64gc-spec-compliance.md) — `doing`

## Next Task

- Next: complete RV64GC spec compliance ([Task 0063](tasks/0063-rv64gc-spec-compliance.md)). The baseline is `RV64IMAFDC_Zicsr_Zifencei`, with Linux/Alpine kept as integration pressure rather than as the definition of correctness. Close instruction and CSR gaps in coherent spec-shaped groups, add documentation-quality comments as files are touched, promote every locally available/buildable official `riscv-tests` row applicable to RV64GC into the `gating` set before claiming completion, and pause for refactoring/tuning whenever roughly 3000 source lines have been added since the previous refactor/tuning pass.

- Previous full-rootfs task context: harden rootfs init and service usability on the established full-rootfs path ([Task 0062](tasks/0062-rootfs-init-service-usability.md)). Task 0061 is done: the full-rootfs path now has auto-root handoff, standard `/sbin/apk`, offline dependency resolution, package persistence through a host-saved virtio-blk image, package-provided `/bin/ping` loopback execution after install, and persisted package runtime execution after reboot. The current generated Alpine rootfs is intentionally not a normal OpenRC boot: `/sbin/init` is the BusyBox init symlink, `/etc/inittab` starts `/sbin/riscv-mbt-autoshell`, and the generated image currently has no populated `/etc/init.d` tree. Task 0062 has an initial BusyBox-init service-style proof: `cmd/alpine_probe xlong --auto-root-handoff --post-init-service-smoke --post-init-command-step-budget 120000000` creates an init.d-shaped script, starts a pidfile-backed background process, checks status/log output, stops it, cleans up, and reaches `post-init-service-ok` at 632,000,000 guest steps. Service configuration persistence also works: the write half saves `/etc/init.d/riscv-mbt-service` into `_build/alpine-rootfs-riscv64-service-persist-probe.ext4` at 616,000,000 guest steps with `--write-back-virtio-blk-disk`, and the read half reboots that image, observes ext4 journal recovery, starts/status-checks/stops the persisted script, removes the pidfile, and reaches `service-persistence-read-ok` at 618,000,000 guest steps. OpenRC is being added only as an explicit optional rootfs-builder path: `ALPINE_SERVICE_PACKAGES` and `ALPINE_APK_EXTRA_REPO_BASE_URLS` let the builder create a local OpenRC repository without replacing the BusyBox-init baseline, the provider resolver handles unversioned virtual provides such as `p:ifupdown-any`, and `ALPINE_EXTRACT_LOCAL_REPO_PACKAGES` can prepare an OpenRC file-surface image for lighter runtime checks. The prepared OpenRC surface proof reaches `post-init-openrc-surface-ok` at 619,000,000 guest steps without reinstalling packages inside the emulator, the OpenRC service-registration proof reaches `post-init-openrc-service-ok` at 636,000,000 guest steps by creating an `openrc-run` script and exercising `rc-update add/show/del`, and the OpenRC action proof reaches `post-init-openrc-action-ok` at 722,000,000 guest steps by running `rc-service --nodeps start/status/stop` for a marker-file service. The next concrete gap is daemon-style OpenRC service supervision, but do not add more OpenRC-specific probe variants just to route around that timeout; use it to inspect and improve the relevant emulator-side process/signal/poll/pipe/lock/timer implementation family before rerunning another long probe. The current body-side hardening pass has already added physical-address LR/SC reservations, unprivileged `cycle`/`time`/`instret` counter CSR reads with `mcounteren`/`scounteren` gates, CSR address privilege checks, RV64 S-mode timer/external interrupt delegation regressions, bounded WFI-to-CLINT-timer fast-forwarding, context-specific virtio-blk/PLIC external interrupt reflection, and UART/PLIC S-mode external interrupt coverage for console input, and spec-aligned PLIC claim priority/threshold behavior for simultaneous UART and virtio-blk sources, PLIC claim/complete IP-clear behavior, with OpenSBI now reporting `zicntr`. Continue RVV backlog work only when Linux execution trips over an illegal instruction, trap, or explicit RISC-V/Linux requirement. Browser checks are optional for each slice; console/native Alpine full-rootfs probes are the routine gate.

- For low-layer inspection, prefer `cmd/alpine_probe xlong --interactive-console` over adding another one-off batch probe. It selects the auto-root virtio artifacts, waits for rootfs-side `post-init-ready`, then forwards host stdin lines to the guest UART while exposing `:stats` and `:quit`; promote only useful command sequences back into scripted probes.

- The first console-path exercise, `printf ':stats\n:quit\n' | moon run --target native cmd/alpine_probe xlong --interactive-console --interactive-command-step-budget 1000000`, reaches `interactive console ready` at 558,000,000 guest steps and exits cleanly with `outcome=interactive-console-quit`, `interactive_console=true`, and the auto-root/post-init markers present.

- RV64 F/D hardening is currently focused on closing the RV64GC baseline
  (`RV64IMAFDC_Zicsr_Zifencei`) before returning to optional RVV backlog.
  Float-to-integer conversions now honor RNE, RTZ, RDN, RUP, RMM, and valid
  dynamic `frm` for `fcvt.{w,wu,l,lu}.{s,d}`. Integer-to-float conversions now
  use a shared integer-magnitude rounding helper for `fcvt.s.{w,wu,l,lu}` and
  `fcvt.d.{l,lu}`, covering legal static/dynamic modes and NX for inexact
  inputs. `FCVT.S.D` now uses an emulator-side double-to-single rounding helper
  for legal static/dynamic modes, NX, overflow result selection, and
  tininess-after-rounding UF behavior. `FADD.S`, `FSUB.S`, and `FMUL.S` now
  round exact single-precision operand results inside the emulator, including
  explicit signed-zero selection for exact cancellation and multiplication by
  zero. `FDIV.S` now uses the same exact-rational finite quotient path,
  including exact-zero quotient signs, and `FSQRT.S` now selects finite
  single-precision square-root results by exact candidate comparison for legal
  rounding modes and NX. Single and double fused multiply-add now use
  exact-rational fused products for finite nonzero results under legal static
  and dynamic non-RNE modes, reject reserved static/dynamic rounding encodings,
  and handle exact-zero fused result signs explicitly. NaN fused operations now write
  canonical NaNs for quiet/signaling addend and multiplicand cases, accruing NV
  only for signaling NaNs. Invalid fused operations also accrue NV for
  `infinity * zero` and
  signaling-NaN operands, and they also accrue NV for an infinite product
  fused with an opposite-signed infinite addend across the FMA opcode variants.
  The focused coverage now pins that behavior for `FMADD`, `FMSUB`, `FNMSUB`,
  and `FNMADD` in both single and double precision, including the
  RISC-V-specific rule that `FNMSUB`/`FNMADD` negate only the product term.
  `FADD.D`, `FSUB.D`, `FMUL.D`, and `FDIV.D` now round exact-rational finite
  results back to double precision for legal non-RNE modes, including NX/OF/UF
  result flags. Scalar `FDIV.S/D`, `FMUL.S/D`, and fused multiply-add family
  underflow coverage now pins subnormal tiny quotients/products accruing UF and
  NX. `FCLASS.S` /`FCLASS.D`
  now decode and execute the architectural 10-bit classification mask for zero,
  subnormal, normal, infinity, signaling-NaN, and quiet-NaN values. Double
  `FSQRT.D` now derives finite results for all legal rounding modes from exact
  operand/candidate comparisons. Scalar `F/D` comparisons now snapshot the
  quiet-vs-signaling NaN flag split case-by-case: ordered `FLT/FLE` set NV for
  any NaN, while `FEQ` sets NV only for signaling NaNs. Scalar `F/D` arithmetic
  now accrues NV for signaling NaNs in both source positions for add/mul/div
  and for the obvious invalid-operation cases,
  while quiet NaN `FSQRT.S/D` inputs stay quiet and do not set NV. `FDIV`
  NaN coverage now includes both dividend and divisor positions, and `FDIV`
  accrues DZ for finite nonzero division by zero. Focused arithmetic coverage
  now also proves that S/D NX, DZ, and NV flags are accrued state until an
  explicit software `fcsr` clear. This is emulator-body hardening for the
  ordinary C floating-point paths that Alpine userspace can exercise; deeper
  NaN payload/flag behavior and full official-suite promotion remain later
  spec-compliance work. Exact widening
  `FCVT.D.S` and exact
  RV32-width-to-double `FCVT.D.W[U]` now validate the otherwise unaffected `rm`
  field for legal/reserved static and dynamic encodings, so legal non-RNE forms
  execute and reserved forms trap instead of being silently accepted. Exact
  widening `FCVT.D.S` also now accrues NV for signaling single-precision NaNs
  before writing the canonical double-precision NaN result.
  Float-to-integer conversion regressions now also pin exact RNE invalid
  boundaries for `FCVT.L.D` at `+2^63`, `FCVT.LU.D` at `+2^64`, and RNE
  NaN/infinity clipping before any host integer cast. Exact integral
  round-to-integer inputs now bypass RNE tie-breaking before any host `Int64`
  evenness cast, keeping large exact boundary values on the safe path.
  `FCVT.WU.D` now also has explicit RV64 sign-extension coverage for the
  valid high-bit result `0x80000000`, not only the all-ones edge.
  Float-to-integer conversions now also reject reserved static and dynamic
  rounding-mode encodings before executing representative word and long forms.
  `FCVT.W.D` now checks signed half-unit boundary cases around `-2^31` and
  `+2^31`, proving the valid-vs-invalid decision is made after rounding.
  RMM ties-away-from-zero coverage now also checks the signed and unsigned word
  half-unit boundaries where that rounding mode pushes the result out of range.
  `FCVT.WU.D` now also checks the mode-dependent upper edge where
  `+2^32 - 0.5` stays valid/inexact under RTZ but rounds out of range and sets
  NV under RNE/RUP, plus the lower S/D `-0.5` edge where RNE/RTZ produce valid
  inexact zero but RDN rounds invalid. Dynamic `rm=111` coverage now also
  checks those word-boundary rules through `fcsr.frm`, using `fflags` clears
  that leave the current rounding mode intact; the F-only single-source paths
  now have matching dynamic checks for word and long outputs.
  `FCVT.LU.S/D` now has matching unsigned-long lower-edge coverage for `-0.5`,
  proving the same rounded-result validity rule on the RV64-width output path;
  RMM coverage also pins FCVT.L.D ties-away behavior on representable `+9.5`
  and `-9.5` inputs. Dynamic `rm=111` coverage now mirrors those long-width
  checks through `fcsr.frm` for RDN and RMM while preserving `frm` across
  `fflags` clears.
  Integer-to-double conversion coverage now also pins dynamic-`frm`
  long-to-double rounding at the binary64 precision boundary, including signed
  negative RDN and unsigned positive RMM halfway cases with NX. Rounded
  integer-to-float conversions now also reject reserved static and dynamic
  rounding-mode encodings before executing representative S and D forms.
  Invalid scalar arithmetic coverage now checks both NV and canonical-NaN
  results for representative add, multiply, and divide cases.
  `FMIN/FMAX` result-selection coverage now includes the D path for signed
  zeros and quiet NaNs, plus S/D signaling-NaN-with-numeric cases that return
  the numeric operand while accruing NV.
  Scalar `FSGNJ.S/D`, `FSGNJN.S/D`, and `FSGNJX.S/D` now have focused
  regressions that valid NaN payloads, including signaling-NaN payloads, are
  preserved without accruing `fflags`; malformed D-present single NaN boxes
  remain covered by the separate NaN-boxing input rule.
  `FMV.W.X` / `FMV.X.W` now also have RV64FD transfer-boundary coverage:
  moving a raw word into an FP register creates a valid NaN box, while moving a
  word out ignores upper FP-register bits and sign-extends only the low word.
  FP-capable runner profiles now start with `mstatus.FS=Initial`, and scalar
  F/D load/store plus arithmetic execution now traps as illegal when software
  sets `mstatus.FS=Off`. FP register and `fcsr` writes now mark FS Dirty, so
  the visible `mstatus.SD` summary follows actual modeled FP state changes.
  The `fflags`, `frm`, and `fcsr` CSR aliases are also FS-gated: read and
  write attempts trap when FS is Off. Alias writes now explicitly preserve the
  untouched field, including `fflags` writes and clears that leave `frm`
  intact. Writes to absent `fcsr` bits 31:8 are
  now covered by regression as ignored-on-write/read-as-zero. A no-`F` profile
  regression also pins those floating-point CSR addresses as absent even when
  an integer S-mode profile keeps `mstatus.FS` writable for context-status
  bookkeeping.
- RV64 `mstatus.SXL`/`mstatus.UXL` and `sstatus.UXL` are now visible as fixed
  64-bit lower-privilege XLEN fields. Writes that try to clear or change them
  are normalized back to the modeled SXLEN=UXLEN=64 profile.
- Post-decode profile legality now rejects extension instructions when the
  active machine profile does not advertise the matching base extension bit.
  The current focused coverage includes 16-bit compressed encodings without
  `MISA.C` and multiply/divide/remainder instructions without `MISA.M`.
  Machine profiles now also canonicalize the architectural extension
  dependency that `D` depends on `F`: a requested `D`-without-`F` profile clears
  both F/D bits, so internal test configs cannot expose or execute an
  impossible `misa.D`-without-`misa.F` profile.
- The status endian-control fields now match the emulator's little-endian-only
  memory system: `mstatus.MBE`, `mstatus.SBE`, and `mstatus.UBE`, plus
  `sstatus.UBE`, are visible where appropriate but normalize to read-only zero
  on writes.
- `sip` and `sie` now behave as `mip`/`mie` views restricted by `mideleg`.
  Non-delegated supervisor interrupt bits read as zero through the supervisor
  CSRs, `sie` writes affect only delegated SSI/STI/SEI enable bits, and `sip`
  writes affect only delegated SSIP; STIP/SEIP pending state is supplied through
  the machine/platform path.
- `medeleg` and `mideleg` now apply WARL masks on read, write, and trap routing.
  The modeled delegatable exception surface is `0xb3fe`, including
  load/store/AMO address-misaligned causes, and delegated interrupts are
  limited to SSI/STI/SEI (`0x222`); machine-only causes remain read-only zero.
- `mcounteren` and `scounteren` now expose only CY/TM/IR (`0x7`) as writable
  WARL bits. HPM counter-enable bits read back as zero because the matching
  `hpmcounter` CSRs are not implemented in the current RV64GC profile. Focused
  coverage now checks first/last low-half HPM counter and event-selector CSR
  slots as absent rather than zero-valued compatibility storage. In an M+U
  profile without S-mode, `mcounteren` gates U-mode counter reads directly
  because there is no supervisor `scounteren` layer.
- `mcountinhibit` is now modeled for the exposed architectural counters. CY
  and IR are writable, HPM inhibit bits read back as zero because HPM counters
  are absent, and `time` remains tied to CLINT `mtime` rather than the inhibit
  mechanism. The `cycle` and `instret` user-visible counters now shadow
  writable machine `mcycle` and `minstret` state instead of aliasing `mtime`.
  Synchronous exception coverage now explicitly pins illegal instructions,
  `ECALL`, `EBREAK`, and `C.EBREAK` as non-retiring instructions for `instret`.
  Interrupt coverage also pins a pending machine-timer interrupt as a
  between-instruction event that does not retire the interrupted instruction.
  Instruction-fetch fault coverage likewise pins pre-decode traps as
  non-retiring. Trap-vector entry now suppresses retirement even when a nonzero
  handler makes `raise_trap` continue with `Running`, for both synchronous
  exceptions, execute-stage faults, and machine-timer interrupts.
  RV32-only counter high-half CSRs are now excluded through the shared CSR
  support classifier on RV64, so `cycleh`/`timeh`/`instreth`,
  `mcycleh`/`minstreth`, and the first/last HPM high-half aliases trap instead
  of reaching ad hoc executor checks.
- `mie` now exposes only the modeled standard interrupt-enable bits
  MSI/MTI/MEI and SSI/STI/SEI (`0xaaa`), while `mip` readback is masked to the
  same implemented pending-bit surface. CSR writes to `mip` affect only the
  software-writable S-level pending bits; machine-level pending bits come from
  CLINT/PLIC state. No-`S` profiles now reduce that surface to machine
  MSI/MTI/MEI only, so writes cannot synthesize absent supervisor pending or
  enable bits and PLIC supervisor external state is not reflected through
  `mip`. The supervisor external interrupt pending bit now follows the
  privileged spec's split semantics: stored `mip.SEIP` is the software-writable
  bit, visible `mip`/`sip` reads OR in the PLIC supervisor external signal, and
  CSRRS/CSRRC write back only the software bit rather than copying the external
  signal into it.

- RV64I byte and halfword load/store regressions now explicitly verify
  sign-extension and zero-extension to XLEN for `LB/LBU/LH/LHU` after `SB/SH`.
  The matching official `rv64ui` rows for `lbu`, `lh`, `sb`, and `sh` now
  build locally and have been promoted to the gating manifest. Official
  non-word integer ALU rows for logical, compare, shift, and `sub` operations
  have also passed survey and moved to `gating`. The RV64 word-operation rows
  `addiw`, `addw`, `subw`, `slliw`, `sllw`, `srliw`, `srlw`, `sraiw`, and
  `sraw` have likewise passed survey and are now part of the gating manifest.
  The remaining local `rv64ui` branch and memory-combination rows (`bge`,
  `bgeu`, `blt`, `bne`, `ld_st`, `st_ld`, `simple`, and `ma_data`) now also
  pass and are gated, so every `rv64ui` source row currently built from the
  local official-test checkout is in the regression floor. The remaining local
  `rv64um` unsigned divide/remainder and high-half multiply rows (`divu`,
  `divuw`, `remu`, `remuw`, `mulh`, `mulhsu`, and `mulhu`) also pass and are
  gated, completing the local official `rv64um` source rows. As of this pass,
  every local official source row for the RV64GC-relevant suites
  (`rv64ui/um/ua/uc/uf/ud`) is in `gating`; remaining local official rows are
  optional non-baseline extensions such as Zba/Zbb/Zfh. Base `SLLI` now
  rejects reserved high immediate bits, and the RV32 profile gate rejects
  `SLLI`/`SRLI`/`SRAI shamt[5]=1` rather than executing those encodings as
  six-bit shifts.

- A-extension LR/SC and AMO W/D operations now enforce the natural address
  alignment required by the atomic extension before translation or memory side
  effects. Misaligned LR raises load-address-misaligned; misaligned SC and AMO
  raise store-address-misaligned. Ordinary non-atomic load/store misalignment
  is intentionally left on the existing EEI path.
  AMO.W bitwise regressions now pin low-word operation with sign-extended
  old-word results in `rd`.
  Focused AMO.D regressions now also pin full-width swap and bitwise behavior
  for AMOSWAP.D, AMOXOR.D, AMOAND.D, and AMOOR.D, keeping those doubleword
  operations distinct from the AMO.W low-word/sign-extension path.

- The first RV64C reserved/hint correction slice for Task 0063 is in place.
  `EBREAK` and `C.EBREAK` now raise the architectural breakpoint exception,
  `C.ADDIW rd=x0` is rejected as reserved on RV64C, nonzero `C.LUI rd=x0`
  and `C.SLLI rd=x0` execute as ignored hints, `C.SLLI` uses the unsigned
  6-bit RV64 shift amount, and `C.FLDSP` can target valid FP register `f0`.
  RV32C now rejects `C.SLLI`, `C.SRLI`, and `C.SRAI` forms with `shamt[5]=1`,
  including `C.SLLI rd=x0`, while RV64C keeps the high-shamt `C.SLLI rd=x0`
  space as ignored hints.
  RV64C coverage now also pins the zero-immediate reserved space for
  `C.LUI` and `C.ADDI16SP`, keeping those traps distinct from the positive and
  negative nonzero `rd=x0` hint encodings.
  Integer stack loads now also pin their reserved `rd=x0` encodings for
  `C.LWSP` and `C.LDSP`, while adjacent stack stores from `x0` remain legal.
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
  RV64C compressed floating double load/store aliases are now pinned as
  D-dependent RV64DC forms: they execute under the FD profile and trap as
  illegal instructions under integer-only RV64C and RV64F-without-D.
  The RV64DC floating double aliases now also have high zero-extended offset
  coverage for both register-based and stack-pointer compressed memory layouts.
  Immediate-form HINTs now cover canonical `C.NOP`, nonzero `C.NOP` hint
  encodings, zero-immediate `C.ADDI rd!=x0`, and zero/positive/negative
  `C.LI rd=x0` forms as no-ops.
  Zero-shift HINTs now cover `C.SLLI`, `C.SRLI`, and `C.SRAI` as no-ops, and
  high-shamt RV64C coverage now pins `C.SLLI`, `C.SRLI`, and `C.SRAI` as
  six-bit shift operations.
  Register-based RV64C integer double load/store forms `C.LD`/`C.SD` now have
  focused round-trip coverage, paired with RV32C rejection of the same integer
  double aliases, and high zero-extended offset coverage for the scattered
  doubleword CL/CS immediate path.
  RV32C now also rejects quadrant-2 integer double stack forms
  `C.LDSP`/`C.SDSP`, keeping those RV64C-only encodings from expanding into
  RV64 load/store operations in the 32-bit profile.
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
  `C.ADD rd=x0, rs2!=x0` forms now execute as ignored hints, including the
  `rs2=x2..x5` compressed Zihintntl non-temporal locality hint subrange.
  CR-format coverage now also pins `C.MV rd=x0, rs2!=x0` as an ignored hint,
  `C.JR rs1=x0` as reserved, and the `C.JALR rs1=x0` encoding as `C.EBREAK`.
  Focused regressions cover the decode and execute behavior, including legal
  `C.JR`/`C.JALR` expansion through `JALR` and the compressed `C.JALR`
  `pc + 2` link address. Post-decode profile legality now also rejects all
  16-bit compressed encodings when `MISA.C` is not advertised, keeping the
  permissive decoder while making the executing profile authoritative.
  Control-flow target alignment now follows the same profile boundary: non-C
  profiles trap taken branches and jumps to 2-byte-only targets with
  instruction-address-misaligned, while RV64GC/C profiles use IALIGN=16 and
  allow those halfword targets. Misaligned `JAL` and `JALR` traps now validate
  the target before link-register writeback, so they leave `rd` unchanged when
  the jump does not retire. Base `JALR` now also has focused coverage for
  clearing target bit 0 before alignment validation, preserving the
  unprivileged ISA's tagged-function-pointer behavior. Base load coverage now
  also pins the unprivileged rule that `rd=x0` discards only the loaded value:
  address checks, exceptions, and memory/device side effects still happen before
  the zero register suppresses writeback.

- Zicsr write-side privilege checks now run even when a CSR instruction
  suppresses the read side. The regression covers `CSRRW rd=x0` from supervisor
  mode to `mstatus`, preventing lower privilege modes from writing
  higher-privilege CSRs just because the instruction form avoids reading the old
  CSR value.
  Suppression is also pinned for absent CSRs: suppressed-read write forms still
  require a supported writable CSR, and zero-mask set/clear forms still require
  a supported readable CSR.
  The debug-mode-only CSR range is now sampled at `0x7B0`, `0x7B7`, and
  `0x7BF`, with read and write forms trapping from M-mode because this baseline
  does not implement Debug Mode.
  Read-only CSR coverage now spans all write-attempting standard forms:
  `CSRRW[I]`, `CSRRS[I]`, and `CSRRC[I]` with a nonzero source all trap, while
  zero-mask `CSRRS[I]` / `CSRRC[I]` remain legal pure reads. The RMW executor
  now keeps `CSRRS/CSRRC[I]` single-read internally, using the same old CSR
  value for `rd` and writeback derivation instead of reading the CSR a second
  time.
- Trap-vector CSR writes now normalize `mtvec` and `stvec` to the modeled WARL
  surface: aligned BASE plus Direct or Vectored MODE only. A delegated
  supervisor-timer regression covers Vectored `stvec` dispatch to
  `BASE + 4*cause`.
- EPC CSR writes now clear hardwired bit 0 for `mepc` and `sepc`, and `MRET` /
  `SRET` mask the same bit when consuming EPC values prepared internally. Bit 1
  remains representable for the RV64GC compressed-instruction baseline.
- `mstatus.MPP` now normalizes the reserved privilege encoding 2 to U-mode on
  visible CSR writes, while preserving legal U/S/M return-mode encodings.
- `MRET` and `SRET` now clear `mstatus.MPRV` when returning to a privilege mode
  below M, while preserving `MPRV` for `MRET` returns that stay in M-mode.
- Sv39 now keeps SUM data-only: supervisor loads/stores may access U pages when
  SUM is set, but supervisor instruction fetches from U pages fault regardless
  of SUM.
- Sv39 PTE bits 63:54 now fault when set. The RV64GC baseline does not
  implement Svnapot, Svpbmt, or future reserved PTE metadata, so the walker
  rejects those bits instead of silently ignoring them.
- Sv39 non-leaf PTEs now reject reserved D/A/U bits before descending to the
  next page-table level. Those bits remain leaf-only state in this baseline.
- Return-instruction legality is now enforced for the modeled privileged
  surface: `MRET` traps outside M-mode, `SRET` traps from U-mode, and S-mode
  `SRET` traps when `mstatus.TSR` is set. `SRET` status restoration now also
  has explicit zero-`SPIE` coverage, pinning the `SIE <- SPIE`, `SPIE <- 1`,
  and `SPP <- least-privileged-mode` side effects separately from the existing
  supervisor-return path. M-mode `SRET` with `TSR=1` is pinned as legal,
  keeping the interception rule scoped to S-mode execution.
- `SFENCE.VMA` now enforces privilege legality before flushing the translation
  cache: U-mode traps, and S-mode traps when `mstatus.TVM` is set.
- Supervisor-mode resources are now conditional on `MISA.S`, not just on the
  Linux default configs: no-`S` RV64 profiles reject supervisor CSRs, `SRET`,
  and `SFENCE.VMA`, and `mstatus` WARL normalization clears supervisor return
  state such as `MPP=S` and `SPP=1`.
- The profile normalizer now also applies the privileged dependency that
  `S` depends on `U`. Requested no-`U` configs clear both bits, and `mstatus`
  reads keep user-mode return state absent by clearing `UXL`, clearing
  `MPRV` because there is no U-mode effective-privilege target, clearing `TW`
  because there are no modes below M after `S` is also absent, and normalizing
  `MPP=U` back to M-mode. Profiles with neither `F` nor `S` now also keep
  `mstatus.FS` read-only zero, making the derived `SD` summary read as zero;
  S-mode integer profiles intentionally retain the existing writable `FS`
  status path for supervisor context-status coverage.
- Compatibility CSR classification now follows those mode dependencies:
  `satp`, `medeleg`, `mideleg`, `scounteren`, and `senvcfg` are absent without
  `S`, while `mcounteren` is absent without `U`. Counter access follows the
  same implemented-mode stack: no-`S` M+U profiles use `mcounteren` directly
  for U-mode counter reads instead of requiring absent `scounteren`.
- `MRET` now resets raw `mstatus.MPP` to the least implemented privilege mode
  for the active profile, so no-`U` MRET-to-M keeps the stored stack-bottom
  field at M instead of relying on read-time WARL normalization.
- `satp` CSR reads and writes now use the same `TVM` interception rule: S-mode
  access traps when `mstatus.TVM` is set, while M-mode remains allowed.
- `satp` writes with unsupported MODE values now follow the privileged WARL
  rule that the whole write has no effect; the previous address-space selector
  is preserved instead of being cleared to Bare.
- FENCE reserved-field behavior is now pinned by decode and execute coverage:
  `FENCE.TSO` and future-reserved `fm`/pred/succ combinations retire as
  conservative base fences, and FENCE.I ignores its unused imm/rs1/rd fields
  while still flushing the local decode/fetch state.
- `WFI` now enforces the modeled privilege/TW legality rule before using the
  existing CLINT timer fast-forward: U-mode traps, and S-mode traps when
  `mstatus.TW` is set.
- `sstatus` now exposes and writes the shared `mstatus.FS` field, matching the
  RV64GC F/D context-status path used by supervisor software.
- `mstatus.SD` / `sstatus.SD` are now read as derived summary bits for dirty
  modeled extension state: direct writes to SD are ignored, while FS=Dirty sets
  SD in the visible RV64 status view.
- `mstatus` now drops unsupported status storage before applying the modeled
  WARL rules. User-interrupt, VS, XS, and other WPRI/reserved bits read back as
  zero; the remaining visible surface is the emulator's implemented interrupt,
  return, privilege, FP-status, memory-access, trap-control, fixed-XLEN, and
  derived-SD fields.
- `menvcfg` and `senvcfg` now expose no optional environment-feature bits in
  the RV64GC baseline. FIOM, Svpbmt, Svadu, Sstc, cache-block controls, pointer
  masking, landing-pad, shadow-stack, and double-trap controls read back as
  zero because those extensions are not implemented. Nonzero set/clear CSR
  forms now also retire and still read back zero, pinning these CSRs as
  writable WARL-zero rather than address-encoded read-only storage.
- `pmpcfg0` and `pmpaddr0` now read as zero because PMP access enforcement is
  not implemented. The OpenSBI smoke still boots and now reports `PMP Count: 0`,
  which is more accurate than accepting protection rules the emulator would
  ignore. Nonzero set/clear CSR forms now also retire and still read back zero,
  matching the same writable WARL-zero model.
- `mnstatus` is no longer exposed as compatibility storage. It belongs to the
  optional Smrnmi resumable-NMI extension, which is not implemented in the
  RV64GC baseline, so read and write attempts now trap as illegal instruction.
- `mconfigptr` is now exposed as the mandatory read-only machine information
  CSR and returns zero, indicating that this platform has no standard
  configuration data structure and relies on the existing device-tree path.
  `misa` now behaves as a fixed WARL machine ISA CSR for the current runner
  profile: `CSRRW[I]`, nonzero `CSRRS[I]`, and nonzero `CSRRC[I]` retire but
  read back the configured ISA. Read-only
  write-trap coverage samples the exposed read-only machine information set:
  `mvendorid`, `marchid`, `mimpid`, `mhartid`, `mconfigptr`, plus the read-only
  `time` counter.
- LR/SC reservations are now shared across SMP runners as per-hart physical
  byte ranges. Normal stores, successful SC stores, and AMO writes invalidate
  every overlapping reservation, so another hart's store to the same word or to
  the upper half of an LR.D reservation makes the original hart's later SC
  fail. Virtio-blk guest-visible DMA/status/used-ring writes now use the same
  reservation-aware device-store path, so device writes to bytes accessed by LR
  also make the later SC fail. Successful `LR.W`/`SC.W` and `LR.D`/`SC.D`
  pairs are covered, failed `SC.W`/`SC.D` without a live reservation are
  both covered as nonzero-status, no-store operations, and a failed mismatched
  `SC.W` is now covered as consuming the hart reservation before any later
  matching `SC.W` can succeed. A later `LR.W` to a different address is also
  covered as replacing the previous reservation, so SC cannot pair with an
  older LR in program order. The reservation-set model is documented as the
  exact physical byte range loaded by the most recent LR, and mixed-width SC
  attempts at the same address are covered as deterministic failures under that
  model. The xRET policy is explicit and covered for `MRET`: trap returns do
  not implicitly clear live reservations, which is permitted by the privileged
  spec. Compressed integer instructions between `LR.W` and `SC.W` are now
  covered as preserving the single-hart reservation when no store or device
  write intervenes, pinning the C/A constrained-sequence boundary. Signed AMO
  min/max coverage now includes both
  `AMOMIN.W` and full-width `AMOMIN.D`/`AMOMAX.D`
  comparisons across the sign boundary, and unsigned AMO.D min/max coverage
  now pins `AMOMINU.D`/`AMOMAXU.D` on the same bit patterns. The remaining
  A-extension audit is true `aq`/`rl` ordering behavior and
  forward-progress/eventual-success behavior beyond the current interpreter
  scheduler.

## Known Blockers

- Local `moon test` now expects build artifacts under `_build/riscv-tests-src/isa`; run `./scripts/build-riscv-tests-official.sh` first if they are missing.
- The built upstream `*-p-*` survey currently stands above the original RV32
  checkpoint. The local RV64GC-relevant source suites `rv64ui`, `rv64um`,
  `rv64ua`, `rv64uc`, `rv64uf`, and `rv64ud` are now treated as a hard
  completion gate: every locally available/buildable source row must be present
  in the manifest as `gating`, and `rv32ui_gating_test.mbt` now checks that
  source-tree-to-manifest coverage mechanically. Broader official coverage for
  optional non-baseline extensions remains survey-only until those extensions
  become part of the active target.
- The official QEMU cross-check path remains RV32-only; RV64 system-emulator cross-checking is still deferred.
- The post-Linux compatibility target is fixed, and the practical Linux-driven `F/D` path is usable. All current upstream `rv64uf` and `rv64ud` official rows are now gated, while broader strict FP work such as non-RNE arithmetic and deeper fused-rounding/flag audits remains tracked in Task 0063. The first `V` state/CSR slice, `vsetvl*` execute path, first fractional LMUL path, first narrow arithmetic slice, first narrow unit-stride memory slice, first masked arithmetic slice, first widening integer add/subtract slice, first `LMUL=2` unit-stride memory path, first strided `e32` memory path, first indexed `e32` memory paths, first unit-stride segment `e32` memory path, vector mask load/store, first unit-stride fault-only-first load path, first masked vector memory path for the current unit-stride/strided/indexed/fault-only-first forms, first `LMUL=2` add/move arithmetic path, first `LMUL=4` arithmetic/memory group path, first `LMUL=8` arithmetic/memory group path, first vector subtract and reverse-subtract paths, first vector multiply, multiply-high, divide, and remainder paths, first vector bitwise logical path, first vector min/max path, first vector shift path, first vector compare mask-result path, first vector mask logical path, first vector mask population/first-set path, first vector mask prefix/only-first path, first vector iota/index path, first vector compress/permutation path, first vector gather/permutation path, first vector slide/permutation path, first vector slide1/permutation path, first whole-register vector move path, and first vector merge/move path are now in place. Broader segment memory forms, the widening `.wv/.wx` forms, narrowing arithmetic, reductions, vector floating-point operations, restart semantics, full vector policy behavior, and richer Linux-oriented ISA coverage remain open.
- The browser host now builds as a Wasm artifact and the bare-metal browser smoke path is green. The Alpine rootfs path currently defaults to `wasm-gc`, while plain `wasm` remains available via `BROWSER_TARGET=wasm`. The browser runtime boundary is split between guest image construction, browser runtime state, Wasm exports, and JS UI glue. The browser can load OpenSBI, DTB, kernel, and initrd artifact bytes through a manifest, switch to the Linux artifact guest, expose explicit long-run scheduling, report boot marker progress, and reach initramfs unpacking in browser Wasm.
- JS string interop is no longer required for the active browser artifact; UART input and Linux artifacts use byte-oriented exports.
- The first `simmerv`-inspired performance slice is in place: decode cache, Sv39 translation cache, cache counters in tests/browser UI, and Linux boot timing observations. Basic-block/uop caching and a larger common-instruction fast executor are intentionally left as follow-up work.
- The Linux boot ABI contract is pinned to the upstream Linux RISC-V boot requirements: kernel entry uses `a0` for hart id, `a1` for DTB address, `satp = 0`, and RV64 kernel Image placement at a 2 MiB PMD boundary.
- Future Linux-specific compatibility checks should start from the upstream Linux RISC-V architecture documentation index, especially boot image header, VM layout, hwprobe, and vector support.
- MoonBit refactor slices split FP execution into `riscv_fp.mbt`, vector execution into `riscv_vector.mbt`, vector memory execution into `riscv_vector_memory.mbt`, vector move/merge helpers into `riscv_vector_move.mbt`, vector permutation helpers into `riscv_vector_permutation.mbt`, vector multiply helpers into `riscv_vector_multiply.mbt`, and vector divide helpers into `riscv_vector_divide.mbt`; vector memory, permutation, and multiply/divide-specific dispatch now live next to their helpers, keeping `riscv_vector.mbt` below the 2k-line guideline and the central dispatcher narrow.
- Browser Wasm Linux boot is complete, and the mainline has resumed at `0048`. Alpine rootfs browser boot remains active as an integration gate for real Linux behavior.
- The active goal is ordinary Linux usability with I/O and full-rootfs progress ahead of broad ISA backlog work. Use the upstream Linux RISC-V architecture documentation, RISC-V ISA specs, and virtio documentation when a precise rule matters. Web specs are fine for readable chapter navigation; the local PDFs under ignored `docs/specs/` are useful for reproducible on-host checks when present, but they are not versioned source-of-truth artifacts. Prefer console/native Linux probes for routine integration evidence; browser checks are optional per-slice, but the one-minute browser Linux usability baseline remains the performance floor for browser-facing work. Backend choice between `wasm` and `wasm-gc` remains measurement-driven.
- Initial Alpine probing favors `wasm-gc` for the browser default: it produces a smaller artifact and reaches the same initramfs-unpack point faster than plain `wasm`. Plain `wasm` remains available with `BROWSER_TARGET=wasm`.
- Alpine bring-up now uses a practical tiny initramfs profile by default. A static `/init` writes the injected marker through `/dev/kmsg`, then runs `/bin/sh -c 'echo riscv-mbt Alpine shell alive > /dev/kmsg; exec /bin/sh'`. QEMU, riscv-mbt native `xxlong`, and browser `wasm-gc` now reach `riscv-mbt Alpine initramfs ready`, `riscv-mbt Alpine shell alive`, and the BusyBox `/ #` prompt. Browser `wasm-gc` also accepts UART input after the prompt and returns `browser-input-ok` from `echo browser-input-ok`. The browser scheduler now runs 262,144 Linux steps/tick and throttles DOM sync to every 16 ticks; `python3 tools/browser_linux_probe.py --serve-dir _build/browser-demo --alpine-functional-smoke --budget-ms 45000 --wall-timeout 180` is the current functional Linux usability gate and checks `/proc`, `/sys`, file creation/readback, directory creation, pipe/grep, `uname -m`, `/proc/cpuinfo`, and `linux-functional-ok`. The latest functional smoke after the first vector subtract slice reached the marker at 360,710,144 guest steps and `wall=0:52.04` on this host.
- The latest console/native Alpine probe after the first vector min/max slice reached the BusyBox `/ #` prompt with `moon run --target native cmd/alpine_probe xxlong`: `outcome=alpine-shell-prompt`, `steps=357000000`, `contains_linux_version=true`, `contains_run_init=true`, and `contains_alpine_shell_prompt=true`.
- The console/native Alpine probe can now inject a command after the BusyBox prompt and wait for an expected UART marker. The latest functional command proof uses octal `printf` for the expected marker so command echo cannot satisfy it. `moon run --target native cmd/alpine_probe xxlong --functional-smoke` reached `outcome=console-command`, `steps=413000000`, `functional_smoke=true`, `shell_command_sent=true`, `shell_expect_seen=true`, `file-ok`, `pipe-ok`, `riscv64`, and `linux-functional-ok`.
- Full rootfs should not be modeled as initrd-only. The short-term gate remains initrd-based because it is already reliable, but the medium-term full-rootfs path is a contract-shaped `virtio,mmio` `virtio-blk` device with a raw Alpine root filesystem image.
- The optional `virtio,mmio` block-device contract slice is in place: `virtio_blk_machine_config()` enables the MMIO window at `0x10001000`, the DTB builder can emit a `virtio,mmio` node, and the device exposes identity/status/queue registers with shared SMP state. `QueueNotify` now consumes split virtqueue read and write requests, supports multiple data descriptors before the final status descriptor, copies bytes between guest memory and `Runner::load_virtio_blk_disk` backing, writes the used ring/status byte, and raises PLIC source 1. PLIC external interrupt reflection now includes virtio-blk, not only UART. The Alpine artifact scripts now build `_build/alpine-rootfs-riscv64.ext4`, extract the matching `linux-lts` kernel/modules as uncompressed `.ko` files, include the virtio/ext4 dependency modules and `switch_root` applet, replace the minirootfs `openrc` inittab with a BusyBox-init inittab, and emit `_build/minimal-alpine-virtio.dtb`. `moon run --target native cmd/alpine_probe xlong --rootfs-smoke` reaches `EXT4-fs (vda): mounted filesystem ... ro` and `rootfs-mount-ok` at 603,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --switch-root-smoke` goes one step further: it mounts `/dev/vda`, mounts `/proc`, `/sys`, and `/dev` under the new root, calls `switch_root /mnt/root /bin/busybox sh -c ...`, and reaches `switch-root-ok` at 612,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --post-init-smoke` reaches ordinary Alpine init plus a writable rootfs-side serial shell at 643,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --post-init-session-smoke` proves a multi-command post-init session at 655,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --post-init-busybox-smoke` proves broader BusyBox usability at 710,000,000 guest steps and now covers `awk`, text pipelines, filesystem/link/search commands, `dd`, `head`, `tail`, `xargs`, `env`, `ps`, `date`, `sleep`, and `sync`. `moon run --target native cmd/alpine_probe xlong --post-init-shell-smoke` proves rootfs-side shell script/job/redirection behavior at 662,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --post-init-system-smoke` proves rootfs-side `/proc`, PID 1, identity, filesystem administration, permissions, cleanup, and sync behavior at 676,000,000 guest steps.
- The initramfs builder now has `ALPINE_INIT_STYLE=auto-root`, which loads virtio/ext4 modules, mounts `/dev/vda`, mounts the target `/proc`, `/sys`, `/dev`, `/run`, and `/tmp`, then `switch_root`s to `/sbin/init` without requiring UART-injected mount commands. The default generated initrd remains the existing static shell style, and non-static init styles are also saved under style-qualified artifact names such as `_build/alpine-initramfs-riscv64-auto-root.cpio` and `_build/minimal-alpine-virtio-auto-root.dtb`. `moon run --target native cmd/alpine_probe xlong --initrd _build/alpine-initramfs-riscv64-auto-root.cpio --dtb _build/minimal-alpine-virtio-auto-root.dtb --auto-root-smoke` reaches `outcome=console-command`, `auto_root_smoke=true`, `shell_command_sent=false`, `post_init_command_sent=false`, `contains_auto_root_marker=true`, and `post-init-ready` at 591,000,000 guest steps. This proves the rootfs handoff can be initramfs-driven rather than serial-command-driven.
- Auto-root can now run a rootfs-side functional command after the automatic handoff. `moon run --target native cmd/alpine_probe xlong --initrd _build/alpine-initramfs-riscv64-auto-root.cpio --dtb _build/minimal-alpine-virtio-auto-root.dtb --auto-root-post-init-smoke --post-init-command-step-budget 120000000` reaches `outcome=console-command`, `auto_root_post_init_smoke=true`, `shell_command_sent=false`, `post_init_command_sent=true`, `post_init_command_index=1`, and `post-init-functional-ok` at 610,000,000 guest steps. The UART tail shows rootfs-side tmpfs/rootfs file writes, `sync`, `riscv64`, and `post-init-functional-ok` after the auto-root `switch_root`.
- `cmd/alpine_probe --auto-root-handoff` now turns the existing post-init probes into auto-root probes: it selects `_build/alpine-initramfs-riscv64-auto-root.cpio` and `_build/minimal-alpine-virtio-auto-root.dtb` by default, sends no initial UART root-handoff command, waits for rootfs-side `post-init-ready`, then injects the selected post-init command sequence. `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-system-smoke --post-init-command-step-budget 120000000` reaches `outcome=console-command`, `auto_root_handoff=true`, `shell_command_sent=false`, `post_init_command_sent=true`, `post_init_command_index=3`, and `post-init-system-ok` at 642,000,000 guest steps. `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-busybox-smoke --post-init-command-step-budget 160000000` reaches `outcome=console-command`, `auto_root_handoff=true`, `shell_command_sent=false`, `post_init_command_index=4`, and `post-init-busybox-ok` at 681,000,000 guest steps. This moves the `/proc`, PID 1, identity, rootfs file management, permissions, cleanup, sync, and broader BusyBox applet proofs off the serial-command-driven `switch_root` path.
- Package-manager usability now has a practical standard-command proof. The rootfs builder downloads Alpine `apk-tools-static` from the current riscv64 main APKINDEX, keeps Alpine's original dynamic binary as `/sbin/apk.dynamic`, installs `/sbin/apk.static`, and maps `/sbin/apk` to the static apk copy by default. `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 80000000 --post-init-apk-static-smoke` reaches `outcome=console-command`, `post_init_apk_static_smoke=true`, `post_init_command_index=4`, `shell_expect_seen=true`, and `post-init-apk-static-ok` at 755,000,000 guest steps. The smoke proves ordinary `/sbin/apk --version`, `/sbin/apk info`, installed package DB lookup for `busybox`, installed package listing, and the `bin/busybox` file listing from the rootfs-side Alpine shell. The dynamic `/sbin/apk.dynamic` path remains a separate loader/performance diagnostic: the staged `--post-init-apk-smoke` reaches `apk-files-ok`, starts `/lib/ld-musl-riscv64.so.1 --list /sbin/apk.dynamic`, prints loader mappings through `libssl.so.3`, then times out before `apk-loader-ok`.
- Offline package installation now works through the standard `/sbin/apk` command for a small local `.apk`: the rootfs builder places `ddate.apk` under `/root/riscv-mbt-apks`, and `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 120000000 --post-init-apk-install-smoke` reaches `outcome=console-command`, `post_init_apk_install_smoke=true`, `post_init_command_index=3`, `shell_expect_seen=true`, and `post-init-apk-install-ok` at 725,000,000 guest steps. The proof runs `/sbin/apk --no-network --allow-untrusted --force-non-repository add /root/riscv-mbt-apks/ddate.apk`, observes `Installing ddate`, then verifies `/sbin/apk info -e ddate`, `/usr/bin/ddate`, and actual `ddate` output. This is not a virtio-net or remote repository proof, but it demonstrates package add, rootfs mutation, trigger execution, and a newly installed userspace binary through the normal apk command name.
- The rootfs builder also lays out a small dependency-aware local repository under `/root/riscv-mbt-apks` and `/root/riscv-mbt-apks/riscv64/`. Instead of copying Alpine's full main `APKINDEX.tar.gz`, it now generates a package-selected local `APKINDEX.tar.gz` for `ALPINE_OFFLINE_APK_PACKAGES`, follows APKINDEX package dependencies and provided `so:` dependencies, and stores both compatibility names like `ddate.apk` and repository names like `ddate-0.2.2-r6.apk`. The local repository, dependency-resolution, and package-persistence probes now use the standard `/sbin/apk` command name for add/info operations. The latest full local-repository proof before that command-name cleanup reached `post-init-apk-local-repo-ok` at 725,000,000 guest steps by installing `ddate` by package name from the local repository and executing it.
- Dependency-resolving local repository installation has a stronger auto-root proof with the default `ALPINE_OFFLINE_APK_PACKAGES="ddate iputils"` rootfs. `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-apk-local-deps-smoke --post-init-command-step-budget 160000000` reaches `outcome=console-command`, `auto_root_handoff=true`, `shell_command_sent=false`, `post_init_apk_local_deps_smoke=true`, `post_init_command_index=3`, `shell_expect_seen=true`, and `post-init-apk-local-deps-ok` at 797,000,000 guest steps. The run uses the standard `/sbin/apk` command after initramfs-driven root handoff, installs `iputils` by name from the local repository, resolves and installs `libcap2`, `iputils-arping`, `iputils-clockdiff`, `iputils-ping`, and `iputils-tracepath`, then verifies `iputils`, `iputils-ping`, `libcap2`, `bin/ping`, and `/bin/ping -V`.
- Installed package runtime behavior now has a loopback network proof. `moon run --target native cmd/alpine_probe xlong --auto-root-handoff --post-init-iputils-loopback-smoke --post-init-command-step-budget 180000000` reaches `outcome=console-command`, `auto_root_handoff=true`, `post_init_iputils_loopback_smoke=true`, `post_init_command_index=4`, and `post-init-iputils-loopback-ok` at 721,000,000 guest steps. The proof installs `iputils` through the standard offline `/sbin/apk`, brings `lo` up with BusyBox `ifconfig`, observes `inet addr:127.0.0.1`, and runs package-provided `/bin/ping -c 1 -W 1 127.0.0.1` with one received ICMP reply and `0% packet loss`. The new `post_init_command_trace` shows the package install phase dominates this run: `cmd2` takes 104,000,000 guest steps, while loopback setup and ping take 10,000,000 and 7,000,000 guest steps.
- Installed package persistence has a host-image proof pair. After copying `_build/alpine-rootfs-riscv64.ext4` to `_build/alpine-rootfs-riscv64-apk-persist-probe.ext4`, the write half installs `iputils`, syncs, reaches `apk-persistence-write-ok`, and writes the mutated disk image back to the host path at 753,000,000 guest steps. The current auto-root saved image read proof reboots `_build/alpine-rootfs-riscv64-apk-auto-root-persist-probe.ext4`, observes ext4 journal recovery, and reaches `apk-persistence-read-ok` at 690,000,000 guest steps. It verifies `iputils`, `iputils-ping`, `libcap2`, the installed `bin/ping` file list, `ifconfig lo up`, `inet addr:127.0.0.1`, and package-provided `/bin/ping -c 1 -W 1 127.0.0.1` with one received ICMP reply and `0% packet loss`. The current persistence probe command strings use `/sbin/apk` for add/info checks and now prove installed package runtime behavior after a host-saved virtio-blk image reboot.
- Native Alpine probe output now includes virtio-blk read/write request and byte counters, plus per-post-init-command deltas. It also reports the read window (`first`, `min`, `max_end`, `last`, `last_end`) and read-pattern counters (`sequential`, `forward-gap`, `backward`) with a per-command pattern delta. Use these counters before adding another long wait: a mostly sequential pattern points at storage/read-ahead work, many backward reads point at cache shape or metadata churn, and flat deltas point back toward CPU-side loader, relocation, syscall, or ISA behavior. The dynamic `/sbin/apk.dynamic` loader diagnostic still times out before `apk-loader-ok` and reports `post_init_command_virtio_delta=867 read-req/3581952 read-bytes 0 write-req/0 write-bytes` plus `post_init_command_read_pattern_delta=840 sequential 16 forward-gap 11 backward`. That means loader-time block I/O is still active and mostly sequential during the 20,000,000-step command window; treat that path as dynamic-loader/library-read performance work, not as a missing-file failure or a flat CPU spin.
- Virtio-blk read copies now use a descriptor-level Bus copy helper instead of checking and storing one guest byte at a time. This preserves the previous zero-fill behavior for reads past the backing image and adds a regression for that behavior. Rerunning the staged `apk` diagnostic after this change still reports `outcome=post-init-command-timeout`, `post_init_command_index=2`, `post_init_command_virtio_delta=868 read-req/3577856 read-bytes`, and no `apk-loader-ok`, so this is a host-side copy-shape cleanup rather than a proven guest-step package-manager improvement.
- Virtio-blk now has a 64 KiB request-level read-ahead cache with explicit invalidation on disk load and guest writes. After the rootfs builder stopped feeding `apk.static` the full Alpine main APKINDEX for the local repository, the local-repository `apk add ddate` proof reports `virtio_blk_read_cache=1350 hits/138 misses` and no post-command virtio reads in the final verification command. The dependency-resolving `apk add iputils` proof reports `virtio_blk_read_cache=1383 hits/139 misses` and `17 write-req/185344 write-bytes`, showing real rootfs package writes. The read-ahead cache remains useful telemetry/storage cleanup, but the decisive package-manager improvement was reducing the local repository metadata shape before probing again.
- Virtio-blk write copies now mutate the backing disk as an `Array[Byte]` and expose a `Bytes` snapshot only at host persistence boundaries, instead of converting the whole rootfs image to an array and back for every write descriptor. A Bus-level guest-to-array copy helper bounds both sides once per descriptor. The targeted `virtio-blk*` tests now cover read/write request behavior, read-ahead invalidation, and the in-place write helper. A purposeful write-heavy integration rerun, `moon run --target native cmd/alpine_probe xlong --post-init-command-step-budget 160000000 --post-init-apk-local-deps-smoke`, still reaches `post-init-apk-local-deps-ok` with `outcome=console-command`, `steps=832000000`, `virtio_blk=1518 read-req/6050816 read-bytes 17 write-req/185344 write-bytes`, and `virtio_blk_read_cache=1379 hits/139 misses`. Treat this as a host-side write-path cleanup and regression proof, not as a guest-step package-manager breakthrough.
- A simple direct-mapped 512-byte sector cache was tried locally and not kept: the staged `apk` diagnostic reported only `4 hits/10118 misses` and still timed out before `apk-loader-ok`. Do not add that cache shape back; the useful next storage slice is Linux-relevant readahead or request coalescing based on the observed sequential multi-megabyte read stream.
- Host Wasm SIMD / `v128` is not used yet. The current guest `V` implementation interprets RISC-V vector operations with scalar MoonBit register-element helpers. MoonBit 0.10 introduced an experimental built-in `V128` type, but the official release notes still describe efficient standard-library operations as future work, so any `v128` experiment should remain measured and isolated before it touches the Linux-facing execution path. `moon bench` now includes `vector_add_lmul2_loop_100k_steps` as the scalar baseline for that work; the first baseline measured `31.18 ms +/- 304.25 us`.

## Read Next

- [Roadmap](roadmap.md)
- [Implementation Notes](guides/implementation-notes.md)
- [Browser Wasm Linux Boot milestone](milestones/12-browser-wasm-linux-boot.md)
- [Task 0049](tasks/0049-browser-wasm-smoke-host.md)
- [Task 0050](tasks/0050-browser-runtime-boundary-refactor.md)
- [Task 0051](tasks/0051-browser-linux-artifact-loader.md)
- [Task 0052](tasks/0052-browser-long-run-refactor.md)
- [Task 0053](tasks/0053-browser-one-hart-linux-boot.md)
- [Task 0054](tasks/0054-browser-linux-observability-refactor.md)
- [Task 0055](tasks/0055-browser-plain-wasm-backend.md)
- [Task 0056](tasks/0056-simmerv-inspired-cache-performance.md)
- [Task 0057](tasks/0057-moonbit-refactoring-pre-0048.md)
- [Task 0058](tasks/0058-alpine-rootfs-browser-boot.md)
- [Task 0059](tasks/0059-console-alpine-linux-probe.md)
- [Task 0060](tasks/0060-full-rootfs-io-strategy.md)
- [Task 0061](tasks/0061-full-rootfs-usability-hardening.md)
- [Task 0062](tasks/0062-rootfs-init-service-usability.md)
- [Performance milestone](milestones/10-verification-debug-performance.md)
- [Extensions milestone](milestones/09-extensions-a-fd-v-h.md)
- [Task 0018](tasks/0018-extensions-a-fd-v-h.md)
- [Task 0048](tasks/0048-broader-vector-memory-and-lmul-slice.md)
- [Task 0047](tasks/0047-masked-and-broader-vector-execute-slice.md)
- [Task 0046](tasks/0046-first-vector-memory-slice.md)
- [Task 0045](tasks/0045-first-vector-arithmetic-slice.md)
- [Task 0044](tasks/0044-vsetvl-and-first-vector-execute-slice.md)
- [Task 0043](tasks/0043-vector-extension-evaluation.md)
- [Task 0042](tasks/0042-post-fd-closure.md)
- [Task 0041](tasks/0041-d-extension-bring-up.md)
- [Task 0009](tasks/0009-rv32-supervisor-sv32.md)
- [ADR 0006](adr/0006-browser-wasm-linux-boot-goal.md)
- [ADR 0007](adr/0007-browser-plain-wasm-backend.md)
- [ADR 0008](adr/0008-browser-wasm-gc-for-alpine-boot.md)
- [ADR 0009](adr/0009-bounded-uop-cache-safety.md)
- [ADR 0001](adr/0001-rv32i-first.md)
- [ADR 0005](adr/0005-post-linux-compatibility-profile.md)
- [ADR 0003](adr/0003-milestone-spine.md)
