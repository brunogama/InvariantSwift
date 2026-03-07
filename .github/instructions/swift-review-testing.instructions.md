---
description: "Ultra-strict Swift testing and merge-gate review checklist."
applyTo: "Sources/**/*.swift,Tests/**/*.swift"
---

# Swift testing and merge gate

## Tests expected per area

- `Vec0` or routing changes: matrix tests plus equivalence against the SQL
  baseline.
- Index changes: nearest-neighbor correctness plus a recall regression guard.
- Quantization changes: precision and recall bounds plus round-trip
  properties.

## Testing blockers

- Every bug fix needs a regression test.
- New concurrency code needs tests for isolation, cancellation,
  reentrancy-sensitive behavior, ordering assumptions, and timeouts.
- Security-sensitive code needs tests for malformed input, authorization
  failure, and secret leakage.
- SwiftUI stateful flows need view-model, reducer, or UI coverage appropriate
  to the architecture.
- Prefer parameterized or property-based tests for pure transformations,
  benchmarks for hot paths, migration tests for persistence, strong fixtures or
  contracts for networking, and tests that avoid hidden global state or timing
  flakiness.

## Interop and documentation blockers

- Objective-C, C, delegate, callback, notification, Combine, and FFI boundaries
  must not weaken Swift isolation guarantees.
- Unsafe bridge layers must document ownership and lifetime precisely.
- Non-obvious invariants must be written down in code comments or docs.
- Every unsafe, unchecked, security-exception, or concurrency escape hatch
  needs a justification comment.
- Public APIs must document usage constraints.
- Feature flags, migrations, and rollout constraints must be documented.
- Prefer metrics, logs, and traces on critical paths, plus runbooks for
  crash-prone or security-sensitive modules and tracked technical debt with an
  owner and exit criteria.

## Automatic rejection list

- `@unchecked Sendable` with no proof.
- `Task.detached` with no owner or cancellation model.
- `DispatchQueue.main.async` used to hide actor-isolation issues.
- Secrets stored outside Keychain when protected storage is required.
- Broad ATS weakening.
- Side effects from `SwiftUI.View.body`.
- Force unwraps on external data.
- Shared mutable global state.
- Hidden failures through `try?`, empty `catch`, or best-effort logic in
  critical paths.
- Public API surface expansion without tests and documentation.

## Verdict rubric

- Reject when any blocker above is violated.
- Fix before release when blockers are clear but major security, concurrency,
  persistence, or UI-correctness risks remain.
- Accept only when blockers are clear and remaining majors are explicitly
  ticketed with owner, scope, and deadline.
