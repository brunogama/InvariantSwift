---
id: E005
title: Plugins and Trust
goal: Minimize permissions and make plugin behavior transparent.
status: todo
---

## Exit criteria
- Plugin permissions match behavior.
- Repo blocks macOS artifacts from entering history.

## Stories
- S001 Remove network permission from plugin (applied in this zip)
- S002 Add CI check: fail if `.DS_Store` or `__MACOSX` exists
