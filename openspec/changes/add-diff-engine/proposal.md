# Change: Add Diff Engine

## Summary
Implement a sophisticated `DiffEngine` to provide minimal, readable differences for property test failures. This engine will support Strings (line/word/char), Arrays, Dictionaries, and Structs (via reflection), ensuring stable and clear output in `FailureReport`.

## Motivation
Current failure reporting shows "Expected: A, Actual: B" which is noisy for large data structures. Readable diffs ("this field changed", "index 5 is missing") reduce cognitive load and speed up debugging.

## Proposed Changes

### 1. New `DiffEngine` Module
- Locate in `Sources/InvariantSwift/Presentation/DiffEngine.swift`.
- Provide a `diff<T>(_ expected: T, _ actual: T) -> String?` function.
- **Strategies:**
  - **Strings:** Line-based diff (unified diff style), falling back to char/word for single lines.
  - **Collections (Array/Set):** LCS (Longest Common Subsequence) to find insertions/deletions. Show only changed indices.
  - **Dictionaries:** Show added/removed/modified keys.
  - **Structs/Classes:** Use `Mirror` to diff properties recursively.

### 2. Update `FailureReport`
- Add `public let diff: String?` to `FailureReport`.
- Update `FailureReport.init` to accept an optional diff.
- Update `FailureReportBuilder`.

### 3. Update `FailureReporter`
- In `formatVerboseMessage` (and potentially compact), include the diff section if present.
- Use a stable, clean format (avoid random ANSI, use stable sorting for keys).

### 4. Integration with Assertions
- Update `expectNoDifference` to use `DiffEngine`.
- Ensure the produced diff is included in the failure record.

## Impact
- **Developer Experience:** drastically improved failure messages.
- **Performance:** Reflection used only on failure, so negligible impact on green tests.
- **Compatibility:** Backwards compatible (diff is optional).

## Risks
- **Reflection Output Order:** Struct field order via `Mirror` is usually stable but not guaranteed by Swift ABI. We will sort by label for stability.
- **Infinite Recursion:** Cyclic references in classes must be handled.

## Alternatives Considered
- **swift-custom-dump:** Excellent library, but we want to minimize external dependencies for this core framework.
