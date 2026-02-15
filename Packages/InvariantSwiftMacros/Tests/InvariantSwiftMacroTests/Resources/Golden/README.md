# Macro Golden Test Guide

## Overview

This directory contains golden test fixtures for InvariantSwift macros. Golden tests validate that macro expansions produce the expected Swift source code across different toolchains.

## Structure

```
Tests/InvariantSwiftMacroTests/Resources/Golden/
├── PropertyTest/     # @PropertyTest macro fixtures
│   ├── Basic.swift   # Input source
│   └── Basic.golden.swift  # Expected expansion
├── Arbitrary/        # @Arbitrary macro fixtures
├── Gen/              # @Gen macro fixtures
└── Label/            # @Label macro fixtures
```

## Creating New Golden Tests

### Step 1: Create Input Fixture

Create a `.swift` file with the macro usage:

```swift
// Tests/InvariantSwiftMacroTests/Resources/Golden/PropertyTest/MyTest.swift
@PropertyTest
func testExample(x: Int) {
  x >= 0
}
```

### Step 2: Generate Expected Output

Run the macro expansion to see the actual output:

```bash
swift test --filter "MacroGoldenTests/testMyTest" 2>&1 | grep -A 50 "Macro expansion"
```

### Step 3: Create Golden File

Copy the **actual expanded source** from the test output (the `+` lines) to create the `.golden.swift` file.

**Important**: Match indentation and formatting exactly as the macro produces it.

### Step 4: Add Test Case

Add a test method in `MacroGoldenTests.swift`:

```swift
func testPropertyTestMyTestGolden() throws {
  try assertGolden(
    macro: "PropertyTest",
    testCase: "MyTest"
  )
}
```

## Normalization

Golden tests use `assertMacroExpansion` from SwiftSyntaxMacrosTestSupport, which:
- Compares expanded source exactly (whitespace-sensitive)
- Reports differences with unified diff format
- Validates diagnostic messages

### Handling Toolchain Differences

If different Swift toolchains produce different formatting:
1. Use the format from the CI toolchain (Swift 6.0 currently)
2. Document toolchain-specific variations in comments
3. Consider using indentationWidth parameter if needed

## Running Tests

```bash
# All golden tests
swift test --filter MacroGoldenTests

# Specific macro
swift test --filter MacroGoldenTests | grep "PropertyTest"

# Single test
swift test --filter "MacroGoldenTests/testPropertyTestBasicGolden"
```

## CI Integration

Golden tests run automatically in CI via:
- `.github/workflows/ci.yml` - `macro-golden-tests` job
- Runs on: ubuntu-latest with swift:6.0-jammy container

## Maintenance

### When Macro Implementation Changes

1. Update `.golden.swift` files to match new output
2. Run tests to verify
3. Review diffs carefully before committing

### Adding New Macro Coverage

For each macro scenario, create fixtures testing:
- ✅ Basic usage
- ✅ Edge cases (empty, single parameter, many parameters)
- ✅ Configuration options (iterations, seed, etc.)
- ✅ Async variants (if applicable)
- ✅ Error conditions

## Current Coverage

### PropertyTest
- ✅ Basic.swift - Simple single parameter
- ✅ Complex.swift - Multiple parameters
- 🔨 WithConfig.swift - Custom iterations/seed
- 🔨 Async.swift - Async property test

### Arbitrary
- ✅ Struct.swift - Basic struct with fields
- 🔨 Enum.swift - Simple enum cases
- 🔨 WithOptional.swift - Optional fields

### Gen
- 🔨 SimpleParameter.swift - Single @Gen parameter
- 🔨 MultipleParameters.swift - Multiple @Gen parameters

### Label
- 🔨 SimpleLabel.swift - Labeled parameters

Legend:
- ✅ = Implemented and passing
- 🔨 = Fixture created, needs golden file update
- ⏸️ = Planned, not yet implemented

## Troubleshooting

### Test Fails with "Macro expansion did not produce expected source"

1. Check indentation (tabs vs spaces, width)
2. Check access modifiers (`public` vs none)
3. Check type names (`Self` vs concrete type name)
4. Run with verbose output to see full diff

### Golden File Not Found

Ensure:
1. File is in correct subdirectory
2. Filename matches exactly (case-sensitive)
3. Extension is `.swift` for input, `.golden.swift` for expected
4. File is included in `Package.swift` resources

### Formatting Differences

The macro implementation determines formatting. If output differs from expectations:
1. Trust the macro implementation
2. Update golden file to match actual output
3. Document any surprising formatting choices

## Best Practices

1. **Keep fixtures minimal** - Test one thing per fixture
2. **Use descriptive names** - `WithConfigAndAsync.swift` not `Test3.swift`
3. **Document edge cases** - Add comments explaining unusual inputs
4. **Test failure paths** - Include fixtures that should produce diagnostics
5. **Maintain consistency** - Follow existing naming patterns
