# Implement Macro Specification v1.0

## Why

The existing macro infrastructure (`@PropertyTest`, `@Property`, `@Gen`, `@DeriveGen`) is partially implemented but incomplete for production v1.0 release. Developers familiar with `@Test` should be able to write property tests with minimal friction - "If you know `@Test`, you know `@Property`".

Current gaps:
- `@Property` macro skeleton exists but lacks complete generator inference and expansion
- `@Arbitrary` macro for custom type derivation is not implemented
- `@Gen` parameter macro exists but DSL is incomplete
- Error messages are basic, not user-friendly
- Seed replay mechanism incomplete
- No `@Label` for diagnostic enhancement

## What Changes

### Phase 1: Core Macros (v1.0 must-have)
- **ADDED** Complete `@Property` macro with full generator inference
- **MODIFIED** `@Gen` parameter macro DSL expansion
- **MODIFIED** Generator inference rules for all primitive and collection types
- **ADDED** Integration with Swift Testing `#expect`

### Phase 2: Arbitrary Derivation (v1.0 must-have)
- **ADDED** `@Arbitrary` macro for structs
- **ADDED** `@Arbitrary` macro for enums with associated values
- **ADDED** Automatic shrinking derivation
- **ADDED** Constraint syntax for field validation

### Phase 3: UX Polish (v1.0 should-have)
- **ADDED** Human-friendly error message formatting
- **ADDED** `@Label` macro for diagnostic enhancement
- **MODIFIED** Seed replay mechanism
- **ADDED** Verbose mode output

### Phase 4: State Machine (v1.1 target, spec now)
- **ADDED** `@StateMachine` macro specification
- **ADDED** `@Command` macro specification

## Impact

- Affected specs: property-macro, arbitrary-macro, gen-macro, label-macro, state-machine-macro
- Affected code:
  - `Sources/InvariantSwiftMacros/PropertyMacro/`
  - `Sources/InvariantSwiftMacros/GenMacro/`
  - `Sources/InvariantSwiftMacros/Utilities/`
  - New: `Sources/InvariantSwiftMacros/ArbitraryMacro/`
  - New: `Sources/InvariantSwiftMacros/LabelMacro/`
  - New: `Sources/InvariantSwiftMacros/StateMachineMacro/` (v1.1)
  - `Sources/InvariantSwift/Macros/` (declarations)
  - `Tests/InvariantSwiftMacroTests/`

## Design Decisions (Confirmed)

1. **Naming**: `@Property` (shorter, cleaner)
2. **Generator DSL**: `.int(in: 0...100)` style (acceptable)
3. **Shrinking**: Automatic by default
4. **State machine**: Deferred to v1.1 (spec documented now)
