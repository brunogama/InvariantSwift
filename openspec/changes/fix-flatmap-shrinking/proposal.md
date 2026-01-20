# Proposal: Fix Gen.flatMap shrinking

## Summary
Make `Gen.flatMap` shrink correctly for dependent generators, removing stub/invalid shrink combinators.

## Background
Today `Gen.flatMap` delegates shrink composition to `Shrink.flatMap`, which is stubbed and returns empty. As a result, dependent generators do not shrink, which is a major usability regression.

## Dependencies
- This change depends on `fix-shrinking-foundations` introducing ShrinkTree.

## Goals
- Provide a correct strategy for shrinking a dependent generation: shrink the outer value first, then shrink the inner value for the chosen outer value.
- Ensure determinism under stable ordering.

## Non-Goals
- Novel shrinking heuristics.
