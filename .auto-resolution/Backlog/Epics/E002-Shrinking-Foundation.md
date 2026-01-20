---
id: E002
title: Shrinking Foundation
objective: Replace placeholder shrinking and provide reliable minimization for dependent generators.
exit_criteria:
  - ShrinkTree exists and is used by the runner.
  - BFS (or best-first) shrink search finds smaller counterexamples than greedy-first.
  - `Gen.flatMap` shrinking works and is tested.
  - Placeholder `Shrink.contramap` and `Shrink.flatMap` are removed or fully implemented.
---

## Stories
- S020 Introduce ShrinkTree model
- S021 Implement BFS shrink search
- S022 Implement/replace `Shrink.contramap`
- S023 Implement/replace `Shrink.flatMap`
- S024 Fix `Gen.flatMap` shrinking via ShrinkTree
