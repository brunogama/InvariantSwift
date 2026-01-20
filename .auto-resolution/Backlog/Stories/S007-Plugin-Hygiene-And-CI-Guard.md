---
id: S007
epic: E001
status: done
owner: llm
---

# S007: Plugin hygiene and CI guard

## Problem
macOS archive artifacts and unjustified permissions reduce trust.

## Scope
- Add CI step to fail if `.DS_Store` or `__MACOSX` appears.
- Keep plugin permissions minimal.

## Acceptance criteria
- A script exists (and is run in CI) to detect forbidden paths.
- Package.swift does not request network permission unless implemented.
