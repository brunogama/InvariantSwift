---
name: trunk-delivery-guard
description: Enforce trunk-based delivery behavior for coding work: short-lived branches, tiny slices, feature flags for incomplete work, commit and PR change budgets, and refusal of oversized changes unless explicitly approved.
---

# Trunk Delivery Guard

## Use this skill when
- the task involves coding, refactoring, review, or release preparation in a repository using trunk-based development
- the repository uses `main` or another explicit branch as trunk
- the user wants small, mergeable slices, frequent integration, and incomplete work hidden behind feature flags

Do not use this skill for:
- prose-only tasks with no repository impact
- large migrations the user explicitly wants done as one coordinated change
- repositories intentionally using Git Flow, release branches, or long-lived integration branches

## Goal
Keep trunk releasable.
Deliver in the smallest safe slice.
Do not let incomplete or oversized work reach trunk without explicit approval and protective controls.

## Operating rules

### 1) Trunk is the source of truth
- Assume `main` is the trunk unless the repo defines another branch explicitly.
- Prefer direct work against trunk or a very short-lived branch merged back the same day.
- Never propose long-lived feature branches, `develop`, `release/*`, or branch pyramids unless the user explicitly overrides policy.

### 2) Small-batch delivery is mandatory
- Break work into the smallest reviewable and mergeable slice.
- Prefer a preparatory refactor, then wiring, then behavior, then cleanup.
- Each slice must compile, pass tests, and leave trunk releasable.
- If a request is too large, propose the first safe slice instead of attempting the whole thing as one change.

### 3) Incomplete work must be hidden
- If the code path is incomplete, risky, or not ready for end users, put it behind a feature flag or inactive execution path.
- A simple boolean flag is acceptable for binary enable/disable behavior.
- Use multivariant or config flags only when the behavior actually needs runtime variants.
- Every new flag must have a clear name, a default value, an owner, and a planned removal condition.

### 4) Oversized changes are not allowed by default
Before proposing a commit or PR, run the repo's change-budget script if present.
Preferred script:
- `scripts/change-budget.sh`

If the repo has no script, estimate the budget manually from `git diff --stat` and `git diff --shortstat`.

Default budget policy:
- Green: <= 10 files and <= 300 changed lines
- Yellow: <= 25 files and <= 800 changed lines
- Red: anything above Yellow

Behavior:
- Green: proceed
- Yellow: proceed only if the change is single-purpose and still easy to review
- Red: do not propose a single commit or PR; split the work into smaller slices first

### 5) Refusal criteria
Stop and split the work when any of the following is true:
- the change mixes refactor, behavior, rename, and docs in one batch
- the diff is above budget
- the work introduces incomplete behavior without a protective flag
- the branch has drifted significantly from trunk
- the task would leave trunk non-releasable
- the change requires broad file moves that are not essential to the first safe slice

### 6) Required checks before proposing merge or commit
Run, or logically account for, the same checks the repo enforces:
- formatter
- linter in strict mode
- build with warnings treated as errors
- tests
- coverage gate, when present
- change-budget script

Never bypass hooks or required checks.
Never recommend `--no-verify`.
Never recommend weakening checks to fit the change.

### 7) PR and commit shaping
- One logical change per commit.
- One user-visible concern per PR.
- Keep PR descriptions explicit about what changed, why this slice exists, what remains for later slices, and whether a feature flag is guarding the behavior.

### 8) Feature-flag hygiene
Do not create permanent flag debt.
For each flag, document:
- flag name
- default state
- owner
- rollout intent
- removal trigger

### 9) Release safety
- Trunk must stay releasable after every accepted slice.
- Do not rely on a future stabilization branch.
- If a release is blocked by incomplete work, disable the flagged path or split the change further.

## Workflow the agent must follow
1. Read `AGENTS.md`, `RULES.md`, `WORKFLOW.md`, `RELEASING.md`, and `CONTRIBUTING.md` if present.
2. Classify the request as tiny fix, safe refactor, new feature slice, risky behavior change, release prep, or review only.
3. Plan the smallest safe slice, including whether it needs a feature flag and what is explicitly deferred.
4. Implement with trunk safety.
5. Run the budget and quality gates.
6. Report the implemented slice, flag usage, diff size, checks run, and next safe slice if work remains.

## Recommended companion files
- `scripts/change-budget.sh`
- CI required checks on trunk
- protected trunk branch with required status checks

## Final rule
If the work cannot be delivered safely as a small, releasable slice, do not force it through.
Split it.
Add a flag.
Or stop and explain why the next slice must come first.
