# ISP-0001: Scheduler-Based Race Condition Testing

- **Status:** Implemented
- **Priority:** P0 (Critical)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce `@AsyncPropertyTest` macro and `Scheduler` type to enable deterministic testing of concurrent Swift code, detecting race conditions through controlled interleaving of async operations.

## Motivation

### The Problem

Race conditions are among the most insidious bugs in software:

1. **Non-deterministic**: They appear sporadically, often only under specific timing conditions
2. **Hard to reproduce**: Traditional tests pass 99% of the time, failing randomly in CI
3. **Difficult to debug**: By the time you observe the bug, the conditions that caused it are gone
4. **Increasingly common**: Swift's structured concurrency (`async/await`, `actor`, `Task`) makes concurrent code easier to write but doesn't eliminate race conditions

Consider this common pattern:

```swift
actor Cache {
    private var storage: [String: Data] = [:]
    
    func get(_ key: String) async -> Data? {
        if let cached = storage[key] {
            return cached
        }
        let data = await fetchFromNetwork(key)
        storage[key] = data  // Race condition if multiple callers fetch same key!
        return data
    }
}
```

Traditional property tests cannot reliably catch this bug because:
- The system scheduler determines execution order
- Tests run too fast for interleaving to occur
- You'd need thousands of runs to maybe hit the race

### The Solution

A **scheduler** that controls exactly when async operations resume, allowing systematic exploration of all possible interleavings:

```swift
@AsyncPropertyTest(scheduler: .exhaustive(depth: 5))
func testCacheConcurrency(keys: [String]) async {
    let cache = Cache()
    
    await withTaskGroup(of: Void.self) { group in
        for key in keys {
            group.addTask { _ = await cache.get(key) }
            group.addTask { _ = await cache.get(key) }
        }
    }
    
    // If we get here without deadlock/crash, the interleaving was safe
    #expect(await cache.isConsistent)
}
```

## Detailed Design

### Core Types

```swift
/// Controls the execution order of concurrent operations
public struct Scheduler: Sendable {
    /// Exploration strategy for interleavings
    public enum Strategy: Sendable {
        /// Random interleaving (default, fast)
        case random(seed: UInt64?)
        
        /// Systematic exploration up to depth
        case exhaustive(depth: Int)
        
        /// Prioritize interleavings likely to expose bugs
        case targeted(heuristic: InterleavingHeuristic)
        
        /// Replay a specific interleaving path
        case replay(path: InterleavingPath)
    }
    
    /// The strategy used for this scheduler
    public let strategy: Strategy
    
    /// Schedule an async operation for controlled execution
    public func schedule<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T
    
    /// Schedule a function, returning a controlled version
    public func scheduleFunction<T: Sendable, R: Sendable>(
        _ f: @escaping @Sendable (T) async throws -> R
    ) -> @Sendable (T) async throws -> R
    
    /// Wait for all scheduled operations to complete
    public func waitAll() async
    
    /// Wait until no operations are pending
    public func waitIdle() async
    
    /// Current interleaving path (for reproduction)
    public var currentPath: InterleavingPath { get }
}

/// Records the exact sequence of operation orderings
public struct InterleavingPath: Sendable, Codable, CustomStringConvertible {
    public let steps: [Int]  // Which pending operation was chosen at each step
    
    public var description: String {
        steps.map(String.init).joined(separator: ":")
    }
}

/// Heuristics for targeted interleaving exploration
public enum InterleavingHeuristic: Sendable {
    /// Favor interleavings that maximize context switches
    case maxContextSwitches
    
    /// Favor interleavings where operations complete in reverse start order
    case reverseCompletion
    
    /// Favor interleavings that delay specific operations
    case delay(pattern: String)
    
    /// Custom heuristic
    case custom(@Sendable ([PendingOperation]) -> Int)
}
```

### The `@AsyncPropertyTest` Macro

```swift
@attached(peer, names: named(test))
public macro AsyncPropertyTest(
    scheduler: Scheduler.Strategy = .random(seed: nil),
    iterations: Int = 100,
    maxInterleavings: Int = 1000,
    timeout: Duration = .seconds(30)
) = #externalMacro(module: "InvariantSwiftMacros", type: "AsyncPropertyTestMacro")
```

