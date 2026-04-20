# Milestone 09: Extensions In Priority Order

## Purpose

Extend the post-Linux emulator in software-value order rather than simply by spec adjacency.

## Target Instructions / Features

- `F`, then `D`
- Any remaining compatibility gaps required by the chosen profile
- `V`
- `H`

## Non-Goals

- Treating every extension as equally urgent

## Exit Criteria

- Extension work follows an explicit order tied to the chosen compatibility target
- Each extension family arrives with dedicated tests and documentation updates

## Required Tests

- Extension-specific conformance and regression tests for each family as it lands

## Prerequisites For Next Milestone

- Stronger verification and observability infrastructure

## Current Checkpoint

- This is now the active mainline milestone
- The chosen baseline is `RV64 Linux Profile v1`
- The extension phase is now staged as:
  1. scalar `F`
  2. `D`
  3. post-`F/D` closure and next-family handoff
  4. `V` evaluation and scope definition
  5. `H` only after `V`
- Scalar `F` and `D` are now both in place with the current constrained host-IEEE implementation
- No additional required compatibility gaps are currently open for `RV64 Linux Profile v1`
- The next active task is `0043` `V` evaluation
