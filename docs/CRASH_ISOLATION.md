# Crash Isolation on macOS

## Overview

InvariantSwift provides opt-in crash isolation for property tests on macOS through subprocess execution. This feature allows property tests to catch and report crashes (fatalError, precondition failures, assertion failures) without terminating the test process.

## Platform Support

| Platform | Subprocess Isolation | Fallback Behavior |
|----------|---------------------|-------------------|
| macOS 14+ | ✅ Full support | N/A |
| iOS | ❌ Not available | In-process execution |
| tvOS | ❌ Not available | In-process execution |
| watchOS | ❌ Not available | In-process execution |
| Linux | ❌ Not available | In-process execution |

## Usage

### Basic Usage

```swift
import Testing
import InvariantSwift

@Test("Property with crash isolation")
func testWithCrashIsolation() async throws {
    let property = Property(generator: Gen<Int>.int) { value in
        // This might crash
        precondition(value >= 0, "Value must be non-negative")
        return true
    }
    
    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(property)
    
    switch result {
    case .success(let iterations):
        print("Passed \(iterations) tests")
        
    case .crashed(let signal, let counterexample, let shrunk, _):
        print("Crashed with signal \(signal)")
        print("Original: \(counterexample)")
        print("Shrunk: \(shrunk)")
        
    case .failure(let counterexample, _, let shrunk, _, let reason):
        print("Failed: \(reason)")
        print("Shrunk: \(shrunk)")
        
    case .gaveUp(let discards):
        print("Gave up after \(discards) discarded inputs")
    }
}
```

### Configuration

```swift
let config = PropertyConfig(
    iterations: 100,
    maxShrinks: 50,
    timeout: 5.0  // Timeout per iteration
)

let result = await runner.runProperty(property, config: config)
```

## How It Works

### IPC Protocol

The crash isolation system uses a subprocess-based architecture:

1. **Parent Process** - The main test runner spawns a helper executable
2. **Helper Process** - Executes individual property test iterations
3. **IPC** - Length-prefixed JSON over stdin/stdout

### Request/Response Flow

```
Parent                           Helper
  |                                |
  |--- PropertyEvaluationRequest -->|
  |    (testId, seed, testInput)   |
  |                                |
  |                         Execute predicate
  |                                |
  |<-- PropertyEvaluationResponse --|
  |    (passed, failureReason)     |
  |                                |
```

If the helper crashes (SIGABRT, SIGSEGV), the parent detects the abnormal termination and reports it as a crash.

## Limitations

### macOS Only

Subprocess isolation is only available on macOS 14+ because:

- iOS/tvOS/watchOS prohibit process spawning in sandboxed apps
- Linux support requires additional posix_spawn implementation

### Performance Overhead

- **Subprocess spawn**: ~10-50ms per test iteration
- **IPC serialization**: ~1-5ms per iteration

For non-crashing code, use the standard `PropertyRunner` for better performance.

### Serialization Requirements

Test inputs must be serializable to JSON. Types supported:

- Primitives: `Int`, `Double`, `String`, `Bool`
- Collections: `Array`, `Dictionary`
- Custom types implementing `Codable`

### No Shared State

Each subprocess has a fresh process space. Global state is not shared between iterations.

## Architecture

### Files

| File | Purpose |
|------|---------|
| `SubprocessIsolation.swift` | IPC protocol and subprocess executor |
| `IsolatedPropertyRunner.swift` | Actor-based runner with crash detection |
| `AnyCodable.swift` | Type-erased Codable support |
| `PropertyTestHelper/main.swift` | Helper executable for subprocess |

### Package Structure

```
InvariantSwift/
├── Sources/
│   ├── InvariantSwift/Core/
│   │   ├── SubprocessIsolation.swift
│   │   ├── IsolatedPropertyRunner.swift
│   │   └── AnyCodable.swift
│   └── PropertyTestHelper/
│       └── main.swift              # Helper executable
```

## Future Work

### Potential Improvements

- [ ] Linux support via posix_spawn
- [ ] Shared memory IPC for large payloads
- [ ] Batch mode: multiple iterations per subprocess
- [ ] XPC service for persistent helper process
- [ ] Custom serialization formats (MessagePack, Protocol Buffers)

### Non-Goals

- iOS/tvOS/watchOS support (platform restrictions)
- Signal handling within the same process (not portable)
- Recovering from crashes in-process (impossible with fatalError)

## References

- [ISP-XXXX] Crash Isolation Proposal
- [Foundation.Process documentation](https://developer.apple.com/documentation/foundation/process)
- [Swift subprocess package](https://github.com/swiftlang/swift-subprocess)
