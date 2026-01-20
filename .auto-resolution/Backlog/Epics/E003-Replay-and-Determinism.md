---
id: E003
title: Replay and Determinism
objective: Any failure is reproducible from a stable replay token.
exit_criteria:
  - Replay token printed on failure and accepted by runner.
  - Shrinking order is stable across runs.
  - Deterministic seed splitting for composite generators is documented and tested.
---

## Stories
- S030 Define Replay token format and API
- S031 Print replay token in Swift Testing failure output
- S032 Seed splitting utilities (zip, array, tuples)
