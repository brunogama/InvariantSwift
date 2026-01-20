---
id: E001
title: Core Correctness
objective: Deterministic property evaluation with correct discard semantics and accurate failure reasons.
exit_criteria:
  - Assumptions do not leak invalid values into predicates.
  - Runner reports discarded count and can return gaveUp.
  - Predicate supports throws (and async where applicable).
  - Tests cover determinism and discard accounting.
---

## Stories
- S010 Implement discard-aware runner
- S011 Make `Gen.suchThat` safe (deprecate or change semantics)
- S012 Add failure reasons for thrown errors and timeouts
- S013 Deterministic per-iteration RNG/seed strategy
