# ISP-0009: Ghostwriter - Automatic Test Generation

- **Status:** Implemented
- **Priority:** P3 (Low)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.0+

## Summary

Introduce the `ghostwrite` CLI command to automatically generate property tests by analyzing code structure and inferring testable properties.

## Motivation

### The Problem

Writing property tests requires:
1. Identifying properties that should hold
2. Writing generators for input types
3. Expressing assertions correctly

This barrier prevents adoption. Many developers:
- Don't know what properties to test
- Find the syntax unfamiliar
- Don't have time to write tests from scratch

**Common scenario:**
```swift
// Developer has this code
struct User: Codable, Equatable {
    let name: String
    let age: Int
}

extension User {
    func validate() -> Bool { ... }
    func hash() -> String { ... }
}

// What property tests should exist?
// 🤷 "I'll write unit tests instead..."
```

### The Solution

Automatic property test generation:

```bash
$ functest ghostwrite --source Sources/Models/User.swift

Generated 4 property tests in Tests/Generated/UserPropertyTests.swift:
  ✓ testUser_codableRoundtrip
  ✓ testUser_equatableReflexive
  ✓ testUser_validate_consistency
  ✓ testUser_hash_deterministic
```

## Detailed Design

### CLI Interface

```bash
# Generate tests for a single file
functest ghostwrite --source Sources/MyFile.swift

# Generate tests for entire module
functest ghostwrite --module MyModule

# Output to specific directory
functest ghostwrite --module MyModule --output Tests/Generated/

# Specify test patterns to generate
functest ghostwrite --source Sources/User.swift \
    --patterns roundtrip,idempotence,equivalence

# Dry run (preview without writing)
functest ghostwrite --source Sources/User.swift --dry-run

# Generate with custom configuration
functest ghostwrite --config ghostwrite.yaml
```

### Inferred Test Patterns

#### 1. Codable Roundtrip

For any `Codable` type:

```swift
// Detected: User: Codable
// Generated:
@PropertyTest
func testUser_codableRoundtrip(user: User) throws {
    let encoded = try JSONEncoder().encode(user)
    let decoded = try JSONDecoder().decode(User.self, from: encoded)
    #expect(decoded == user)
}
```

#### 2. Equatable Properties

For any `Equatable` type:

```swift
// Detected: User: Equatable
// Generated:
@PropertyTest
func testUser_equatableReflexive(user: User) {
    #expect(user == user, "Reflexivity: x == x")
}

@PropertyTest
func testUser_equatableSymmetric(a: User, b: User) {
    if a == b {
        #expect(b == a, "Symmetry: a == b implies b == a")
    }
}

@PropertyTest
func testUser_equatableTransitive(a: User, b: User, c: User) {
    if a == b && b == c {
        #expect(a == c, "Transitivity: a == b && b == c implies a == c")
    }
}
```

#### 3. Hashable Consistency

For any `Hashable` type:

```swift
// Detected: User: Hashable
// Generated:
@PropertyTest
func testUser_hashableConsistency(a: User, b: User) {
    if a == b {
        #expect(a.hashValue == b.hashValue, 
            "Equal values must have equal hashes")
    }
}
```

#### 4. Comparable Ordering

For any `Comparable` type:

```swift
// Detected: Score: Comparable
// Generated:
@PropertyTest
func testScore_comparableIrreflexive(score: Score) {
    #expect(!(score < score), "Irreflexivity: !(x < x)")
}

@PropertyTest
func testScore_comparableAsymmetric(a: Score, b: Score) {
    if a < b {
        #expect(!(b < a), "Asymmetry: a < b implies !(b < a)")
    }
}

@PropertyTest
func testScore_comparableTransitive(a: Score, b: Score, c: Score) {
    if a < b && b < c {
        #expect(a < c, "Transitivity: a < b && b < c implies a < c")
    }
}

@PropertyTest
func testScore_comparableTrichotomy(a: Score, b: Score) {
    let less = a < b
    let equal = a == b
    let greater = b < a
    let exactlyOne = [less, equal, greater].filter { $0 }.count == 1
    #expect(exactlyOne, "Trichotomy: exactly one of <, ==, > holds")
}
```

#### 5. Idempotence

For functions that look idempotent:

