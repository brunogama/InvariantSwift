# ISP-0006: Contract Testing

- **Status:** Implemented
- **Priority:** P2 (Medium)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce `@Contract` macro for declaratively specifying pre-conditions, post-conditions, and invariants on protocol methods, with automatic property test generation for any conforming type.

## Motivation

### The Problem

Protocol definitions in Swift specify *syntax* but not *semantics*:

```swift
protocol Stack {
    associatedtype Element
    mutating func push(_ element: Element)
    mutating func pop() -> Element?
    func peek() -> Element?
    var isEmpty: Bool { get }
    var count: Int { get }
}
```

This tells us the method signatures but nothing about:
- What `pop()` returns relative to `push()`
- How `count` changes after operations
- What `peek()` returns vs `pop()`
- The relationship between `isEmpty` and `count`

Developers must read documentation (if it exists) or guess the semantics.

### The Solution

Encode behavioral contracts directly in the protocol:

```swift
@Contract
protocol Stack {
    associatedtype Element: Equatable
    
    @Precondition { !$0.isEmpty }
    @Postcondition { $0.count == old($0.count) - 1 }
    @Postcondition { result == old($0.peek()) }
    mutating func pop() -> Element?
    
    @Postcondition { $0.peek() == element }
    @Postcondition { $0.count == old($0.count) + 1 }
    @Postcondition { !$0.isEmpty }
    mutating func push(_ element: Element)
    
    @Invariant { $0.isEmpty == ($0.count == 0) }
}

// Automatic test generation for any conforming type
@TestContract(Stack.self)
struct ArrayStackTests {
    typealias SUT = ArrayStack<Int>
}
```

## Detailed Design

### Core Macros

```swift
/// Marks a protocol as having behavioral contracts
@attached(extension, conformances: ContractProtocol)
@attached(member, names: arbitrary)
public macro Contract() = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "ContractMacro"
)

/// Specifies a precondition that must hold before method execution
@attached(peer)
public macro Precondition(
    _ check: @escaping (Self) -> Bool
) = #externalMacro(module: "InvariantSwiftMacros", type: "PreconditionMacro")

/// Specifies a postcondition that must hold after method execution
@attached(peer)
public macro Postcondition(
    _ check: @escaping (Self, /* result */ Any?) -> Bool
) = #externalMacro(module: "InvariantSwiftMacros", type: "PostconditionMacro")

/// Specifies an invariant that must always hold
@attached(peer)
public macro Invariant(
    _ check: @escaping (Self) -> Bool
) = #externalMacro(module: "InvariantSwiftMacros", type: "InvariantMacro")

/// Generates property tests for a contract
@attached(member, names: named(tests))
public macro TestContract<P: ContractProtocol>(
    _ protocol: P.Type,
    operations: Int = 100,
    examples: Int = 100
) = #externalMacro(module: "InvariantSwiftMacros", type: "TestContractMacro")
```

### The `old()` Function

Capture pre-execution state for postconditions:

```swift
/// Captures a value before method execution for use in postconditions
public func old<T>(_ value: @autoclosure () -> T) -> T

// Usage in postcondition
@Postcondition { $0.count == old($0.count) + 1 }
mutating func push(_ element: Element)
```

Implementation uses copy-on-write snapshots:
```swift
// Generated wrapper captures old state
func push_withContract(_ element: Element) {
    let oldCount = self.count  // Captured before
    push(element)              // Original call
    assert(self.count == oldCount + 1)  // Postcondition
}
```

### Contract Specification Example

```swift
@Contract
protocol Queue {
    associatedtype Element: Equatable
    
    // Invariants (always true)
    @Invariant { $0.count >= 0 }
    @Invariant { $0.isEmpty == ($0.count == 0) }
    
    var count: Int { get }
    var isEmpty: Bool { get }
    
    // Enqueue: adds to back
    @Postcondition { $0.count == old($0.count) + 1 }
    @Postcondition { !$0.isEmpty }
    mutating func enqueue(_ element: Element)
    
    // Dequeue: removes from front (FIFO)
    @Precondition { !$0.isEmpty }
    @Postcondition { $0.count == old($0.count) - 1 }
    mutating func dequeue() -> Element
    
    // Peek: view front without removing
    @Precondition { !$0.isEmpty }
    @Postcondition { $0.count == old($0.count) }  // Unchanged
    func peek() -> Element
    
    // FIFO property: dequeue returns oldest enqueued
    @Postcondition { 
        old($0.peek()) == result  // Dequeue returns what peek showed
    }
    mutating func dequeue() -> Element
}
```

### Generated Test Suite

