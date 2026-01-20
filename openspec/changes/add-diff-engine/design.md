# Design: Diff Engine

## Architecture

The `DiffEngine` will be a standalone component in the `Presentation` layer. It is responsible for taking two values of the same type and producing a human-readable string describing their difference.

### Core Interface

```swift
public struct DiffEngine {
    public static func diff<T>(_ expected: T, _ actual: T) -> String?
}
```

### Diffing Strategies

#### 1. Strings
- **Algorithm:** Myers Difference Algorithm (or simple LCS).
- **Output:** Unified diff format (`- expected`, `+ actual`).
- **Granularity:** Line-based by default. If string is single-line, use char-based highlighting if possible (or just print both).

#### 2. Collections (Arrays)
- **Algorithm:** Myers Diff on elements (requires `Equatable`).
- **Output:**
  ```
  [2] - "removed"
  [2] + "inserted"
  ```
- **Optimization:** If arrays are huge, only show context around the change.

#### 3. Dictionaries
- **Logic:** Compare keys.
  - **Missing keys:** Keys in `expected` but not `actual`.
  - **Extra keys:** Keys in `actual` but not `expected`.
  - **Modified values:** Keys in both but values differ.
- **Sorting:** **CRITICAL**. Dictionaries are unordered. To ensure "stable text output", we MUST sort keys by their string representation before diffing.

#### 4. Structs/Classes (Reflection)
- **Logic:** Use `Mirror` to iterate children.
- **Recursion:** Diff child values recursively.
- **Output:**
  ```
  User(
    name: ...
    age: - 20
         + 21
  )
  ```
- **Stability:** `Mirror.children` order is usually stable for structs, but we should verify.

### Stability & Performance
- **Reflection Cost:** Reflection is slow. This feature should be used only on *failure*. Since failures stop the test (or happen rarely compared to success), the performance cost is acceptable.
- **ANSI:** The user requested "no random ANSI". We should default to plain text or provide a `DiffFormat` config. We will implement plain text diffing first (using `+` / `-` markers).

## Integration with FailureReport

`FailureReport` is the data structure. `FailureReporter` is the formatter.

1. `FailureReport` gains `diff: String?`.
2. When `expectNoDifference` fails:
   - Compute diff using `DiffEngine`.
   - Record failure with this diff.
3. When `PropertyRunner` detects a failure:
   - It usually captures the *input* (counterexample).
   - If the failure was caused by `expectNoDifference` inside the property, the diff is "output" based.
   - We need to ensure `FailureReason` or `PropertyResult` can capture this rich info.
   - *Current plan:* Focus on `expectNoDifference` populating the diff, and `FailureReporter` displaying it if available.

### Handling `FailureReason`
We might need to extend `FailureReason` to case `assertionFailed(diff: String)` to carry this info up to the runner if we want `FailureReport` to contain it automatically from standard property failures.
However, `expectNoDifference` currently talks directly to `Issue.record`.
For this proposal, we will focus on:
1. `DiffEngine` implementation.
2. `FailureReport` support for holding a diff (for future use or manual population).
3. `expectNoDifference` using `DiffEngine`.

## Risks
- **Infinite Recursion:** Cyclic references in classes. `DiffEngine` needs cycle detection (keep a set of visited object identifiers).
- **Large Diffs:** Diffing 1MB strings or 10k arrays. We should implement a limit (max lines/chars) to avoid flooding the console.
