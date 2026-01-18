# InvariantSwift Proposals

This directory contains proposals for new features and enhancements to InvariantSwift.

## Proposal Status

| ID | Title | Priority | Status |
|----|-------|----------|--------|
| [ISP-0001](ISP-0001-scheduler-race-condition-testing.md) | Scheduler-Based Race Condition Testing | P0 | Draft |
| [ISP-0002](ISP-0002-composite-generators.md) | Composite Generators with `#draw` | P0 | Draft |
| [ISP-0003](ISP-0003-rule-based-stateful-testing.md) | Rule-Based Stateful Testing | P1 | Draft |
| [ISP-0004](ISP-0004-example-database-reproduce.md) | Example Database and `@Reproduce` | P1 | Draft |
| [ISP-0005](ISP-0005-differential-testing.md) | Differential Testing | P2 | Draft |
| [ISP-0006](ISP-0006-contract-testing.md) | Contract Testing | P2 | Draft |
| [ISP-0007](ISP-0007-libfuzzer-integration.md) | LibFuzzer Integration | P3 | Draft |
| [ISP-0008](ISP-0008-targeted-property-testing.md) | Targeted Property Testing | P2 | Draft |
| [ISP-0009](ISP-0009-ghostwriter.md) | Ghostwriter - Automatic Test Generation | P3 | Draft |
| [ISP-0010](ISP-0010-faker-integration.md) | Faker Integration for Realistic Test Data | P3 | Draft |

## Priority Definitions

- **P0 (Critical)**: Core features that significantly differentiate InvariantSwift
- **P1 (High)**: Important features for production readiness
- **P2 (Medium)**: Valuable features that enhance usability
- **P3 (Low)**: Nice-to-have features for future iterations

## Proposal Categories

### 🔥 Critical (P0)

#### [ISP-0001: Scheduler-Based Race Condition Testing](ISP-0001-scheduler-race-condition-testing.md)
**Unique in Swift ecosystem.** Deterministic testing of concurrent Swift code through controlled interleaving of async operations. Essential for testing `actor` isolation and `Task` ordering.

```swift
@AsyncPropertyTest(scheduler: .exhaustive(depth: 5))
func testConcurrentCache(keys: [String]) async {
    let cache = Cache()
    await withTaskGroup(of: Void.self) { group in
        for key in keys {
            group.addTask { _ = await cache.get(key) }
        }
    }
}
```

#### [ISP-0002: Composite Generators with `#draw`](ISP-0002-composite-generators.md)
**Massive ergonomic improvement.** Declarative construction of dependent generators where later values depend on earlier ones, while preserving shrinking.

```swift
@Composite
func validUser() -> Gen<User> {
    let age = #draw(from: .int(0...120))
    let canDrink = age >= 21
    let bar = canDrink ? #draw(String?.self) : nil
    return User(age: age, canDrink: canDrink, favoriteBar: bar)
}
```

### 🎯 High Priority (P1)

#### [ISP-0003: Rule-Based Stateful Testing](ISP-0003-rule-based-stateful-testing.md)
Hypothesis-style stateful testing with rules, bundles, preconditions, and invariants for testing complex stateful systems.

#### [ISP-0004: Example Database and `@Reproduce`](ISP-0004-example-database-reproduce.md)
Persist failing test cases across runs with deterministic replay for debugging and CI reliability.

### ⚡ Medium Priority (P2)

#### [ISP-0005: Differential Testing](ISP-0005-differential-testing.md)
Compare two implementations automatically to find inputs where they diverge—essential for refactoring and migration.

#### [ISP-0006: Contract Testing](ISP-0006-contract-testing.md)
Design by Contract with pre/post conditions and invariants as executable specifications.

#### [ISP-0008: Targeted Property Testing](ISP-0008-targeted-property-testing.md)
Guide generation toward interesting inputs by optimizing for specified metrics.

### 🌟 Nice to Have (P3)

#### [ISP-0007: LibFuzzer Integration](ISP-0007-libfuzzer-integration.md)
Bridge to LLVM's LibFuzzer for industrial-strength mutation-based fuzzing.

#### [ISP-0009: Ghostwriter](ISP-0009-ghostwriter.md)
Automatic property test generation by analyzing code structure.

#### [ISP-0010: Faker Integration](ISP-0010-faker-integration.md)
Built-in faker generators for realistic test data with shrinking support.

## Implementation Roadmap

### Phase 1: Foundation (P0 + P1)
1. **ISP-0002**: Composite generators - ergonomic foundation
2. **ISP-0004**: Example database - production readiness
3. **ISP-0001**: Race condition testing - unique differentiator
4. **ISP-0003**: Rule-based testing - complete stateful testing story

### Phase 2: Enhancement (P2)
5. **ISP-0005**: Differential testing
6. **ISP-0008**: Targeted testing
7. **ISP-0006**: Contract testing

### Phase 3: Ecosystem (P3)
8. **ISP-0009**: Ghostwriter CLI
9. **ISP-0010**: Faker integration
10. **ISP-0007**: LibFuzzer integration

## Competitive Advantage

These proposals would make InvariantSwift the most advanced property-based testing framework for Swift:

| Feature | SwiftCheck | swift-property-based | InvariantSwift |
|---------|------------|----------------------|----------------|
| Race condition testing | ❌ | ❌ | ✅ (ISP-0001) |
| Declarative composites | ❌ | ❌ | ✅ (ISP-0002) |
| Rule-based stateful | ❌ | ❌ | ✅ (ISP-0003) |
| Example database | ❌ | ❌ | ✅ (ISP-0004) |
| Differential testing | ❌ | ❌ | ✅ (ISP-0005) |
| Contract testing | ❌ | ❌ | ✅ (ISP-0006) |
| Targeted generation | ❌ | ❌ | ✅ (ISP-0008) |
| Auto-generation | ❌ | ❌ | ✅ (ISP-0009) |

## Contributing

To propose a new feature:

1. Create a new file: `ISP-XXXX-feature-name.md`
2. Use the existing proposals as templates
3. Include: Summary, Motivation, Detailed Design, When to Use, Importance, Implementation Notes
4. Submit a PR with the proposal

## References

- [Hypothesis Documentation](https://hypothesis.readthedocs.io/)
- [fast-check Documentation](https://fast-check.dev/)
- [QuickCheck Paper](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quickcheck.pdf)
- [Hedgehog Documentation](https://hedgehog.qa/)
