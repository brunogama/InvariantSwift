# Copilot review guidance

Use the path-specific instruction files in `.github/instructions/` for pull
request reviews that touch `Sources/**/*.swift` or `Tests/**/*.swift`.

Repository-wide review baseline:

- Treat `RULES.md` as mandatory: formatting, SwiftLint strict, zero warnings,
  and passing tests.
- Assume Swift 6 language mode and Complete strict concurrency checking on every
  active target, including tests.
- Reject changes that break target layering, introduce unsafe concurrency, or
  change behavior without matching tests unless the PR is explicitly doc-only.
- Prefer value types, avoid implicit global singletons, and keep routing logic
  deterministic and testable.
