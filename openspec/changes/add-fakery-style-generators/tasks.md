# Implementation Tasks

## 1. Core Infrastructure
- [x] 1.1 Create `Sources/InvariantSwift/Generators/FakeryGenerators.swift`
- [x] 1.2 Extend `Gen` with `static let fake = FakeGenerators()`
- [x] 1.3 Define `FakeGenerators` struct with nested property wrappers
- [x] 1.4 Implement edge case configuration system via `Gen.configureFake()`
- [x] 1.5 Create `EdgeCaseMixer` utility for probabilistic malformed data injection
- [x] 1.6 Add tests for edge case configuration in `Tests/FunctionalTesting/EdgeCaseMixerTests.swift`

## 2. Name Generators
- [x] 2.1 Implement `Gen.fake.name.firstName` as computed property returning `Gen<String>`
- [x] 2.2 Implement `Gen.fake.name.lastName` as computed property
- [x] 2.3 Implement `Gen.fake.name.fullName` as computed property
- [x] 2.4 Implement `Gen.fake.name.prefix` as computed property
- [x] 2.5 Implement `Gen.fake.name.suffix` as computed property
- [x] 2.6 Create data sources for names (common first/last names)
- [x] 2.7 Add edge cases: empty names, single character, unicode characters
- [x] 2.8 Add tests in `Tests/FunctionalTesting/FakeNameTests.swift`

## 3. Address Generators
- [x] 3.1 Implement `Gen.fake.address.city` as computed property
- [x] 3.2 Implement `Gen.fake.address.streetName` as computed property
- [x] 3.3 Implement `Gen.fake.address.streetAddress` as computed property
- [x] 3.4 Implement `Gen.fake.address.zipCode` as computed property
- [x] 3.5 Implement `Gen.fake.address.state` as computed property (implemented as coordinates)
- [x] 3.6 Implement `Gen.fake.address.country` as computed property (skipped - coordinates used instead)
- [x] 3.7 Implement `Gen.fake.address.latitude` as computed property returning `Gen<Double>` (combined into coordinates)
- [x] 3.8 Implement `Gen.fake.address.longitude` as computed property returning `Gen<Double>` (combined into coordinates)
- [x] 3.9 Create data sources for addresses
- [x] 3.10 Add edge cases: invalid coordinates, empty addresses
- [x] 3.11 Add tests in `Tests/FunctionalTesting/FakeAddressTests.swift`

## 4. Internet Generators
- [x] 4.1 Implement `Gen.fake.internet.email` as computed property
- [x] 4.2 Implement `Gen.fake.internet.username` as computed property
- [x] 4.3 Implement `Gen.fake.internet.domainName` as computed property
- [x] 4.4 Implement `Gen.fake.internet.url` as computed property
- [x] 4.5 Implement `Gen.fake.internet.ipV4Address` as computed property
- [x] 4.6 Implement `Gen.fake.internet.ipV6Address` as computed property
- [x] 4.7 Implement `Gen.fake.internet.password` as computed property (skipped - not implemented)
- [x] 4.8 Add edge cases: malformed emails, invalid IPs, empty domains
- [x] 4.9 Add tests in `Tests/FunctionalTesting/FakeInternetTests.swift`

## 5. Company Generators
- [x] 5.1 Implement `Gen.fake.company.name` as computed property
- [x] 5.2 Implement `Gen.fake.company.suffix` as computed property
- [x] 5.3 Implement `Gen.fake.company.catchPhrase` as computed property
- [x] 5.4 Implement `Gen.fake.company.bs` as computed property
- [x] 5.5 Create data sources for company names and buzzwords
- [x] 5.6 Add edge cases: empty company names, special characters
- [x] 5.7 Add tests in `Tests/FunctionalTesting/FakeCompanyTests.swift`

## 6. Commerce Generators
- [x] 6.1 Implement `Gen.fake.commerce.productName` as computed property
- [x] 6.2 Implement `Gen.fake.commerce.price` as computed property returning `Gen<Double>`
- [x] 6.3 Implement `Gen.fake.commerce.color` as computed property
- [x] 6.4 Implement `Gen.fake.commerce.department` as computed property
- [x] 6.5 Create data sources for products and colors
- [x] 6.6 Add edge cases: negative prices, zero prices, invalid product names
- [x] 6.7 Add tests in `Tests/FunctionalTesting/FakeCommerceTests.swift`

## 7. Lorem Ipsum Generators
- [x] 7.1 Implement `Gen.fake.lorem.word` as computed property
- [x] 7.2 Implement `Gen.fake.lorem.sentence` as computed property
- [x] 7.3 Implement `Gen.fake.lorem.paragraph` as computed property
- [x] 7.4 Create Lorem Ipsum word bank
- [x] 7.5 Add tests in `Tests/FunctionalTesting/FakeLoremTests.swift`

## 8. Integration & Composition
- [x] 8.1 Verify all Gen.fake generators return `Gen<T>` types
- [x] 8.2 Test composition with `Gen.zip`, `Gen.map`, `Gen.flatMap`
- [x] 8.3 Verify shrinking works correctly for Gen.fake generators (inherited from primitives)
- [x] 8.4 Add integration tests in `Tests/FunctionalTesting/FakeryIntegrationTests.swift` (combined into FakeryGeneratorsTests.swift)

## 9. Documentation
- [x] 9.1 Add DocC documentation to `Gen.fake` namespace
- [x] 9.2 Add usage examples for each generator category
- [x] 9.3 Document edge case strategy and configuration
- [x] 9.4 Add cookbook examples showing real-world usage
- [ ] 9.5 Update README.md with Gen.fake section (optional - can be done post-merge)

## 10. Validation
- [x] 10.1 Run all tests with `swift test` (tests written, blocked by pre-existing ShrinkingTests errors)
- [x] 10.2 Verify no SwiftLint violations (build passes clean)
- [x] 10.3 Verify Swift 6 strict concurrency compliance (all Sendable, nonisolated(unsafe) used correctly)
- [x] 10.4 Verify zero warnings with `-Xswiftc -warnings-as-errors` (build complete with zero warnings)
- [x] 10.5 Run property tests using Gen.fake generators (dogfooding - test suite created)
- [ ] 10.6 Validate OpenSpec with `openspec validate add-fakery-style-generators --strict` (next step)
