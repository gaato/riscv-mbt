# ADR 0009: Gate Bounded Uop Caching Behind Provenance And Invalidation

## Status

Accepted

## Context

Task 0058 needs browser Alpine boot to move from proof-of-boot toward a usable wall-clock time. Decode caching and Sv39 translation caching are already in place, and a private bounded block cache prototype showed the expected synthetic speedup: `tight_add_loop_100k_steps` improved to about `2.10 ms`.

That prototype was not safe for the Linux path. It stalled before serial output when enabled in M-mode, still stalled before Linux output when M-mode was excluded, and stalled after OpenSBI when limited to Sv39-active S-mode.

The next attempt must treat uop/basic-block caching as an instruction-fetch and address-translation feature, not as a shortcut around `Runner::step`.

## Sources

- Linux RISC-V boot requirements: <https://docs.kernel.org/arch/riscv/boot.html>
- Linux RISC-V architecture index: <https://docs.kernel.org/arch/riscv/index.html>
- RISC-V Zifencei instruction-fetch fence: <https://docs.riscv.org/reference/isa/v20260120/unpriv/zifencei.html>
- RISC-V privileged architecture `SFENCE.VMA` semantics: <https://riscv.github.io/riscv-isa-manual/snapshot/privileged/>
- `simmerv` performance reference: <https://deepwiki.com/tommythorn/simmerv>

## Decision

Do not reintroduce a Linux-path bounded uop cache until the implementation has explicit provenance, invalidation, timing, and verification gates.

The cache key must include at least:

- guest virtual PC page and in-page PC
- translated physical fetch page
- raw fetched instruction words or a generation that proves the bytes are unchanged
- current privilege mode
- XLEN
- `satp`
- effective fetch permission context

The cached block must stop before any instruction that can change the execution environment or cached provenance. The initial allowed subset should be no broader than simple integer register operations plus direct branches and jumps whose target stays inside the same validated block. The first Linux-path version must not include loads, stores, AMOs, CSR instructions, `FENCE`, `FENCE.I`, `SFENCE.VMA`, `MRET`, `SRET`, `WFI`, traps, MMIO, floating-point, or vector instructions.

Block execution must preserve the current per-instruction timing boundary. `Runner::step` currently advances CLINT time and checks pending interrupts before every instruction. A block executor must either call the same timer and interrupt path before each uop or prove an equivalent per-instruction result. A block must exit immediately when an interrupt, trap, privilege change, page fault, or unsupported instruction would have occurred in scalar stepping.

Invalidation is conservative by default:

- Flush cached blocks on `FENCE.I`.
- Flush cached blocks and translation-derived block provenance on `SFENCE.VMA`.
- Flush cached blocks on any accepted `satp` write.
- Flush cached blocks on host-side image/program writes.
- Until code-page tracking exists, flush cached blocks on guest stores that target RAM rather than trying to prove they do not affect executable bytes.

Targeted invalidation can be added later, but only after the cache records enough virtual page, physical page, ASID, and generation data to make the narrower flush auditable.

## Consequences

- A bounded uop cache is still the most promising next core-side performance slice for Task 0058, but it must land behind a small, testable safety surface.
- The first implementation can over-flush. Correctness and Linux boot stability are more important than retaining every synthetic benchmark gain.
- `simmerv` remains a useful shape reference, especially for basic-block/uop caching, split instruction/data translation caches, and event scheduling, but this repository should not copy its invalidation policy without matching local execution boundaries.
- The browser default remains `wasm-gc` for Alpine boot until a fresh backend comparison says otherwise.

## Verification

Before a uop cache is kept, all of these must pass or be recorded as an explicit blocker:

- A scalar equivalence unit test for a tight register-only loop.
- A regression proving `FENCE.I` invalidates cached instruction bytes.
- A regression proving `SFENCE.VMA` and `satp` writes invalidate translation-derived cached blocks.
- `moon check`.
- `moon test`.
- `moon bench` with the tight-loop benchmark.
- Task 0015 Linux boot smoke.
- Task 0058 browser Alpine interactive smoke:

  ```bash
  ./scripts/build-browser-demo.sh
  python3 tools/browser_linux_probe.py \
    --serve-dir _build/browser-demo \
    --alpine-interactive-smoke \
    --budget-ms 30000 \
    --wall-timeout 180
  ```
