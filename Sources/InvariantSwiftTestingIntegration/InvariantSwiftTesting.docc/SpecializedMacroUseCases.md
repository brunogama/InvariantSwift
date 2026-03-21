# Specialized Macro Use Cases

@Metadata {
  @PageKind(article)
}

Use the named assertion macros when the property you want to test already has a standard shape and you want the test declaration to read like the contract you care about.

These macros sit on top of the same generator, shrinking, and issue-reporting machinery as `@PropertyTest`, but they trade some flexibility for intent:

- `@Idempotent` says repeated application should stabilize.
- `@Deterministic` says the same input should always produce the same output.
- `@Pure` says you expect a helper to behave like a side-effect-free deterministic function, while still remembering that Swift cannot prove purity for you.

## Use Case 1: Stabilize a Normalization Pipeline

Choose `@Idempotent` when an operation should stop changing data after the first successful pass.

Typical examples:

- trimming and canonicalizing user input
- normalizing URLs or file-system paths
- deduplicating or sorting already-normalized collections

```swift
import InvariantSwiftTesting
import InvariantSwiftMacroAPI

@Idempotent(iterations: 200, applicationCount: 3)
func normalizeEmail(_ raw: String) -> String {
  raw
    .trimmingCharacters(in: .whitespacesAndNewlines)
    .lowercased()
}
```

If this macro finds a counterexample, the shrunk input usually points directly at the transformation stage that keeps changing the value.

## Use Case 2: Protect a Stable Cache or Serialization Key

Choose `@Deterministic` when repeated calls with the same input must always agree.

Typical examples:

- building cache keys
- canonical request serialization
- deriving reproducible IDs from stable inputs

```swift
import InvariantSwiftTesting
import InvariantSwiftMacroAPI

@Deterministic(iterations: 150, callCount: 4)
func cacheKey(for userID: Int) -> String {
  "user:\\(userID)"
}
```

This is a good fit for helpers that must be reproducible, but that you do not necessarily want to describe as mathematically pure.

## Use Case 3: Document a Side-Effect-Free Helper Contract

Choose `@Pure` when the function should be deterministic and you also want the declaration to communicate a side-effect-free expectation to reviewers and maintainers.

```swift
import InvariantSwiftTesting
import InvariantSwiftMacroAPI

@Pure(iterations: 200, callCount: 3)
func renderSummary(name: String, count: Int) -> String {
  "\\(name): \\(count)"
}
```

`@Pure` is intentionally conservative:

- it does test repeatability for the same input
- it does not prove absence of hidden mutation or I/O

Use it after you have manually verified the implementation is intended to be side-effect free.