```swift
@TestContract(Queue.self)
struct LinkedListQueueTests {
    typealias SUT = LinkedListQueue<Int>
}

// Generates:
extension LinkedListQueueTests {
    
    @Test
    func testInvariant_countNonNegative() {
        forAll { (operations: [QueueOperation<Int>]) in
            var queue = SUT()
            for op in operations {
                op.apply(to: &queue)
                #expect(queue.count >= 0, "Invariant violated: count >= 0")
            }
        }
    }
    
    @Test
    func testInvariant_isEmptyCountRelation() {
        forAll { (operations: [QueueOperation<Int>]) in
            var queue = SUT()
            for op in operations {
                op.apply(to: &queue)
                #expect(queue.isEmpty == (queue.count == 0))
            }
        }
    }
    
    @Test
    func testEnqueue_postconditions() {
        forAll { (initial: [Int], element: Int) in
            var queue = SUT(initial)
            let oldCount = queue.count
            
            queue.enqueue(element)
            
            #expect(queue.count == oldCount + 1)
            #expect(!queue.isEmpty)
        }
    }
    
    @Test
    func testDequeue_preconditions() {
        forAll { (initial: [Int]) in
            var queue = SUT(initial)
            assume(!queue.isEmpty)  // Precondition
            
            let oldPeek = queue.peek()
            let oldCount = queue.count
            
            let result = queue.dequeue()
            
            #expect(queue.count == oldCount - 1)
            #expect(result == oldPeek)  // FIFO
        }
    }
    
    @Test
    func testPeek_doesNotModify() {
        forAll { (initial: [Int]) in
            var queue = SUT(initial)
            assume(!queue.isEmpty)
            
            let oldCount = queue.count
            _ = queue.peek()
            
            #expect(queue.count == oldCount)
        }
    }
}
```

### Multi-Operation Contracts

Express relationships across operations:

```swift
@Contract
protocol Dictionary {
    associatedtype Key: Hashable
    associatedtype Value: Equatable
    
    // Insert then lookup returns the value
    @CrossOperationContract
    func insertThenLookup(key: Key, value: Value) {
        self[key] = value
        #expect(self[key] == value)
    }
    
    // Delete then lookup returns nil
    @CrossOperationContract
    func deleteThenLookup(key: Key) {
        self[key] = nil
        #expect(self[key] == nil)
    }
    
    // Overwrite replaces
    @CrossOperationContract
    func overwrite(key: Key, v1: Value, v2: Value) {
        self[key] = v1
        self[key] = v2
        #expect(self[key] == v2)
    }
}
```

### Algebraic Laws

Express mathematical properties:

```swift
@Contract
protocol Monoid {
    static var identity: Self { get }
    func combine(with other: Self) -> Self
    
    // Left identity: identity.combine(x) == x
    @Law
    static func leftIdentity(x: Self) -> Bool where Self: Equatable {
        identity.combine(with: x) == x
    }
    
    // Right identity: x.combine(identity) == x
    @Law
    static func rightIdentity(x: Self) -> Bool where Self: Equatable {
        x.combine(with: identity) == x
    }
    
    // Associativity: (x.combine(y)).combine(z) == x.combine(y.combine(z))
    @Law
    static func associativity(x: Self, y: Self, z: Self) -> Bool 
        where Self: Equatable 
    {
        x.combine(with: y).combine(with: z) == 
            x.combine(with: y.combine(with: z))
    }
}

@TestContract(Monoid.self)
struct StringMonoidTests {
    typealias SUT = String
}
// Tests identity = "", combine = +
```

### Runtime Contract Checking

Optional runtime validation (debug builds):

```swift
// Enable runtime checks
ContractConfig.runtimeChecks = true

// Now contracts are checked at runtime
var stack = ArrayStack<Int>()
stack.pop()  // 💥 Precondition failed: !isEmpty
```

