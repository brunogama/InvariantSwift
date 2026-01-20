# Current Concerns (verified in branch export)

## Correctness
- **Assumptions/discards are unsafe**: `Property.filter` relies on `Gen.suchThat`, which can return a value that fails the predicate after a fixed number of attempts.
- **No discard accounting**: `PropertyRunner.runProperty` does not track discards and cannot return `.gaveUp`.
- **Dependent shrinking is not implemented**: `Shrink.flatMap` returns `[]` and `Shrink.contramap` returns the original value repeatedly; as a result `Gen.flatMap` does not shrink real counterexamples.
- **Shrinking is greedy-first**: `shrinkFailure` picks the first failing candidate repeatedly, which often fails to find a minimal counterexample.

## Trust / OSS hygiene
- **SPM plugin requests network permission** without shipping a networked feature.
- macOS zip artifacts (`.DS_Store`, `__MACOSX`) frequently appear in exports.

## API surface / roadmap drift
- Many “advanced” modules exist (coverage-guided, fuzzing, SMT, etc.). Until the core contract is solid, these expand maintenance cost and reduce confidence.
