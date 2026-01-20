---
id: S002
title: Prevent macOS zip artifacts from entering the repo
epic: E005
priority: P0
status: done
dependencies: []
---

## Problem
`.DS_Store` and `__MACOSX` directories show up in exports and can be accidentally committed.

## Scope
- Add ignore rules.
- Add a CI check or a test script that fails when these files exist.

## Acceptance criteria
- `.gitignore` ignores `.DS_Store` and `__MACOSX/`.
- A script exists: `Scripts/check_repo_hygiene.sh`.
- CI runs the script.

## Files to touch
- `.gitignore`
- `Scripts/check_repo_hygiene.sh` (new)
- CI workflow/config file (where applicable)
