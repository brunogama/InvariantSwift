# Coding Conventions

**Analysis Date:** 2026-01-23

## Naming Patterns

**Files:**
- Type-focused naming with format `[Type]+[Function].swift` per project guidelines
- Examples: `Generator.swift`, `Property.swift`, `Shrink.swift`, `NumericGenerators.swift`
- Feature modules organize related generators by domain: `CollectionGenerators.swift`, `OptionalResultGenerators.swift`
- Test files follow pattern: `[ComponentName]Tests.swift` (e.g., `PropertyTests.swift`, `GeneratorCoreTests.swift`)

**Functions:**
- Lower camelCase throughout: `generate`, `shrink`, `runProperty`, `checkProperty`, `findMinimal`
- Factory functions use lowercase prefix: `pure`, `oneOf`, `frequency`, `int`, `string`, `array`
- Verb-first imperative style for actions: `sample`, `map`, `flatMap`, `filter`, `zip`
- Test functions use descriptive lower camelCase: `propertyBasicInitialization`, `integerInRange`, `determinism`

**Variables:**
- Lower camelCase consistently: `property`, `generator`, `result`, `counterexample`, `shrinkTree`
- Single-letter variables restricted to mathematical/algorithmic contexts: `n` (numeric), `f` (function), `d` (delta), `c` (count), `s` (string), `t` (type), `p` (position), `u` (unit), `e` (element), `x`, `y`, `z`, `r`, `g`, `b`, `a`, `i`, `j`, `k`
- Loop and collection variables use descriptive names: `inputs`, `candidates`, `values` rather than single letters
- Parameter names in closures: `{ rng, size in ... }`, `{ n in ... }`, `{ value in ... }`

**Types:**
- Upper PascalCase for all types: `Gen<T>`, `Shrink<T>`, `Size`, `Property<T>`, `PropertyResult<T>`
- Protocols in UpperCase: `RandomNumberGenerator`, `Sendable`, `Equatable`, `Codable`
- Error enums: `FailureReason`, `PropertyEvaluation`, `GhostwriterError`, `CorpusDatabaseError`, `ModelTestError`, `SMTSolverError`
- Minimum 3 characters for type names (enforced by swiftlint)
- Maximum 40 characters warning, 50 error (enforced by swiftlint)

**Constants:**
- Static properties for predefined values: `Size.small`, `Size.medium`, `Size.large`
- Enum cases use lower camelCase: `.pass`, `.fail(reason:)`, `.discard(reason:)`, `.predicateFailed`, `.threwError`, `.timedOut`

## Code Style

**Formatting:**
- Tool: `swift-format` (enforced via pre-commit hooks)
- Indentation: 2 spaces (configured in `.swift-format`)
- Line length: 100 characters maximum (configured in `.swift-format` and `.swiftlint.yml`)
- Maximum blank lines: 2
- No trailing whitespace

**Linting:**
- Tool: SwiftLint with strict mode (`swiftlint lint --strict`)
- Configuration file: `.swiftlint.yml` (Google Swift Style Guide based)
- Zero warnings policy: All Swift warnings treated as errors (`-Xswiftc -warnings-as-errors`)
- Pre-commit hooks enforce formatting and linting before commits

**Indentation rules:**
- Function signatures break after opening paren: `func name(\n  param: Type\n)`
- Closure arguments on same line unless complex
- Case statements not indented relative to switch (configured: `indentSwitchCaseLabels: false`)
- Conditional compilation not indented (configured: `indentConditionalCompilationBlocks: false`)

## Import Organization

**Order:**
1. Foundation framework: `import Foundation`
2. Platform-specific frameworks: `import CoreGraphics`, `import InvariantSwiftCore`
3. Internal module imports: `import InvariantSwift`, `@testable import InvariantSwift`
4. Test framework (in tests only): `import Testing`

**Path Aliases:**
- No path aliases currently used in codebase
- Fully qualified imports required for macro-generated code clarity

**Test imports:**
```swift
import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift
```

## Error Handling

**Patterns:**
- Result enums with associated values: `case fail(reason: String?)`, `case discard(reason: String?)`
- Swift 5+ `Error` protocol adoption with `Sendable` conformance for async:
  ```swift
  public enum GhostwriterError: Error, Sendable, CustomStringConvertible {
    case invalidConfig(String)
    case generationFailed(String)
  }
  ```
- No `fatalError` or `preconditionFailure` in library code (production safety requirement)
- Errors with descriptive associated values for context
- Custom `CustomStringConvertible` conformance for human-readable error messages

**Example error handling:**
```swift
switch result {
case .success: break
case .failure(let counterexample, _, _, _, _):
  Issue.record("Property failed with: \(counterexample)")
case .gaveUp:
  Issue.record("Property test gave up unexpectedly")
}
```

## Logging

**Framework:** No structured logging framework (no dependency on OSLog or similar)

**Patterns:**
- Logging via `Issue.record(_:)` in tests (Swift Testing integration)
- `CustomStringConvertible` for readable error output
- No `print()` statements in production code (SwiftLint rule enforces in `Sources/`)
- Debug output in tests acceptable

**Usage:**
```swift
Issue.record("Property failed with: \(counterexample)")
Issue.record("Generator should produce parseable strings, got: \(value)")
```

## Comments

