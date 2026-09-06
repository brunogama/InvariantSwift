# AI Coding Agent Rules (Project-Agnostic, Lint-First)

**Purpose**: Ensure any AI agent changes compile cleanly, pass tests, and comply with repo lint/format rules *by design* (not by cleanup at the end).

---

## 1) Non-negotiables (Definition of Done)

Work is **not done** unless all items below are true:

1. **Formatting applied** using the repo formatter (Swift: `swift-format` with the repo `.swift-format`).
2. **Lint clean**: run SwiftLint in *fix* mode, then in *strict* mode, on the changed files.
3. **Zero warnings / zero errors** when building with warnings treated as errors (Swift: `swift build -Xswiftc -warnings-as-errors`).
4. **Tests pass** (Swift packages: `swift test`).
5. **Coverage gate passes** when the repo enforces it (do not lower thresholds or bypass checks).
6. **No bypasses**: never use `--no-verify`, never disable hooks, never “temporarily” commit broken code.

These checks are enforced by pre-commit hooks in many repos (format, lint strict, tests, coverage, warnings-as-errors). If your output would fail them, refactor before finishing.

---

## 2) Treat lint rules as design constraints (budget-based coding)

### 2.1 Hard budgets (SwiftLint)

When writing or extending code, stay comfortably under these limits. If you are trending toward a limit, **split before you cross it**.

- **Line length**: 100 (warning/error)
- **Function parameters**: warn 4, error 6
- **Function body length**: warn 60, error 120
- **Type body length**: warn 300, error 800
- **File length**: warn 400, error 1000
- **Cyclomatic complexity**: warn 10, error 15
- **Nesting**: type level 2, function level 3

Also respect SwiftLint custom rules such as:

- Prefer `struct` over `class` when possible.
- No `print(...)` in production sources (allowed in excluded paths only).

### 2.2 “Refactor triggers” (act early)

Refactor **before** adding more code when any of these are true:

- A function is likely to exceed ~50 lines (you are approaching the 60-line warning).
- Complexity is increasing (multiple `if`/`switch` branches, nested loops, deep guards).
- A file is trending past ~350 lines (you are approaching the 400-line warning).
- A type becomes a “god type” (multiple responsibilities, many private helpers, many stored properties).

---

## 3) Mandatory tactics to stay under budgets

### 3.1 Keep functions small and flat

Preferred shape:

- Early exits (`guard`) instead of deep nesting.
- Extract private helpers when:
  - A block is >10–15 lines,
  - A branch has >1 responsibility,
  - A loop does more than one conceptual thing.
- Split “do everything” functions into:
  - `parse/validate` (pure), `transform` (pure), `perform` (side effects), `persist` (I/O).

### 3.2 Reduce cyclomatic complexity (target ≤ 8)

Use these patterns:

- Replace long `if/else` chains with:
  - Table-driven mappings (`Dictionary` lookup),
  - Small strategy types (protocol + structs),
  - `switch` with extracted case handlers.
- If a `switch` has many cases, create a per-case private function (or type) so the main function stays small.

### 3.3 Keep files/types small

Default split rules:

- **1 type per file** (exceptions: tiny internal helpers tightly coupled to the type).
- If a file has multiple “sections” (protocols, adapters, mappers), split them.
- If a type needs many helpers: move helpers into:
  - `TypeName+Helpers.swift`,
  - nested types,
  - or separate collaborator types.

### 3.4 Parameter count control

If a function wants >4 parameters:

- Introduce a parameter object (`struct`) or a small domain type.
- Prefer passing cohesive objects (e.g., `Request`, `Context`) over parallel primitives.

---

## 4) Process the agent must follow (every change)

1. **Plan**: state what you will change and where (files/types), and how you will keep within the budgets above.
2. **Implement** with budget-first refactoring (do not “just add code”).
3. **Self-review** (required): verify you did not introduce:
   - large functions,
   - large files,
   - added nesting,
   - increased complexity,
   - unnecessary public API surface.
4. **Run the same checks the repo runs** (locally or logically, if tooling is unavailable):
   - `swift-format -i --configuration .swift-format <changed files>`
   - `swiftlint lint --fix --config .swiftlint.yml <changed files>` and then
     `swiftlint lint --strict --config .swiftlint.yml <changed files>`
   - `swift test` (when `Package.swift` exists and Swift files changed)
   - `swift build -Xswiftc -warnings-as-errors` (same condition)
   - Coverage gate script, if present

If any check fails, **fix the code** (do not weaken rules).

---

## 5) Allowed exceptions (rare, documented, minimal)

- Temporary `swiftlint:disable` is allowed only when:
  - you include a one-line justification,
  - you scope it to the smallest region,
  - you add a TODO with a removal plan.
- Never disable: file length, function length, complexity, nesting, warnings-as-errors, or tests, unless the repo owner explicitly changed policy.

---

## 6) Output requirements for AI agents

When producing code changes, the agent must also:

- Avoid unrelated refactors, reformat-only diffs, or renames unless required to meet budgets.
- Keep the public API stable unless the request explicitly requires changes.
- Prefer incremental PR-friendly changes: small commits, small diff, high signal.

---

## 7) Keep this document reusable

This file is intentionally project-agnostic.

Repository-specific details belong in:

- `.swiftlint.yml`, `.swift-format`, CI, `Makefile`, and per-module READMEs.

When this document conflicts with repo tooling, **repo tooling wins**.
