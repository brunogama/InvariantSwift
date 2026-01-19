# Fuzzing Guide

LibFuzzer integration for coverage-guided fuzz testing of Swift code.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [FuzzTarget API](#fuzztarget-api)
4. [FuzzDataProvider](#fuzzdataprovider)
5. [Crash Detection](#crash-detection)
6. [Corpus Management](#corpus-management)
7. [CI Integration](#ci-integration)

---

## Overview

InvariantSwift provides LibFuzzer integration for coverage-guided fuzzing. Unlike random testing, fuzzing:

- Uses **code coverage feedback** to guide input generation
- Automatically discovers **edge cases and crashes**
- Builds a **corpus of interesting inputs**
- Integrates with sanitizers (ASan, TSan, UBSan)

---

## Quick Start

### 1. Define a Fuzz Target

```swift
import InvariantSwift

let target = FuzzTarget(name: "parseJSON") { data in
    let provider = FuzzDataProvider(data: data)
    
    // Consume structured data from fuzz bytes
    let jsonString = provider.consumeString(maxLength: 1000)
    
    // Test the function under fuzzing
    _ = try? JSONDecoder().decode(MyModel.self, from: Data(jsonString.utf8))
}
```

### 2. Register and Run

```swift
// Register the target
await FuzzTestRunner.shared.register(target)

// Run fuzzing (typically from CLI or CI)
await FuzzTestRunner.shared.executeDefault()
```

### 3. Run via Make

```bash
# Add to Makefile
fuzz:
    swift run FuncTestCLI fuzz --target parseJSON --iterations 10000
```

---

## FuzzTarget API

### Creating Targets

```swift
// Simple target
let simple = FuzzTarget(name: "simple") { data in
    processBytes(data)
}

// Target with typed generator
let typed = FuzzTarget(
    name: "typedInput",
    generator: Gen<MyInput>.arbitrary
) { input in
    validateInput(input)
}

// Target with configuration
let configured = FuzzTarget(
    name: "configured",
    config: FuzzableConfig(
        maxInputSize: 4096,
        timeout: 5.0,
        sanitizers: [.address, .undefined]
    )
) { data in
    riskyOperation(data)
}
```

### Target Results

```swift
enum FuzzResult {
    case ok                    // Input processed successfully
    case interesting           // New coverage discovered
    case crash(CrashType)      // Crash detected
    case timeout               // Execution timed out
}
```

---

## FuzzDataProvider

Convert raw fuzz bytes into structured Swift types.

### Basic Consumption

```swift
let provider = FuzzDataProvider(data: fuzzData)

// Primitives
let int = provider.consumeInt()
let bool = provider.consumeBool()
let double = provider.consumeDouble()

// Bounded values
let bounded = provider.consumeInt(in: 0...100)

// Strings
let string = provider.consumeString(maxLength: 256)
let ascii = provider.consumeAsciiString(maxLength: 100)

// Data
let bytes = provider.consumeBytes(count: 32)
let remaining = provider.consumeRemainingBytes()
```

### Arrays and Collections

```swift
// Fixed-size array
let fixedArray = provider.consumeArray(count: 10) {
    provider.consumeInt()
}

// Variable-size array
let varArray = provider.consumeArray(maxCount: 100) {
    provider.consumeString(maxLength: 50)
}

// Dictionaries
let dict = provider.consumeDictionary(maxCount: 20) {
    (provider.consumeString(maxLength: 10), provider.consumeInt())
}
```

### Enums and Choices

```swift
enum Operation { case add, subtract, multiply, divide }

// Pick from enum cases
let op = provider.consumeEnum(Operation.self)

// Weighted choice
let weighted = provider.consumeWeighted([
    (0.7, "common"),
    (0.2, "uncommon"),
    (0.1, "rare")
])
```

### Complex Types

```swift
struct User: Sendable {
    let id: UUID
    let name: String
    let age: Int
}

extension FuzzDataProvider {
    func consumeUser() -> User {
        User(
            id: UUID(uuid: consumeBytes(count: 16).withUnsafeBytes { 
                $0.load(as: uuid_t.self) 
            }),
            name: consumeString(maxLength: 50),
            age: consumeInt(in: 0...150)
        )
    }
}
```

---

## Crash Detection

### Crash Types

```swift
enum CrashType: Sendable {
    case signal(Int32)           // SIGSEGV, SIGABRT, etc.
    case assertion(String)       // Assertion failure
    case precondition(String)    // Precondition failure
    case fatalError(String)      // fatalError()
    case outOfMemory             // Memory exhaustion
    case timeout                 // Execution timeout
}
```

### Crash Isolation

InvariantSwift runs fuzz targets in isolated processes to safely catch crashes:

```swift
let runner = IsolatedPropertyRunner()

let result = await runner.runProperty(property)

switch result {
case .success:
    print("No crashes found")
case .crashed(let input, let crashType, let shrunk):
    print("Crash found!")
    print("Type: \(crashType)")
    print("Minimal input: \(shrunk)")
}
```

### Crash Shrinking

When a crash is found, the fuzzer automatically shrinks the input:

```swift
// Original crash input: 4096 bytes
// After shrinking: 12 bytes (minimal reproducer)

let crash = FuzzingCrash(
    input: minimalInput,
    crashType: .signal(11),
    reproducer: "FuzzData(bytes: [0x00, 0x01, ...])"
)

// Save for regression testing
try await crash.save(to: ".invariant/crashes/")
```

---

## Corpus Management

### Building a Corpus

```swift
let corpus = try await CorpusDatabase(path: ".invariant/corpus.db")

// Fuzzing automatically adds interesting inputs
let runner = FuzzTestRunner(corpus: corpus)
await runner.execute(target, iterations: 100000)

// Check corpus statistics
let stats = try await corpus.getStatistics()
print("Corpus size: \(stats.totalCount)")
print("Unique edges: \(stats.uniqueEdges)")
```

### Seeding the Corpus

```swift
// Add known interesting inputs as seeds
let seeds = [
    Data("{}".utf8),           // Empty JSON
    Data("[]".utf8),           // Empty array
    Data("{\"key\": null}".utf8),  // Null value
]

for seed in seeds {
    try await corpus.put(CorpusEntry(data: seed, source: .seed))
}
```

### Corpus Pruning

```swift
// Remove redundant or old entries
try await corpus.prune(
    strategy: .minimizeEdges,    // Keep inputs with unique coverage
    maxSize: 10000               // Cap corpus size
)
```

---

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/fuzz.yml
name: Fuzz Testing

on:
  schedule:
    - cron: '0 0 * * *'  # Nightly
  workflow_dispatch:

jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        
      - name: Build with Sanitizers
        run: |
          swift build -c release \
            -Xswiftc -sanitize=address \
            -Xswiftc -sanitize=undefined
      
      - name: Run Fuzzing
        run: |
          swift run FuncTestCLI fuzz \
            --target all \
            --iterations 100000 \
            --corpus .invariant/corpus
      
      - name: Upload Crashes
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: fuzz-crashes
          path: .invariant/crashes/
      
      - name: Upload Corpus
        uses: actions/upload-artifact@v4
        with:
          name: fuzz-corpus
          path: .invariant/corpus/
```

### Makefile Integration

```makefile
# Fuzz testing targets
fuzz:
	swift run FuncTestCLI fuzz --iterations 10000

fuzz-overnight:
	swift run FuncTestCLI fuzz --iterations 1000000

fuzz-minimize:
	swift run FuncTestCLI fuzz --minimize-corpus

fuzz-reproduce:
	swift run FuncTestCLI fuzz --reproduce .invariant/crashes/crash-001.txt
```

---

## Best Practices

### 1. Start Small

```swift
// Focus fuzzing on parser/decoder functions
let target = FuzzTarget(name: "parseHeader") { data in
    _ = try? Header.parse(data)
}
```

### 2. Use Sanitizers

```bash
# Build with address sanitizer
swift build -Xswiftc -sanitize=address
```

### 3. Seed with Real Data

```swift
// Use real-world examples as seeds
let seeds = try FileManager.default.contentsOfDirectory(atPath: "testdata/")
for seed in seeds {
    try await corpus.put(CorpusEntry(data: Data(contentsOf: seed)))
}
```

### 4. Monitor Coverage

```swift
let result = await runner.execute(target, iterations: 100000)
print("Coverage: \(result.coverage.percentage)%")
print("New edges: \(result.coverage.newEdges)")
```

---

## See Also

- [ADVANCED.md](ADVANCED.md) - Coverage-guided testing
- [ISP-0007](proposals/ISP-0007-libfuzzer-integration.md) - LibFuzzer proposal
- [SHRINKING.md](SHRINKING.md) - Shrinking strategies
