# ISP-0004: Example Database and Reproducible Failures

- **Status:** Implemented
- **Priority:** P1 (High)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce an example database system that persists failing test cases across runs, combined with `@Reproduce` macro for deterministic replay of specific failures.

## Motivation

### The Problem

Property-based testing generates random inputs. When a test fails:

1. **Lost failures**: Re-running might not reproduce the same failure
2. **CI amnesia**: Each CI run starts fresh, potentially missing known bugs
3. **Debugging friction**: Developers must manually extract and hard-code failing cases
4. **Flaky appearance**: Same bug might manifest differently across runs

**Common frustration:**
```
// CI log from yesterday:
// ❌ testSorting failed with input: [3, -1, 0, 2147483647, -2147483648]

// Today's run:
// ✅ testSorting passed (100 examples)

// The bug is still there, we just got lucky!
```

### The Solution

1. **Example Database**: Automatically persist failing cases
2. **`@Reproduce` Macro**: Replay exact failures deterministically
3. **Failure Prioritization**: Check known failures before random generation

```swift
// Automatic: Failures are saved to ~/.invariant/examples.db
@PropertyTest
func testSorting(array: [Int]) {
    let sorted = array.sorted()
    #expect(sorted.isSorted)
}

// When debugging: Replay exact failure
@PropertyTest
@Reproduce(seed: 0xDEADBEEF, size: 42)
func testSorting(array: [Int]) {
    // Will generate exact same array every time
}

// Or with full shrink path
@PropertyTest
@Reproduce(path: "0:1:3:0:2", seed: 12345)
func testSorting(array: [Int]) {
    // Replays the minimal shrunk example
}
```

## Detailed Design

### Example Database

```swift
/// Persistent storage for failing test examples
public actor ExampleDatabase {
    /// Shared instance using default location
    public static let shared = ExampleDatabase()
    
    /// Storage backend
    public enum Backend: Sendable {
        case file(URL)           // SQLite file
        case memory              // In-memory (testing)
        case directory(URL)      // One file per test (git-friendly)
        case none                // Disabled
    }
    
    /// Initialize with custom backend
    public init(backend: Backend = .file(.defaultExampleDatabaseURL))
    
    /// Save a failing example
    public func save(
        testID: TestIdentifier,
        example: FailingExample
    ) async
    
    /// Retrieve all known failing examples for a test
    public func examples(
        for testID: TestIdentifier
    ) async -> [FailingExample]
    
    /// Mark an example as fixed (no longer failing)
    public func markFixed(
        testID: TestIdentifier,
        example: FailingExample
    ) async
    
    /// Clear all examples for a test
    public func clear(testID: TestIdentifier) async
    
    /// Clear entire database
    public func clearAll() async
}

/// Identifies a specific property test
public struct TestIdentifier: Hashable, Codable {
    public let module: String
    public let file: String
    public let function: String
    public let signature: String  // Parameter types hash
}

/// A recorded failing example
public struct FailingExample: Codable, Sendable {
    public let seed: UInt64
    public let size: Int
    public let shrinkPath: [Int]?
    public let serializedInput: Data?  // Codable input
    public let failureMessage: String
    public let timestamp: Date
    public let swiftVersion: String
    public let frameworkVersion: String
}
```

### Configuration

```swift
/// Global configuration for example database
public enum ExampleDatabaseConfig {
    /// The active database backend
    public static var backend: ExampleDatabase.Backend = .file(.defaultExampleDatabaseURL)
    
    /// Maximum examples to store per test
    public static var maxExamplesPerTest: Int = 100
    
    /// Whether to save examples automatically
    public static var autoSave: Bool = true
    
    /// Whether to check saved examples first
    public static var checkSavedFirst: Bool = true
    
    /// Prune examples older than this
    public static var maxAge: Duration? = .days(30)
}

extension URL {
    /// Default location: ~/.invariant/examples.db
    public static var defaultExampleDatabaseURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".invariant")
            .appendingPathComponent("examples.db")
    }
}
```

### The `@Reproduce` Macro

```swift
/// Replay a specific failing example deterministically
@attached(peer)
public macro Reproduce(
    seed: UInt64,
    size: Int? = nil,
    path: String? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "ReproduceMacro")

/// Replay from serialized input directly
@attached(peer)
public macro Reproduce(
    input: String  // Base64-encoded Codable
) = #externalMacro(module: "InvariantSwiftMacros", type: "ReproduceMacro")
```

**Usage:**

