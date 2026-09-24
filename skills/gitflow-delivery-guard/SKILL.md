---
name: gitflow-delivery-guard
description: Enforce Git Flow delivery behavior for coding work: the right base branch for each prefix, release and hotfix branches merged back into develop, feature flags for incomplete work, and the repository's quality gates before any commit or pull request.
---

# Git Flow Delivery Guard

## Use this skill when

- the task involves coding, refactoring, review, or release preparation in a repository using Git Flow
- the repository has a permanent production branch and a permanent integration branch
- the user wants work staged through `develop` and released through `release/` branches

Do not use this skill for:

- prose-only tasks with no repository impact
- repositories using trunk-based development, where `main` is the single integration point

## Goal

Put every change on the branch its role calls for.
Keep `develop` building and green.
Keep `main` releasable, and never let a fix released from `main` disappear on the next merge.

## Operating rules

### 1) Two permanent branches

- `main` holds released code. Every commit on it is a release point.
- `develop` is the integration branch and the base for everyday work.
- Never commit directly to either. The repository's `branch-guardian` pre-commit hook
  blocks it, and that hook is not to be bypassed.

### 2) The prefix decides the base

| Prefix | Branches from | Merges into |
| --- | --- | --- |
| `feature/` | `develop` | `develop` |
| `bugfix/` | `develop` | `develop` |
| `release/` | `develop` | `main` and `develop` |
| `hotfix/` | `main` | `main` and `develop` |
| `support/` | `main` | - |

Before creating a branch, decide which row the work belongs to. A defect in released code
is a `hotfix/` cut from `main`; the same defect found before release is a `bugfix/` cut
from `develop`. Getting this wrong is not cosmetic: a hotfix cut from `develop` drags
unreleased work into the release.

### 3) Always merge back

A `release/` or `hotfix/` branch is finished only when it has landed on **both** `main` and
`develop`. Stopping after `main` means the next `develop`-to-`main` merge silently reverts
the fix.

Use a regular merge for these, not a squash. Squashing into `main` and again into `develop`
produces two unrelated commits for one change, and every later merge conflicts on it.

### 4) Small-batch delivery

- Break work into the smallest reviewable, mergeable slice.
- Prefer a preparatory refactor, then wiring, then behavior, then cleanup.
- Each slice must compile, pass tests, and leave `develop` green.
- If a request is too large, propose the first safe slice instead of attempting the whole
  thing as one change.

Judge size by whether a reviewer can actually follow the change, not by a line count. A
mechanical rename touching forty files is reviewable; a two-hundred-line change that mixes
a refactor, a behavior change, and a rename is not. When a change is large because it is
genuinely one thing, say so in the pull request rather than splitting it artificially.

### 5) Incomplete work must be hidden

- If the code path is incomplete, risky, or not ready for end users, put it behind a
  feature flag or inactive execution path before it reaches `develop`.
- A simple boolean flag is acceptable for binary enable/disable behavior.
- Use multivariant or config flags only when the behavior actually needs runtime variants.
- Every new flag must have a clear name, a default value, an owner, and a planned removal
  condition.

### 6) Stop and split when

- the change mixes refactor, behavior, rename, and docs in one batch
- the work introduces incomplete behavior without a protective flag
- the branch has drifted significantly from its base
- the task would leave `develop` non-releasable
- the change requires broad file moves that are not essential to the first safe slice

### 7) Required checks before proposing merge or commit

Run, or logically account for, the same checks the repository enforces:

- formatter
- linter in strict mode
- build with warnings treated as errors
- tests
- coverage gate, when present

Never bypass hooks or required checks.
Never recommend `--no-verify`.
Never recommend weakening checks to fit the change.

### 8) PR and commit shaping

- One logical change per commit.
- One user-visible concern per PR.
- Target `develop`, unless the branch is a `release/` or `hotfix/`.
- Keep PR descriptions explicit about what changed, why this slice exists, what remains for
  later slices, and whether a feature flag is guarding the behavior.

### 9) Feature-flag hygiene

Do not create permanent flag debt.
For each flag, document:

- flag name
- default state
- owner
- rollout intent
- removal trigger

### 10) Release safety

- `develop` must stay green after every accepted slice.
- Stabilize a release on `release/<version>`, not on `develop` and not on `main`.
- If a release is blocked by incomplete work, disable the flagged path or leave it out of
  the release branch.

## Workflow the agent must follow

1. Read `AGENTS.md`, `RULES.md`, `WORKFLOW.md`, `RELEASING.md`, and `CONTRIBUTING.md` if present.
2. Classify the request as tiny fix, safe refactor, new feature slice, risky behavior change, release prep, or review only.
3. Pick the branch prefix and base that classification implies.
4. Plan the smallest safe slice, including whether it needs a feature flag and what is explicitly deferred.
5. Implement it.
6. Run the quality gates.
7. Report the implemented slice, the branch and its target, flag usage, checks run, and the next safe slice if work remains.

## Recommended companion files

- `scripts/gitflow-init.sh`
- CI required checks on `main` and `develop`
- protected `main` and `develop` branches with required status checks

## Final rule

If the work cannot be delivered safely as a small slice on the right branch, do not force
it through.
Split it.
Add a flag.
Or stop and explain why the next slice must come first.
