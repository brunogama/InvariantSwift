# InvariantSwift Rebuild Plan

## Objective
Ship a trustworthy property-based testing (PBT) core for Swift that is:
- **Deterministic**: seed + size schedule fully defines generation and shrinking.
- **Discard-aware**: assumptions/discards never “leak” invalid values into predicates.
- **Shrink-correct**: shrinking works for dependent generators and converges to small counterexamples.
- **Native in Swift Testing**: failures report a minimal counterexample + replay info.

## Current problems driving the rebuild
- `Gen.suchThat` returns values that fail the predicate after max attempts, violating assumption semantics.
- The runner does not track discards and cannot return “gave up”.
- `Shrink.contramap` and `Shrink.flatMap` are placeholders; dependent generators effectively do not shrink.
- Shrinking strategy is greedy-first, often producing non-minimal results.
- SPM plugin requests network permission without implementing networking (trust issue).

## Deliverables
1. A redesigned **core semantics**: generation, discard handling, shrinking, replay.
2. A story-based backlog in `Backlog/` suitable for LLM execution.
3. Repository hygiene fixes (remove macOS artifacts, tighten permissions).

## Definition of done
- A failing property always prints a stable replay token (seed + size schedule + iterations).
- Assumptions never cause invalid values to be tested; excessive discards produce `.gaveUp`.
- `flatMap`-built generators produce meaningful shrunk counterexamples.
- Plugin permissions are minimal and justified.
