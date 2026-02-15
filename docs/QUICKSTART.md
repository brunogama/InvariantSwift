# InvariantSwift Quick Start Guide

> Get up and running in 10 minutes

---

## Prerequisites

- **Swift 6.0+** (`swift --version`)
- **Xcode 16.0+** (macOS)
- **Homebrew** (optional, for dev tools)

---

## Package Structure

InvariantSwift is organized as a monorepo with two sub-packages for optimized build times:

### InvariantSwiftCore (No SwiftSyntax)

The core library with generators, properties, shrinking, and testing infrastructure.
Users who don't need macros can depend on this package for faster builds.

```swift
// Package.swift - Depend on core only for faster builds
.package(url: "https://github.com/your-org/InvariantSwift", from: "2.0.0"),
// Then use:
.product(name: "InvariantSwiftCore", package: "InvariantSwift"),
```

### InvariantSwiftMacros (SwiftSyntax)

Macro implementations including @PropertyTest, @Arbitrary, @StateMachine, etc.
SwiftSyntax prebuilts are supported for 40-75% faster builds.

### Unified Import (Recommended)

For most users, simply import from the root package:

```swift
import InvariantSwift  // Gets everything via re-exports
```

---

## Build Performance

Enable SwiftSyntax prebuilts for faster macro builds (Swift 6.1.1+):

```bash
# Command line
swift build --enable-experimental-prebuilts
swift test --enable-experimental-prebuilts

# Or use Makefile targets (prebuilts enabled by default)
make build
make test-swift
```

In Xcode 16.4+:

```bash
defaults write com.apple.dt.Xcode IDEPackageEnablePrebuilts YES
```

**Expected improvement:** 40-75% faster macro compilation.

---

## 1. Clone & Setup

```bash
# Clone repository
git clone https://github.com/your-org/InvariantSwift.git
cd InvariantSwift

# Install dev tools
make setup

# Resolve dependencies
swift package resolve
```

---

## 2. Build & Test

```bash
# Build (with prebuilts for faster macro compilation)
make build

# Run tests (with prebuilts)
make test-swift

# Verify linting
make lint
```

### Building Sub-Packages Independently

```bash
# Build core only (fast, no SwiftSyntax)
make build-core

# Build macros only (with prebuilts)
make build-macros

# Test sub-packages
make test-core
make test-macros

# Clean all packages
make clean-all
```

---

## 3. Install Git Hooks (Optional but Recommended)

```bash
pip install pre-commit
pre-commit install
```

---

## 4. Your First Property Test

Add to any test file:

```swift
import Testing
import InvariantSwift

@PropertyTest
func testAdditionCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}
```

Run it:

```bash
swift test --filter testAdditionCommutative
```

---

## 5. Key Commands

| Task | Command |
|------|---------|
| Build | `swift build` |
| Test | `swift test \| xcbeautify` |
| Lint | `make lint` |
| Format | `make format` |
| Pre-PR Check | `make validate` |

---

## 6. Next Steps

1. Read [ONBOARDING.md](ONBOARDING.md) for full details
2. Explore [GENERATORS.md](GENERATORS.md) for generator reference
3. Check [MACROS.md](MACROS.md) for macro documentation
4. Browse examples in `Tests/FunctionalTesting/`

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

---

> Questions? Open an issue or check `CONTRIBUTING.md`
