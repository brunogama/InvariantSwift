Run tests for InvariantSwift: $ARGUMENTS

## Usage

- `/run-tests` - Run all tests
- `/run-tests generators` - Run generator tests
- `/run-tests macros` - Run macro tests
- `/run-tests coverage` - Run with coverage report

## Test Commands

### All Tests
```bash
swift test | xcbeautify
```

### Filtered Tests
```bash
# Core library tests
swift test --filter FunctionalTesting

# Macro tests
swift test --filter InvariantSwiftMacroTests

# Specific test file
swift test --filter "$ARGUMENTS"
```

### Platform-Specific
```bash
# macOS
make test-macos

# iOS Simulator
make test-ios

# Linux (Docker)
make test-linux

# Beta SDK (SIGTRAP protected)
make test-safe
```

### Coverage
```bash
swift test --enable-code-coverage
make coverage
```

## After Running

1. Report test results (pass/fail count)
2. If failures, show the failing test names and error messages
3. If coverage requested, show coverage percentage
4. Suggest fixes for any failures
