# Task 0018: Add Post-Linux Extensions In Priority Order

## Background

Once compatibility goals are explicit, extension work should proceed in a deliberate order instead of opportunistically.

## Work

- Bring up scalar `F` first as the next required extension family for `RV64 Linux Profile v1`
- Follow with `D`
- Close any remaining compatibility gaps required by the chosen profile
- Evaluate and add `V`
- Evaluate and add `H`

## Acceptance Criteria

- Extension order is tied to software value, not just spec completeness
- Each extension family arrives with targeted tests and updated milestone docs

## Related Milestone

- `Extensions: A, F/D, V, H`

## Dependencies

- [Task 0017](0017-post-linux-compatibility.md)

## Status

- `doing`

## Progress Notes

- This task is now the active mainline follow-up after the compatibility target decision
- `A` is already part of the current implemented baseline and is no longer the first post-Linux extension milestone
- `F`/`D` is the first required extension family for `RV64 Linux Profile v1`
- `F`/`D` is now complete in the current repo contract, with the documented constrained host-IEEE implementation
- There are no additional required compatibility gaps currently open for `RV64 Linux Profile v1`
- This task now acts as an umbrella for `0040` (`F`), `0041` (`D`), `0042` (post-`F/D` closure), `0043` (the first `V` state/CSR-only slice), `0044` (the first execute-level `V` slice via `vsetvl*`), `0045` (the first vector arithmetic slice), `0046` (the first vector memory slice), `0047` (the first masked arithmetic slice), and `0048` (the next broader vector memory/addressing + `LMUL` slice)
- [ADR 0006](../adr/0006-browser-wasm-linux-boot-goal.md) temporarily moved the mainline to browser Wasm Linux boot; that goal is now complete, so this umbrella resumes at `0048`
