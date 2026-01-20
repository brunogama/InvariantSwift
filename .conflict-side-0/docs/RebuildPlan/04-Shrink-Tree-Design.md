# Shrink Tree Design

## Problem
Current shrinking is list-based and greedy-first. This is insufficient for:
- dependent generators (`flatMap`)
- finding minimal counterexamples reliably

## Proposed model: ShrinkTree
Represent shrinking as a tree where each node is a candidate value and children are its immediate shrinks.

```text
value
├─ shrink1
│  ├─ shrink1.1
│  └─ shrink1.2
└─ shrink2
   └─ shrink2.1
```

### API sketch
- `struct ShrinkTree<T> { let value: T; let children: () -> [ShrinkTree<T>] }`
- `protocol Shrinkable { associatedtype T; func shrinkTree(_ value: T) -> ShrinkTree<T> }`

### Search strategy
Use **BFS** (or “best-first” with a user-defined simplicity metric) to find the smallest failing value:
1. Start at the failing value.
2. Enqueue its children.
3. Visit candidates in queue order; keep the smallest failing seen.
4. Continue until queue exhausted or `maxShrinks`/budget is hit.

### Simplicity metric
Default metric (examples):
- integers: absolute value
- arrays: length, then element metrics
- strings: length, then character class

## Fixing current placeholders
- Remove `Shrink.contramap` and `Shrink.flatMap` placeholders or re-implement them using `ShrinkTree`.
- Make `Gen.flatMap` produce a `ShrinkTree` that shrinks both the outer value and the dependent inner value.
