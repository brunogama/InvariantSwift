# ISP-0007: LibFuzzer Integration

- **Status:** Implemented
- **Priority:** P3 (Low)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce `@Fuzzable` macro to bridge InvariantSwift property tests with LLVM's LibFuzzer for industrial-strength mutation-based fuzzing.

## Motivation

### The Problem

Property-based testing and fuzzing are complementary:

| Aspect | Property Testing | Fuzzing |
|--------|-----------------|---------|
| Input Generation | Structured, type-aware | Byte-level mutation |
| Iteration Count | ~100-1000 | Millions+ |
| Coverage Guidance | Optional (InvariantSwift has it) | Core feature |
| Shrinking | Built-in | Crash minimization |
| Speed | Medium | Very fast |
| Corpus | None | Evolving |

**Current state:**
- Property tests find logic bugs with smart generation
- Fuzzers find crashes with brute-force mutation
- No bridge between them in Swift

### The Solution

Unite both worlds:

```swift
@Fuzzable
func parseJSON(_ data: Data) throws -> JSON {
    // This function will be:
    // 1. Testable via @PropertyTest with structured JSON
    // 2. Fuzzable via LibFuzzer with raw bytes
    // 3. Corpus seeded from property test failures
}
```

## Detailed Design

### The `@Fuzzable` Macro

```swift
/// Makes a function available for LibFuzzer integration
@attached(peer, names: named(LLVMFuzzerTestOneInput))
@attached(peer, names: named(fuzzTarget))
public macro Fuzzable(
    maxLength: Int = 4096,
    timeout: Duration = .seconds(30),
    corpusDir: String? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "FuzzableMacro")
```

### Expansion Example

**Input:**
```swift
@Fuzzable(maxLength: 1024)
func parseProtobuf(_ data: Data) throws -> Message {
    try Message(serializedData: data)
}
```

**Expands to:**
```swift
// Original function unchanged
func parseProtobuf(_ data: Data) throws -> Message {
    try Message(serializedData: data)
}

// LibFuzzer entry point
@_cdecl("LLVMFuzzerTestOneInput")
public func LLVMFuzzerTestOneInput(
    _ data: UnsafePointer<UInt8>,
    _ size: Int
) -> CInt {
    let buffer = Data(bytes: data, count: min(size, 1024))
    
    do {
        _ = try parseProtobuf(buffer)
    } catch {
        // Parse errors are expected, not crashes
        return 0
    }
    
    return 0  // Success
}

// Structured target for property testing
enum FuzzTarget_parseProtobuf {
    static func test(_ data: Data) throws {
        _ = try parseProtobuf(data)
    }
    
    static let generator: Gen<Data> = .data(0...1024)
}
```

### Structured Fuzzing

For functions with typed inputs, generate structure-aware mutations:

```swift
@Fuzzable
@StructuredInput
func processUser(_ user: User) throws {
    // ...
}

// Generated: Custom mutator that understands User structure
@_cdecl("LLVMFuzzerCustomMutator")
public func LLVMFuzzerCustomMutator(
    _ data: UnsafeMutablePointer<UInt8>,
    _ size: Int,
    _ maxSize: Int,
    _ seed: UInt32
) -> Int {
    // Decode as User, mutate fields, re-encode
    var rng = SplitMix64(seed: UInt64(seed))
    
    guard let user = try? User.decode(from: Data(bytes: data, count: size)) else {
        // Invalid, generate fresh
        let newUser = User.arbitrary.generate(using: &rng, size: 50)
        return encode(newUser, into: data, maxSize: maxSize)
    }
    
    // Mutate one field
    var mutated = user
    switch Int.random(in: 0..<3, using: &rng) {
    case 0: mutated.name = String.arbitrary.generate(using: &rng, size: 20)
    case 1: mutated.age = Int.arbitrary.generate(using: &rng, size: 100)
    case 2: mutated.email = Gen.email.generate(using: &rng, size: 50)
    default: break
    }
    
    return encode(mutated, into: data, maxSize: maxSize)
}
```

### Corpus Seeding

Property test failures become fuzzer corpus entries:

```swift
@Fuzzable(corpusDir: "Corpus/parseJSON")
func parseJSON(_ data: Data) throws -> JSON {
    // ...
}

// When property test finds failure:
// 1. Serialize failing input to Corpus/parseJSON/
// 2. Fuzzer picks up and mutates further
// 3. Cross-pollination between approaches
```

### Integration with Coverage-Guided Generation

InvariantSwift's coverage guidance feeds into fuzzing:

```swift
@Fuzzable
@CoverageGuided
func processInput(_ data: Data) {
    // Coverage feedback from property tests
    // informs fuzzer's mutation strategy
}
```

### Fuzzing Modes

```swift
public enum FuzzingMode {
    /// Property testing with random generation
    case propertyTest(iterations: Int)
    
    /// LibFuzzer mutation-based fuzzing
    case libfuzzer(runs: Int, timeout: Duration)
    
    /// Hybrid: property test then fuzz failures
    case hybrid(propertyIterations: Int, fuzzRuns: Int)
    
    /// OSS-Fuzz compatible mode
    case ossFuzz
}

@Fuzzable(mode: .hybrid(propertyIterations: 1000, fuzzRuns: 100_000))
func parseComplex(_ data: Data) { ... }
```

### CLI Integration

```bash
# Run as property test
$ functest test --target parseJSON

# Run as fuzzer
$ functest fuzz --target parseJSON --runs 1000000 --timeout 60

# Generate corpus from property test failures
$ functest corpus --target parseJSON --output Corpus/

# Minimize corpus
$ functest minimize --corpus Corpus/parseJSON/
```

### Sanitizer Integration

