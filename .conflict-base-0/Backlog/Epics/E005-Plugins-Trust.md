---
id: E005
title: Plugins Trust and Hygiene
objective: Plugins request minimal permissions and repository exports are clean.
exit_criteria:
  - No default network permissions.
  - CI check blocks macOS zip artifacts (.DS_Store, __MACOSX).
  - Plugin outputs are deterministic and documented.
---

## Stories
- S050 Remove network permission (already applied)
- S051 Add CI repo hygiene check
- S052 Document plugin outputs and flags
