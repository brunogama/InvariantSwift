# Design: Dependent generator shrinking

## Goal
When a property fails on a value produced by `Gen<A>.flatMap(A -> Gen<B>)`, shrinking should be able to reduce both the outer `A` and the resulting `B` while keeping determinism.

## Approach
1. Model `Gen` as producing `(value, replayToken)` (or a stable RNG split) so we can re-run the inner generator for a given outer value deterministically.
2. Shrinking proceeds in two phases:
   - shrink outer A (and regenerate B for each candidate A)
   - shrink inner B while keeping the outer A fixed

## Notes
If this is implemented before full replay support, use a deterministic RNG splitting scheme (e.g., derive child seed from parent seed + outer value index).
