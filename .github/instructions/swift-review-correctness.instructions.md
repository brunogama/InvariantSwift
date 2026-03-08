---
description: "Ultra-strict Swift correctness, ownership, and security review."
applyTo: "Sources/**/*.swift,Tests/**/*.swift"
---

# Swift correctness review

## SwiftUI and UI blockers

- `body` must stay pure: no network, disk, crypto, database, analytics,
  logging, or side-effectful object construction.
- UI state mutations must happen on the main actor.
- Views must not own business logic they should not own.
- Reject accidental state-object recreation during render.
- Reject async work launched from render paths outside intended lifecycle
  modifiers.
- Reject update loops driven by `onChange`, `onReceive`, bindings, or
  observation.
- Reject hidden dependencies on redraw timing.
- Check that `.task(id:)` identity is intentional, async work is
  cancellation-aware, loading and error states are explicit, and heavy work
  stays out of the view layer.

## Ownership and lifetime blockers

- No retain cycles through owners, delegates, closures, tasks, timers,
  observers, or async streams.
- Capture lists must be deliberate.
- Lifetimes for timers, notifications, tasks, subscriptions, and delegates must
  be explicit.
- Reject unbounded caches or memory growth without eviction.
- Reject force-unwrapped weak references.
- Reject `unowned` unless lifetime is mathematically guaranteed.
- Confirm ownership is readable: who owns the object, who mutates it, on which
  actor or executor, what cancels it, and what happens if the owner disappears.

## Security and privacy blockers

- No secrets in source, fixtures, screenshots, logs, crash reports, or
  `Info.plist`.
- Secrets that belong in protected storage must use Keychain, not `UserDefaults`.
- ATS must not be weakened broadly; exceptions must be narrow, documented, and
  justified.
- Manual trust evaluation or pinning changes require security review and tests.
- Reject plaintext logging of sensitive user data.
- Privacy manifests and entitlements must stay accurate and least-privilege.
- Deep links, file URLs, universal links, pasteboard, and imported files must
  be validated before use.
- Prefer redacted logs, minimal data collection, clear retention and deletion
  rules, and auth flows that handle replay, stale session, and races.

## Data-boundary blockers

- No force unwrap or force decode of external input.
- Network and persistence boundaries must validate input shape, size, and
  semantics.
- Partial failure, retry, and offline behavior must be designed intentionally.
- File writes must be atomic where corruption matters.
- Persistence and UI propagation must not race.
- Check explicit timeouts, backoff, idempotency, migrations, date and locale
  handling, and actionable error mapping.

## Architecture and performance blockers

- Invalid states should be unrepresentable where practical.
- Domain invariants should be enforced at construction.
- Reject convenience APIs that weaken safety.
- Keep dependencies pointing inward and surfaces minimal.
- No blocking I/O, heavy parsing, crypto, or image work on the main actor.
- Reject accidental quadratic work in render, diffing, sort, filter, or
  reconciliation paths.
- Reject repeated hot-path formatter or decoder creation and other expensive
  tight-loop allocations.
- Prefer small behavior-oriented protocols, value types unless identity is
  required, bounded caches, and measured performance work.

## Error-handling blockers

- Reject `try!` and production force unwraps unless crashing is explicit policy.
- Reject empty `catch`.
- Reject lossy fallback that silently corrupts business behavior.
- Cancellation must not be reported as a generic failure.
- User-visible operations must always reach a terminal state.
- Preserve diagnostic context without leaking secrets, and keep retryability and
  recovery expectations explicit.
