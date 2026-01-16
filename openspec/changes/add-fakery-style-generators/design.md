# Fakery-Style Generators Design

## Context

InvariantSwift currently provides primitive generators (Int, String, Bool) but lacks realistic, domain-specific data generation. Property-based testing benefits from realistic test data that represents production scenarios. This design adds Fakery-style generators with:

1. **Parentheses-free API** using computed properties
2. **Edge case injection** for stress-testing properties
3. **Full Gen<T> integration** for composability

## Goals / Non-Goals

### Goals
- Provide realistic data generators for common domains (names, addresses, internet, commerce)
- Clean API without parentheses (using computed properties)
- Probabilistic edge case injection (5% malformed data by default)
- Seamless integration with existing Gen<T> system
- Zero external dependencies

### Non-Goals
- Full locale/internationalization support (use English data initially)
- Database-backed data generation (keep in-memory)
- Runtime data file loading (embed data in code)
- 100% Fakery API parity (implement subset based on common use cases)

## Decisions

### Decision 1: Computed Properties through Gen.fake Namespace

**Choice**: Use computed properties on `Gen.fake` nested structs to provide `Gen.fake.name.firstName` syntax.

**Implementation**:
```swift
extension Gen {
  public static let fake = FakeGenerators()
}

public struct FakeGenerators {
  public let name = NameGenerators()
  public let address = AddressGenerators()
  public let internet = InternetGenerators()
  // ...
}

public struct NameGenerators {
  public var firstName: Gen<String> {
    Gen.withEdgeCases(
      normal: Gen.oneOf(/* first name pool */),
      edge: Gen.oneOf("", "A", "🙂", /* malformed names */)
    )
  }
  
  public var lastName: Gen<String> {
    Gen.withEdgeCases(
      normal: Gen.oneOf(/* last name pool */),
      edge: Gen.oneOf("", "X", "Jr.", /* edge cases */)
    )
  }
  
  public var fullName: Gen<String> {
    Gen.zip(firstName, lastName).map { "\($0) \($1)" }
  }
}
```

**Rationale**: 
- Computed properties eliminate parentheses while maintaining flexibility
- Each access returns a fresh `Gen<T>` instance (no shared state)
- Naturally composes with Gen combinators (map, zip, flatMap)
- Unified API: everything goes through `Gen` namespace

**Alternatives considered**:
- Static functions: `Gen.fake.name.firstName()` - requires parentheses (rejected per requirement)
- Global variables: Would share state across tests (unsafe)
- Separate `Fake` namespace: Less discoverable than `Gen.fake` (rejected per user feedback)

### Decision 2: Probabilistic Edge Case Injection

**Choice**: Mix realistic and malformed data at generation time based on configurable probability.

**Implementation**:
```swift
public struct FakeConfig: Sendable {
  public var edgeCaseFrequency: Double = 0.05 // 5% by default
  
  public static var current = FakeConfig()
}

extension Gen {
  public static func configureFake(edgeCaseFrequency: Double) {
    FakeConfig.current.edgeCaseFrequency = edgeCaseFrequency
  }
  
  static func withEdgeCases<T>(normal: Gen<T>, edge: Gen<T>) -> Gen<T> {
    Gen { rng, size in
      let roll = Double.random(in: 0..<1, using: &rng)
      if roll < FakeConfig.current.edgeCaseFrequency {
        return edge.generate(&rng, size)
      } else {
        return normal.generate(&rng, size)
      }
    }
  }
}
```

**Rationale**:
- Property-based testing thrives on finding edge cases
- 5% edge case rate balances realistic data with stress testing
- Configurable frequency allows developers to tune based on needs
- Deterministic: same seed produces same edge case distribution

**Edge case categories**:
- **Empty/nil**: Empty strings, zero values
- **Boundary**: Max/min integers, extreme coordinates
- **Invalid format**: Malformed emails, broken URLs
- **Special characters**: Unicode, emoji, control characters
- **Unexpected types**: Numeric strings where text expected

### Decision 3: Embedded Data Sources

**Choice**: Embed data arrays directly in Swift code rather than loading from files.