```swift
// Detected: func normalize() -> String
// Heuristic: "normalize", "sanitize", "clean", "trim", "format"
// Generated:
@PropertyTest
func testString_normalize_idempotent(input: String) {
    let once = input.normalize()
    let twice = once.normalize()
    #expect(once == twice, "normalize should be idempotent")
}
```

#### 6. Inverse Functions

For function pairs that look like inverses:

```swift
// Detected: func encode() -> Data, func decode(Data) -> Self
// Generated:
@PropertyTest
func testMessage_encodeDecodeRoundtrip(message: Message) throws {
    let encoded = message.encode()
    let decoded = try Message.decode(encoded)
    #expect(decoded == message)
}
```

#### 7. Commutative Operations

For binary operations that might be commutative:

```swift
// Detected: func combine(_ other: Self) -> Self
// Heuristic: "combine", "merge", "union", "intersect", "add"
// Generated:
@PropertyTest
func testSet_union_commutative(a: Set<Int>, b: Set<Int>) {
    #expect(a.union(b) == b.union(a), "union should be commutative")
}
```

#### 8. Collection Invariants

For `Collection` types:

```swift
// Detected: CustomArray: Collection
// Generated:
@PropertyTest
func testCustomArray_countMatchesIteration(array: CustomArray<Int>) {
    var count = 0
    for _ in array { count += 1 }
    #expect(count == array.count)
}

@PropertyTest
func testCustomArray_indicesValid(array: CustomArray<Int>) {
    for index in array.indices {
        // Should not crash
        _ = array[index]
    }
}

@PropertyTest
func testCustomArray_startEndIndices(array: CustomArray<Int>) {
    if array.isEmpty {
        #expect(array.startIndex == array.endIndex)
    } else {
        #expect(array.startIndex < array.endIndex)
    }
}
```

#### 9. Pure Function Properties

For functions detected as pure (no side effects):

```swift
// Detected: func transform(_ input: String) -> String (pure)
// Generated:
@PropertyTest
func testTransform_deterministic(input: String) {
    let result1 = transform(input)
    let result2 = transform(input)
    #expect(result1 == result2, "Pure function should be deterministic")
}
```

#### 10. Failable Initializer Consistency

For failable initializers:

```swift
// Detected: init?(rawValue: String)
// Generated:
@PropertyTest
func testStatus_rawValueRoundtrip(status: Status) {
    let raw = status.rawValue
    let recreated = Status(rawValue: raw)
    #expect(recreated == status)
}
```

### Configuration File

```yaml
# ghostwrite.yaml
output: Tests/Generated/
prefix: "test"
suffix: "PropertyTests"

# Patterns to generate
patterns:
  - codable_roundtrip
  - equatable_laws
  - hashable_consistency
  - comparable_ordering
  - idempotence
  - inverse_functions
  - commutative_operations
  - collection_invariants

# Custom patterns
custom_patterns:
  - name: "api_response"
    match: "struct.*Response.*Codable"
    template: |
      @PropertyTest
      func test${TypeName}_validJSON(response: ${TypeName}) throws {
          let json = try JSONEncoder().encode(response)
          #expect(JSONSerialization.isValidJSONObject(
              try JSONSerialization.jsonObject(with: json)))
      }

# Exclusions
exclude:
  - "**/Generated/**"
  - "**/Mocks/**"

# Type-specific configuration
types:
  User:
    patterns: [codable_roundtrip, equatable_laws]
    custom_generator: "User.validArbitrary"
  
  Price:
    patterns: [comparable_ordering]
    constraints:
      value: "0...1_000_000"
```

### Generated File Structure

```
Tests/
└── Generated/
    ├── ModelsPropertyTests.swift
    │   ├── testUser_codableRoundtrip
    │   ├── testUser_equatableReflexive
    │   └── ...
    ├── ServicesPropertyTests.swift
    │   ├── testParser_idempotent
    │   └── ...
    └── _GhostwriteManifest.json  # Tracks what was generated
```

### Manifest File

```json
{
  "version": "1.0",
  "generatedAt": "2025-01-17T10:30:00Z",
  "sourceHash": "abc123...",
  "tests": [
    {
      "name": "testUser_codableRoundtrip",
      "source": "Sources/Models/User.swift",
      "pattern": "codable_roundtrip",
      "line": 15
    }
  ]
}
```

### Regeneration

```bash
# Regenerate only changed files
functest ghostwrite --incremental

# Force full regeneration
functest ghostwrite --force

# Check if regeneration needed
functest ghostwrite --check
# Exit code 1 if out of date
```

