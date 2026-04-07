# ADR 0002: Repo Markdown Is The Source Of Truth

## Context

The project will be worked on by humans plus coding agents across many sessions. Chat history alone is too fragile to preserve intent and state.

## Decision

Keep milestone, task, and current-state information in repo-local Markdown. GitHub Issues mirror that information for collaboration but do not replace it.

## Rationale

- Local docs are always available to coding agents
- Repo diffs show when scope or execution state changes
- Agents can rehydrate context without requiring API calls or issue sync

## Consequences

- Docs must be updated with code changes
- GitHub Issues should link back to the canonical repo docs