**Expansion Example:**

```swift
// Input
@AsyncPropertyTest(scheduler: .exhaustive(depth: 3))
func testConcurrentQueue(items: [Int]) async {
    // test body
}

// Expands to
@Test(arguments: PropertyRunner.cases(for: ([Int]).self, count: 100))
func testConcurrentQueue(items: [Int]) async {
    let scheduler = Scheduler(strategy: .exhaustive(depth: 3))
    var interleavingsExplored = 0
    
    while let nextPath = scheduler.nextInterleaving(), interleavingsExplored < 1000 {
        interleavingsExplored += 1
        
        do {
            try await withScheduler(scheduler) {
                // Original test body with scheduler injected
            }
        } catch let failure as PropertyFailure {
            // Shrink the interleaving path
            let minimalPath = await shrinkInterleaving(
                path: scheduler.currentPath,
                reproduce: { path in
                    try await withScheduler(Scheduler(strategy: .replay(path: path))) {
                        // test body
                    }
                }
            )
            
            Issue.record("""
                Race condition detected!
                Interleaving: \(minimalPath)
                Input: \(items)
                """)
            return
        }
    }
}
```

### Actor Isolation Testing

Special support for testing `actor` isolation:

```swift
@AsyncPropertyTest(scheduler: .targeted(heuristic: .maxContextSwitches))
func testActorIsolation(
    @Gen(.array(of: .int, count: 1...10)) operations: [Int]
) async {
    let counter = Counter()  // actor
    
    await withTaskGroup(of: Void.self) { group in
        for op in operations {
            if op % 2 == 0 {
                group.addTask { await counter.increment() }
            } else {
                group.addTask { _ = await counter.value }
            }
        }
    }
    
    // Actor isolation should guarantee this
    #expect(await counter.value >= 0)
}
```

### MainActor Testing

For UI code that must run on `@MainActor`:

```swift
@AsyncPropertyTest
@MainActor
func testUIUpdates(updates: [UIUpdate]) async {
    let viewModel = ViewModel()
    
    // Scheduler respects @MainActor isolation
    for update in updates {
        await viewModel.apply(update)
    }
    
    #expect(viewModel.isConsistent)
}
```

### Integration with TaskGroup

The scheduler hooks into Swift's concurrency primitives:

