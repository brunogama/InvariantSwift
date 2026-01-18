# AGENTS.md - InvariantSwift Main Library

> **Sub-package AGENTS.md** for `Sources/InvariantSwift/`

## Package Identity

**Purpose:** Core property-based testing library for Swift  
**Framework:** Pure Swift 6.0 with Sendable conformance  
**Exports:** `Gen<T>`, `Property`, `Shrink<T>`, `Seed`, `Size`, macros, and test runners

---

## Setup & Run

```bash
# Build this package
swift build

# Run all library tests
swift test --filter FunctionalTesting

# Run single test file
swift test --filter "GeneratorTests"

# Typecheck
swift build -Xswiftc -warnings-as-errors
```

---

## Directory Structure

```
InvariantSwift/
├── Core/              # Gen, Property, Shrink, Seed, Size
├── Generators/        # String, Int, Collection generators
├── Advanced/          # TreeGen, lens, prism, metamorphic
├── Faker/             # Fake data generators (ISP-0010)
├── Ghostwriter/       # Auto-test generation (ISP-0009)
├── Fuzzing/           # LibFuzzer integration (ISP-0007)
├── Contract/          # Contract testing (ISP-0006)
├── Differential/      # Differential testing (ISP-0005)
├── Database/          # Example database (ISP-0004)
├── SwiftTesting/      # Swift Testing integration
├── Testing/           # Test runners and configuration
├── Macros/            # Macro declarations (not implementations)
├── Persistence/       # Shrink tree persistence
├── Presentation/      # Pretty-printing, reporters
├── Reliability/       # Flaky test detection
└── Observability/     # Metrics and telemetry
```

---

## Patterns & Conventions

### ✅ DO: Generator Pattern
```swift
// See: Core/Generator.swift (lines 547-634)
public struct Gen<T>: @unchecked Sendable {
  public let generate: (inout any RandomNumberGenerator, Size) -> T
  public let shrink: Shrink<T>
}
```

### ✅ DO: Use Gen combinators
```swift
// See: Generators/StringGenerator.swift
Gen<String>.faker(.email)
Gen<Int>.pure(42)
Gen.oneOf([gen1, gen2])
Gen.zip(genA, genB).map { "\($0):\($1)" }
```

### ✅ DO: Implement Shrink strategies
```swift
// See: Core/Generator.swift (lines 95-512)
Shrink<Int> { n in Shrink.towards(0, n) }
Shrink.removeElements(from: array)
```

### ❌ DON'T: Use force unwrap
```swift
// BAD
let value = optional!

// GOOD
guard let value = optional else { return }
```

### ❌ DON'T: Use fatalError in library code
```swift
// BAD
fatalError("Invalid state")

// GOOD - Make illegal states unrepresentable
enum State { case valid(Data) }  // No invalid case
```

---

## Touch Points / Key Files

| File | Purpose |
|------|---------|
| `Core/Generator.swift` | `Gen<T>`, `Shrink<T>`, `Size`, `Seed` |
| `Core/Property.swift` | Property test definition |
| `Testing/PropertyRunner.swift` | Test execution engine |
| `Generators/StringGenerator.swift` | String generators |
| `Faker/FakerGenerator.swift` | 100+ fake data generators |
| `Ghostwriter/Ghostwriter.swift` | Auto-test generation |
| `FunctionalTesting.swift` | Public API exports |

---

## JIT Index Hints

```bash
# Find all generators
rg -n "public static (func|var)" Generators/ Core/

# Find Faker types
rg -n "case \." Faker/FakerType.swift

# Find shrink implementations
rg -n "Shrink\(" Core/Generator.swift

# Find property test patterns
rg -n "@Property|checkProperty" .

# Find all public API
rg -n "^public " --type swift
```

---

## Common Gotchas

1. **Sendable conformance** - All generators must be `@unchecked Sendable` because closures capture mutable RNG
2. **Size parameter** - Always pass through `Size` for recursive generators to prevent infinite depth
3. **Shrink termination** - Ensure shrink functions eventually return `[]` to prevent infinite loops
4. **Determinism** - Same `Seed` + `Size` must always produce same value

---

## Pre-PR Checks

```bash
swift build -Xswiftc -warnings-as-errors && \
swift test --filter FunctionalTesting && \
swiftlint lint --strict Sources/InvariantSwift/
```