```swift
// Reproduce with seed (regenerates input)
@PropertyTest
@Reproduce(seed: 0xDEADBEEF)
func testParser(input: String) { ... }

// Reproduce with seed and size
@PropertyTest
@Reproduce(seed: 12345, size: 50)
func testLargeInput(data: [Int]) { ... }

// Reproduce with full shrink path
@PropertyTest
@Reproduce(seed: 12345, path: "0:1:3:0:2")
func testComplex(data: ComplexStruct) { ... }

// Reproduce with serialized input (most reliable)
@PropertyTest
@Reproduce(input: "eyJuYW1lIjoiSm9obiIsImFnZSI6MzB9")
func testUser(user: User) { ... }
```

### Expansion Example

**Input:**
```swift
@PropertyTest
@Reproduce(seed: 0xDEADBEEF, size: 42)
func testSorting(array: [Int]) {
    let sorted = array.sorted()
    #expect(sorted.isSorted)
}
```

**Expands to:**
```swift
@Test
func testSorting() {
    // Fixed seed and size from @Reproduce
    let config = PropertyConfig(
        seed: 0xDEADBEEF,
        initialSize: 42,
        maxSize: 42,  // Fixed size
        iterations: 1  // Single deterministic run
    )
    
    let generator = Gen<[Int]>.arbitrary
    var rng = SeededRandomNumberGenerator(seed: 0xDEADBEEF)
    let array = generator.generate(using: &rng, size: 42)
    
    // Original test body
    let sorted = array.sorted()
    #expect(sorted.isSorted)
}
```

### Integration with Property Runner

```swift
extension PropertyRunner {
    /// Run a property test with example database integration
    public static func run<each T: Generatable>(
        _ property: (repeat each T) throws -> Void,
        config: PropertyConfig = .default,
        file: StaticString = #file,
        function: StaticString = #function
    ) async throws {
        let testID = TestIdentifier(
            module: String(describing: #module),
            file: String(describing: file),
            function: String(describing: function),
            signature: typeSignature(repeat each T.self)
        )
        
        // Phase 1: Check saved failing examples first
        if ExampleDatabaseConfig.checkSavedFirst {
            let savedExamples = await ExampleDatabase.shared.examples(for: testID)
            for example in savedExamples {
                if let result = try? replayExample(example, property: property) {
                    if case .failure = result {
                        // Still fails - report immediately
                        throw PropertyFailure(example: example)
                    } else {
                        // Fixed! Remove from database
                        await ExampleDatabase.shared.markFixed(testID: testID, example: example)
                    }
                }
            }
        }
        
        // Phase 2: Random exploration
        var rng = config.rng
        for size in config.sizeSequence {
            let input = (repeat (each T).arbitrary.generate(using: &rng, size: size))
            
            do {
                try property(repeat each input)
            } catch {
                // Shrink and save
                let shrunk = shrink(input: input, property: property)
                
                let example = FailingExample(
                    seed: config.seed,
                    size: size,
                    shrinkPath: shrunk.path,
                    serializedInput: try? encode(shrunk.input),
                    failureMessage: error.localizedDescription,
                    timestamp: Date(),
                    swiftVersion: swiftVersion,
                    frameworkVersion: frameworkVersion
                )
                
                if ExampleDatabaseConfig.autoSave {
                    await ExampleDatabase.shared.save(testID: testID, example: example)
                }
                
                throw PropertyFailure(example: example)
            }
        }
    }
}
```

### Failure Message Format

When a test fails, InvariantSwift outputs reproduction information:

```
❌ Property failed: testSorting

Input: [3, -1, 0, 2147483647, -2147483648]
Shrunk from: [3, -17, 0, 2147483647, -2147483648, 42, -999]
Shrink steps: 12

To reproduce this exact failure, add:
    @Reproduce(seed: 0xDEADBEEF, size: 42, path: "0:1:3:0:2")

Or with serialized input:
    @Reproduce(input: "WzMsLTEsMCwyMTQ3NDgzNjQ3LC0yMTQ3NDgzNjQ4XQ==")

Example saved to: ~/.invariant/examples.db
Run with INVARIANT_CHECK_SAVED=1 to verify saved examples first.
```

### Directory-Based Storage (Git-Friendly)

For teams that want to commit failing examples:

```swift
// In test configuration
ExampleDatabaseConfig.backend = .directory(
    URL(fileURLWithPath: "Tests/FailingExamples")
)
```

Creates structure:
```
Tests/FailingExamples/
├── MyModule/
│   ├── testSorting/
│   │   ├── example_001.json
│   │   └── example_002.json
│   └── testParsing/
│       └── example_001.json
└── OtherModule/
    └── ...
```

**Benefits:**
- Version control tracks when bugs were introduced/fixed
- Code review can include new failing examples
- CI can validate all known failures are fixed before merge

### Environment Variables

