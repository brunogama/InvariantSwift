# AnySendable Example

## Basic Usage

```swift
import InvariantSwift

// Wrap different types
let intValue = AnySendable(42)
let stringValue = AnySendable("hello")
let arrayValue = AnySendable([1, 2, 3])

// Store in heterogeneous collection
let values: [AnySendable] = [intValue, stringValue, arrayValue]

// Retrieve original values with type casting
if let number = intValue.base as? Int {
    print("Number: \(number)")  // Number: 42
}

// Pattern matching
switch stringValue.base {
case let str as String:
    print("String: \(str)")  // String: hello
default:
    print("Unknown type")
}
```

## Property-Based Testing Use Case

```swift
import InvariantSwift
import Testing

// Store generated test values of different types
@Test("AnySendable in property testing")
func testHeterogeneousGeneration() async throws {
    let generators: [Gen<AnySendable>] = [
        Gen<Int>.int.map { AnySendable($0) },
        Gen<String>.string.map { AnySendable($0) },
        Gen<Bool>.bool.map { AnySendable($0) },
    ]
    
    let mixedGen = Gen.oneOf(generators)
    let property = Property(generator: mixedGen) { value in
        // All values are Sendable
        value.base is any Sendable
    }
    
    try await checkProperty(property)
}
```

## Equality and Hashing

```swift
let a = AnySendable(42)
let b = AnySendable(42)
let c = AnySendable("42")

print(a == b)  // true - same type, same value
print(a == c)  // false - different types

// Use in Set or Dictionary
let set: Set<AnySendable> = [
    AnySendable(1),
    AnySendable(2),
    AnySendable(1),  // Duplicate, will be removed
]
print(set.count)  // 2
```

## Description and Debugging

```swift
let wrapped = AnySendable([1, 2, 3])

print(wrapped.description)  // [1, 2, 3]
debugPrint(wrapped)  // AnySendable(Array<Int>: [1, 2, 3])
```

## Thread Safety

`AnySendable` is fully `Sendable`, making it safe to use across concurrency boundaries:

```swift
let value = AnySendable(42)

Task {
    // Safe to capture across concurrency boundaries
    let result = value.base as? Int
    print(result ?? 0)
}

actor MyActor {
    var storage: [AnySendable] = []
    
    func add(_ value: AnySendable) {
        storage.append(value)
    }
}
```
