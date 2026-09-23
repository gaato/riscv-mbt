# Milestone 13: Fast, Observable, Networked Linux

## Purpose

Turn the working Linux environment into one that is fast enough to use,
inspectable with standard tools, and connected to the network. Direction set
by [ADR 0011](../adr/0011-no-version-tags-and-new-direction.md).

## Target Features

- Performance of the Linux execution path, native and browser `wasm-gc`,
  measured by the protocol in ADR 0011
- A GDB remote serial protocol stub: `gdb` attaches over TCP, reads and
  writes registers and memory through the guest's current translation,
  sets PC breakpoints, single-steps, and continues, including inside the
  Linux kernel
- A `virtio-net` device and a user-mode NAT stack in MoonBit, so the Alpine
  guest can reach the real internet natively; browser transport later
- Reusable sub-packages per [ADR 0012](../adr/0012-reusable-subpackages-and-modules.md)

## Non-Goals

- A production multi-hart stepping loop
- TLS termination inside the NAT stack
- IPv6
- `V` completion, `riscv-arch-test`, PMP, Debug Mode / `Sdtrig`

## Exit Criteria

- Native `moon bench` copy and spinlock loops at least 1.3x the 2026-09-23
  baseline, and the browser Alpine interactive smoke median wall time improved
- `gdb` attaches to the native Linux guest, stops at an address breakpoint
  from `System.map`, single-steps, and detaches, via `tools/gdb_smoke.py`
- `apk add` from `dl-cdn.alpinelinux.org` succeeds inside the guest through
  `virtio-net` and the MoonBit NAT stack, natively

## Required Tests

- Decode/execute/integration tests as today, plus per-slice failing tests
  named in each task doc
- Sub-package unit tests that need no sockets
- `tools/gdb_smoke.py` and the `--post-init-network-smoke` probe

## Implementation Order

1. Task 0064: docs retarget
2. Task 0065: de-allocate the step hot path
3. Task 0066: word-addressed RAM backing store
4. Task 0067: `gdb_rsp/` package
5. Task 0068: `Runner` debug API and `run_debug`
6. Task 0069: native GDB server and gdb smoke
7. Task 0070: `virtio/` package
8. Task 0071: `virtio-net` device and PLIC N-source generalization
9. Task 0072: DTB node, module staging, init, TX proof
10. Task 0073: `slirp/` L2/L3
11. Task 0074: `slirp/` L4 relays
12. Task 0075: native NAT wiring and real `apk add`
13. Task 0076: single-translation fetch and fetch-page cache
14. Task 0077: event-driven `mip` and cheap per-step timer
15. Task 0078: RAM-first load/store
16. Task 0079: ADR 0009 block cache (last, optional)
17. Later: browser network transport, browser gdb bridge, `virtio-blk` on `@virtio`

## Current Checkpoint

- Tasks 0064 and 0065 done; Task 0066 is in progress.
- Baseline (2026-09-23, before 0065): native `tight_add_loop_100k_steps` 6.85 ms,
  `spinlock_shape_loop_100k_steps` 15.7 ms; browser Alpine interactive smoke
  reaches the shell response at 373 M guest steps in 95.5 s wall (median of 3).
- After 0065: 3.98 ms, 9.4 ms, and 93.8 s respectively.
