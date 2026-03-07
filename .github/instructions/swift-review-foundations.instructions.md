---
description: "Ultra-strict Swift review foundations for Sources and Tests."
applyTo: "Sources/**/*.swift,Tests/**/*.swift"
---

# Swift review foundations

Apply these rules when reviewing changes in `Sources/` and `Tests/`.

## Hard blockers

- No change may break target layering, especially Core targets importing GRDB,
  SQLite, CoreML, or similar infrastructure.
- No unsafe concurrency: no data races, non-Sendable escapes, or missing actor
  isolation under strict concurrency.
- No behavior change without tests unless the PR clearly states it is doc-only.

## Build and toolchain gate

- Require clean Debug and Release builds for supported platforms.
- Require zero compiler warnings in CI.
- Require Swift 6 language mode everywhere under active development.
- Require Complete strict concurrency checking everywhere, including tests.
- Reject `#if DEBUG` changes that alter correctness, security, data flow, or
  isolation behavior.
- Reject suppressed warnings, `@preconcurrency`, or similar shims unless the PR
  gives a written reason and removal plan.
- Reject new `public` or `open` API without explicit review of stability,
  naming, docs, and tests.
- Check availability annotations, consistent build settings, module boundaries,
  and pinned dependency choices.

## Concurrency and isolation blockers

- Shared mutable state must be protected by actor isolation, `@MainActor`,
  `Mutex`, atomics, or equivalent synchronization.
- Every type that crosses concurrency domains must actually be safe to send.
- Reject `@unchecked Sendable` unless the PR includes a proof of invariants,
  ownership, and synchronization.
- Reject mutable globals and singletons with unsynchronized mutable storage.
- Reject `Task.detached` unless ownership, lifetime, cancellation, and priority
  are explicitly correct.
- Reject `nonisolated` escape hatches without a real performance or interop
  reason.
- Treat every `await` in actor-isolated code as a reentrancy boundary.
- Reject cross-domain closures that capture non-Sendable mutable state.
- Reject misused continuations, blocking work on responsive executors, and
  main-actor dumping-ground patterns.
- Prefer explicit actor boundaries, cancellation-aware long-running work,
  intentional task ownership, and minimal actor hopping in hot paths.
- Ensure callback, delegate, Combine, GCD, or Objective-C bridges preserve
  isolation guarantees.

## Immediate rejection patterns

- `DispatchQueue.main.async` used to paper over actor isolation.
- `nonisolated(unsafe)` or `@unchecked Sendable` added just to silence the
  compiler.
- Background code reading or mutating view-model state directly.
- "It seems to work" offered as the concurrency proof.

## Review preferences

- Prefer value types and small focused types.
- Avoid implicit global singletons.
- Keep routing logic deterministic and testable.

## Swift macro rule

- Swift macro code expansion must be built with Swift AST syntax.
