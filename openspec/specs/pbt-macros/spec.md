# Macros Specification

## Purpose

Define the macro surface (@PropertyTest, @Arbitrary, @Gen, @Reproduce, etc.) and constraints for predictable codegen.

---

## Requirements

### Requirement: Macro Expansion Is Transparent

Macro expansions MUST produce debuggable code that maps clearly to user-written tests.

#### Scenario: Expanded test includes a single runner call

- GIVEN a function annotated with `@PropertyTest`
- WHEN the macro expands
- THEN the expanded code contains exactly one call into the core runner

### Requirement: Macro Expansion Is Stable

Under the same toolchain, macro expansion MUST be deterministic.

#### Scenario: Expansion yields identical source across runs

- GIVEN identical input source
- WHEN expanding twice
- THEN the expanded source is identical

### Requirement: Macros Respect Core Semantics

Macros MUST emit code that uses `Property`, `PropertyRunner`, and related core APIs correctly.

#### Scenario: Generated code honors assumptions

- GIVEN a `@PropertyTest` with assumption in DSL
- WHEN the macro expands
- THEN the emitted code uses `Property(assumption:predicate:)`

---

## Macro Catalog

| Macro | Purpose | Status |
|-------|---------|--------|
| `@PropertyTest` | Generate property test from function | Active |
| `@Arbitrary` | Derive `Gen<T>` for types | Active |
| `@Gen` | Inline generator construction | Active |
| `@Reproduce` | Re-run with specific seed | Active |
| `@LawChecked` | Verify algebraic laws | Active |
| `@StateMachine` | Model-based testing DSL | Active |
| `@BusinessRule` | Rule-based test generation | Active |
| `@DeriveGen` | Generate arbitrary instances | Active |

---

## Known Limitations

1. **Swift compiler version coupling**: Macros require matching swift-syntax version
2. **Async predicate expansion**: Some macro variants may not fully support async
3. **Error messages**: Macro diagnostics may be cryptic on syntax errors
