# Check Code Coverage

Check code coverage for specific files, directories, or entire project.

## Steps

1. **Parse Target** from `$ARGUMENTS`:
   - File path: `Sources/Core/Gen.swift`
   - Directory: `Sources/Core/`
   - Component: `Gen` → find file
   - No args: Full project coverage

2. **Run Tests with Coverage**:
   ```bash
   swift test --enable-code-coverage
   ```

3. **Generate Coverage Report**:
   ```bash
   xcrun llvm-cov export \
     .build/debug/InvariantSwiftTestPackageTests.xctest/Contents/MacOS/InvariantSwiftTestPackageTests \
     -instr-profile .build/debug/codecov/default.profdata \
     -format=lcov > /tmp/coverage.lcov
   ```

4. **Extract Target Coverage**:
   ```bash
   # For specific file
   xcrun llvm-cov report \
     .build/debug/InvariantSwiftTestPackageTests.xctest/Contents/MacOS/InvariantSwiftTestPackageTests \
     -instr-profile .build/debug/codecov/default.profdata \
     ${TARGET_FILE}
   ```

5. **Report Results**:
   - Overall coverage percentage
   - Lines covered / total lines
   - Uncovered lines with line numbers
   - Compare against 99% threshold
   - Suggest tests for uncovered code

## Usage

```
/check-coverage Sources/Core/Gen.swift   # Specific file
/check-coverage Sources/Core/            # Directory
/check-coverage Gen                      # Component name
/check-coverage                          # Full project
```

## Coverage Requirements

- **Target**: 99%+ for library code
- **Enforcement**: Pre-commit hook (`swift-coverage-guard`)
- **Bypass** (exceptional cases only): `SKIP=swift-coverage-guard git commit`

## Notes

- Coverage script: `scripts/check-coverage.sh`
- Never lower coverage thresholds without explicit user request
- Uncovered code must have justification (unreachable, defensive, etc.)
- Use `make coverage` for full coverage report with lcov format