**When to Comment:**
- Algorithm explanation for non-obvious shrinking strategies
- Mathematical concepts or references (e.g., "coalgebraic shrinking" with academic citation)
- Complex RNG state management and seed determinism requirements
- Performance characteristics or budget constraints

**JSDoc/TSDoc:**
- Triple-slash documentation format required for all public APIs: `///`
- Single-line summary on first line
- Followed by blank line
- Detailed explanation in paragraphs
- Parameters documented: `- Parameters:`
- Return values documented: `- Returns:`
- Examples for complex types: `- Example:`
- Related types noted: `- See Also:`
- Severity: All public declarations must have documentation (swift-format rule enforced)

**Example documentation pattern:**
```swift
/// Classifies how a property test failed.
///
/// `FailureReason` distinguishes between different failure modes, enabling better
/// diagnostics and targeted fixes:
/// - `.predicateFailed`: The property's predicate returned `false`
/// - `.threwError`: The predicate threw an error during evaluation
/// - `.timedOut`: The test exceeded the configured timeout
///
/// - Parameters:
///   - seconds: The timeout duration that was exceeded
///
/// - Returns: String description of the failure reason
///
/// - See Also: ``PropertyResult``, ``PropertyConfig``
```

## Function Design

**Size:**
- Recommended: 20-60 lines per function
- Warning level: 60 lines (swiftlint `function_body_length: warning: 60`)
- Error level: 120 lines (swiftlint `function_body_length: error: 120`)
- Typical library functions: 30-45 lines

**Parameters:**
- Maximum 4 parameters before warning (swiftlint `function_parameter_count: warning: 4`)
- Maximum 6 parameters before error (swiftlint `function_parameter_count: error: 6`)
- Use trailing closures for final parameter:
  ```swift
  func generate(_ fn: @escaping (inout RNG, Size) -> T) { ... }
  // Called as: gen.generate { rng, size in ... }
  ```
- Avoid default parameter values for behavioral differentiation (explicit call site clarification preferred)

**Return Values:**
- Explicit return type always specified (no implicit return type inference from closure)
- Void used explicitly: `func sample() -> Void`
- Tuple returns for multiple values: `-> (value: T, shrunk: T)`
- Optional returns documented: `-> T?` with explanation when nil

**Async/Throws:**
- Async functions use `async` keyword: `func runProperty(_ property: Property) async`
- Throwing functions use `throws` keyword: `func run(property: Property) throws`
- Combined: `async throws` for test runners
- Error handling with do-catch for known error types

## Module Design

**Exports:**
- Public API re-exported in `FunctionalTesting.swift` (main entry point)
- Public types at module scope: `Gen<T>`, `Property<T>`, `Shrink<T>`, `Size`, `Seed`
- Internal types prefixed with underscore for clarity: `_ShrinkTree`, `_PropertyRunner`
- Actor types use `actor` keyword for concurrent operations: `actor ElitePool<T>`

**Barrel Files:**
- `FunctionalTesting.swift` consolidates public API exports:
  ```swift
  public typealias Gen = InvariantSwift.Gen
  public typealias Property = InvariantSwift.Property
  public typealias Shrink = InvariantSwift.Shrink
  ```
- Reduces consumer import complexity: `import InvariantSwift` instead of `import InvariantSwift.Core`

**File Organization:**
- MARK comments organize logical sections within files
- Sections follow pattern: `// MARK: - [Section Name]`
- Order: Type definitions → Initializers → Public functions → Implementation helpers → Extensions

**Example file structure:**
```swift
import Foundation

// MARK: - Type Definition

public struct MyType {
  // Properties
  public let value: Int

  // MARK: - Initialization

  public init(value: Int) { ... }

  // MARK: - Public API

  public func publicMethod() { ... }

  // MARK: - Implementation

  private func helper() { ... }
}
```

## Strict Concurrency & Sendable

**Pattern:**
- All types use `Sendable` conformance for async compatibility
- `@unchecked Sendable` for types with closure captures (RNG closures inherently mutable):
  ```swift
  public struct Gen<T>: @unchecked Sendable {
    public let generate: (inout any RandomNumberGenerator, Size) -> T
    public let shrink: Shrink<T>
  }
  ```
- Error enums explicitly conform: `enum MyError: Error, Sendable`
- Actors for concurrent state: `public actor ElitePool<T: Sendable>`

## Consistency Rules

**MUST:**
- Compile with zero warnings: `swift build -Xswiftc -warnings-as-errors`
- Format with swift-format before commit
- Lint with swiftlint strict: `swiftlint lint --strict`
- Document all public declarations with `///` triple-slash comments
- Use `guard let` instead of force unwrap (`!`)
- Make illegal states unrepresentable (no `.invalid` cases if invalid state is impossible)

**SHOULD:**
- Keep lines under 100 characters
- Use type aliases for complex generics: `typealias StringProperty = Property<String>`
- Use shorthand property syntax: `init(value: Int) { self.value = value }` → `init(value: Int) { self.value }`
- Prefer `if let` over `switch` for single optional unwrapping
- Use implicit returns in short closures

**SHOULD NOT:**
- Use `any` type (requires explicit justification if necessary)
- Add TODO/FIXME comments without corresponding issue tracking
- Use string interpolation for macro code generation (use SwiftSyntax AST builders)
- Change linter rules to pass checks (fix the code instead)

---

*Convention analysis: 2026-01-23*
