# Problem inventory

## Core semantics

### Discards / assumptions
- Filtering is implemented by generator rejection sampling (`Gen.suchThat`).
- After 100 failed attempts, it returns a value anyway.
- Runner does not track discards; `.gaveUp` is never produced.

Impact: properties can be evaluated on inputs that violate assumptions; results are untrustworthy.

### Shrinking
- `Shrink.contramap` returns the same input repeatedly (does not produce smaller U values).
- `Shrink.flatMap` returns `[]`.
- `Gen.flatMap` depends on `Shrink.flatMap`, therefore composed generators often do not shrink.
- Shrink search is greedy-first (first failing candidate), which commonly yields non-minimal counterexamples.

Impact: debugging experience is poor and “shrinking” is effectively absent for non-trivial generators.

### Failure reasons / async / throws
- `FailureReason.threwError` and `timedOut` exist but are unreachable from the current `(T) -> Bool` predicate signature.

Impact: surface area is misleading; adding async/throws later becomes a breaking change.

### Crash isolation
- In-process runner cannot catch `fatalError`/`preconditionFailure`.
- The current naming/docs imply stronger isolation than the implementation provides.

Impact: user trust issue.

## Packaging and trust

### Plugin permissions
- The SwiftPM plugin declares `.allowNetworkConnections(scope: .all)`.
- Current implementation executes a local CLI and writes local artifacts.

Impact: adoption blocker; default-on network is a red flag.

### Repo hygiene
- `__MACOSX/` and `.DS_Store` artifacts were present in earlier zips.

Impact: signals lack of release discipline.
