---
id: E005
title: Plugin Trust and Hygiene
objective: Plugins are minimal-permission, deterministic, and repo exports are clean.
exit_criteria:
  - No network permissions by default.
  - Plugin creates/uses a dedicated output directory (`.invariant/` or similar).
  - CI prevents `.DS_Store`/`__MACOSX` from landing in the repo.
---

## Stories
- S001 Remove network permission from InvariantSwiftPlugin (already applied in this zip)
- S002 Add CI check for macOS artifacts
- S003 Ensure plugin output is deterministic and placed under `.invariant/`
