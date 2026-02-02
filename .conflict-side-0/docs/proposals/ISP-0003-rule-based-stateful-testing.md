# ISP-0003: Rule-Based Stateful Testing

- **Status:** Implemented
- **Priority:** P1 (High)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce `@RuleBasedTest` macro for declarative stateful testing where Hypothesis-style rules define valid operations, bundles accumulate values, and invariants are checked automatically after each step.

## Motivation

### The Problem

Testing stateful systems (databases, caches, UI, network layers) requires:
1. Generating sequences of operations
2. Tracking state changes
3. Verifying invariants after each operation
4. Comparing against a reference model

Current approaches are imperative and verbose:

```swift
@PropertyTest
func testDatabaseOperations(operations: [DatabaseOp]) {
    let db = Database()
    var model: [String: Data] = [:]
    
    for op in operations {
        switch op {
        case .write(let key, let value):
            // Must manually track if key was previously generated
            db.write(key: key, value: value)
            model[key] = value
        case .read(let key):
            // Key might not exist - test becomes flaky
            let result = db.read(key: key)
            XCTAssertEqual(result, model[key])
        case .delete(let key):
            db.delete(key: key)
            model.removeValue(forKey: key)
        }
    }
}
```

**Problems:**
1. Operations might use keys that don't exist
2. No guarantee operations form valid sequences
3. Manual state tracking is error-prone
4. Hard to express preconditions
5. Shrinking doesn't understand operation semantics

### The Solution

Hypothesis-style rule-based state machines:

```swift
@RuleBasedTest
struct DatabaseSpec {
    // Model state
    var model: [String: Data] = [:]
    
    // System under test
    let database = Database()
    
    // Bundles accumulate values across rules
    @Bundle var knownKeys: [String]
    @Bundle var knownValues: [Data]
    
    // Rules that generate data
    @Rule(into: \.knownKeys)
    func generateKey(@Gen(.alphanumeric(1...50)) key: String) -> String {
        key
    }
    
    @Rule(into: \.knownValues)
    func generateValue(@Gen(.data(0...1000)) value: Data) -> Data {
        value
    }
    
    // Rule with precondition
    @Rule
    @Precondition { !$0.knownKeys.isEmpty && !$0.knownValues.isEmpty }
    mutating func write(key: KeyRef, value: ValueRef) {
        database.write(key: key.value, value: value.value)
        model[key.value] = value.value
    }
    
    @Rule
    @Precondition { !$0.knownKeys.isEmpty }
    func read(key: KeyRef) {
        let result = database.read(key: key.value)
        #expect(result == model[key.value])
    }
    
    // Invariant checked after every rule
    @Invariant
    func modelMatchesDatabase() -> Bool {
        model.allSatisfy { key, value in
            database.read(key: key) == value
        }
    }
}
```

## Detailed Design

### Core Macros

```swift
/// Marks a struct as a rule-based state machine test
@attached(member, names: named(run), named(TestCase))
@attached(extension, conformances: RuleBasedStateMachine)
public macro RuleBasedTest(
    maxSteps: Int = 100,
    maxExamples: Int = 100,
    stateful: Bool = true
) = #externalMacro(module: "InvariantSwiftMacros", type: "RuleBasedTestMacro")

/// Marks a property as a bundle that accumulates values
@attached(accessor)
public macro Bundle() = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "BundleMacro"
)

/// Marks a method as a rule that can be executed
@attached(peer)
public macro Rule(
    into bundle: KeyPath<Self, some Collection>? = nil,
    weight: Int = 1
) = #externalMacro(module: "InvariantSwiftMacros", type: "RuleMacro")

/// Adds a precondition that must be true for the rule to be considered
@attached(peer)
public macro Precondition(
    _ check: @escaping (Self) -> Bool
) = #externalMacro(module: "InvariantSwiftMacros", type: "PreconditionMacro")

/// Marks a method as an invariant checked after every rule
@attached(peer)
public macro Invariant() = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "InvariantMacro"
)
```

### Bundle References

When a rule parameter type is `KeyRef`, `ValueRef`, etc., it draws from the corresponding bundle:

```swift
/// Reference to a value in a bundle
public struct BundleRef<T> {
    public let value: T
    internal let bundlePath: AnyKeyPath
    internal let index: Int
}

/// Type alias for common patterns
public typealias KeyRef = BundleRef<String>
public typealias ValueRef = BundleRef<Data>
```

### Generated Code

**Input:**
```swift
@RuleBasedTest
struct CounterSpec {
    var expected = 0
    let counter = Counter()
    
    @Rule
    mutating func increment() {
        counter.increment()
        expected += 1
    }
    
    @Rule
    @Precondition { $0.expected > 0 }
    mutating func decrement() {
        counter.decrement()
        expected -= 1
    }
    
    @Invariant
    func valueMatches() -> Bool {
        counter.value == expected
    }
}
```

