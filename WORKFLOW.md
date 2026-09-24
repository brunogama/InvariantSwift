# WORKFLOW.md

## Purpose

Repository workflow rules for coding agents and contributors.

This repository uses Git Flow, with `main` as the production branch and `develop` as the
integration branch.
This file defines how to handle issues, branches, pull requests, reviews, and merges.
For code quality and validation rules, follow `RULES.md`.
For repository operating behavior during implementation, follow `AGENTS.md`.

---

## General Workflow

- Read the full task before acting.
- Prefer understanding the existing code path before proposing structural changes.
- Keep work scoped to the requested task.
- Do not mix implementation, cleanup, and unrelated refactors in the same change unless explicitly requested.
- Prefer the smallest releasable slice.

---

## Issues

- Read the full issue, including comments, before changing code.
- Treat issue comments as part of the requirement unless they clearly contradict the latest user instruction.
- If the issue is underspecified, inspect the relevant code and docs before deciding on the implementation shape.
- Do not close issues unless the user explicitly asked.

---

## Branching

Two branches are permanent:

- `main` holds released code. Every commit on it is a release point, and pushing to it
  triggers the release tag.
- `develop` is where finished work accumulates between releases. It is the base for
  everyday work and the default target for pull requests.

Everything else is temporary and named by its role:

| Prefix | Branches from | Merges into | Purpose |
| --- | --- | --- | --- |
| `feature/` | `develop` | `develop` | New behavior, refactors, docs, chores |
| `bugfix/` | `develop` | `develop` | A defect that is not yet released |
| `release/` | `develop` | `main` and `develop` | Stabilizing a version for release |
| `hotfix/` | `main` | `main` and `develop` | An urgent fix to released code |
| `support/` | `main` | - | Maintaining an older release line |

Rules:

- Direct commits to `main`, `develop`, and `dev` are blocked by the repository's
  `branch-guardian` pre-commit hook.
- Branch from `develop` for ordinary work and from `main` only for a hotfix.
- Keep branches focused; merge them only when the user explicitly asks and checks pass.
- Merge a `release/` or `hotfix/` branch into both `main` and `develop`, so a fix released
  from `main` is never lost on the next merge from `develop`.

Name the branch after its role and topic, `<prefix>/<area>-<topic>`:

- `feature/sqlite-hnsw-build`
- `feature/agent-workflow-docs`
- `bugfix/vector-distance-null-check`
- `release/0.5.0`
- `hotfix/coverage-helper-path`

The prefixes match the git-flow (AVH) defaults this repository configures, so
`git flow feature start sqlite-hnsw-build` and a plain
`git switch -c feature/sqlite-hnsw-build develop` produce the same branch. Run
`scripts/gitflow-init.sh` once per clone to configure the extension; it is not required.

---

## Releases and Hotfixes

A release is prepared on a branch, not on `develop` and not on `main`:

1. Cut `release/<version>` from `develop`.
2. Land only stabilization work on it: fixes, docs, and version metadata. No new features.
3. Merge it into `main` when the gates in `RULES.md` pass. The push to `main` tags the
   release; see `RELEASING.md`.
4. Merge it back into `develop` so the stabilization work is not lost.

A hotfix is the same shape with a different base: cut `hotfix/<topic>` from `main`, then
merge it into both `main` and `develop`.

---

## Pull Requests

- Do not open a pull request unless the user explicitly asked.
- Do not merge a pull request unless the user explicitly asked.
- Keep pull requests small, single-purpose, and easy to review.
- Review the full PR description and discussion before making review comments.
- Prefer precise review comments tied to correctness, safety, DX, performance, maintainability, or repo policy.
- Do not approve code that passes superficially but violates `RULES.md`.

---

## Feature Delivery

- Split large changes into slices that each leave `develop` building and green.
- Hide incomplete work behind a feature flag or inactive path if it must land on `develop`
  before it is ready for users.
- Land behavior on `develop`, never directly on `main`. `main` advances only through a
  `release/` or `hotfix/` merge.

---

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
- whether the branch targets the right base for its prefix

---

## Local Change Policy

- Change only what is necessary for the requested task.
- Avoid renames, file moves, or broad reorganizations unless they are part of the task.
- Avoid introducing compatibility layers unless there is a clear migration need.
- Prefer deletion over dead abstractions, but do not remove intentional behavior without approval.

---

## Commit Policy

- Never commit unless the user explicitly asked.
- Keep commits focused and logically grouped.
- Keep each commit to one logical change.
- Stage files explicitly by path.
- Verify staged content with `git status` and `git diff --cached` before committing.
- Reference the issue in the commit message when applicable using:
  - `fixes #<number>`
  - `closes #<number>`

---

## Merge Policy

- Prefer squash merge for a `feature/` or `bugfix/` branch into `develop`, especially a
  noisy or iterative one.
- Use a regular merge for a `release/` or `hotfix/` branch. Squashing it into `main` and
  then again into `develop` creates two unrelated commits for one change, so every later
  merge between the two branches conflicts on it.
- Rebase only when it improves clarity and does not risk other contributors’ work.
- Never force push `main`, `develop`, or any other shared branch.

---

## Conflict Policy

- Resolve conflicts only in files you intentionally touched.
- If conflicts appear in unrelated files, stop and ask the user.
- Do not use destructive Git commands to “simplify” conflict resolution.

---

## Documentation Expectations

Update docs when the change affects:

- public API
- setup or installation
- repository workflow
- release process
- package layout
- developer commands
- behavior users depend on

---

## Escalation Triggers

Stop and ask the user before proceeding when:

- the requested change implies a breaking API change
- the safest fix requires structural refactoring beyond the task scope
- the repository state suggests another agent is actively editing overlapping files
- the issue requirements and current code behavior materially conflict
- the change would have to land directly on `main` or `develop` to work
- a `release/` or `hotfix/` branch has not been merged back into `develop`
