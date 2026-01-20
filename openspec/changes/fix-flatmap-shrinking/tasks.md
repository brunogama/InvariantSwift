## 1. Define the correct contract for dependent shrinking
- [ ] 1.1 Specify how a dependent generator shrinks (outer value shrink, then inner shrink)
- [ ] 1.2 Decide how to split RNG so the inner generator is stable across shrinks

## 2. Implement
- [ ] 2.1 Remove or rewrite `Shrink.flatMap` and `Shrink.contramap` to be valid under ShrinkTree
- [ ] 2.2 Implement `Gen.flatMap` shrinking using ShrinkTree composition
- [ ] 2.3 Add property tests: flatMap generator shrinks to a smaller failing input

## 3. Regression tests
- [ ] 3.1 Add a minimal example generator using flatMap where shrinking currently fails
- [ ] 3.2 Ensure it shrinks after the change
