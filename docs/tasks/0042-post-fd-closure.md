# Task 0042: Post-`F/D` Closure

## Background

After `F` and `D` land, the repo should re-check the compatibility target before deciding whether the next extension family is a remaining profile gap, `V`, or `H`.

## Work

- Re-evaluate the gap between the current implementation and `RV64 Linux Profile v1`
- Close the `F`/`D` phase with updated milestone docs and current-state docs
- Hand off to the next extension family in explicit priority order

## Acceptance Criteria

- The repo docs clearly state what `F`/`D` changed in the post-Linux profile
- The next extension-family decision is recorded without ambiguity

## Related Milestone

- `Extensions In Priority Order`

## Dependencies

- [Task 0041](0041-d-extension-bring-up.md)

## Status

- `done`

## Progress Notes

- Scalar `F` and `D` are both in place with the current constrained host-IEEE implementation
- For the current repo contract, `F/D` closes the first required post-Linux compatibility gap for `RV64 Linux Profile v1`
- No additional required profile gaps are currently open in the docs spine; the next mainline extension family is `V`
- `H` remains after `V`, and neither `V` nor `H` is part of the base profile
