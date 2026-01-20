---
description: Full validation pipeline before PR submission
---

# Validate Workflow

Run full validation pipeline before creating a PR.

// turbo-all

## Steps

### 1. Build with Strict Warnings
```bash
swift build -Xswiftc -warnings-as-errors
```

### 2. Run Linting
```bash
swiftlint lint --strict
```

### 3. Check Formatting
```bash
swift-format lint --configuration .swift-format --recursive ./Sources ./Tests 2>&1 | head -20 || echo "Some files need formatting - run: make format"
```

### 4. Run All Tests
```bash
swift test 2>&1 | xcbeautify || swift test 2>&1 | tail -50
```

### 5. Summary
Report:
- Build status (pass/fail)
- Lint violations count
- Formatting issues
- Test results (pass/fail count)

## Quick Alternative
```bash
make validate
```

## Definition of Done

Before creating a PR, ensure:
1. ✅ `swift build -Xswiftc -warnings-as-errors` passes
2. ✅ `swift test` passes all tests
3. ✅ `swiftlint lint --strict` reports zero violations
4. ✅ Code is formatted: `make format`
5. ✅ Documentation updated for API changes
6. ✅ CHANGELOG.md updated (if user-facing change)
