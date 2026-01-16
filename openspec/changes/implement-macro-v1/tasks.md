# Tasks: Implement Macro Specification v1.0

## 1. Phase 1: Core Macros

### 1.1 Complete @Property Macro Expansion
- [x] 1.1.1 Enhance `PropertyMacro.swift` to generate proper Swift Testing integration
- [x] 1.1.2 Implement `buildTransformedFunction` with full `@Test(arguments:)` pattern
- [x] 1.1.3 Handle `#expect` passthrough correctly in expanded body
- [x] 1.1.4 Generate proper result handling (`success`, `failure`, `gaveUp` cases)
- [x] 1.1.5 Add seed parameter forwarding to `PropertyConfig`

### 1.2 Generator Inference System
- [x] 1.2.1 Create `GeneratorInference.swift` with complete type mapping table
- [x] 1.2.2 Handle `Optional<T>` inference with proper unwrapping
- [x] 1.2.3 Handle `Array<T>` and `[T]` syntax equivalence
- [x] 1.2.4 Handle `Set<T>` inference
- [x] 1.2.5 Handle `Dictionary<K,V>` and `[K:V]` syntax equivalence
- [x] 1.2.6 Handle `Result<Success, Failure>` inference
- [x] 1.2.7 Fallback to `T.arbitrary` for custom types

### 1.3 Enhance @Gen DSL
- [x] 1.3.1 Complete `GeneratorDSL.swift` with all documented patterns
- [x] 1.3.2 Implement `.int(in: Range)` bounded generation
- [x] 1.3.3 Implement `.int(.positive)`, `.int(.negative)`, `.int(.nonZero)`
- [x] 1.3.4 Implement `.string(length: Range)` 
- [x] 1.3.5 Implement `.string(.ascii)`, `.string(.alphanumeric)`, `.string(.email)`
- [x] 1.3.6 Implement `.array(of:count:)` with fixed and range counts
- [x] 1.3.7 Implement `.oneOf([...])` union generator
- [x] 1.3.8 Implement `.frequency([...])` weighted selection
- [x] 1.3.9 Implement `.custom { rng, size in ... }` escape hatch

### 1.4 Swift Testing Integration
- [x] 1.4.1 Verify `@Test` attribute generation compatibility
- [x] 1.4.2 Ensure `#expect` macros pass through correctly
- [x] 1.4.3 Test `Issue.record()` integration for failures
- [x] 1.4.4 Write integration tests with Swift Testing framework

### 1.5 Phase 1 Validation
- [x] 1.5.1 All existing `PropertyMacroTests` pass
- [x] 1.5.2 New tests for generator inference edge cases
- [x] 1.5.3 Build passes with zero warnings
- [ ] 1.5.4 DocC comments on all public APIs

---

## 2. Phase 2: Arbitrary Derivation

### 2.1 Create ArbitraryMacro Infrastructure
- [x] 2.1.1 Create `Sources/InvariantSwiftMacros/ArbitraryMacro/` directory
- [x] 2.1.2 Implement `ArbitraryMacro.swift` as `MemberMacro` + `ExtensionMacro`
- [x] 2.1.3 Register in `MacroPlugin.swift`
- [x] 2.1.4 Add macro declaration in `Sources/InvariantSwift/Macros/`

### 2.2 Struct Analysis and Generation
- [x] 2.2.1 Implement `StructAnalyzer.swift` to extract stored properties
- [x] 2.2.2 Generate `Gen.zip(...)` for all fields
- [x] 2.2.3 Generate `.map { ... }` to construct instance
- [x] 2.2.4 Handle memberwise initializer pattern
- [x] 2.2.5 Handle default values in properties

### 2.3 Enum Analysis and Generation
- [x] 2.3.1 Implement `EnumAnalyzer.swift` to extract cases
- [x] 2.3.2 Handle cases without associated values (`Gen.pure(.case)`)
- [x] 2.3.3 Handle cases with associated values (generate each)
- [x] 2.3.4 Generate `Gen.oneOf([...])` for case selection
- [x] 2.3.5 Handle labeled vs unlabeled associated values

### 2.4 Shrinking Derivation
- [x] 2.4.1 Implement `ShrinkDerivation.swift`
- [x] 2.4.2 Generate shrink for each field independently
- [x] 2.4.3 Combine field shrinks into composite shrink
- [x] 2.4.4 Handle `ShrinkStrategy` configuration (`.automatic`, `.towards`, `.none`)