**Implementation**:
```swift
private let firstNames = [
  "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason",
  "Isabella", "James", "Mia", "Alexander", "Charlotte", "Michael",
  // ... 100-200 names
]

private let lastNames = [
  "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
  "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
  // ... 100-200 names
]
```

**Rationale**:
- Zero runtime file I/O (fast, no filesystem dependencies)
- No bundle resource management complexity
- Easy to audit and version control
- Sufficient variety for property testing (100-200 items per category)

**Alternatives considered**:
- JSON files in Resources/: Adds complexity, slower
- External library dependency: Against project philosophy
- Locale-based data files: Over-engineering for v1

### Decision 4: Gen<T> Return Types

**Choice**: All Fake generators return `Gen<T>` types directly.

**Implementation**:
```swift
public var firstName: Gen<String> { /* ... */ }
public var email: Gen<String> { /* ... */ }
public var price: Gen<Double> { /* ... */ }
```

**Rationale**:
- Seamless integration with existing Gen system
- Natural composition with combinators
- Automatic shrinking support
- Type-safe at compile time

**Benefits**:
```swift
// Works directly with existing APIs
let property = Property(generator: Gen.fake.name.firstName) { name in
  !name.isEmpty // Will find edge case: empty string
}

// Composes naturally
let personGen = Gen.zip(
  Gen.fake.name.fullName,
  Gen.fake.internet.email,
  Gen.fake.address.city
).map { name, email, city in
  Person(name: name, email: email, city: city)
}
```

### Decision 5: Data Source Size

**Choice**: Use 100-200 items per category (names, cities, companies, etc.)

**Rationale**:
- Sufficient variety for property testing
- Keeps binary size reasonable (~50KB for all data)
- Easy to read and maintain
- Balance between realism and pragmatism

**Categories and sizes**:
- First names: 200
- Last names: 200
- Cities: 150
- Street names: 100
- Company names: 100
- Product adjectives: 50
- Product materials: 30
- Product types: 50
- Colors: 40
- Departments: 20
- Lorem words: 500

## Risks / Trade-offs

### Risk 1: Binary Size Growth
- **Mitigation**: Monitor binary size; current estimate ~50KB for all data
- **Acceptable**: InvariantSwift is dev-time only dependency

### Risk 2: Predictable Data Patterns
- **Risk**: Limited data pools might create patterns in tests
- **Mitigation**: Randomization + edge case injection prevents predictability
- **Acceptable**: 100-200 items per category provides sufficient variety

### Risk 3: Edge Case Over-Triggering
- **Risk**: 5% edge case rate might be too high/low for some users
- **Mitigation**: Fully configurable via `Fake.configure(edgeCaseFrequency:)`
- **Default**: 5% balances finding bugs vs. realistic data

### Risk 4: Non-locale Specific Data
- **Risk**: English-only data may not suit all users
- **Mitigation**: Extensibility via custom providers (future enhancement)
- **Acceptable**: English is universal default; can extend later

## Migration Plan

**No migration needed** - This is an additive change with no breaking changes.

**Adoption path**:
1. Import InvariantSwift
2. Use `Gen.fake.name.firstName`, `Gen.fake.internet.email`, etc. directly
3. Optionally configure edge case frequency with `Gen.configureFake(edgeCaseFrequency:)`
4. Compose with existing Gen<T> system

**Example migration**:
```swift
// Before: Manual string generators
let nameGen = Gen<String> { rng, size in 
  ["Alice", "Bob", "Charlie"].randomElement(using: &rng)!
}

// After: Realistic fake generator via Gen.fake
let nameGen = Gen.fake.name.firstName
```

## Open Questions

1. **Q**: Should we support custom data providers in v1?
   - **A**: No. Defer to v2. Keep v1 simple with embedded data.

2. **Q**: Should edge case frequency be global or per-generator?
   - **A**: Global in v1 for simplicity. Can add per-generator control later if needed.

3. **Q**: Should we include NSFW/profanity filtering?
   - **A**: No. Keep data neutral and professional. Curate data sources manually.

4. **Q**: Should Lorem generators support variable lengths?
   - **A**: Yes. `Fake.lorem.words(count:)` can be added later, but v1 uses computed properties for consistency.
