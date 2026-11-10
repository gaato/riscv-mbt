# Task 0070: MoonBit 0.10.20 and core/async

Status: done

## Scope

Move the toolchain pin from `0.10.17+d971670cd` to `0.10.20+65efd5b93`, then
replace the registry module `moonbitlang/async@0.22.5` with
`moonbitlang/core/async`, which ships with the toolchain from 0.10.20 on. The
emulator core and the reusable sub-packages are unaffected: only the native
host commands (`cmd/c_sample`, `cmd/official_survey`, `cmd/alpine_probe`) and
the root package's tests used the runtime. Task 0067 and the GDB milestone
remain separate.

## Changes

- `moon.mod` no longer imports `moonbitlang/async`.
- File reads use `@fs.read_text` / `@fs.read_binary`; console output uses
  `@stdio.stdout.text.write`; the alpine_probe console reads lines through one
  `@io.Utf8Reader` over stdin.
- Every package that imports core/async lists the experimental packages it uses
  in `allow-experimental-packages`, as moon requires.
- ADR 0012 and AGENTS.md now name the runtime as `moonbitlang/core/async*`,
  since "only `moonbitlang/core/*`" would otherwise admit it.

## Validation

- `moon check --deny-warn`, `moon fmt --check`, `moon info --target native`
  (no interface change) and `git diff --check` passed.
- Native tests: 618 passed, the same count as on 0.10.17, before and after the
  runtime move. Official ISA ELF inputs were copied from the existing checkout's
  `_build`; its uncommitted work was not copied or modified.
- The three host commands build on native release; `./scripts/build-browser-demo.sh`
  passed.
- A whole-project `moon check --target wasm-gc` fails on the root package's
  async tests before and after this change (core/async does not exist on
  wasm-gc); CI does not run it, and no reusable sub-package exists on main yet.
