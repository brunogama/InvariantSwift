# WORKFLOW.md

## Purpose
Repository workflow rules for coding agents and contributors.

This file defines how to handle issues, branches, pull requests, reviews, and merges.
For code quality and validation rules, follow `RULES.md`.
For repository operating behavior during implementation, follow `AGENTS.md`.

## General Workflow
- Read the full task before acting.
- Prefer understanding the existing code path before proposing structural changes.
- Keep work scoped to the requested task.
- Do not mix implementation, cleanup, and unrelated refactors in the same change unless explicitly requested.

## Issues
- Read the full issue, including comments, before changing code.
- Treat issue comments as part of the requirement unless they clearly contradict the latest user instruction.
- If the issue is underspecified, inspect the relevant code and docs before deciding on the implementation shape.
- Do not close issues unless the user explicitly asked.

## Branching
- Use feature branches for implementation work.
- Keep branch names short and descriptive.

Recommended patterns:
- `feat/<area>-<topic>`
- `fix/<area>-<bug>`
- `refactor/<area>-<topic>`
- `docs/<area>-<topic>`
- `chore/<area>-<topic>`

Examples:
- `feat/sqlite-hnsw-build`
- `fix/vector-distance-null-check`
- `refactor/release-scripts`
- `docs/agent-workflow`

## Pull Requests
- Do not open a pull request unless the user explicitly asked.
- Do not merge a pull request unless the user explicitly asked.
- Review the full PR description and discussion before making review comments.
- Prefer precise review comments tied to correctness, safety, DX, performance, maintainability, or repo policy.
- Do not approve code that passes superficially but violates `RULES.md`.

## Review Expectations
When reviewing a change, check at minimum:
- correctness
- edge cases
- regression risk
- API impact
- test coverage
- lint / formatter compliance
- complexity / file-size budget impact
- backward compatibility where relevant
- documentation updates where relevant

## Local Change Policy
- Change only what is necessary for the requested task.
- Avoid renames, file moves, or broad reorganizations unless they are part of the task.
- Avoid introducing compatibility layers unless there is a clear migration need.
- Prefer deletion over dead abstractions, but do not remove intentional behavior without approval.

## Commit Policy
- Never commit unless the user explicitly asked.
- Keep commits focused and logically grouped.
- Stage files explicitly by path.
- Verify staged content with `git status` and `git diff --cached` before committing.
- Reference the issue in the commit message when applicable using:
  - `fixes #<number>`
  - `closes #<number>`

## Merge Policy
- Prefer squash merge for noisy or iterative branches.
- Prefer regular merge when preserving commit history is important.
- Rebase only when it improves clarity and does not risk other contributors’ work.
- Never force push shared branches.

## Conflict Policy
- Resolve conflicts only in files you intentionally touched.
- If conflicts appear in unrelated files, stop and ask the user.
- Do not use destructive Git commands to “simplify” conflict resolution.

## Documentation Expectations
Update docs when the change affects:
- public API
- setup or installation
- repository workflow
- release process
- package layout
- developer commands
- behavior users depend on

## Escalation Triggers
Stop and ask the user before proceeding when:
- the requested change implies a breaking API change
- the safest fix requires structural refactoring beyond the task scope
- the repo state suggests another agent is actively editing overlapping files
- the issue requirements and current code behavior materially conflict
