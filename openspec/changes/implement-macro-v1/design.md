# Design: Macro Specification v1.0

## Context

InvariantSwift is a production-grade property-based testing framework for Swift 6.0+. The macro system must:
- Enable property tests to look almost identical to unit tests
- Use pure SwiftSyntax AST builders (NEVER raw string expansion)
- Support Swift Testing integration (`@Test`, `#expect`)
- Generate deterministic, reproducible tests via seed handling
- Provide excellent error messages for debugging

### Stakeholders
- Swift developers writing tests (primary users)
- Framework maintainers
- CI/CD systems (seed replay for reproduction)

### Constraints (from CLAUDE.md)
- Zero warnings policy - no suppressing type errors
- Production code - no `fatalError`, `preconditionFailure` in library
- Macro expansion must use pure swift-syntax AST
- SRP enforced - public types in separate files

## Goals / Non-Goals

### Goals
- Minimal friction for developers: `@Test @Property` should feel natural
- Type-safe generator inference for all primitive and common collection types
- Automatic shrinking derivation for custom types via `@Arbitrary`
- Clear, actionable error messages with shrunk counterexamples
- Seed-based reproducibility for CI failure investigation
- Integration with existing `Gen<T>`, `Shrink<T>`, `Property<T>` types

### Non-Goals
- Generic programming derivation (too complex for v1.0)
- Cross-module generator inference (requires compiler support)
- Runtime generator registration (static generation only)
- Custom operator DSL (use method syntax for clarity)

## Decisions

### Decision 1: Pure SwiftSyntaxBuilder for All Macro Expansion

**What**: All macro expansions MUST use typed SwiftSyntax builders. Raw string interpolation is forbidden.

**Why**:
- Type safety catches malformed syntax at compile time
- Refactoring-safe - IDE can navigate syntax nodes
- Consistent with Swift macro best practices
- Prevents subtle bugs from string escaping issues

**Example - CORRECT**:
```swift
let funcDecl = FunctionDeclSyntax(
    attributes: AttributeListSyntax {
        AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Test")))
    },
    name: .identifier(functionName),
    signature: buildSignature(),
    body: buildBody()
)
```

**Example - FORBIDDEN**:
```swift
// NEVER DO THIS
let code = """
@Test
func \(name)() { ... }
"""
return [DeclSyntax(stringLiteral: code)]
```

**Alternatives Considered**:
- String templates: Rejected - type-unsafe, hard to debug
- Mixed approach: Rejected - inconsistent, maintenance burden

### Decision 2: Generator Inference via Type Mapping Table

**What**: Maintain a static mapping from Swift types to generators with fallback to `T.arbitrary`.

**Why**:
- Predictable behavior - developers know what to expect
- Extensible - custom types via `@Arbitrary`
- Debuggable - clear error when inference fails

**Type Mapping**:
| Swift Type | Generator | Shrink Strategy |
|------------|-----------|-----------------|
| `Int` | `Gen<Int>.int` | Towards 0 |
| `Int8/16/32/64` | `Gen<IntN>.int` | Towards 0 |
| `UInt` variants | `Gen<UInt>.uint` | Towards 0 |
| `Bool` | `Gen<Bool>.bool` | True -> False |
| `Double/Float` | `Gen<Double>.double` | Towards 0.0 |
| `String` | `Gen<String>.string` | Towards "" |
| `Character` | `Gen<Character>.letter` | Towards 'a' |
| `UUID` | `Gen<UUID>.uuid` | None |
| `Date` | `Gen<Date>.date` | Towards epoch |
| `Data` | `Gen<Data>.data` | Towards empty |
| `URL` | `Gen<URL>.url` | None |
| `[T]` | `Gen.array(T.arbitrary)` | Remove elements |
| `Set<T>` | `Gen.set(T.arbitrary)` | Remove elements |
| `[K:V]` | `Gen.dictionary(K.arb, V.arb)` | Remove entries |
| `T?` | `Gen.optional(T.arbitrary)` | Some -> None |
| `Result<S,F>` | `Gen.result(S.arb, F.arb)` | Success first |
| Custom `@Arbitrary` | `T.arbitrary` | `T.shrink` |

**Alternatives Considered**:
- Protocol-based inference: Rejected - requires Generatable conformance
- Runtime reflection: Rejected - not available in Swift

### Decision 3: `@Arbitrary` Generates Both Gen and Shrink

**What**: `@Arbitrary` macro generates extension conforming to `Generatable` with both `arbitrary` and `shrink` static properties.

**Why**:
- Single annotation for complete generation support
- Shrinking is essential for useful counterexamples
- Follows QuickCheck/Hypothesis patterns

**Expansion Pattern**:
```swift
// Input
@Arbitrary
struct User {
    let name: String
    let age: Int
}

// Expanded (via SwiftSyntaxBuilder, NOT strings)
extension User: Generatable {
    public static var arbitrary: Gen<User> {
        Gen.zip(Gen<String>.string, Gen<Int>.int)
            .map { name, age in User(name: name, age: age) }
    }
    
    public static var shrink: Shrink<User> {
        Shrink { user in
            var candidates: [User] = []
            for shrunkName in Gen<String>.string.shrink.shrink(user.name) {
                candidates.append(User(name: shrunkName, age: user.age))
            }
            for shrunkAge in Gen<Int>.int.shrink.shrink(user.age) {
                candidates.append(User(name: user.name, age: shrunkAge))
            }
            return candidates
        }
    }
}
```

