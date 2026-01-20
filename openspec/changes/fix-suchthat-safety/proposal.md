# Proposal: Make suchThat safe

## Why
`suchThat` currently retries a fixed number of times and then returns the last value even if it violates the predicate. This violates the meaning of the operator.

## What
Change `suchThat` to return a discard/give-up outcome (or integrate with runner discard flow) rather than returning invalid values.

## Out of scope
- Discard counting at the runner level (handled in `fix-discard-semantics`)
