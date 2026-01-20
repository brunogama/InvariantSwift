# Work Plan

## Phases

### Phase 0: Hygiene & trust
- Remove network permission from plugin (done in this zip)
- Add `.gitignore` entries for macOS artifacts (done)

### Phase 1: Core correctness (P0)
- Implement discard-aware runner and `.gaveUp`
- Remove unsafe behavior from `Gen.suchThat` (either deprecate or make it return Optional / throw)
- Introduce `throws` (and optionally `async`) predicates

### Phase 2: Shrinking foundation (P1)
- Implement `ShrinkTree` and BFS shrink search
- Replace placeholder `Shrink.contramap` and `Shrink.flatMap`
- Fix `Gen.flatMap` shrinking

### Phase 3: DX (P2)
- Replay tokens printed on failure
- Classification/cover reporting
- Swift Testing adapter polish

## “Stop the line” rules
- No new feature modules until Phase 1 & 2 are green.
- If a story changes semantics, it must add/adjust tests and update docs.
