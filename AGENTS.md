# AGENTS.md

## Purpose
Repository-specific operating instructions for coding agents.

This repository uses trunk-based development.
The trunk is `main` unless the user explicitly says otherwise.
For code quality, validation, lint budgets, and definition of done, follow `RULES.md`.
For issue, PR, merge, and conflict policy, follow `WORKFLOW.md`.
For release and changelog policy, follow `RELEASING.md`.

## Task Intake
- If the request is concrete, start with the files directly relevant to that task.
- If the request is not concrete, inspect the top-level docs most relevant to the task such as `README.md`, package manifests, and module READMEs.
- Do not assume the task is module-scoped. It may be architectural, debugging, refactoring, review, release, or documentation work.
- Prefer the smallest safe slice that leaves `main` releasable.

## Trunk Rules
- Prefer direct work against `main` or a very short-lived branch.
- Do not propose long-lived feature branches, `develop`, `release/*`, or branch pyramids.
- Keep work in small, reviewable, mergeable slices.
- If a requested change is too large, implement the first safe slice instead of forcing one oversized change.
- If work is incomplete but must land, hide it behind a feature flag or an inactive execution path.

## Code Change Rules
- Follow `RULES.md` strictly.
- Read every file you modify in full before editing it.
- Do not remove, rename, or downgrade intentional functionality unless the user explicitly asked for it.
- Do not fix dependency, type, or test failures by deleting behavior or weakening checks.
- Keep diffs tight. Avoid unrelated refactors and formatting-only churn unless required by repo rules.

## Validation
- After code changes, run the repository validation commands that enforce the standards in `RULES.md`.
- Run `scripts/change-budget.sh` before proposing a commit or PR when that script exists.
- Treat formatter, lint, warnings-as-errors, tests, and coverage as design constraints, not cleanup steps.
- Never bypass hooks or checks.
- Never use `--no-verify`.

## Commits
- Never commit unless the user explicitly asked.
- If committing, keep each commit to one logical change.
- Stage files explicitly by path.
- Before committing, run `git status` and `git diff --cached`.
- If the diff is oversized, split it before committing.

## Git Safety for Parallel Agents
Multiple agents may work in the same worktree. Protect other agents' changes.

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

## Reviews and PRs
- Read the full issue or PR discussion before acting.
- Analyze PRs before making local changes.
- Do not open a PR unless the user explicitly asked.
- Do not merge or close anything unless the user explicitly asked.
- Favor small, single-purpose PRs.

## Communication Style
- Keep responses concise, direct, and technical.
- No fluff.
- No emojis in commits, issues, PR comments, or code comments unless the user explicitly asked.

## References
- `RULES.md` — code quality and validation
- `WORKFLOW.md` — issue, PR, branch, merge, and conflict policy
- `RELEASING.md` — release and changelog policy