### IDE Integration

```swift
// Xcode: Right-click on type
// Context menu: "Generate Property Tests"

// VSCode: Command palette
// > InvariantSwift: Ghostwrite Tests for Current File
```

## When to Use

### ✅ Ideal Use Cases

1. **Bootstrapping Test Suite**
   ```bash
   # New project, need tests fast
   functest ghostwrite --module MyApp
   # Instant baseline coverage
   ```

2. **Code Review Assistance**
   ```bash
   # What tests should this PR have?
   functest ghostwrite --source PR/NewFeature.swift --dry-run
   ```

3. **Compliance Requirements**
   ```bash
   # Ensure all Codable types have roundtrip tests
   functest ghostwrite --pattern codable_roundtrip --module DataModels
   ```

4. **Learning Tool**
   ```bash
   # Show developers what properties to test
   functest ghostwrite --verbose
   # Explains why each test is generated
   ```

5. **CI Enforcement**
   ```bash
   # Fail if generated tests are out of date
   functest ghostwrite --check || (echo "Regenerate tests!" && exit 1)
   ```

### ❌ When NOT to Use

1. **Complex domain logic** — Need human insight for meaningful properties
2. **Integration tests** — Ghostwriter focuses on unit-level properties
3. **Already well-tested code** — Don't duplicate effort
4. **Non-standard protocols** — Patterns are for standard Swift protocols

## Importance

### Why This Matters

1. **Lower Barrier to Entry**
   - No need to know property testing patterns
   - Get started instantly
   - Learn by example

2. **Consistency**
   - Same patterns applied everywhere
   - No forgotten protocol requirements
   - Automated compliance

3. **Maintenance**
   - Regenerate when code changes
   - Always up to date
   - Track generation in version control

4. **Education**
   - Shows what properties should hold
   - Demonstrates testing patterns
   - Builds intuition over time

### Comparison

| Approach | Coverage | Effort | Quality |
|----------|----------|--------|---------|
| Manual tests | Variable | High | High |
| Ghostwriter | Baseline | Zero | Medium |
| Manual + Ghostwriter | Comprehensive | Medium | High |

## Implementation Notes

### Phase 1: Core Patterns
- Codable roundtrip
- Equatable/Hashable/Comparable laws
- Basic idempotence

### Phase 2: Advanced Inference
- Inverse function detection
- Commutative operation detection
- Collection invariants

### Phase 3: Customization
- Configuration file
- Custom patterns
- Type-specific settings

### Phase 4: Integration
- IDE plugins
- CI helpers
- Incremental regeneration

### Analysis Approach

1. **Parse source files** using SwiftSyntax
2. **Extract type information**: protocols, methods, properties
3. **Match patterns**: Codable, Equatable, naming heuristics
4. **Generate tests**: Apply templates
5. **Write output**: Format and save

### Heuristics for Function Properties

| Pattern | Keywords | Example |
|---------|----------|---------|
| Idempotent | normalize, clean, trim, sanitize, format | `"  hello  ".trim()` |
| Inverse | encode/decode, compress/decompress, encrypt/decrypt | `encode()`/`decode()` |
| Commutative | union, intersect, merge, combine, add | `a.union(b)` |
| Associative | combine, append, concat | `(a + b) + c` |

## Alternatives Considered

### 1. Annotation-Based Generation
```swift
@GenerateTests(.codable, .equatable)
struct User { ... }
```
- **Rejected**: Requires modifying source code

### 2. Compile-Time Generation
```swift
// Swift macro that generates tests at compile time
@AutoPropertyTests
struct User { ... }
```
- **Rejected**: Macros can't create new files

### 3. IDE-Only
```swift
// Only generate via Xcode refactoring
```
- **Rejected**: Not automatable, not CI-friendly

## References

- [Hypothesis Ghostwriter](https://hypothesis.readthedocs.io/en/latest/ghostwriter.html)
- [QuickCheck Derive](https://hackage.haskell.org/package/quickcheck-instances)
- [AutoFixture (.NET)](https://github.com/AutoFixture/AutoFixture)
- [Kotlin Test Generation](https://www.jetbrains.com/help/idea/create-tests.html)
- [TypeScript Test Generation](https://github.com/microsoft/TypeScript/wiki/Using-the-Compiler-API)
