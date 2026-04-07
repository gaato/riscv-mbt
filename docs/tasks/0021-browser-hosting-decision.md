# Task 0021: Decide The Browser Demo Hosting Target

## Background

Browser deployment should not wait until the entire browser milestone is done, but the repository does need one clear hosting decision before deployment-related work starts to accumulate.

At the moment, `Cloudflare Pages` is the recommended default because it fits static browser artifacts first and can later grow into preview-deployment workflows cleanly.

## Work

- Choose the default browser demo hosting target
- Treat `Cloudflare Pages` as the default unless a concrete repo constraint rules it out
- Record why that host was chosen and what it is expected to provide
- Keep the decision lightweight enough that implementation can still wait for a real browser artifact

## Acceptance Criteria

- The hosting target is written down in repo docs
- Future browser deployment work can assume one default platform instead of re-deciding it

## Related Milestone

- `Browser Demo`

## Dependencies

- None

## Status

- `todo`