```swift
extension Scheduler {
    /// Create a TaskGroup where child task execution is controlled
    public func withTaskGroup<ChildTaskResult: Sendable, GroupResult>(
        of childTaskResultType: ChildTaskResult.Type,
        returning returnType: GroupResult.Type = GroupResult.self,
        body: (inout TaskGroup<ChildTaskResult>) async -> GroupResult
    ) async -> GroupResult
    
    /// Create a ThrowingTaskGroup with controlled execution
    public func withThrowingTaskGroup<ChildTaskResult: Sendable, GroupResult>(
        of childTaskResultType: ChildTaskResult.Type,
        returning returnType: GroupResult.Type = GroupResult.self,
        body: (inout ThrowingTaskGroup<ChildTaskResult, Error>) async throws -> GroupResult
    ) async rethrows -> GroupResult
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Actor State Machines**
   ```swift
   @AsyncPropertyTest
   func testActorStateMachine(commands: [Command]) async {
       let machine = StateMachineActor()
       for cmd in commands {
           await machine.execute(cmd)
       }
       #expect(await machine.isValidState)
   }
   ```

2. **Concurrent Data Structures**
   ```swift
   @AsyncPropertyTest(scheduler: .exhaustive(depth: 4))
   func testConcurrentDictionary(ops: [DictOperation]) async {
       let dict = ConcurrentDictionary<String, Int>()
       await withTaskGroup(of: Void.self) { group in
           for op in ops {
               group.addTask { await dict.apply(op) }
           }
       }
   }
   ```

3. **Network Request Ordering**
   ```swift
   @AsyncPropertyTest
   func testRequestCoalescing(requests: [Request]) async {
       let client = CoalescingClient()
       let results = await withTaskGroup(of: Response.self) { group in
           for req in requests {
               group.addTask { await client.fetch(req) }
           }
           return await group.reduce(into: []) { $0.append($1) }
       }
       // Coalesced requests should return identical responses
       #expect(results.allEqual(by: \.data))
   }
   ```

4. **Async Stream Processing**
   ```swift
   @AsyncPropertyTest
   func testStreamMerging(
       stream1: [Int],
       stream2: [Int]
   ) async {
       let merged = merge(stream1.async, stream2.async)
       let collected = await Array(merged)
       
       // All elements should be present
       #expect(Set(collected) == Set(stream1 + stream2))
   }
   ```

5. **Database Transaction Isolation**
   ```swift
   @AsyncPropertyTest(scheduler: .targeted(heuristic: .reverseCompletion))
   func testTransactionIsolation(transactions: [Transaction]) async {
       let db = Database()
       await withTaskGroup(of: Void.self) { group in
           for tx in transactions {
               group.addTask { try? await db.execute(tx) }
           }
       }
       #expect(await db.isConsistent)
   }
   ```

### ❌ When NOT to Use

1. **Pure synchronous code** — No concurrency, no races
2. **Single-threaded async** — Sequential `await` chains
3. **Performance-critical paths** — Scheduler adds overhead
4. **Third-party async APIs** — Can't control their scheduling

## Importance

### Why This Matters

1. **Unique in Swift Ecosystem**
   - No existing Swift testing framework offers controlled concurrency testing
   - Would be a **first-of-its-kind** capability for Swift
   - Directly addresses pain points with `actor` and `Task` testing

2. **Proven Technique**
   - fast-check's scheduler has found bugs in major JS projects
   - CHESS (Microsoft Research) pioneered this for .NET
   - Academic research validates systematic interleaving exploration

3. **Swift Concurrency Adoption**
   - Swift 6 strict concurrency is driving massive adoption
   - More concurrent code = more potential race conditions
   - Developers need tools to verify their actor designs

4. **CI Reliability**
   - Deterministic tests don't flake
   - Reproducible failures with exact interleaving paths
   - Shrinking finds minimal race-triggering sequences

### Real-World Impact

| Scenario | Without Scheduler | With Scheduler |
|----------|------------------|----------------|
| Race detection | ~1% chance per run | 100% if exists |
| Reproduction | "Works on my machine" | Exact path replay |
| Debugging | Add sleep(), pray | Minimal interleaving |
| CI stability | Random failures | Deterministic |
| Coverage | Luck-based | Systematic |

## Implementation Notes

### Phase 1: Core Scheduler
- Basic random interleaving
- Task suspension points
- Path recording and replay

### Phase 2: Systematic Exploration
- Exhaustive enumeration (bounded)
- State-space reduction (DPOR algorithm)
- Targeted heuristics

### Phase 3: Integration
- `@AsyncPropertyTest` macro
- Automatic shrinking of interleavings
- Integration with existing generators

### Phase 4: Advanced Features
- Deadlock detection
- Livelock detection
- Memory ordering tests (if Swift exposes)

## Alternatives Considered

### 1. Thread Sanitizer (TSan)
- **Pros**: Built into Xcode, catches data races
- **Cons**: Only catches races that actually happen, not deterministic, significant overhead

### 2. Stress Testing (Run 10000 Times)
- **Pros**: Simple, no new concepts
- **Cons**: Unreliable, slow, doesn't guarantee coverage

### 3. Manual Synchronization Points
- **Pros**: Full control
- **Cons**: Tedious, error-prone, doesn't generalize

## References

- [fast-check Scheduler Documentation](https://fast-check.dev/docs/advanced/race-conditions/)
- [CHESS: Systematic Concurrency Testing](https://www.microsoft.com/en-us/research/project/chess-find-and-reproduce-heisenbugs-in-concurrent-programs/)
- [Systematic Testing for Concurrent Programs](https://dl.acm.org/doi/10.1145/1926385.1926432)
- [Swift Concurrency Manifesto](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
