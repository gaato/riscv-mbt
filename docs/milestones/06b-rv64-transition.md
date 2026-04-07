# Milestone 06B: RV64 Transition

## Purpose

Pivot from the 32-bit learning path to the 64-bit general-purpose path before going deep on Linux-oriented platform work.

## Target Instructions / Features

- RV64 register width and sign-extension rules
- Carry-forward of `M`, `C`, `Zicsr`, `Zifencei`, and minimal privileged behavior
- RV64-specific load/store width and shift semantics

## Non-Goals

- Full Linux boot platform
- Browser UI

## Exit Criteria

- RV64 becomes the default path for Linux-oriented work
- RV64 width and sign-extension edge cases have dedicated tests
- RV32 behavior remains understandable and regression-tested

## Required Tests

- RV64 execute tests for width, sign extension, and shifts
- Regression tests proving the widened path still honors the carried-over features

## Prerequisites For Next Milestone

- Stable 64-bit core and privileged baseline
