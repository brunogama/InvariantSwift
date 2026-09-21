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
just format-check
```

### 4. Run All Tests
```bash
set -o pipefail
swift test 2>&1 | xcbeautify --preserve-unbeautified -q
```

### 5. Summary
Report:
- Build status (pass/fail)
- Lint violations count
- Formatting issues
- Test results (pass/fail count)

---

## Quick Alternative
```bash
just validate
```

---

## Definition of Done

Before creating a PR, ensure:
1. ✅ `swift build -Xswiftc -warnings-as-errors` passes
2. ✅ `swift test` passes all tests
3. ✅ `swiftlint lint --strict` reports zero violations
4. ✅ Code is formatted: `just format`
5. ✅ Documentation updated for API changes
6. User-facing changes described for generated release notes
