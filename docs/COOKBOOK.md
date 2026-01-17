# InvariantSwift Cookbook

Practical recipes for common property-based testing scenarios.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Testing Data Structures](#testing-data-structures)
3. [Testing Algorithms](#testing-algorithms)
4. [Testing Serialization](#testing-serialization)
5. [Testing Business Logic](#testing-business-logic)
6. [Testing APIs](#testing-apis)
7. [Testing Concurrency](#testing-concurrency)
8. [Testing UI State](#testing-ui-state)
9. [Advanced Patterns](#advanced-patterns)

---

## Getting Started

### Recipe: Your First Property Test

Test that sorting preserves array length.

```swift
import Testing
import InvariantSwift

@Test("Sorting preserves array length")
func testSortPreservesLength() async throws {
    let property = Property(generator: Gen.array(Gen<Int>.int)) { array in
        array.sorted().count == array.count
    }
    try await checkProperty(property)
}
```

### Recipe: Using @PropertyTest Macro

Simplify with automatic generator inference.

```swift
@PropertyTest
func testSortPreservesLength(array: [Int]) {
    #expect(array.sorted().count == array.count)
}
```

### Recipe: Reproducible Tests

Fix the seed for deterministic behavior.

```swift
@PropertyTest(seed: 42)
func testDeterministic(value: Int) {
    // Always runs with same sequence of values
    #expect(value == value)
}
```

---

## Testing Data Structures

### Recipe: Stack Push/Pop Inverse

Test that push followed by pop returns the original value.

```swift
@PropertyTest
func testStackPushPop(initial: [Int], element: Int) {
    var stack = Stack(initial)
    stack.push(element)
    let popped = stack.pop()
    #expect(popped == element)
}
```

### Recipe: Dictionary Get/Set Consistency

Test that setting a key makes it retrievable.

```swift
@PropertyTest
func testDictionaryConsistency(
    dict: [String: Int],
    key: String,
    value: Int
) {
    var copy = dict
    copy[key] = value
    #expect(copy[key] == value)
}
```

### Recipe: Queue FIFO Order

Test first-in-first-out ordering.

```swift
@PropertyTest
func testQueueFIFO(elements: [Int]) {
    var queue = Queue<Int>()
    for element in elements {
        queue.enqueue(element)
    }
    
    var dequeued: [Int] = []
    while let element = queue.dequeue() {
        dequeued.append(element)
    }
    
    #expect(dequeued == elements)
}
```

### Recipe: Binary Search Tree Invariant

Test BST ordering property after insertions.

```swift
@PropertyTest
func testBSTInvariant(elements: [Int]) {
    var bst = BinarySearchTree<Int>()
    for element in elements {
        bst.insert(element)
    }
    
    #expect(bst.isValid)
}

extension BinarySearchTree {
    var isValid: Bool {
        inOrderTraversal().isSorted
    }
}
```

---

## Testing Algorithms

### Recipe: Sort Idempotence

Sorting twice equals sorting once.

```swift
@PropertyTest
func testSortIdempotent(array: [Int]) {
    let onceSorted = array.sorted()
    let twiceSorted = onceSorted.sorted()
    #expect(onceSorted == twiceSorted)
}
```

### Recipe: Sort Output is Permutation

Sorted array contains same elements.

```swift
@PropertyTest
func testSortIsPermutation(array: [Int]) {
    let sorted = array.sorted()
    #expect(sorted.sorted() == array.sorted())
    #expect(Set(sorted) == Set(array))
}
```

### Recipe: Reverse Involution

Reversing twice returns original.

```swift
@PropertyTest
func testReverseInvolution(array: [Int]) {
    #expect(Array(array.reversed().reversed()) == array)
}
```

### Recipe: Map Composition

map(f).map(g) == map(f >>> g)

```swift
@PropertyTest
func testMapComposition(array: [Int]) {
    let f: (Int) -> Int = { $0 * 2 }
    let g: (Int) -> String = { String($0) }
    
    let composed = array.map { g(f($0)) }
    let chained = array.map(f).map(g)
    
    #expect(composed == chained)
}
```

### Recipe: Filter Preserves Order

Filtering maintains relative order.

```swift
@PropertyTest
func testFilterPreservesOrder(array: [Int]) {
    let filtered = array.filter { $0 > 0 }
    
    // All elements in filtered appear in same relative order in original
    var originalIndex = 0
    for element in filtered {
        while array[originalIndex] != element {
            originalIndex += 1
        }
        originalIndex += 1
    }
    #expect(true) // If we get here, order is preserved
}
```

---

## Testing Serialization

### Recipe: JSON Round-Trip

Encode then decode returns original.

```swift
@Arbitrary
struct User: Codable, Equatable {
    let id: UUID
    let name: String
    let age: Int
}

@PropertyTest
func testUserJSONRoundTrip(user: User) throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    let data = try encoder.encode(user)
    let decoded = try decoder.decode(User.self, from: data)
    
    #expect(decoded == user)
}
```

### Recipe: Custom Encoder Consistency

Test custom encoding matches expected format.

```swift
@PropertyTest
func testCustomEncoderFormat(value: Int) throws {
    let encoded = CustomEncoder.encode(value)
    let decoded = CustomDecoder.decode(encoded)
    
    #expect(decoded == value)
    #expect(encoded.hasPrefix("INT:"))
}
```

### Recipe: Protocol Buffers Round-Trip

```swift
@PropertyTest
func testProtobufRoundTrip(message: MyProtoMessage) throws {
    let data = try message.serializedData()
    let decoded = try MyProtoMessage(serializedData: data)
    
    #expect(decoded == message)
}
```

---

## Testing Business Logic

### Recipe: Discount Never Exceeds Total

```swift
@Arbitrary
struct Order {
    let items: [OrderItem]
    let discountPercent: Int
}

@PropertyTest
func testDiscountNeverExceedsTotal(
    @Gen(.array(OrderItem.arbitrary, count: 1...10)) items: [OrderItem],
    @Gen(.int(in: 0...100)) discountPercent: Int
) {
    let order = Order(items: items, discountPercent: discountPercent)
    let total = order.calculateTotal()
    let discount = order.calculateDiscount()
    
    #expect(discount <= total)
    #expect(discount >= 0)
}
```

### Recipe: Account Balance Consistency

```swift
@PropertyTest
func testAccountBalanceConsistency(
    @Gen(.int(in: 0...10000)) initial: Int,
    @Gen(.array(.int(in: -1000...1000), count: 0...20)) transactions: [Int]
) {
    var account = Account(balance: initial)
    var expectedBalance = initial
    
    for amount in transactions {
        if amount >= 0 {
            account.deposit(amount)
            expectedBalance += amount
        } else if account.balance >= -amount {
            account.withdraw(-amount)
            expectedBalance += amount
        }
    }
    
    #expect(account.balance == expectedBalance)
    #expect(account.balance >= 0)
}
```

### Recipe: Price Calculation Bounds

```swift
@PropertyTest
func testPriceCalculation(
    @Gen(.double(in: 0.01...10000.0)) basePrice: Double,
    @Gen(.double(in: 0.0...0.5)) taxRate: Double,
    @Gen(.int(in: 1...100)) quantity: Int
) {
    let calculator = PriceCalculator(taxRate: taxRate)
    let total = calculator.calculate(basePrice: basePrice, quantity: quantity)
    
    let minExpected = basePrice * Double(quantity)
    let maxExpected = basePrice * Double(quantity) * (1 + taxRate)
    
    #expect(total >= minExpected)
    #expect(total <= maxExpected * 1.001) // Allow floating-point tolerance
}
```

---

## Testing APIs

### Recipe: REST API Idempotence

Test that GET requests are idempotent.

```swift
@PropertyTest
func testGetIdempotent(
    @Gen(.uuid) resourceId: UUID
) async throws {
    let client = APIClient()
    
    let first = try await client.get(resource: resourceId)
    let second = try await client.get(resource: resourceId)
    
    #expect(first == second)
}
```

### Recipe: API Error Handling

Test that invalid inputs return proper errors.

```swift
@PropertyTest
func testAPIErrorHandling(
    @Gen(.string(length: 0...1000)) invalidInput: String
) async {
    let client = APIClient()
    
    do {
        _ = try await client.validate(input: invalidInput)
        // If validation passes, input must meet criteria
        #expect(invalidInput.count >= 1 && invalidInput.count <= 100)
    } catch let error as ValidationError {
        // Error should describe the problem
        #expect(!error.message.isEmpty)
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}
```

### Recipe: Rate Limiting

```swift
@PropertyTest(iterations: 10) // Fewer iterations due to timing
func testRateLimiting(
    @Gen(.int(in: 1...20)) requestCount: Int
) async throws {
    let limiter = RateLimiter(maxRequests: 10, perSeconds: 1)
    var successCount = 0
    
    for _ in 0..<requestCount {
        if limiter.tryAcquire() {
            successCount += 1
        }
    }
    
    #expect(successCount <= 10)
}
```

---

## Testing Concurrency

### Recipe: Thread-Safe Counter

```swift
@PropertyTest(iterations: 50)
func testThreadSafeCounter(
    @Gen(.int(in: 1...100)) incrementCount: Int
) async {
    let counter = ThreadSafeCounter()
    
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<incrementCount {
            group.addTask {
                counter.increment()
            }
        }
    }
    
    #expect(counter.value == incrementCount)
}
```

### Recipe: Actor State Consistency

```swift
actor BankAccount {
    private(set) var balance: Int = 0
    
    func deposit(_ amount: Int) {
        balance += amount
    }
    
    func withdraw(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}

@PropertyTest(iterations: 50)
func testActorConsistency(
    @Gen(.array(.int(in: 1...100), count: 1...20)) deposits: [Int],
    @Gen(.array(.int(in: 1...50), count: 0...10)) withdrawals: [Int]
) async {
    let account = BankAccount()
    
    // Concurrent deposits
    await withTaskGroup(of: Void.self) { group in
        for amount in deposits {
            group.addTask {
                await account.deposit(amount)
            }
        }
    }
    
    let afterDeposits = await account.balance
    #expect(afterDeposits == deposits.reduce(0, +))
    
    // Sequential withdrawals (order matters)
    var withdrawn = 0
    for amount in withdrawals {
        if await account.withdraw(amount) {
            withdrawn += amount
        }
    }
    
    let finalBalance = await account.balance
    #expect(finalBalance == afterDeposits - withdrawn)
    #expect(finalBalance >= 0)
}
```

---

## Testing UI State

### Recipe: State Machine Transitions

```swift
enum ViewState: Equatable {
    case idle
    case loading
    case loaded(Data)
    case error(String)
}

@PropertyTest
func testViewStateTransitions(
    @Gen(.oneOf([
        Gen.pure(ViewState.idle),
        Gen.pure(ViewState.loading),
        Gen<Data>.data.map { ViewState.loaded($0) },
        Gen<String>.string.map { ViewState.error($0) }
    ])) initialState: ViewState
) {
    var viewModel = ViewModel(state: initialState)
    
    // Loading from any state should go to loading
    viewModel.startLoading()
    #expect(viewModel.state == .loading)
}
```

### Recipe: Form Validation

```swift
@Arbitrary
struct FormData {
    let email: String
    let password: String
    let age: Int
}

@PropertyTest
func testFormValidation(form: FormData) {
    let validator = FormValidator()
    let result = validator.validate(form)
    
    switch result {
    case .valid:
        // If valid, all fields must meet criteria
        #expect(form.email.contains("@"))
        #expect(form.password.count >= 8)
        #expect(form.age >= 18)
    case .invalid(let errors):
        // Errors should be non-empty and specific
        #expect(!errors.isEmpty)
        for error in errors {
            #expect(!error.field.isEmpty)
            #expect(!error.message.isEmpty)
        }
    }
}
```

---

## Advanced Patterns

### Recipe: Metamorphic Testing

Test without knowing exact outputs.

```swift
// For a function where we don't know the exact output,
// test relationships between inputs and outputs
@PropertyTest
func testSinMetamorphic(
    @Gen(.double(in: 0...Double.pi)) x: Double
) {
    // sin(x) == sin(pi - x)
    let result1 = sin(x)
    let result2 = sin(.pi - x)
    
    #expect(abs(result1 - result2) < 0.0001)
}
```

### Recipe: Oracle Testing

Compare against reference implementation.

```swift
@PropertyTest
func testOptimizedSort(array: [Int]) {
    let reference = array.sorted() // Known-correct implementation
    let optimized = myOptimizedSort(array) // Implementation under test
    
    #expect(optimized == reference)
}
```

### Recipe: Stateful Testing with Commands

```swift
// Define commands for a key-value store
enum KVCommand: Command {
    case set(String, Int)
    case get(String)
    case delete(String)
    
    typealias Model = [String: Int]
    typealias Result = Int?
    
    func run(model: inout Model) -> Result {
        switch self {
        case .set(let key, let value):
            model[key] = value
            return nil
        case .get(let key):
            return model[key]
        case .delete(let key):
            let old = model[key]
            model.removeValue(forKey: key)
            return old
        }
    }
    
    func postcondition(model: Model, result: Result) -> Bool {
        switch self {
        case .get(let key):
            return result == model[key]
        default:
            return true
        }
    }
}

@Test("KV Store matches model")
func testKVStore() async throws {
    let commandGen = Gen.oneOf([
        Gen.zip(Gen<String>.alphanumeric, Gen<Int>.int).map { KVCommand.set($0, $1) },
        Gen<String>.alphanumeric.map { KVCommand.get($0) },
        Gen<String>.alphanumeric.map { KVCommand.delete($0) }
    ])
    
    let property = Property(generator: Gen.array(commandGen, count: 1...50)) { commands in
        var model: [String: Int] = [:]
        var sut = KeyValueStore()
        
        for command in commands {
            let expected = command.run(model: &model)
            let actual: Int?
            
            switch command {
            case .set(let key, let value):
                sut.set(key, value: value)
                actual = nil
            case .get(let key):
                actual = sut.get(key)
            case .delete(let key):
                actual = sut.delete(key)
            }
            
            guard command.postcondition(model: model, result: actual) else {
                return false
            }
            guard expected == actual else {
                return false
            }
        }
        return true
    }
    
    try await checkProperty(property)
}
```

### Recipe: Shrinking Custom Types

```swift
struct NonEmptyArray<T> {
    let head: T
    let tail: [T]
    
    var all: [T] { [head] + tail }
}

extension NonEmptyArray where T: Sendable {
    static func arbitrary(element: Gen<T>) -> Gen<NonEmptyArray<T>> {
        Gen.zip(element, Gen.array(element))
            .map { NonEmptyArray(head: $0, tail: $1) }
            .withShrink(Shrink { array in
                // Shrink tail but keep at least the head
                AnySequence(
                    array.tail.indices.map { i in
                        var newTail = array.tail
                        newTail.remove(at: i)
                        return NonEmptyArray(head: array.head, tail: newTail)
                    }
                )
            })
    }
}
```

### Recipe: Coverage-Guided Testing

```swift
@Test("Coverage-guided path exploration")
func testWithCoverage() async throws {
    let config = PropertyConfig(
        iterations: 1000,
        enableCoverage: true,
        coverageStrategy: .adaptive
    )
    
    let property = Property(generator: Gen<Int>.int(in: 0...100)) { input in
        // Complex branching logic
        if input < 10 {
            return validateLow(input)
        } else if input < 50 {
            return validateMid(input)
        } else if input < 90 {
            return validateHigh(input)
        } else {
            return validateExtreme(input)
        }
    }
    
    try await checkProperty(property, config: config)
}
```

### Recipe: Diff-Based Assertions

```swift
@Arbitrary
struct Config: Equatable {
    var timeout: Int
    var retries: Int
    var enabled: Bool
}

@Test("Config update changes only specified fields")
func testConfigUpdate() {
    var config = Config(timeout: 30, retries: 3, enabled: true)
    
    expectDifference(config) {
        config.timeout = 60
    } changes: {
        $0.timeout = 60
    }
    
    // Only timeout changed, other fields unchanged
}
```

---

## Tips and Best Practices

### 1. Start Simple

Begin with basic properties before adding complexity.

```swift
// Start here
@PropertyTest
func testBasic(x: Int) {
    #expect(x + 0 == x)
}

// Then add complexity
@PropertyTest
func testComplex(
    @Gen(.int(in: 1...1000)) x: Int,
    @Gen(.int(in: 1...1000)) y: Int
) {
    #expect((x + y) - y == x)
}
```

### 2. Use Appropriate Generators

Match generators to your domain.

```swift
// Bad: Too general
@PropertyTest
func testAge(age: Int) { ... }

// Good: Domain-appropriate
@PropertyTest
func testAge(@Gen(.int(in: 0...150)) age: Int) { ... }
```

### 3. Test Properties, Not Examples

Focus on universal truths.

```swift
// Bad: Testing a specific case
@PropertyTest
func testSpecific(x: Int) {
    if x == 5 {
        #expect(double(5) == 10)
    }
}

// Good: Testing a property
@PropertyTest
func testDouble(x: Int) {
    #expect(double(x) == x + x)
}
```

### 4. Leverage Shrinking

Let InvariantSwift find minimal counterexamples.

```swift
// When this fails, you'll get minimal failing input
@PropertyTest
func testComplex(data: ComplexType) {
    #expect(validate(data))
}
// Output: "Shrunk counterexample: ComplexType(field: -1)"
```

### 5. Use Seeds for Debugging

Reproduce failures with fixed seeds.

```swift
// When a test fails, note the seed from output
// Then reproduce:
@PropertyTest(seed: 12345)
func testReproducible(x: Int) {
    #expect(buggyFunction(x))
}
```

---

## See Also

- [API Reference](API_REFERENCE.md) - Complete type documentation
- [Generators Guide](GENERATORS.md) - All available generators
- [Shrinking Guide](SHRINKING.md) - How shrinking works
- [Advanced Features](ADVANCED.md) - Coverage, model-based testing
