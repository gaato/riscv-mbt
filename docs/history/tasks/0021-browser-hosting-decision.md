# Task 0021: Decide The Browser Demo Hosting Target

## Background

Browser deployment should not wait until the entire browser milestone is done, but the repository does need one clear hosting decision before deployment-related work starts to accumulate.

At the moment, `GitHub Pages` is the default because the browser demo is a static artifact, the repository already uses GitHub Actions, and the first smoke deploy does not need Workers or platform-specific services.

## Work

- Choose the default browser demo hosting target
- Treat `GitHub Pages` as the default unless a concrete repo constraint rules it out
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

- `done`

## Progress Notes

- `GitHub Pages` is now the default browser-demo host for this repo
- The decision stays intentionally narrow: publish the static browser artifact first, then evaluate how preview deploys should layer on top of the same GitHub-native workflow
- This choice does not require Linux-in-browser, Workers, or a richer browser product before the first smoke deploy
