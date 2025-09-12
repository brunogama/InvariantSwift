# FunctionalTesting

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20Linux-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-4BC51D.svg)](https://swift.org/package-manager/)

A comprehensive property-based testing framework for Swift, designed to help you write more reliable and thorough tests by automatically generating test cases and finding edge cases you might have missed.

## Features

### 🔧 Core Testing Framework
- **Property-based testing** with automatic test case generation
- **Integrated shrinking** for minimal counterexamples
- **Comprehensive generators** for primitive and complex types
- **Swift 6 concurrency** support with async properties
- **Mathematical law verification** for functional programming patterns

### 🚀 Advanced Features  
- **Coverage-guided testing** with 99% target coverage
- **Macro system** for automatic test generation (`@PropertyTest`)
- **Swift Testing integration** for seamless test execution
- **Performance benchmarking** and memory usage validation
- **CLI tool** (`functest`) for command-line testing
- **SPM Plugin** integration for build-time testing

### 🧪 Specialized Testing
- **Model-based testing** for complex state machines
- **Lens system** for compositional property testing
- **DICE (Distributed Integrated Coverage Engine)** for advanced coverage analysis
- **SMT solver support** for constraint-based testing
- **Flake detection** and reliability analysis

## Quick Start

### Installation

Add FunctionalTesting to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/FunctionalTesting", from: "1.0.0")
]
```

Then add it to your test target:

```swift
.testTarget(
    name: "YourTests",
    dependencies: [
        "FunctionalTesting"
    ]
)
```

### Basic Usage

```swift
import Testing
import FunctionalTesting

@Test("Array reverse property")
func testArrayReverse() {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { array in
        return array.reversed().reversed() == array
    }
    
    try checkProperty(property, config: PropertyConfig(iterations: 100))
}
```

### Using the @PropertyTest Macro

```swift
import Testing
import FunctionalTesting

@PropertyTest
func testIntegerAddition(a: Int, b: Int) {
    #expect((a + b) - a == b)
}

@PropertyTest  
func testStringConcatenation(s1: String, s2: String) {
    let combined = s1 + s2
    #expect(combined.hasPrefix(s1))
    #expect(combined.hasSuffix(s2))
}
```

## Generators

FunctionalTesting provides generators for all common Swift types:

### Primitive Types
```swift
Gen.bool           // Bool
Gen.int            // Int  
Gen.string         // String
Gen.double         // Double
Gen.character      // Character
```

### Collections
```swift
Gen.array(Gen.int)                    // [Int]
Gen.set(Gen.string)                   // Set<String>
Gen.dictionary(Gen.string, Gen.int)   // [String: Int]
```

### Custom Types
```swift
struct Person {
    let name: String
    let age: Int
}

let personGen = Gen<Person> { rng, size in
    Person(
        name: Gen.string.generate(&rng, size),
        age: Gen.int.generate(&rng, size)
    )
}
```

## Advanced Features

### Async Property Testing
```swift
@Test("Async property test")
func testAsyncOperation() async {
    let property = Property<String>(generator: Gen.string) { input in
        let result = await someAsyncOperation(input)
        return result.count >= input.count
    }
    
    try await checkPropertyAsync(property)
}
```

### Mathematical Law Verification
```swift
// Verify functor laws for Optional
@PropertyTest
func testOptionalFunctorIdentity<T>(value: T?) {
    #expect(value.map { $0 } == value)
}

@PropertyTest  
func testOptionalFunctorComposition<T>(value: T?, f: @escaping (T) -> String, g: @escaping (String) -> Int) {
    #expect(value.map(f).map(g) == value.map { g(f($0)) })
}
```

### Model-Based Testing
```swift
class StackModel {
    private var items: [Int] = []
    
    func push(_ item: Int) { items.append(item) }
    func pop() -> Int? { items.popLast() }
    func peek() -> Int? { items.last }
    var isEmpty: Bool { items.isEmpty }
}

@Test("Stack model-based test")
func testStackModel() {
    let commands = Gen.array(StackCommand.generator)
    
    let property = Property(generator: commands) { commands in
        let model = StackModel()
        let implementation = Stack<Int>()
        
        for command in commands {
            let modelResult = command.execute(model)
            let implResult = command.execute(implementation)
            guard modelResult == implResult else { return false }
        }
        
        return true
    }
    
    try checkProperty(property)
}
```

## CLI Tool

Use the `functest` command-line tool for advanced testing:

```bash
# Run property tests with coverage
swift run functest --coverage --iterations 1000

# Generate test reports  
swift run functest --report html --output test-results.html

# Run with specific generators
swift run functest --generator string --size 100
```

## SPM Plugin

Add property testing to your build process:

```bash
# Run property tests as part of build
swift package functest --validate --coverage-threshold 95
```

## Configuration

Customize testing behavior with `PropertyConfig`:

```swift
let config = PropertyConfig(
    iterations: 1000,
    maxSize: 100,
    maxShrinks: 1000,
    timeout: 30.0,
    seed: 42,
    enableCoverage: true
)

try checkProperty(property, config: config)
```

## Performance

FunctionalTesting is designed for high performance:

- **10,000+ generations/second** for primitive types
- **Linear scaling** with CPU cores for concurrent testing  
- **Minimal memory footprint** with lazy evaluation
- **Efficient shrinking** with tree-based algorithms

## Documentation

- [API Documentation](https://your-org.github.io/FunctionalTesting/documentation/functionaltesting/)
- [User Guide](docs/UserGuide.md)  
- [Advanced Features](docs/AdvancedFeatures.md)
- [Contributing Guide](CONTRIBUTING.md)

## Examples

Check out the [Examples](Examples/) directory for:

- Basic property testing patterns
- Advanced generator composition
- Model-based testing examples
- Performance benchmarking
- Integration with existing test suites

## Requirements

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+ / tvOS 16.0+ / watchOS 9.0+
- Linux (Swift-compatible distributions)

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Policy](SECURITY.md)
- [Issue Templates](.github/ISSUE_TEMPLATE/)

## Inspiration

FunctionalTesting is inspired by:

- [QuickCheck](https://hackage.haskell.org/package/QuickCheck) (Haskell)
- [Hypothesis](https://hypothesis.readthedocs.io/) (Python)
- [SwiftCheck](https://github.com/typelift/SwiftCheck) (Swift)
- [Property-based testing](https://en.wikipedia.org/wiki/Property-based_testing) methodologies

## License

FunctionalTesting is released under the MIT license. See [LICENSE](LICENSE) for details.

## Support

- GitHub Issues: [Report bugs or request features](https://github.com/your-org/FunctionalTesting/issues)
- Discussions: [Ask questions and share ideas](https://github.com/your-org/FunctionalTesting/discussions)
- Documentation: [Read the full documentation](https://your-org.github.io/FunctionalTesting/)

---

Made with ❤️ by the FunctionalTesting team