### 2.5 Constraint Syntax
- [ ] 2.5.1 Parse `constraints: ["field": "expression"]` attribute argument
- [ ] 2.5.2 Apply constraints to field generators
- [ ] 2.5.3 Validate constraint expressions at compile time
- [ ] 2.5.4 Document constraint syntax in DocC

### 2.6 Phase 2 Validation
- [x] 2.6.1 Tests for `@Arbitrary` on simple structs
- [x] 2.6.2 Tests for `@Arbitrary` on nested structs
- [x] 2.6.3 Tests for `@Arbitrary` on enums with associated values
- [ ] 2.6.4 Tests for constraint application
- [x] 2.6.5 Build passes with zero warnings

---

## 3. Phase 3: UX Polish

### 3.1 Error Message Formatting
- [ ] 3.1.1 Implement `PropertyFailureFormatter` for human-readable output
- [ ] 3.1.2 Format original failing input clearly
- [ ] 3.1.3 Format shrunk counterexample with shrink count
- [ ] 3.1.4 Include source location of failed expectation
- [ ] 3.1.5 Add actionable tips based on failure type
- [x] 3.1.6 Include reproduction seed in output

### 3.2 @Label Macro
- [x] 3.2.1 Create `Sources/InvariantSwiftMacros/LabelMacro/` directory
- [x] 3.2.2 Implement `LabelMacro.swift` as parameter attribute
- [ ] 3.2.3 Extract label from `@Property` expansion
- [ ] 3.2.4 Include labels in failure messages
- [x] 3.2.5 Register in `MacroPlugin.swift`

### 3.3 Seed Replay Mechanism
- [x] 3.3.1 Ensure `seed` parameter in `@Property` creates deterministic RNG
- [ ] 3.3.2 Output seed in all failure messages
- [ ] 3.3.3 Verify same seed produces identical test sequence
- [ ] 3.3.4 Document seed usage in DocC

### 3.4 Verbose Mode
- [ ] 3.4.1 Add `verbose: Bool` parameter to `@Property`
- [ ] 3.4.2 Log each generated value when verbose
- [ ] 3.4.3 Log shrinking steps when verbose
- [ ] 3.4.4 Respect verbose in CI vs local contexts

### 3.5 Phase 3 Validation
- [ ] 3.5.1 Visual inspection of error message format
- [ ] 3.5.2 Tests for seed determinism
- [ ] 3.5.3 Tests for verbose output
- [x] 3.5.4 Build passes with zero warnings

---

## 4. Phase 4: State Machine (v1.1 Spec Only)

### 4.1 @StateMachine Macro Specification
- [ ] 4.1.1 Document `@StateMachine` syntax in spec
- [ ] 4.1.2 Document `@Command` syntax in spec
- [ ] 4.1.3 Document `@Commands(model:count:)` generator pattern
- [ ] 4.1.4 Create placeholder files (not implemented)

### 4.2 State Machine Tests (Placeholder)
- [ ] 4.2.1 Create example state machine test (manual, not macro)
- [ ] 4.2.2 Document intended expansion pattern

---

## 5. Documentation & Testing

### 5.1 DocC Documentation
- [ ] 5.1.1 Document `@Property` macro usage and expansion
- [ ] 5.1.2 Document `@Arbitrary` macro usage and expansion
- [ ] 5.1.3 Document `@Gen` DSL patterns
- [ ] 5.1.4 Document `@Label` usage
- [ ] 5.1.5 Document generator inference rules
- [ ] 5.1.6 Document error message format
- [ ] 5.1.7 Create tutorial: "Your First Property Test"

### 5.2 Example Projects
- [ ] 5.2.1 Create `Examples/BasicExamples/` with simple property tests
- [ ] 5.2.2 Create `Examples/IntermediateExamples/` with @Arbitrary
- [ ] 5.2.3 Create `Examples/AdvancedExamples/` with @Gen DSL

### 5.3 Dogfooding
- [ ] 5.3.1 Write property tests for `Gen<T>` functor laws
- [ ] 5.3.2 Write property tests for `Gen<T>` monad laws
- [ ] 5.3.3 Write property tests for shrinking correctness
- [ ] 5.3.4 Ensure all tests pass with `swift test | xcbeautify`

### 5.4 Final Validation
- [ ] 5.4.1 All tests pass
- [ ] 5.4.2 Zero compiler warnings
- [ ] 5.4.3 Documentation renders correctly
- [ ] 5.4.4 Examples compile and run
