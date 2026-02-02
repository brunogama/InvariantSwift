# Phase 4.7: Codebase Cleanup (INSERTED)

**Status:** Not planned yet
**Created:** 2026-01-24
**Depends on:** Phase 4.6 (Advanced Property Testing Features)

## Goal

Clean up the codebase by removing all SwiftLint disable markers, properly refactoring files to respect linting rules and RULES.md budgets, fixing all compiler warnings, fixing all failing tests, and re-enabling all disabled test files.

## Description

This phase addresses technical debt accumulated during rapid feature development in phases 4.1-4.6. The codebase currently contains:
- SwiftLint disable markers scattered throughout files
- Compiler warnings
- Failing tests
- Tests disabled via `.swift.disabled` file extension (potential API breakage)

The cleanup will:
1. Remove all `swiftlint:disable` markers
2. Properly refactor files to comply with SwiftLint rules
3. Respect RULES.md budgets (line length, function body, file length, cyclomatic complexity)
4. Fix all Swift compiler warnings
5. Fix all failing tests
6. Re-enable and fix all `.swift.disabled` test files
7. Ensure `swift build -Xswiftc -warnings-as-errors` passes
8. Ensure `swiftlint lint --strict` passes
9. Ensure `swift test` passes with 100% test success rate

## Priority

**P0 (URGENT)** - Technical debt blocks release quality

## Next Steps

Run `/gsd:plan-phase 4.7` to break down this phase into executable plans.

