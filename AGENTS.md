# AGENTS.md

## Purpose

Repository-specific operating instructions for coding agents.

This repository uses trunk-based development with `main` as the trunk.
For coding quality, validation, lint budgets, and definition of done, follow `RULES.md`.
For issue, PR, merge, and conflict policy, follow `WORKFLOW.md`.
For release and changelog policy, follow `RELEASING.md`.
If this file conflicts with repository tooling or explicit user instructions, those instructions win.

## Task Intake

- If the user request is concrete, start with the files directly relevant to that task.
- If the request is not concrete, inspect the top-level documentation most relevant to the task such as `README.md`, package manifests, and module READMEs before deciding where to work.
- Do not assume the task is module-scoped. It may be architectural, debugging, refactoring, review, release, or documentation work.
- Prefer the smallest safe slice that leaves `main` releasable.

## Trunk Rules

- Prefer working off `main` via very short-lived branches and pull requests.
- Direct commits to `main` and `dev` are blocked by the repository's `branch-guardian` pre-commit hook.
- Do not propose long-lived feature branches, `develop`, `release/*`, or branch pyramids.
- Keep work in small, reviewable, mergeable slices.
- If a requested change is too large, implement the first safe slice instead of forcing one oversized change.
- If work is incomplete but must land, hide it behind a feature flag or an inactive execution path.

## Code Change Rules

- Follow `RULES.md` strictly.
- Read every file you modify in full before editing it.
- Do not remove, rename, or downgrade intentional functionality unless the user explicitly asked for it.
- Do not “fix” dependency or type problems by deleting behavior or weakening checks. Prefer the real fix.
- Keep diffs tight. Avoid unrelated refactors and formatting-only churn unless required to satisfy repository rules.


## Package Manifest Synchronization
- Treat `Package.swift` as the active source manifest and keep `Package.local.swift` as its exact local-development copy.
- Whenever a change affects package products, targets, dependencies, platforms, resources, plugins, or tests, update `Package.swift`, `Package.local.swift`, and `Package.binary.swift` in the same change.
- Preserve intentional binary-manifest differences such as `.binaryTarget` declarations, release placeholders, and source-only tooling boundaries. Mirror the resulting package surface rather than copying incompatible implementation details.
- Before finishing a manifest change, verify `Package.swift` and `Package.local.swift` are identical and validate both source and binary manifest behavior.
## Validation

- After code changes, run the repository validation commands that enforce the standards in `RULES.md`.
- Run `scripts/change-budget.sh` before proposing a commit or pull request.
- Treat formatter, lint, warnings-as-errors, tests, and coverage as design constraints, not cleanup steps.
- Do not bypass hooks, checks, or validation steps.
- Never use `--no-verify`.

## Commits

- Never commit unless the user explicitly asks.
- If committing, commit only files changed in this session.
- Keep each commit to one logical change.
- Use explicit paths when staging. Never use broad staging commands that can capture other agents’ work.
- Before committing, run `git status` and `git diff --cached` to verify only intended files are staged.
- If the diff is oversized, split it before committing.
- If there is a related issue or PR, include `fixes #<number>` or `closes #<number>` in the commit message.

## Git Safety for Parallel Agents

Multiple agents may work in the same worktree. Protect other agents’ changes.

### Allowed

- `git status`
- `git diff`
- `git add <specific-file-paths>`
- `git commit`
- `git pull --rebase`
- `git push`

### Forbidden

- `git add -A`
- `git add .`
- `git reset --hard`
- `git checkout .`
- `git clean -fd`
- `git stash`
- `git commit --no-verify`
- force push

### Rebase Conflicts

- Resolve conflicts only in files you actually changed.
- If a conflict appears in untouched files, stop and ask the user.

## Issue and PR Review

- When reviewing an issue, read the full issue including comments before acting.
- Prefer complete issue reads over partial snippets.
- Analyze PRs before making local changes.
- Do not open PRs unless the user explicitly asked.
- Do not merge or close anything unless the user explicitly asked.
- Favor small, single-purpose PRs.

## Communication Style

- Keep responses concise, direct, and technical.
- No fluff.
- No emojis in commits, issues, PR comments, or code comments unless the user explicitly asked for them.

## Context Storage

- Store transient agent context, scratch notes, logs, and task state under `.llm/{DIR}/`.
- Choose `{DIR}` per task or per agent to avoid collisions when multiple agents share the same worktree.
- Do not use `.context/` for new work. It is treated as a legacy location only.
- Treat `.llm/` contents as disposable working state, not as tracked project source.
- If temporary context needs to become durable documentation, promote it into a tracked docs path explicitly.

## Repository References

- `RULES.md` is the canonical source for:
  - definition of done
  - formatting and lint requirements
  - warnings-as-errors
  - tests and coverage
  - code size and complexity budgets
- `WORKFLOW.md` defines repository workflow for issues, branches, PRs, reviews, and merges.
- `RELEASING.md` defines release, versioning, changelog, tagging, and publishing rules.
