# Discard Semantics (Assumptions)

## Problem
Currently assumptions are implemented by filtering generators (`Gen.suchThat`) and can return invalid values after max attempts. This violates the meaning of assumptions and makes failures non-actionable.

## Rule
**Assumptions live in the runner, not in the generator.**

## Proposed API
- `Property(generator: Gen<T>, assumption: (T) -> Bool, predicate: (T) throws -> Bool)`
- Convenience: `prop.assuming { ... }` or `Property.implies(...)` for logical implication.

## Runner algorithm
For each iteration:
1. Generate `value`.
2. If assumption exists and fails:
   - `discarded += 1`
   - if `discarded > maxDiscarded`: return `.gaveUp(discarded:discarded, iterations:iteration)`
   - continue to next iteration.
3. Evaluate predicate.

## Reporting
Always return:
- `iterations`, `discarded`
- replay token
- (optional) distribution stats: discard rate and labels
