# Proposal: Fix shrinking foundations (ShrinkTree + deterministic search)

## Summary
Replace the current ad-hoc shrinking (`Shrink` returning `[T]` + greedy search) with a shrink-tree abstraction and a deterministic search strategy that reliably finds minimal counterexamples.

## Background
Current issues include an invalid `Shrink.contramap`, a stubbed `Shrink.flatMap`, and greedy shrink search that can miss minimal cases.

## Goals
- Introduce `ShrinkTree<T>` (or `RoseTree<T>`) representing a value and its recursive shrinks.
- Implement a deterministic minimization algorithm (BFS or best-first with stable ordering).
- Provide reference shrinkers for core types and collection/sequence shrinking.

## Non-Goals
- Coverage-guided generation.
- Stateful/model-based testing.

## Risks
- Performance regressions if the shrink tree explodes; requires caps and laziness.
