# Milestone 08: Post-Linux Compatibility Target

## Purpose

Define what “compatible after Linux boots” actually means so future extension work stops depending on ad-hoc decisions.

## Target Instructions / Features

- A documented compatibility target such as `RV64G`, `RV64GC`, or a profile-aligned subset
- A written mapping from target software expectations to planned emulator features

## Non-Goals

- Implementing every extension immediately
- Browser hosting

## Exit Criteria

- The compatibility target is explicit in docs and ADRs
- Later extension work can cite that target directly

## Required Tests

- No new execution tests are required beyond those needed to support the chosen target definition

## Prerequisites For Next Milestone

- A fixed compatibility target
