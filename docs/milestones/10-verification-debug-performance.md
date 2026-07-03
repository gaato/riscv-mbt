# Milestone 10: Verification, Debug, And Performance

## Purpose

Move from “featureful” to “mature” by making the emulator verifiable, observable, and measurable.

## Target Instructions / Features

- Deeper `riscv-tests` integration
- Architectural conformance suites such as `riscv-arch-test`
- Trace and debug facilities
- Performance measurement and regression tracking

## Non-Goals

- New ISA work for its own sake

## Exit Criteria

- Regressions are caught by layered test suites
- Failures are inspectable through tracing or debug support
- Performance changes can be measured deliberately

## Required Tests

- Regression-suite integration tests
- Smoke tests for trace or debug hooks
- Benchmark or performance-baseline scripts

## Prerequisites For Next Milestone

- Stable enough core behavior to measure and observe meaningfully

## Current Checkpoint

- A first `simmerv`-inspired cache performance slice is in place.
- Decode caching keeps fetch/decode separate while avoiding repeated decode on hot instruction addresses.
- Sv39 translation caching keeps page-table walking behind the existing translation boundary while avoiding repeated walks for hot pages.
- Cache counters are visible in native tests and the browser status panel.
- Native and browser Linux boot proofs now record cache hit/miss observations.
- Full basic-block/uop caching and a broader common-instruction fast executor remain future work because they require a larger execution-boundary refactor.
- A MoonBit refactor slice split FP and vector execution into dedicated files, kept `Runner::step` as the dispatcher, reduced `riscv_execute.mbt` below the 2k-line guideline, and removed current `moon check` warnings.