```bash
# Disable example database
INVARIANT_EXAMPLES_DISABLED=1

# Custom database location
INVARIANT_EXAMPLES_PATH=/custom/path/examples.db

# Always check saved examples first
INVARIANT_CHECK_SAVED=1

# Clear database before run
INVARIANT_CLEAR_EXAMPLES=1

# Verbose logging
INVARIANT_DEBUG=1
```

## When to Use

### ✅ Ideal Use Cases

1. **CI Pipelines**
   ```yaml
   # GitHub Actions
   - name: Run property tests
     env:
       INVARIANT_CHECK_SAVED: "1"
       INVARIANT_EXAMPLES_PATH: "./failing_examples.db"
     run: swift test
   
   - name: Archive failing examples
     if: failure()
     uses: actions/upload-artifact@v3
     with:
       name: failing-examples
       path: failing_examples.db
   ```

2. **Debugging Sessions**
   ```swift
   // Copy from CI output
   @PropertyTest
   @Reproduce(seed: 0xDEADBEEF, path: "0:1:3")
   func testFailingCase(input: ComplexInput) {
       // Set breakpoint here
       processInput(input)
   }
   ```

3. **Regression Prevention**
   ```swift
   // Keep in test file permanently until root cause fixed
   @PropertyTest
   @Reproduce(input: "base64encodeddata...")
   func testKnownBug_JIRA123(data: Data) {
       // This specific input caused crash in production
   }
   ```

4. **Sharing Failures**
   ```swift
   // Slack/GitHub message:
   // "Found a bug! Add this to reproduce:"
   // @Reproduce(seed: 12345, size: 50, path: "0:2:1")
   ```

5. **Bisecting**
   ```bash
   # Find which commit introduced the bug
   git bisect start
   git bisect bad HEAD
   git bisect good v1.0.0
   git bisect run swift test --filter testFailingCase
   # @Reproduce ensures same input every run
   ```

### ❌ When NOT to Use

1. **Intentionally non-deterministic tests** — Some tests should explore randomly
2. **Very large inputs** — Serialization might be impractical
3. **External dependencies** — Network/DB state affects reproducibility
4. **Ephemeral debugging** — Just use print statements

## Importance

### Why This Matters

1. **CI Reliability**
   - No more "flaky" property tests
   - Known failures always checked first
   - New failures automatically persisted

2. **Developer Experience**
   - One-line reproduction of any failure
   - No manual input extraction
   - Immediate debugging capability

3. **Team Collaboration**
   - Share exact failures across team
   - Version control failing examples
   - Clear audit trail of bugs

4. **Bug Investigation**
   - Deterministic reproduction
   - Bisect-friendly
   - Minimal examples via shrinking

### Comparison with Other Frameworks

| Framework | Persistence | Reproduction | Git-Friendly |
|-----------|-------------|--------------|--------------|
| Hypothesis | ✅ SQLite | ✅ @seed | ✅ Directory mode |
| fast-check | ✅ File | ✅ seed/path | ❌ |
| SwiftCheck | ❌ | ❌ Manual | ❌ |
| **InvariantSwift** | ✅ SQLite | ✅ @Reproduce | ✅ Directory mode |

## Implementation Notes

### Phase 1: Core Persistence
- SQLite-based `ExampleDatabase`
- `@Reproduce(seed:)` macro
- Failure message formatting

### Phase 2: Enhanced Reproduction
- `@Reproduce(path:)` for shrink paths
- `@Reproduce(input:)` for serialized inputs
- Environment variable configuration

### Phase 3: Git Integration
- Directory-based storage
- JSON format for examples
- Example pruning/cleanup

### Phase 4: Tooling
- CLI for managing examples
- IDE integration
- CI helpers

## Alternatives Considered

### 1. Annotation-Based Only
```swift
@PropertyTest(seed: 12345)
func testFixed(input: String) { ... }
```
- **Rejected**: Conflates configuration with reproduction

### 2. External File Reference
```swift
@PropertyTest
@ReproduceFrom("failing_examples/test1.json")
func testFixed(input: String) { ... }
```
- **Rejected**: Extra file management, easy to desync

### 3. Automatic Seed Logging Only
```
// Just log: "Seed: 12345, Size: 42"
// Developer manually adds to test
```
- **Rejected**: Too much friction, often forgotten

## References

- [Hypothesis Example Database](https://hypothesis.readthedocs.io/en/latest/database.html)
- [fast-check Seed and Path](https://fast-check.dev/docs/core-blocks/runners/#seed)
- [Property-Based Testing with PropEr, Erlang, and Elixir](https://pragprog.com/titles/fhproper/property-based-testing-with-proper-erlang-and-elixir/)
- [Deterministic Simulation Testing](https://www.youtube.com/watch?v=4fFDFbi3toc) — FoundationDB talk