Generated wrapper:
```swift
extension ArrayStack: Stack {
    mutating func pop() -> Element? {
        #if DEBUG
        if ContractConfig.runtimeChecks {
            precondition(!isEmpty, "Stack.pop precondition: !isEmpty")
        }
        #endif
        
        let oldCount = count
        let oldPeek = peek()
        
        let result = _pop()  // Original implementation
        
        #if DEBUG
        if ContractConfig.runtimeChecks {
            assert(count == oldCount - 1, "Stack.pop postcondition: count == old(count) - 1")
            assert(result == oldPeek, "Stack.pop postcondition: result == old(peek())")
        }
        #endif
        
        return result
    }
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Standard Library Protocols**
   ```swift
   @Contract
   protocol Collection {
       @Invariant { $0.startIndex <= $0.endIndex }
       @Postcondition { $0.index(after: i) > i }
       // ...
   }
   ```

2. **Domain Protocols**
   ```swift
   @Contract
   protocol BankAccount {
       @Precondition { amount > 0 }
       @Precondition { $0.balance >= amount }
       @Postcondition { $0.balance == old($0.balance) - amount }
       mutating func withdraw(_ amount: Decimal)
   }
   ```

3. **Data Structure Contracts**
   ```swift
   @Contract
   protocol PriorityQueue {
       @Postcondition { result == $0.min(by: <) }
       mutating func extractMin() -> Element
   }
   ```

4. **API Contracts**
   ```swift
   @Contract
   protocol Repository {
       @Postcondition { $0.find(id: entity.id) != nil }
       func save(_ entity: Entity)
       
       @Postcondition { $0.find(id: id) == nil }
       func delete(id: ID)
   }
   ```

5. **Mathematical Structures**
   ```swift
   @Contract
   protocol Group: Monoid {
       func inverse() -> Self
       
       @Law
       static func inverseProperty(x: Self) -> Bool where Self: Equatable {
           x.combine(with: x.inverse()) == identity
       }
   }
   ```

### ❌ When NOT to Use

1. **Implementation-specific behavior** — Contracts are for interface semantics
2. **Performance-critical paths** — Runtime checks add overhead
3. **Non-deterministic operations** — Can't specify contracts for random behavior
4. **External system interactions** — Network, DB outcomes vary

## Importance

### Why This Matters

1. **Executable Specifications**
   - Contracts ARE the specification
   - No drift between docs and implementation
   - Tests generated directly from spec

2. **Design by Contract**
   - Bertrand Meyer's proven methodology
   - Clear responsibility boundaries
   - Self-documenting interfaces

3. **Conformance Validation**
   - Verify any implementation satisfies the protocol
   - Catch semantic bugs, not just type errors
   - Multiple implementations? Same tests!

4. **Documentation That Runs**
   - Contracts explain expected behavior
   - Examples embedded in tests
   - Always up-to-date

### Academic Foundations

| Concept | Origin | Application |
|---------|--------|-------------|
| Pre/Post Conditions | Hoare Logic (1969) | Method contracts |
| Invariants | Liskov & Wing (1994) | Type invariants |
| Algebraic Laws | Category Theory | Mathematical properties |
| Design by Contract | Meyer (1986) | Eiffel language |

### Real-World Impact

- **Eiffel**: Built-in contract support, proven in aerospace
- **Spec#**: Microsoft's contract system for .NET
- **Ada/SPARK**: Contracts for safety-critical systems
- **Kotlin**: `require`/`ensure` inspired by contracts
- **Swift itself**: Has `precondition`/`assert`, but not systematic

## Implementation Notes

### Phase 1: Basic Contracts
- `@Precondition` and `@Postcondition` macros
- `old()` state capture
- Simple `@Invariant`

### Phase 2: Test Generation
- `@TestContract` macro
- Automatic operation generation
- Shrinking of operation sequences

### Phase 3: Advanced Features
- `@Law` for algebraic properties
- `@CrossOperationContract`
- Runtime checking mode
- IDE integration

### Challenges

1. **State Capture**: `old()` needs copy semantics
2. **Method Interception**: Requires wrapper generation
3. **Generic Protocols**: Associated types complicate generation
4. **Performance**: Runtime checks must be fast or optional

## Alternatives Considered

### 1. Attribute Macros on Methods
```swift
protocol Stack {
    @PrePost(pre: { !$0.isEmpty }, post: { $0.count == old - 1 })
    mutating func pop() -> Element?
}
```
- **Rejected**: Too cramped, hard to read multiple conditions

### 2. Separate Contract Files
```swift
// Stack.contract.swift
contract Stack {
    pop.precondition { !isEmpty }
    pop.postcondition { count == old.count - 1 }
}
```
- **Rejected**: Disconnected from protocol, easy to desync

### 3. Comment-Based (Like Javadoc)
```swift
/// @pre !isEmpty
/// @post count == old(count) - 1
mutating func pop() -> Element?
```
- **Rejected**: Not executable, easy to ignore

## References

- [Design by Contract - Bertrand Meyer](https://www.eiffel.com/values/design-by-contract/introduction/)
- [Hoare Logic](https://en.wikipedia.org/wiki/Hoare_logic)
- [Spec# - Microsoft Research](https://www.microsoft.com/en-us/research/project/spec/)
- [QuickCheck: Testing Monadic Code](https://www.cse.chalmers.se/~rjmh/Papers/QuickCheckST.ps)
- [ScalaCheck: Property-Based Testing for Algebraic Laws](https://www.scalacheck.org/)
- [Hypothesis: Contract Testing](https://hypothesis.readthedocs.io/en/latest/contracts.html)
