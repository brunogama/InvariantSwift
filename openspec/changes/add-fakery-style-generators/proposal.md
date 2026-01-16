# Add Fakery-Style Generators

## Why

InvariantSwift needs realistic, domain-specific data generators for property-based testing. Currently, generators produce only primitive types (Int, String, Bool), but real-world testing requires realistic data like names, addresses, emails, and business entities. Fakery-style generators provide:

1. **Realistic test data** - Names, addresses, companies that look authentic
2. **Property-based edge cases** - Mix of valid and intentionally malformed data to break tests
3. **Domain-specific types** - Internet, commerce, business, Lorem Ipsum, etc.
4. **Fluent API without parentheses** - Clean, readable generator syntax using computed properties

This enables developers to write property tests with meaningful, realistic data that better represents production scenarios.

## What Changes

- Add `Gen.fake` namespace with computed property-based API (no parentheses)
- Implement domain-specific generators: Name, Address, Internet, Company, Commerce, Lorem, etc.
- Include edge-case generation strategy: occasionally produce malformed/invalid data to stress-test properties
- All fake generators accessible through `Gen.fake` for unified API
- Support extensibility for custom fake data providers

**API Design (no parentheses):**
```swift
// Clean, fluent API using computed properties through Gen namespace
let nameGen = Gen.fake.name.firstName    // Gen<String>
let emailGen = Gen.fake.internet.email  // Gen<String>
let companyGen = Gen.fake.company.name  // Gen<String>

// Composability with existing Gen system
let personGen = Gen.zip(Gen.fake.name.fullName, Gen.fake.internet.email)
```

**Edge-case strategy:**
- 95% valid data, 5% intentionally malformed (empty strings, special characters, boundary values)
- Configurable via `Gen.configureFake(edgeCaseFrequency: 0.05)`

## Impact

- **Affected specs**: New capability `fakery-generators` (no existing specs)
- **Affected code**:
  - `Sources/InvariantSwift/Generators/FakeryGenerators.swift` (new)
  - `Sources/InvariantSwift/Core/Generator.swift` (extension for Fake namespace)
  - `Tests/FunctionalTesting/FakeryGeneratorTests.swift` (new)
- **Breaking changes**: None (additive only)
- **Dependencies**: None (self-contained, no external libraries)
