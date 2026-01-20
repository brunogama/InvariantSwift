---
id: S002
title: Add CI check to block .DS_Store and __MACOSX artifacts
epic: E005
priority: P0
status: todo
dependencies: []
---

## Scope
- Add a lightweight check script and a CI step that fails if macOS zip artifacts exist in the repo.

## Acceptance criteria
- CI fails when `.DS_Store` exists anywhere.
- CI fails when `__MACOSX/` exists anywhere.

## Implementation notes
- Provide a script `Scripts/check-repo-hygiene.sh` and call it from your CI workflow.

## Files to touch
- `Scripts/check-repo-hygiene.sh`
- `.github/workflows/*` (if present)
