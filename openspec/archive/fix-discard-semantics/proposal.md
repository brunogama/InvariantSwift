# Proposal: Fix discard semantics (assumptions)

## Summary
Correct the PBT contract around assumptions by moving discard tracking into the runner. Stop representing assumptions as generator filtering that can return invalid values.

## Background
The current code expresses assumptions by calling `Gen.suchThat` from `Property.filter`. `Gen.suchThat` retries a bounded number of times and then returns the last attempt even if it violates the predicate. The runner also does not count discards and cannot report a proper "gave up" result.

## Goals
- Runner-level discard counting and `gaveUp` reporting.
- Assumptions never cause invalid test inputs to be evaluated.
- Clear output: iterations, discarded count, seed, and minimal counterexample on failure.

## Non-Goals
- Changing shrinking strategy (handled in separate change).
- Coverage-guided generation.

## Out of Scope Risks
- API breaking changes to predicate signatures (throwing/async) should be planned explicitly and staged.
