# ADR-0001: Characterization macro uses one runtime seam

## Status

Accepted.

## Context

`@CharacterizationTest` is declared in `InvariantSwiftMacroAPI`, while characterization execution lives in `InvariantSwiftTesting`. Making the macro declaration mention `CharacterizationInput` would reverse that intentional package direction. Keeping `inputs: Any` would preserve the split but discard useful collection, Codable, and Sendable checking.

Macro implementations receive source syntax rather than resolved argument types. They can diagnose attachment shape, but they cannot reliably determine protocol conformances or prove that a collection element matches the annotated function parameter.

Generated peers also need names that do not collide when overloaded functions are annotated. Finally, emitted code is a source-compatibility commitment even though macro expansions do not add ABI.

## Decision

Declare the macro with a generic collection argument:

```swift
@attached(peer)
public macro CharacterizationTest<C>(
  fixture: String,
  inputs: C
) = #externalMacro(
  module: "InvariantSwiftMacros",
  type: "CharacterizationTestMacro"
) where C: Collection & Sendable, C.Element: Codable & Sendable
```

`InvariantSwiftMacroAPI` does not import or depend on `InvariantSwiftTesting`. The generated peer makes exactly one qualified runtime call to `InvariantSwiftTesting.CharacterizationTestRuntime.run`. That public entry converts the generic collection and delegates to the existing public manual `characterize` facade. Generated code does not construct `CharacterizationConfiguration` or call a global `characterize` function directly.

The macro diagnoses non-function attachment at the attribute and wrong function arity at the parameter clause. The compiler owns collection and element constraints, missing labels, carrier/function input mismatches, and output constraints.

Peer names use `MacroExpansionContext.makeUniqueName` with a stable discriminator derived from the complete function signature so overloaded declarations do not collide.

## Consequences

Typed nonempty collections remain supported. Empty collections require an explicit element type. Scalars and non-Codable or non-Sendable elements fail during macro argument type checking. Carrier/function and output mismatches fail while type-checking the generated runtime call.

`CharacterizationTestRuntime.run` is the sole public generated-code compatibility seam. `CharacterizationConfiguration` and both `characterize` overloads remain unchanged as the manual API and composition roots. No shared carrier module or MacroAPI-to-Testing dependency is introduced.
