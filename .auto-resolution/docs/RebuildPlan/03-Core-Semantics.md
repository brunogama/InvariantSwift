# Core Semantics

## Generation
- `Gen<T>`: deterministic function `(inout RNG, Size) -> T`.
- **Seed splitting**: composite generators should derive independent child RNG streams from the parent stream to reduce unwanted coupling and to stabilize replay.

## Property evaluation
Define `Predicate<T>` as:
- synchronous: `(T) throws -> Bool`
- async: `(T) async throws -> Bool`

The runner must:
1. Derive per-iteration seed / RNG state deterministically.
2. Generate `T`.
3. If an assumption exists:
   - if it fails: increment `discarded`, continue.
4. Evaluate predicate (catch errors/timeouts).
5. On failure, minimize via shrink search.

## Results
`PropertyResult` should include:
- `iterations`, `discarded`
- `seed` and a stable `Replay` token
- `counterexample` and `shrunkCounterexample`
- failure reason: predicate false, threw error, timed out, gave up
