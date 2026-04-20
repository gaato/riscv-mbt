# Task 0043: `V` Extension Evaluation And Scope Definition

## Background

With the `F/D` phase closed, the next extension-family decision for the current mainline is `V`. The repo should not jump straight into vector implementation without first fixing the initial scope, execution model assumptions, and verification bar.

## Work

- Define the first concrete `V` slice for this repo
- Record what the initial vector milestone will and will not attempt
- Decide the minimum architectural state and legality-gating changes needed before the first vector instructions land
- Set the follow-up task sequence so `H` remains explicitly after `V`

## Acceptance Criteria

- The repo docs state unambiguously that `V` is the next extension family
- The initial `V` scope is narrow enough to implement without mixing in unrelated platform or hypervisor work
- The handoff from `F/D` to `V` is reflected in `current.md`, milestone 09, and the umbrella extension task

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0042](0042-post-fd-closure.md)

## Status

- `doing`

## Progress Notes

- This is the next active slice after post-`F/D` closure
- The immediate goal is to define a first vector slice before committing to implementation work