### Decision 4: @Gen DSL with Method Syntax

**What**: Use `.method(arg:)` syntax for generator DSL rather than custom operators.

**Why**:
- Familiar Swift method syntax
- Autocomplete support
- Clear error messages
- No operator precedence confusion

**DSL Examples**:
```swift
@Gen(.int)                         // Full range
@Gen(.int(in: 0...100))           // Bounded
@Gen(.int(.positive))             // Positive only
@Gen(.string(length: 1...20))     // With length
@Gen(.array(of: .int, count: 5))  // Fixed count
@Gen(.oneOf([.int, .string]))     // Union
@Gen(.frequency([(3, .a), (1, .b)])) // Weighted
```

### Decision 5: Error Messages with Shrunk Counterexample Format

**What**: Standardize failure output format with original, shrunk, and reproduction info.

**Format**:
```
Property failed after N iterations

Test: functionName(a: Type, b: Type)

Original failing input:
   a = <original value>
   b = <original value>

Shrunk to minimal case (M shrink steps):
   a = <shrunk value>
   b = <shrunk value>  <-- annotation if special

Failure location:
   #expect(...) failed at line L

Tip: <actionable suggestion>

Reproduce with seed:
   @Property(seed: SEED)
```

## Risks / Trade-offs

### Risk 1: Generator Inference Fails for Complex Types
- **Mitigation**: Clear error message directing to `@Arbitrary` or explicit `@Gen`
- **Mitigation**: Comprehensive type mapping for common types

### Risk 2: Shrinking Too Slow for Large Structures
- **Mitigation**: `maxShrinks` configuration parameter
- **Mitigation**: Breadth-first shrinking with early termination

### Risk 3: Macro Expansion Complexity
- **Mitigation**: Modular builder functions (`PropertyTestBodyBuilder`, `GeneratorBuilder`)
- **Mitigation**: Comprehensive unit tests for each builder

### Risk 4: SwiftSyntax Version Compatibility
- **Mitigation**: Pin to swift-syntax 510.0.0+ (Swift 6 compatible)
- **Mitigation**: Minimal API surface usage

## Migration Plan

### Phase 1: Core Macros (Week 1-2)
1. Complete `@Property` macro expansion
2. Implement full generator inference
3. Enhance `@Gen` DSL
4. Integration tests with Swift Testing

### Phase 2: Arbitrary Derivation (Week 3)
1. Implement `@Arbitrary` for structs
2. Implement `@Arbitrary` for enums
3. Shrinking derivation
4. Constraint syntax

### Phase 3: UX Polish (Week 4)
1. Error message formatting
2. `@Label` macro
3. Seed replay mechanism
4. Verbose output mode

### Phase 4: Documentation & Testing (Week 5)
1. DocC documentation
2. Example projects
3. Dogfooding tests

### Rollback
- Each phase is independently testable
- Feature flags can disable incomplete macros
- Existing `@PropertyTest` remains as fallback

## File Structure

```
Sources/InvariantSwiftMacros/
+-- MacroPlugin.swift              # Plugin entry point (exists)
+-- PropertyMacro/
|   +-- PropertyMacro.swift        # @Property implementation (enhance)
|   +-- PropertyMacroConfig.swift  # Config extraction (exists)
|   +-- PropertyTestBodyBuilder.swift # Body building (enhance)
+-- ArbitraryMacro/                # NEW
|   +-- ArbitraryMacro.swift       # @Arbitrary implementation
|   +-- StructAnalyzer.swift       # Analyze struct fields
|   +-- EnumAnalyzer.swift         # Analyze enum cases
|   +-- ShrinkDerivation.swift     # Derive shrinking
+-- GenMacro/
|   +-- GenMacro.swift             # @Gen attribute (exists)
|   +-- GeneratorDSL.swift         # DSL parsing (enhance)
+-- LabelMacro/                    # NEW
|   +-- LabelMacro.swift           # @Label diagnostic
+-- StateMachineMacro/             # NEW (v1.1)
|   +-- StateMachineMacro.swift
|   +-- CommandMacro.swift
+-- Utilities/
    +-- TypeAnalyzer.swift         # Type analysis (exists)
    +-- GeneratorBuilder.swift     # Generator building (exists)
    +-- SyntaxFactory.swift        # Syntax helpers (exists)
    +-- Diagnostics.swift          # Error messages (enhance)
    +-- ParameterExtractor.swift   # Parameter extraction (exists)
    +-- ClosureBuilder.swift       # Closure building (exists)
    +-- FunctionCallBuilder.swift  # Function call building (exists)
    +-- AttributeBuilder.swift     # Attribute building (exists)
```

## Open Questions

1. Should `@Arbitrary` support computed properties or only stored?
2. Should shrinking be configurable per-field in `@Arbitrary`?
3. How to handle recursive types (e.g., tree structures)?
4. Should `@Property` support async test bodies out of the box?
