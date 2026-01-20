# InvariantSwift Quick Start

> **Get up and running in 5 minutes**

---

## Prerequisites

- Swift 6.0+ (`swift --version`)
- Xcode 16.0+ (macOS)
- Homebrew (recommended)

---

## 1. Clone & Setup

```bash
git clone https://github.com/brunogama/InvariantSwift.git
cd InvariantSwift

# Install dev tools
make setup

# Resolve dependencies
swift package resolve
```

---

## 2. Build & Test

```bash
# Build
swift build

# Run tests
swift test | xcbeautify

# Lint
make lint
```

---

## 3. Install Git Hooks (Recommended)

```bash
pip install pre-commit
pre-commit install
```

---

## 4. Your First Property Test

Create a test file or add to existing tests:

```swift
import Testing
import InvariantSwift

@PropertyTest
func testAdditionCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}

@PropertyTest
func testArrayReversalIdentity(array: [Int]) {
    #expect(array.reversed().reversed() == Array(array))
}
```

Run it:

```bash
swift test --filter testAdditionCommutative
```

---

## 5. Essential Commands

| Task | Command |
|------|---------|
| Build | `swift build` |
| Test | `swift test \| xcbeautify` |
| Lint | `make lint` |
| Format | `make format` |
| Pre-PR Check | `make validate` |
| Coverage | `swift test --enable-code-coverage` |

---

## 6. Project Structure at a Glance

```
Sources/InvariantSwift/     # Main library
  Core/                     # Gen<T>, Property, Seed
  Generators/               # Numeric, Collection, Combinator generators
  Advanced/                 # Coverage-guided, Lens system, Linearizability
  Macros/                   # @PropertyTest, @Arbitrary declarations

Tests/FunctionalTesting/    # Test examples

Plugins/                    # SPM plugins
  InvariantSwiftPlugin/     # swift package invariant
  GhostwriterPlugin/        # swift package ghostwrite
```

---

## 7. Key Generators

```swift
Gen<Int>.int                     // Random Int
Gen<Int>.int(in: 0...100)        // Int in range
Gen<String>.string               // Random String
Gen<Bool>.bool                   // true or false
Gen.array(Gen<Int>.int)          // [Int]
Gen.optional(Gen<Int>.int)       // Int?
Gen.oneOf([Gen.pure(1), Gen.pure(2)])  // Choose from options
```

---

## 8. Next Steps

1. Read [ONBOARDING.md](ONBOARDING.md) for full details
2. Explore [GENERATORS.md](GENERATORS.md) for all generators
3. Check [MACROS.md](MACROS.md) for macro documentation
4. Browse `Tests/FunctionalTesting/` for examples

---

## Troubleshooting

**Module not found:**
```bash
swift package clean && rm -rf .build && swift package resolve
```

**Pre-commit fails:**
```bash
make setup  # Install missing tools
```

**Build warnings:**
```bash
# Warnings are errors - fix all warnings before committing
swiftlint --fix  # Auto-fix lint issues
```

---

> Questions? See [CONTRIBUTING.md](../CONTRIBUTING.md) or open a GitHub issue.