**Expands to:**
```swift
struct CounterSpec: RuleBasedStateMachine {
    var expected = 0
    let counter = Counter()
    
    // Original methods...
    
    // Generated rule metadata
    static let rules: [Rule<CounterSpec>] = [
        Rule(
            name: "increment",
            weight: 1,
            precondition: { _ in true },
            execute: { state, _ in
                state.increment()
            },
            generator: Gen.pure(())
        ),
        Rule(
            name: "decrement",
            weight: 1,
            precondition: { $0.expected > 0 },
            execute: { state, _ in
                state.decrement()
            },
            generator: Gen.pure(())
        )
    ]
    
    static let invariants: [(String, (CounterSpec) -> Bool)] = [
        ("valueMatches", { $0.valueMatches() })
    ]
    
    // Generated test case
    static func run(maxSteps: Int = 100, maxExamples: Int = 100) {
        for _ in 0..<maxExamples {
            var state = CounterSpec()
            var steps: [ExecutedStep] = []
            
            for _ in 0..<maxSteps {
                let validRules = rules.filter { $0.precondition(state) }
                guard !validRules.isEmpty else { break }
                
                let rule = Gen.element(of: validRules).sample()!
                let args = rule.generator.sample()!
                
                steps.append(ExecutedStep(rule: rule.name, args: args))
                rule.execute(&state, args)
                
                // Check invariants
                for (name, check) in invariants {
                    if !check(state) {
                        // Shrink and report
                        let minimal = shrinkSteps(steps, reproduce: { ... })
                        reportFailure(invariant: name, steps: minimal)
                        return
                    }
                }
            }
        }
    }
}

// Integration with Swift Testing
@Test
func testCounterSpec() {
    CounterSpec.run()
}
```

### Advanced Features

#### Weighted Rules

Control how often rules are selected:

```swift
@Rule(weight: 3)  // 3x more likely than default
mutating func commonOperation() { }

@Rule(weight: 1)  // Default weight
mutating func rareOperation() { }
```

#### Target Bundles

Rules can produce values that go into bundles:

```swift
@Bundle var users: [User]

@Rule(into: \.users)
func createUser(@Gen(.name) name: String) -> User {
    let user = User(name: name)
    database.insert(user)
    return user
}

@Rule
@Precondition { !$0.users.isEmpty }
func deleteUser(user: BundleRef<User>) {
    database.delete(user.value.id)
    // Note: user stays in bundle (referential integrity testing)
}
```

#### Multiple Bundles

Complex relationships between entities:

```swift
@RuleBasedTest
struct SocialNetworkSpec {
    @Bundle var users: [User]
    @Bundle var posts: [Post]
    @Bundle var friendships: [(User, User)]
    
    @Rule(into: \.users)
    func createUser(@Gen(.name) name: String) -> User { ... }
    
    @Rule(into: \.posts)
    @Precondition { !$0.users.isEmpty }
    func createPost(author: BundleRef<User>, @Gen(.text) content: String) -> Post { ... }
    
    @Rule(into: \.friendships)
    @Precondition { $0.users.count >= 2 }
    func addFriend(user1: BundleRef<User>, user2: BundleRef<User>) -> (User, User) {
        guard user1.value.id != user2.value.id else { return }
        // ...
    }
}
```

#### Setup and Teardown

```swift
@RuleBasedTest
struct DatabaseSpec {
    let db: Database
    
    init() {
        db = Database.createTemporary()
    }
    
    @Teardown
    func cleanup() {
        db.destroy()
    }
}
```

#### Async Rules

