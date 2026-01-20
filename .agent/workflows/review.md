---
description: Perform comprehensive code review against InvariantSwift conventions
---

# Code Review Workflow

Perform a comprehensive code review of recent changes:

## 1. Code Conventions
Check code follows our Swift conventions from CLAUDE.md:
- Swift 6 strict concurrency (`Sendable` conformance)
- 2-space indentation
- 100 character line limit
- No force unwrap (`!`)
- No `fatalError` in library code

## 2. Macro Patterns
If editing macros:
- Uses SwiftSyntax AST builders (NOT string interpolation)
- Preserves trivia for proper formatting
- Returns empty array with diagnostic on error (never throws)

## 3. Error Handling
Verify proper error handling:
- Uses `guard let` instead of force unwrap
- Errors are propagated appropriately
- No silent failures

## 4. Test Coverage
Verify test coverage:
- New functionality has corresponding tests
- Tests use Swift Testing (`@Test`, `@Suite`)
- Uses deterministic seeds for reproducibility

## 5. Documentation
Check documentation:
- Public APIs have DocC comments
- Complex logic is explained
- README/CHANGELOG updated if user-facing

## 6. Security
Check for vulnerabilities:
- No secrets or API keys committed
- No PII in test fixtures
- Input validation on public APIs

## 7. Performance
Consider performance implications:
- Shrink functions terminate (return `[]` eventually)
- Size parameter passed through for recursive generators
- No unnecessary allocations in hot paths

Provide specific, actionable feedback with file:line references.
