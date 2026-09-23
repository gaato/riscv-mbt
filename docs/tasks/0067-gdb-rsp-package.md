# Task 0067: `gdb_rsp/` Package

## Background

Nothing in the repo lets a debugger attach to the guest. The first GDB slice
is the transport-agnostic GDB Remote Serial Protocol layer as a reusable
sub-package under [ADR 0012](../adr/0012-reusable-subpackages-and-modules.md):
pure MoonBit, no I/O, testable with byte strings.

## Scope

New package `gdb_rsp/` (`gaato/riscv_mbt/gdb_rsp`, alias `@gdb_rsp`):

- `gdb_rsp/moon.pkg` with no imports.
- `framing.mbt`: `Framer` with `feed(Bytes)`, `next_packet() -> Bytes?`
  (payload between `$` and `#xx`, checksum verified, `}` escapes decoded),
  `next_interrupt() -> Bool` (a bare `0x03` byte), `take_output() -> Bytes`
  for `+` / `-` acks, and `set_no_ack(Bool)`.
- `packet.mbt`: `Command` enum and `parse(Bytes) -> Command` covering
  `qSupported`, `qAttached`, `?`, `g`, `G`, `p n`, `P n=v`, `m addr,len`,
  `M addr,len:hex`, `X addr,len:binary`, `c [addr]`, `s [addr]`,
  `vCont?` / `vCont;c` / `vCont;s` (per-thread suffixes ignored),
  `Z0/Z1 addr,kind` / `z0/z1`, `H`, `T`, `qC`, `qfThreadInfo` /
  `qsThreadInfo`, `qXfer:features:read:target.xml:off,len`, `qRcmd,hex`,
  `D`, `k`, `QStartNoAckMode`, and `Unknown(Bytes)`.
- `target_xml.mbt`: `riscv_rv64_target_xml(csrs : Array[(String, Int)]) -> String`
  producing `org.gnu.gdb.riscv.cpu` (x0..x31 regnum 0..31, `pc` 32,
  bitsize 64), `org.gnu.gdb.riscv.fpu` (f0..f31 regnum 33..64 as
  `ieee_double`, plus `fflags` `frm` `fcsr`), `org.gnu.gdb.riscv.csr`
  entries with regnum `65 + csr`, and `org.gnu.gdb.riscv.virtual` with
  `priv` regnum 4161. These numbers match gdb's `riscv-tdep` so `$satp`
  and `$priv` work without symbols.
- `server.mbt`: `pub(open) trait Target` with `read_reg(Self, Int) -> UInt64?`,
  `write_reg(Self, Int, UInt64) -> Bool`, `read_memory(Self, UInt64, Int) -> Bytes?`,
  `write_memory(Self, UInt64, Bytes) -> Bool`, `insert_breakpoint(Self, UInt64) -> Bool`,
  `remove_breakpoint(Self, UInt64) -> Bool`, `target_xml(Self) -> String`,
  `g_packet_reg_count(Self) -> Int`, `monitor(Self, String) -> String`.
  `Server[T : Target]` with `new(T)`, `feed(Bytes)`, `take_output() -> Bytes`,
  `take_run_request() -> RunRequest?` where
  `RunRequest = Continue | Step | Halt | Detach | Kill`, and
  `report_stop(StopReason)` with `StopReason = Breakpoint | Step | Interrupt | Trap(Int)`
  emitting `S05` / `S02` / `Sxx`. `qSupported` replies
  `PacketSize=4000;qXfer:features:read+;swbreak+;hwbreak+;vContSupported+;QStartNoAckMode+`.
  `g` returns `g_packet_reg_count` registers as 16-hex-digit little-endian
  words; other registers are served by `p`. Unknown packets reply with an
  empty packet. `E01`-style errors for failed target calls.
- `README.mbt.md` with a short usage sketch and tests in
  `framing_test.mbt` and `server_test.mbt` using a fake `Target`.

## Tests (write first)

- framing decodes `}` escapes and rejects a bad checksum (replies `-`)
- `qSupported` reply text
- `g` reply from a fake target with 33 registers is 528 hex characters
- `m` / `M` round trip through fake memory; `X` binary form with escapes
- `Z0` / `z0` reach the target and reply `OK`
- `c` yields `Continue`, then `report_stop(Breakpoint)` emits `$S05#b8`
- `vCont;s` yields `Step`; `vCont?` lists `vCont;c;s`
- a `0x03` byte between packets yields `Halt`
- `qXfer:features:read:target.xml:0,fff` pages with `l` / `m` prefixes
- `p 41` (satp is 65 + 0x180) maps to `read_reg(449)`

## Validation (Claude)

- `moon check --target native`, `moon check --target wasm-gc`
- `moon test --target native -p gaato/riscv_mbt/gdb_rsp`
- `moon info --target native` (review `gdb_rsp/pkg.generated.mbti`), `moon fmt`, `git diff --check`

## Status

- `doing`