```swift
@RuleBasedTest
struct AsyncCacheSpec {
    let cache = AsyncCache()
    
    @Rule
    func set(key: KeyRef, value: ValueRef) async {
        await cache.set(key.value, value.value)
    }
    
    @Rule
    @Precondition { !$0.knownKeys.isEmpty }
    func get(key: KeyRef) async {
        _ = await cache.get(key.value)
    }
    
    @Invariant
    func isConsistent() async -> Bool {
        await cache.validateIntegrity()
    }
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Database/Storage Testing**
   ```swift
   @RuleBasedTest
   struct KeyValueStoreSpec {
       var model: [String: Data] = [:]
       let store = KeyValueStore()
       
       @Rule mutating func put(key: KeyRef, value: ValueRef) { ... }
       @Rule func get(key: KeyRef) { ... }
       @Rule mutating func delete(key: KeyRef) { ... }
       
       @Invariant func modelMatches() -> Bool { ... }
   }
   ```

2. **UI State Machines**
   ```swift
   @RuleBasedTest
   struct NavigationSpec {
       var expectedStack: [Screen] = [.home]
       let navigator = Navigator()
       
       @Rule mutating func push(screen: ScreenRef) { ... }
       @Rule @Precondition { $0.expectedStack.count > 1 } mutating func pop() { ... }
       @Rule mutating func reset() { ... }
       
       @Invariant func stackMatches() -> Bool { ... }
   }
   ```

3. **Protocol Compliance**
   ```swift
   @RuleBasedTest
   struct CollectionSpec<C: RangeReplaceableCollection> where C.Element: Equatable {
       var model: [C.Element] = []
       var sut: C = C()
       
       @Rule mutating func append(element: ElementRef) { ... }
       @Rule @Precondition { !$0.model.isEmpty } mutating func removeLast() { ... }
       @Rule @Precondition { !$0.model.isEmpty } mutating func removeFirst() { ... }
       
       @Invariant func elementsMatch() -> Bool { ... }
   }
   ```

4. **Distributed System Mocks**
   ```swift
   @RuleBasedTest
   struct DistributedCacheSpec {
       @Bundle var nodes: [CacheNode]
       @Bundle var keys: [String]
       
       @Rule(into: \.nodes) func addNode() -> CacheNode { ... }
       @Rule @Precondition { $0.nodes.count > 1 } func removeNode(node: NodeRef) { ... }
       @Rule func write(key: KeyRef, value: ValueRef, node: NodeRef) { ... }
       @Rule func read(key: KeyRef, node: NodeRef) { ... }
       
       @Invariant func eventualConsistency() -> Bool { ... }
   }
   ```

5. **Game Logic**
   ```swift
   @RuleBasedTest
   struct ChessSpec {
       var board = ChessBoard()
       
       @Bundle var whitePieces: [Piece]
       @Bundle var blackPieces: [Piece]
       
       @Rule func moveWhite(piece: WhitePieceRef, to: SquareRef) { ... }
       @Rule func moveBlack(piece: BlackPieceRef, to: SquareRef) { ... }
       
       @Invariant func validBoard() -> Bool { board.isLegal }
       @Invariant func alternatingTurns() -> Bool { ... }
   }
   ```

### ❌ When NOT to Use

1. **Pure functions** — Use `@PropertyTest` instead
2. **Simple state** — A few operations don't need full machinery
3. **Non-deterministic systems** — External dependencies make invariants unreliable
4. **Performance-critical tests** — Rule selection adds overhead

## Importance

### Why This Matters

1. **Industry Standard**
   - Hypothesis stateful testing is widely used in production
   - ScalaCheck state machine testing found critical bugs
   - Erlang QuickCheck's stateful testing is legendary

2. **Finds Deep Bugs**
   - Bugs that only appear after specific operation sequences
   - Race conditions in stateful systems
   - Edge cases in state transitions
   - Off-by-one errors in counters/indices

3. **Self-Documenting**
   - Rules describe valid operations
   - Preconditions document constraints
   - Invariants document expected properties
   - Better than prose documentation

4. **Shrinking Power**
   - Shrinks operation sequences, not just data
   - Finds minimal failing sequence
   - "Do A, then B, then C" instead of 50-step sequence

### Real-World Bugs Found

| System | Bug Type | How Found |
|--------|----------|-----------|
| Redis | Data loss on failover | Stateful testing with node failures |
| LevelDB | Corruption after crash | Write/crash/read sequences |
| SQLite | Index inconsistency | Concurrent write patterns |
| React | UI state desync | Rapid state updates |

## Implementation Notes

### Phase 1: Core Framework
- `@RuleBasedTest` macro
- `@Rule` and `@Precondition`
- Basic `@Invariant`
- Synchronous execution

### Phase 2: Bundles
- `@Bundle` macro
- Bundle references in rules
- Cross-bundle relationships

### Phase 3: Advanced
- Async rules
- Weighted selection
- Parallel rule exploration
- Custom shrinking strategies

### Shrinking Strategy

When an invariant fails:
1. Record the sequence of (rule, arguments) pairs
2. Try removing rules from the sequence
3. Try shrinking arguments within rules
4. Try reordering independent rules
5. Report minimal failing sequence

## Alternatives Considered

### 1. Imperative State Machine
```swift
class DatabaseStateMachine: StateMachine {
    func nextState() -> State { ... }
    func execute(_ command: Command) { ... }
}
```
- **Rejected**: Too much boilerplate, not declarative

### 2. Protocol-Based
```swift
protocol StatefulTest {
    associatedtype State
    associatedtype Command
    static var commands: [Command] { get }
}
```
- **Rejected**: Doesn't express preconditions well

### 3. Enum-Based Commands
```swift
enum Command {
    case write(key: String, value: Data)
    case read(key: String)
}
```
- **Rejected**: Can't express that `read` needs existing keys

## References

- [Hypothesis Stateful Testing](https://hypothesis.readthedocs.io/en/latest/stateful.html)
- [ScalaCheck Stateful Testing](https://github.com/typelevel/scalacheck/blob/main/doc/UserGuide.md#stateful-testing)
- [QuickCheck State Machines](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quickcheck.pdf)
- [Jepsen Testing](https://jepsen.io/) — Inspiration for distributed system testing
- [How Not to Die Hard with Hypothesis](https://hypothesis.works/articles/how-not-to-die-hard-with-hypothesis/)
