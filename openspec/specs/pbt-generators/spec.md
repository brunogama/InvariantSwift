# Generators Specification

## Purpose

Document the generator catalog, composition rules (map/flatMap/zip/oneOf/frequency), and determinism guarantees.

## Definitions

- **Gen<T>**: A function `(inout RNG, Size) -> T` producing random values
- **Size**: Complexity hint controlling value size (0-100 typical range)
- **RNG**: Random number generator (seeded for determinism)

---

## Requirements

### Requirement: Generator Composition Preserves Determinism

Combinators MUST not break determinism under a fixed seed.

#### Scenario: zip is deterministic

- GIVEN two generators `A` and `B`
- WHEN zipping under seed `S` twice
- THEN results match

#### Scenario: flatMap is deterministic

- GIVEN generators `A` and `f: A -> Gen<B>`
- WHEN `A.flatMap(f)` is sampled twice with same seed
- THEN results match

### Requirement: Size Is Propagated

Combinators MUST pass size to child generators.

#### Scenario: Nested generators receive size

- GIVEN `Gen.array(innerGen)`
- WHEN sampled with `size = N`
- THEN `innerGen` receives size proportional to `N`

### Requirement: Domain Generators Are Optional

Real-world generators (email, URL, names, addresses) SHOULD live in an optional target to avoid bloating the core.

#### Scenario: Core remains minimal

- GIVEN a consumer that imports only the core product
- WHEN building
- THEN no domain generator dependencies are pulled in

---

## Core Combinators

| Combinator | Signature | Preserves Shrinking |
|-----------|-----------|---------------------|
| `map` | `Gen<A>.map(A -> B) -> Gen<B>` | Yes |
| `flatMap` | `Gen<A>.flatMap(A -> Gen<B>) -> Gen<B>` | Via ShrinkTree |
| `zip` | `Gen<A>.zip(Gen<B>) -> Gen<(A,B)>` | Yes (pair shrinking) |
| `oneOf` | `Gen.oneOf([Gen<A>]) -> Gen<A>` | Inherits from chosen |
| `frequency` | `Gen.frequency([(Int, Gen<A>)]) -> Gen<A>` | Inherits from chosen |
| `suchThat` | `Gen<A>.suchThat(A -> Bool) -> Gen<A>` | Best-effort filtering |

---

## Known Limitations

1. **RNG splitting not modeled**: Composite generators share RNG state, creating coupling between branches
2. **suchThat may fail silently**: After max retries, returns last value even if filter fails
3. **Size interpretation varies**: Some generators interpret size linearly, others logarithmically