```swift
@Fuzzable(sanitizers: [.address, .undefined])
func processUntrustedInput(_ data: Data) {
    // Compiled with ASan and UBSan for fuzzing
}
```

Build configuration:
```bash
# Fuzzing build
swift build -c release \
    -Xswiftc -sanitize=address,fuzzer \
    -Xswiftc -parse-as-library
```

### Crash Analysis

When fuzzer finds a crash:

```swift
public struct FuzzingCrash {
    public let input: Data
    public let inputHex: String
    public let crashType: CrashType  // SEGV, ABRT, timeout, OOM
    public let stackTrace: String
    public let minimized: Data?
    
    /// Convert to property test reproduction
    public func toPropertyTest() -> String {
        """
        @Test
        func testCrash_\(inputHex.prefix(8))() {
            let input = Data(hex: "\(inputHex)")
            // Expected to crash or be fixed
            _ = try? parseJSON(input)
        }
        """
    }
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Parser/Deserializer Testing**
   ```swift
   @Fuzzable
   func parseXML(_ data: Data) throws -> XMLDocument { ... }
   
   @Fuzzable
   func decodeProtobuf(_ data: Data) throws -> Message { ... }
   
   @Fuzzable
   func parseMarkdown(_ text: String) -> AST { ... }
   ```

2. **Compression/Decompression**
   ```swift
   @Fuzzable
   func decompress(_ data: Data) throws -> Data { ... }
   
   @Fuzzable
   func decryptAES(_ ciphertext: Data, key: Data) throws -> Data { ... }
   ```

3. **Image Processing**
   ```swift
   @Fuzzable(maxLength: 1_000_000)
   func decodeImage(_ data: Data) throws -> CGImage { ... }
   ```

4. **Network Protocol Handling**
   ```swift
   @Fuzzable
   func parseHTTPRequest(_ data: Data) throws -> HTTPRequest { ... }
   
   @Fuzzable
   func handleWebSocketFrame(_ data: Data) throws { ... }
   ```

5. **Security-Sensitive Code**
   ```swift
   @Fuzzable(sanitizers: [.address, .memory, .undefined])
   func validateCertificate(_ data: Data) throws -> Certificate { ... }
   ```

### ❌ When NOT to Use

1. **Pure business logic** — Property tests are better suited
2. **High-level APIs** — Fuzzing works best at byte boundaries
3. **Network-dependent code** — External state complicates fuzzing
4. **Very slow operations** — Fuzzing needs speed (millions of iterations)

## Importance

### Why This Matters

1. **Security Hardening**
   - Fuzzers find memory corruption bugs
   - Essential for parsing untrusted input
   - OSS-Fuzz has found thousands of CVEs

2. **Complementary Approaches**
   - Property tests: Smart, structured, few iterations
   - Fuzzing: Dumb, fast, millions of iterations
   - Together: Best of both worlds

3. **Continuous Fuzzing**
   - OSS-Fuzz provides free fuzzing infrastructure
   - Run 24/7, find bugs you'd never think of
   - Automatic bug reports

4. **Industry Standard**
   - Google, Microsoft, Apple all use fuzzing
   - Required for many security certifications
   - LLVM LibFuzzer is the de facto standard

### Real-World Bugs Found by Fuzzing

| Project | Bug Type | CVE |
|---------|----------|-----|
| ImageIO (Apple) | Buffer overflow | CVE-2020-27929 |
| libpng | Heap corruption | CVE-2019-7317 |
| SQLite | Integer overflow | Many |
| OpenSSL | Heartbleed-class | Many |
| SwiftNIO | Multiple | N/A |

## Implementation Notes

### Phase 1: Basic Integration
- `@Fuzzable` macro generating `LLVMFuzzerTestOneInput`
- Data-based fuzzing
- Corpus directory support

### Phase 2: Structured Fuzzing
- Custom mutators from `@Arbitrary`
- Type-aware mutation
- Cross-over support

### Phase 3: Tooling
- CLI commands for fuzzing
- Corpus management
- Crash analysis and reproduction

### Phase 4: CI Integration
- OSS-Fuzz integration guide
- GitHub Actions workflow
- Continuous fuzzing setup

### Build System Requirements

```swift
// Package.swift
.target(
    name: "FuzzTargets",
    dependencies: ["MyLibrary"],
    swiftSettings: [
        .unsafeFlags([
            "-sanitize=fuzzer,address",
            "-parse-as-library"
        ], .when(configuration: .release))
    ]
)
```

## Alternatives Considered

### 1. Standalone Fuzzer Wrapper
```swift
// Separate file: fuzz_parseJSON.swift
import LibFuzzer
FuzzTest(parseJSON)
```
- **Rejected**: Disconnected from main code, easy to forget

### 2. Macro-Free Integration
```swift
protocol Fuzzable {
    static func fuzz(_ data: Data)
}
```
- **Rejected**: Requires manual implementation, no code generation

### 3. Swift-Only Fuzzing (No LibFuzzer)
```swift
InvariantSwift.fuzz(parseJSON, iterations: 1_000_000)
```
- **Rejected**: Reinventing the wheel, LibFuzzer is mature and fast

## References

- [LibFuzzer Documentation](https://llvm.org/docs/LibFuzzer.html)
- [Structure-Aware Fuzzing with libFuzzer](https://github.com/google/fuzzing/blob/master/docs/structure-aware-fuzzing.md)
- [OSS-Fuzz](https://github.com/google/oss-fuzz)
- [Swift Fuzzing Guide](https://github.com/apple/swift/blob/main/docs/Fuzzing.md)
- [American Fuzzy Lop (AFL)](https://lcamtuf.coredump.cx/afl/)
- [Hypothesis + Atheris (Python Fuzzer)](https://hypothesis.readthedocs.io/en/latest/details.html#use-with-external-fuzzers)
