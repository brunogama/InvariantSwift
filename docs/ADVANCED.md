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
9. [Linearizability Testing](#linearizability-testing)
10. [Contract Testing](#contract-testing)
11. [Regression Banking](#regression-banking)
12. [Lens and Prism Optics](#lens-and-prism-optics)

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

---

## Linearizability Testing

Test that concurrent operations on shared data structures are linearizable—i.e., they behave as if executed atomically in some sequential order.

### Wing-Gong Algorithm

InvariantSwift implements the Wing-Gong algorithm for efficient linearizability checking:

```swift
import InvariantSwift

// Define a sequential specification
let stackSpec = Spec<StackOp, StackResult> { op, state in
    switch op {
    case .push(let value):
        state.append(value)
        return .ok
    case .pop:
        if let last = state.popLast() {
            return .value(last)
        }
        return .empty
    }
}

// Check linearizability of concurrent execution
let checker = LinearizabilityChecker(spec: stackSpec)

let result = await checker.check(operations: [
    Operation(thread: 1, op: .push(42), start: 0, end: 10),
    Operation(thread: 2, op: .pop, start: 5, end: 15),
    Operation(thread: 2, result: .value(42))
])

switch result {
case .linearizable(let witness):
    print("Linearizable! Order: \(witness.linearization)")
case .notLinearizable(let witness):
    print("Not linearizable: \(witness.explanation)")
}
```

### Concurrent Data Structure Testing

```swift
@Test("ConcurrentQueue is linearizable")
func testQueueLinearizability() async throws {
    let queue = ConcurrentQueue<Int>()
    let scheduler = DeterministicScheduler(seed: 42)
    
    let operations = try await scheduler.runConcurrent(threads: 4) { threadId in
        if threadId % 2 == 0 {
            queue.enqueue(threadId)
            return Operation(op: .enqueue(threadId))
        } else {
            let value = queue.dequeue()
            return Operation(op: .dequeue, result: value)
        }
    }
    
    let result = await LinearizabilityChecker(spec: queueSpec).check(operations)
    #expect(result.isLinearizable)
}
```

### Happens-Before Analysis

```swift
// Build happens-before graph
let hbGraph = HappensBefore()

hbGraph.addEdge(from: op1, to: op2)  // op1 happens-before op2
hbGraph.addEdge(from: op2, to: op3)

// Check ordering
if hbGraph.happensBefore(op1, op3) {
    print("op1 → op3 (transitive)")
}

// Find concurrent operations
let concurrent = hbGraph.findConcurrent(op2)
```

---

## Contract Testing

Define behavioral contracts for types and verify implementations conform to them.

### Defining Contracts

```swift
import InvariantSwift

// Define a contract for Equatable types
let equatableContract = ContractTestRunner<Int> { value in
    // Reflexivity: a == a
    Contract.require("reflexivity") { value == value }
    
    // Symmetry: if a == b then b == a (tested via generator)
    // Transitivity: if a == b and b == c then a == c
}

// Run the contract
let result = try await equatableContract.test(
    generator: Gen<Int>.int,
    iterations: 1000
)

switch result {
case .passed:
    print("Contract satisfied")
case .violated(let violation):
    print("Violated: \(violation.contractName)")
    print("Counterexample: \(violation.input)")
}
```

### Protocol Contracts

```swift
// Contract for Comparable
protocol ComparableContract {
    static func verifyContract<T: Comparable>(
        _ gen: Gen<T>
    ) async throws -> ContractTestResult
}

extension ComparableContract {
    static func verifyContract<T: Comparable>(
        _ gen: Gen<T>
    ) async throws -> ContractTestResult {
        let runner = ContractTestRunner<(T, T, T)>()
        
        return try await runner.test(
            generator: Gen.zip(gen, gen, gen)
        ) { (a, b, c) in
            // Irreflexivity: !(a < a)
            Contract.require("irreflexivity") { !(a < a) }
            
            // Asymmetry: if a < b then !(b < a)
            Contract.require("asymmetry") {
                !(a < b) || !(b < a)
            }
            
            // Transitivity: if a < b and b < c then a < c
            Contract.require("transitivity") {
                !(a < b && b < c) || a < c
            }
        }
    }
}
```

### Custom Type Contracts

```swift
@ContractProtocol
struct Money: Equatable, Comparable {
    let amount: Decimal
    let currency: String
    
    // Invariant: amount >= 0
    static var invariants: [Invariant<Money>] {
        [
            Invariant("non-negative") { $0.amount >= 0 }
        ]
    }
}

@Test("Money satisfies contracts")
func testMoneyContracts() async throws {
    let moneyGen = Gen.zip(
        Gen<Decimal>.decimal(in: 0...1000),
        Gen.element(of: ["USD", "EUR", "GBP"])
    ).map { Money(amount: $0, currency: $1) }
    
    try await Money.verifyContracts(generator: moneyGen)
}
```

### Precondition and Postcondition Checking

```swift
extension Array {
    /// Sorts the array in place.
    /// - Precondition: Elements must be Comparable
    /// - Postcondition: Array is sorted in ascending order
    /// - Postcondition: Array contains same elements (permutation)
    @Contract(
        precondition: { _ in true },
        postcondition: { old, new in
            new.isSorted && Set(new) == Set(old)
        }
    )
    mutating func checkedSort() where Element: Comparable {
        sort()
    }
}
```

---

## Regression Banking

Persist and replay failing test cases for regression testing.

### Banking Failures

```swift
let bank = RegressionBank(path: ".invariant/regressions.db")

// Run property with automatic failure banking
let property = Property(generator: Gen<String>.string) { input in
    parseAndValidate(input)
}

let result = await PropertyRunner().runProperty(
    property,
    config: PropertyConfig(regressionBank: bank)
)

// Failed cases are automatically stored
if case .failure(let counterexample, _, let shrunk, _, let seed) = result {
    // This failure is now banked for future runs
    print("Banked failure: \(shrunk)")
}
```

### Replaying Banked Failures

```swift
// On subsequent test runs, replay banked failures first
let failures = try await bank.allFailures()

for failure in failures {
    let reproduced = property.predicate(failure.input)
    
    if reproduced {
        print("Regression still fails: \(failure.id)")
    } else {
        // Bug was fixed, remove from bank
        try await bank.removeFailure(failure.id)
        print("Regression fixed: \(failure.id)")
    }
}
```

### Bank Statistics

```swift
let stats = try await bank.getStatistics()
print("Total banked failures: \(stats.totalCount)")
print("By property:")
for (name, count) in stats.byProperty {
    print("  \(name): \(count)")
}
```

### CI Integration

```swift
@Test("Replay regressions before random testing")
func testWithRegressions() async throws {
    let bank = try await RegressionBank(path: ".invariant/regressions.db")
    
    // First: replay all banked failures
    let regressions = try await bank.failuresForProperty("myProperty")
    for regression in regressions {
        let passed = myProperty.predicate(regression.input)
        #expect(passed, "Regression \(regression.id) still fails")
    }
    
    // Then: run random testing
    try await checkProperty(myProperty)
}
```

---

## Lens and Prism Optics

Functional optics for immutable data access and manipulation in tests.

### Lens Basics

A Lens focuses on a single value within a structure:

```swift
import InvariantSwift

struct Address {
    var street: String
    var city: String
    var zip: String
}

struct Person {
    var name: String
    var age: Int
    var address: Address
}

// Define lenses
let addressLens = Lens<Person, Address>(
    get: { $0.address },
    set: { address, person in
        var copy = person
        copy.address = address
        return copy
    }
)

let cityLens = Lens<Address, String>(
    get: { $0.city },
    set: { city, address in
        var copy = address
        copy.city = city
        return copy
    }
)

// Compose lenses
let personCityLens = addressLens.compose(cityLens)

// Use in tests
let person = Person(name: "Alice", age: 30, 
                    address: Address(street: "123 Main", city: "Boston", zip: "02101"))

let city = personCityLens.view(person)  // "Boston"
let updated = personCityLens.set("Cambridge", person)  // New person with city = "Cambridge"
```

### Prism Basics

A Prism focuses on one case of a sum type (enum):

```swift
enum Result<T, E> {
    case success(T)
    case failure(E)
}

let successPrism = Prism<Result<Int, String>, Int>(
    extract: { result in
        if case .success(let value) = result { return value }
        return nil
    },
    embed: { .success($0) }
)

// Use in tests
let result: Result<Int, String> = .success(42)
let value = successPrism.extract(result)  // Optional(42)
let embedded = successPrism.embed(100)    // .success(100)
```

### Testing with Optics

```swift
@PropertyTest
func testLensLaws(person: Person, newCity: String) {
    let lens = personCityLens
    
    // Law 1: Get-Put - setting what you get changes nothing
    let current = lens.view(person)
    let afterGetPut = lens.set(current, person)
    #expect(afterGetPut == person)
    
    // Law 2: Put-Get - getting what you set returns what you set
    let afterSet = lens.set(newCity, person)
    let retrieved = lens.view(afterSet)
    #expect(retrieved == newCity)
    
    // Law 3: Put-Put - setting twice is same as setting once
    let afterFirst = lens.set("First", person)
    let afterSecond = lens.set(newCity, afterFirst)
    let direct = lens.set(newCity, person)
    #expect(afterSecond == direct)
}
```

### Traversal

Focus on multiple values within a structure:

```swift
let arrayElementsTraversal = Traversal<[Int], Int>(
    getAll: { $0 },
    modify: { transform, array in array.map(transform) }
)

// Double all elements
let doubled = arrayElementsTraversal.over({ $0 * 2 }, [1, 2, 3])  // [2, 4, 6]

// Get all elements
let all = arrayElementsTraversal.getAll([1, 2, 3])  // [1, 2, 3]
```

### Using Optics for State Diffs

```swift
@Test("Config changes tracked with lens")
func testConfigChange() {
    var config = AppConfig.default
    
    expectDifference(config) {
        config = timeoutLens.set(60, config)
    } changes: {
        $0.timeout = 60
    }
}
```

---

## See Also

- [COOKBOOK.md](COOKBOOK.md) - Practical recipes
- [API_REFERENCE.md](API_REFERENCE.md) - Complete API documentation
- [FUZZING.md](FUZZING.md) - LibFuzzer integration guide
