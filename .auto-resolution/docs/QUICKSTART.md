# InvariantSwift Quick Start Guide

> Get up and running in 10 minutes

---

## Prerequisites

- **Swift 6.0+** (`swift --version`)
- **Xcode 16.0+** (macOS)
- **Homebrew** (optional, for dev tools)

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
# Build
swift build

# Run tests
swift test | xcbeautify

# Verify linting
make lint
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
