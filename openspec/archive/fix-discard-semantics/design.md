# Design: Discard semantics

## Decision
Assumptions are a property-runner concern, not a generator concern.

## Key Changes
- `Property` will carry an `assumption: (T) -> Bool` (and later async/throws variants) rather than filtering the generator.
- `PropertyRunner` will implement the loop:
  1) draw value
  2) if assumption fails: discard++ and continue
  3) evaluate predicate; on failure shrink
  4) stop when iterations met or discarded exceeded

## Non-Goals
- No subprocess crash isolation in this change.
- No coverage-guided logic in this change.

## Open Questions
- Whether to represent the discard budget as `maxDiscarded` or derive it from iterations.
