# Check Documentation Coverage

Run documentation coverage check using `check_docs.py` script.

## Steps

1. **Parse Options** from `$ARGUMENTS`:
   - `--verbose`: Detailed output
   - `--json`: JSON report
   - `--strict`: Fail on issues (CI mode)
   - No args: Standard check

2. **Run Documentation Check**:
   ```bash
   python3 check_docs.py --verbose
   ```

3. **Parse Results**:
   - Undocumented public APIs
   - Missing `///` doc comments
   - Incomplete documentation (missing parameters, returns)
   - Files without documentation

4. **Report Findings**:
   - Coverage percentage (target: 100% for public APIs)
   - List undocumented APIs with file:line
   - Suggest documentation templates
   - Link to `docs/API_DOCUMENTATION_TEMPLATE.md`

5. **Suggest Fixes**:
   - Generate skeleton doc comments
   - Reference similar documented APIs
   - Use SwiftDoc best practices

## Usage

```
/check-docs                    # Standard check
/check-docs --verbose          # Detailed output
/check-docs --json             # JSON report
/check-docs --strict           # Fail on issues (CI mode)
```

## Documentation Standards

**Public API** (required):
```swift
/// Brief one-line summary.
///
/// Detailed description of functionality, behavior, and usage.
///
/// - Parameters:
///   - param1: Description
///   - param2: Description
/// - Returns: Description of return value
/// - Throws: Conditions that cause errors
/// - Complexity: Time/space complexity
/// - Note: Additional notes
/// - Warning: Important warnings
/// - SeeAlso: Related types/functions
public func example(param1: Int, param2: String) -> Bool {
  // ...
}
```

**Internal API** (recommended):
```swift
// Brief comment explaining purpose
internal func helper() {
  // ...
}
```

## Related Files

- `check_docs.py` - Documentation checker script
- `docs/API_DOCUMENTATION_TEMPLATE.md` - Documentation template
- `docs/API_REFERENCE_GENERATED.md` - Auto-generated API reference

## Notes

- Pre-commit hook does not enforce doc coverage (warning only)
- Use this command before creating PRs with new public APIs
- Documentation is generated into `docs/API_REFERENCE_GENERATED.md`
- Use `make doc-check` or `make doc-check-strict` shortcuts
