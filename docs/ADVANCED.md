# Advanced Features Guide

InvariantSwift includes powerful advanced features for sophisticated testing scenarios.

## Table of Contents

1. [Coverage-Guided Testing](#coverage-guided-testing)
2. [Model-Based Testing](#model-based-testing)
3. [Stateful Testing](#stateful-testing)
4. [Async and Concurrent Testing](#async-and-concurrent-testing)
5. [Corpus Management](#corpus-management)
6. [Flake Detection](#flake-detection)
7. [SMT Solver Integration](#smt-solver-integration)
8. [DICE (Distributed Integrated Coverage Engine)](#dice)

---

## Coverage-Guided Testing

Coverage-guided testing automatically focuses test generation on inputs that explore new code paths.

### Basic Usage

```swift
let property = Property(generator: myGen) { input in
    complexFunction(input)
    return true
}

try await checkProperty(property, config: PropertyConfig(
    enableCoverage: true,
    coverageStrategy: .adaptive
))
```

### Coverage Strategies

```swift
enum CoverageStrategy {
    case random           // Standard random testing
    case frequency        // Favor inputs that hit rare branches
    case boundary         // Focus on boundary conditions
    case adaptive         // Dynamically adjust based on coverage
}
```

### Branch Tracking

```swift
// Manual branch tracking for custom coverage
let property = Property(generator: myGen) { input in
    CoverageCollector.trackBranch("validation")
    
    if input.isValid {
        CoverageCollector.trackBranch("valid-path")
        // ...
    } else {
        CoverageCollector.trackBranch("invalid-path")
        // ...
    }
    
    return true
}
```

### Coverage Reports

```swift
let runner = PropertyRunner()
let result = await runner.runProperty(property, config: config)

if let coverage = result.coverageBudget {
    print("Branches covered: \(coverage.covered.count)")
    print("Total branches: \(coverage.total.count)")
    print("Coverage: \(coverage.percentage)%")
}
```

---

## Model-Based Testing

Test implementations against reference models to ensure correctness.

### Defining a Model

```swift
// Reference model (simple, obviously correct)
class StackModel<T> {
    private var items: [T] = []
    
    func push(_ item: T) {
        items.append(item)
    }
    
    func pop() -> T? {
        items.popLast()
    }
    
    func peek() -> T? {
        items.last
    }
    
    var count: Int {
        items.count
    }
    
    var isEmpty: Bool {
        items.isEmpty
    }
}
```

### Defining Commands

```swift
enum StackCommand<T>: Equatable {
    case push(T)
    case pop
    case peek
    case count
    case isEmpty
    
    static func generator(elementGen: Gen<T>) -> Gen<StackCommand<T>> {
        Gen.frequency([
            (3, elementGen.map { .push($0) }),
            (2, Gen.pure(.pop)),
            (2, Gen.pure(.peek)),
            (1, Gen.pure(.count)),
            (1, Gen.pure(.isEmpty))
        ])
    }
}
```

### Running Model-Based Tests

```swift
@Test("Stack implementation matches model")
func testStackAgainstModel() async throws {
    let commandsGen = Gen.array(
        StackCommand<Int>.generator(elementGen: Gen<Int>.int),
        count: 1...50
    )
    
    let property = Property(generator: commandsGen) { commands in
        let model = StackModel<Int>()
        let sut = MyStack<Int>()  // System under test
        
        for command in commands {
            switch command {
            case .push(let value):
                model.push(value)
                sut.push(value)
                
            case .pop:
                let modelResult = model.pop()
                let sutResult = sut.pop()
                guard modelResult == sutResult else {
                    return false
                }
                
            case .peek:
                guard model.peek() == sut.peek() else {
                    return false
                }
                
            case .count:
                guard model.count == sut.count else {
                    return false
                }
                
            case .isEmpty:
                guard model.isEmpty == sut.isEmpty else {
                    return false
                }
            }
        }
        
        return true
    }
    
    try await checkProperty(property, config: PropertyConfig(iterations: 500))
}
```

---

## Stateful Testing

Test sequences of operations that modify state.

### Using @StateMachine Macro

```swift
@StateMachine
struct CounterStateMachine {
    var count: Int = 0
    
    mutating func increment() {
        count += 1
    }
    
    mutating func decrement() {
        count -= 1
    }
    
    mutating func reset() {
        count = 0
    }
    
    func value() -> Int {
        count
    }
}
```

### Manual Stateful Testing

```swift
enum CounterCommand {
    case increment
    case decrement
    case reset
    
    static var generator: Gen<CounterCommand> {
        Gen.element(of: [.increment, .decrement, .reset])
    }
}

@Test("Counter state machine")
func testCounterStateMachine() async throws {
    let commandsGen = Gen.array(CounterCommand.generator, count: 1...100)
    
    let property = Property(generator: commandsGen) { commands in
        var expectedCount = 0
        var counter = Counter()
        
        for command in commands {
            switch command {
            case .increment:
                expectedCount += 1
                counter.increment()
                
            case .decrement:
                expectedCount -= 1
                counter.decrement()
                
            case .reset:
                expectedCount = 0
                counter.reset()
            }
            
            guard counter.value == expectedCount else {
                return false
            }
        }
        
        return true
    }
    
    try await checkProperty(property)
}
```

### Preconditions and Postconditions

```swift
struct DatabaseStateMachine {
    var records: [String: Int] = [:]
    
    // Precondition: key must not exist
    mutating func insert(key: String, value: Int) -> Bool {
        guard records[key] == nil else { return false }
        records[key] = value
        return true
    }
    
    // Postcondition: record should exist after insert
    func invariant() -> Bool {
        // Check any invariants that should always hold
        true
    }
}
```

---

## Async and Concurrent Testing

### Async Properties

```swift
@Test("Async operation property")
func testAsyncProperty() async throws {
    let property = Property(generator: Gen<String>.string) { input in
        let result = await processAsync(input)
        return result.isValid
    }
    
    try await checkPropertyAsync(property)
}
```

### Concurrent Operations

```swift
@Test("Concurrent access safety")
func testConcurrentAccess() async throws {
    let opsGen = Gen.array(
        Gen.element(of: ["read", "write"]),
        count: 10...50
    )
    
    let property = Property(generator: opsGen) { ops in
        let cache = ThreadSafeCache()
        
        await withTaskGroup(of: Bool.self) { group in
            for op in ops {
                group.addTask {
                    switch op {
                    case "read":
                        _ = cache.get("key")
                    case "write":
                        cache.set("key", value: Int.random(in: 0...100))
                    default:
                        break
                    }
                    return true
                }
            }
            
            for await _ in group { }
        }
        
        // Check invariants after concurrent operations
        return cache.isConsistent
    }
    
    try await checkPropertyAsync(property, config: PropertyConfig(iterations: 100))
}
```

### Actor-Based Testing

```swift
actor Counter {
    private var value = 0
    
    func increment() {
        value += 1
    }
    
    func get() -> Int {
        value
    }
}

@Test("Actor counter property")
func testActorCounter() async throws {
    let incrementsGen = Gen<Int>.int(in: 1...100)
    
    let property = Property(generator: incrementsGen) { count in
        let counter = Counter()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<count {
                group.addTask {
                    await counter.increment()
                }
            }
        }
        
        let finalValue = await counter.get()
        return finalValue == count
    }
    
    try await checkPropertyAsync(property)
}
```

---

## Corpus Management

Persist interesting test cases for regression testing.

### SQLite Corpus

```swift
// Initialize corpus database
let corpus = try await SQLiteExampleDatabase(path: ".invariant/corpus.db")

// Run with corpus recording
let property = Property(generator: myGen) { input in
    // Test logic
}
.withCorpusRecording(corpus)

// Replay from corpus
let savedExamples = try await corpus.getExamples(for: "MyTest")
for example in savedExamples {
    // Replay saved test cases
}
```

### Corpus Statistics

```swift
let stats = try await corpus.getStatistics()
print("Total examples: \(stats.totalCount)")
print("Unique inputs: \(stats.uniqueCount)")
print("Failure rate: \(stats.failureRate)%")
```

### Corpus Pruning

```swift
// Remove old or redundant examples
try await corpus.prune(
    maxAge: .days(30),
    maxCount: 10000,
    keepFailures: true
)
```

---

## Flake Detection

Detect and analyze flaky tests.

### Flake Hunter

```swift
let hunter = FlakeHunter(iterations: 1000)

let result = await hunter.analyze(property) { input in
    // Property that might be flaky
    someFlakyOperation(input)
}

switch result {
case .stable:
    print("Property is stable")
    
case .flaky(let occurrences, let pattern):
    print("Flaky! Failed \(occurrences) times")
    print("Pattern: \(pattern)")
    
case .alwaysFails:
    print("Property always fails")
}
```

### Deterministic Reproduction

```swift
// When flakiness is detected, capture the exact conditions
let flakeReport = await hunter.captureFlake(property)

// Reproduce with exact seed and environment
try await checkProperty(property, config: PropertyConfig(
    seed: flakeReport.seed,
    iterations: 1
))
```

---

## SMT Solver Integration

Use satisfiability modulo theories for constraint solving.

### Basic SMT Usage

```swift
let solver = SMTSolver()

// Define constraints
solver.addConstraint("x > 0")
solver.addConstraint("x < 100")
solver.addConstraint("x % 2 == 0")

// Generate values satisfying constraints
let values = try solver.generateValues(count: 10)
// Returns: [2, 4, 6, 8, ...]
```

### Constraint-Based Generation

```swift
let constrainedGen = Gen<Int>.int.satisfying { x in
    x > 0 && x < 100 && x % 2 == 0
}

// Uses SMT solver to efficiently generate valid values
```

### Complex Constraints

```swift
struct Point { let x: Int; let y: Int }

let pointGen = SMTSolver.generate(Point.self) { solver in
    solver.addConstraint("x >= 0")
    solver.addConstraint("y >= 0")
    solver.addConstraint("x + y <= 100")
    solver.addConstraint("x != y")
}
```

---

## DICE

DICE (Distributed Integrated Coverage Engine) provides advanced coverage analysis and distributed testing.

### Deterministic Scheduling

```swift
@available(macOS 15.0, *)
@Test("Deterministic concurrency test")
func testDeterministicConcurrency() async throws {
    let traces = try await DeterministicScheduler.deterministicProperty(
        config: SchedulerConfig(seed: 42),
        iterations: 100
    ) {
        // Concurrent operations are scheduled deterministically
        async let a = operationA()
        async let b = operationB()
        return await (a, b)
    }
    
    // Analyze all possible interleavings
    for trace in traces {
        print("Execution trace: \(trace.steps)")
    }
}
```

### Coverage Budget

```swift
let budget = CoverageBudget()

// Track branch coverage
budget.track(branch: "validation")
budget.track(branch: "error-handling")

// Check coverage goals
let report = budget.report()
print("Coverage: \(report.percentage)%")
print("Uncovered: \(report.uncoveredBranches)")
```

### Adaptive Testing

```swift
let config = PropertyConfig(
    enableCoverage: true,
    coverageStrategy: .adaptive,
    coverageBudget: CoverageBudget(
        targetCoverage: 0.95,
        maxIterations: 10000
    )
)

// Testing continues until 95% coverage or 10000 iterations
try await checkProperty(property, config: config)
```

---

## Configuration Reference

### PropertyConfig Options

```swift
PropertyConfig(
    // Basic settings
    iterations: 100,
    maxSize: 100,
    maxShrinks: 1000,
    timeout: 30.0,
    seed: nil,
    
    // Coverage settings
    enableCoverage: false,
    coverageStrategy: .random,
    coverageBudget: nil,
    
    // Advanced settings
    parallelism: .automatic,
    memoryLimit: nil,
    verboseLogging: false
)
```

### Feature Availability

| Feature | iOS | macOS | tvOS | watchOS | Linux |
|---------|-----|-------|------|---------|-------|
| Basic Testing | 17+ | 14+ | 17+ | 10+ | Yes |
| Coverage-Guided | 17+ | 14+ | 17+ | 10+ | Yes |
| Model-Based | 17+ | 14+ | 17+ | 10+ | Yes |
| Async Properties | 17+ | 14+ | 17+ | 10+ | Yes |
| SQLite Corpus | 17+ | 14+ | 17+ | 10+ | Yes |
| DICE | 18+ | 15+ | 18+ | 11+ | No |
| SMT Solver | 17+ | 14+ | 17+ | 10+ | Yes |

---

## Best Practices

### 1. Start Simple, Add Complexity

```swift
// Start with basic property testing
@PropertyTest
func testBasic(input: Int) { ... }

// Add coverage when needed
// Add model-based when testing complex state
// Add DICE for concurrency issues
```

### 2. Use Appropriate Iteration Counts

```swift
// Simple properties: 100 (default)
// Complex state: 500-1000
// Concurrency: 1000+
// Critical security: 5000+
```

### 3. Leverage Corpus for Regression

```swift
// Record interesting cases
// Replay on every CI run
// Prune periodically
```

### 4. Profile Before Optimizing

```swift
// Check coverage reports
// Identify uncovered branches
// Focus generation on gaps
```
