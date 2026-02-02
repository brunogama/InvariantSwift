# Phase 7: @Roundtrip — Encode/Decode Testing - Research

**Researched:** 2026-01-23
**Domain:** Swift Macros, Codable Testing, Property-Based Roundtrip Verification
**Confidence:** HIGH

## Summary

Phase 7 implements a `@Roundtrip` macro to automate property-based testing for serialization roundtrips (Codable encode/decode cycles) and hash stability (Hashable consistency). This research identifies the standard Swift approach to roundtrip testing, existing patterns within InvariantSwift's Ghostwriter feature, and the macro architecture needed to implement `@Roundtrip` as a peer macro generating property tests.

**Key findings:**
- InvariantSwift already implements Codable roundtrip testing via Ghostwriter (generates test code with `@PropertyTest`)
- Standard Swift pattern: `encode(x) -> Data -> decode -> x'` then verify `x == x'`
- Hash stability testing requires `SWIFT_DETERMINISTIC_HASHING=1` for reproducibility
- Macro implementation follows `@attached(peer)` pattern like existing `@PropertyTest` macro
- Protocol conformance checking (Codable/Equatable/Hashable) must use static analysis of inheritance clauses

**Primary recommendation:** Build `@Roundtrip` as a peer macro using the existing PropertyMacro.swift patterns, reuse Ghostwriter's test generation logic for Codable roundtrips, and add new hash stability verification following QuickCheck's property-based testing philosophy.

## Standard Stack

The established libraries/tools for Codable roundtrip testing in Swift:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation | Built-in | JSONEncoder, PropertyListEncoder, Codable protocol | Apple's official encoding/decoding system |
| SwiftSyntax | 600.0.1 | Macro AST manipulation | Official Swift macro implementation framework |
| Swift Testing | Built-in | @Test attribute, #expect assertions | Modern Swift testing framework (WWDC 2024) |
| SwiftSyntaxBuilder | 600.0.1 | AST construction via builders | Type-safe AST generation for macros |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-custom-dump | 1.3.3+ | Pretty-printing test failures | Already used in InvariantSwift for diagnostics |
| SwiftSyntaxMacros | 600.0.1 | PeerMacro, MemberMacro protocols | Macro role implementations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @attached(peer) | @attached(member) | Member macro would add methods inside type vs alongside; peer is correct for test generation |
| JSONEncoder default | Custom encoder config | Custom config adds complexity; default is sufficient for most cases |
| Property-based testing | Example-based testing | Example-based can't verify all edge cases; property-based is required for completeness |

**Installation:**
```bash
# Already in Package.swift
.product(name: "SwiftSyntax", package: "swift-syntax"),
.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
```

## Architecture Patterns

### Recommended Project Structure
```
Sources/InvariantSwiftMacros/
├── RoundtripMacro.swift         # New: @Roundtrip implementation
├── Utilities/
│   ├── ProtocolConformanceChecker.swift  # New: Check Codable/Equatable/Hashable
│   ├── ASTBuilders.swift        # Existing: Reuse for test generation
│   └── TypeExtraction.swift     # Existing: Reuse for type analysis
Sources/InvariantSwift/Macros/
└── RoundtripMacroDeclaration.swift  # New: Public macro declaration
```

### Pattern 1: Peer Macro for Test Generation
**What:** Generate a property test function alongside the annotated type
**When to use:** When you need to create test code without modifying the original type
**Example:**
```swift
// Source: Existing PropertyMacro.swift (lines 7-48)
public struct RoundtripMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Extract type from declaration
    // Verify protocol conformances
    // Build test function using ASTBuilders
    // Return generated test declaration
  }
}
```

### Pattern 2: Codable Roundtrip Test Generation
**What:** Generate property test verifying `decode(encode(x)) == x`
**When to use:** For types conforming to `Codable` and `Equatable`
**Example:**
```swift
// Source: Ghostwriter TestGenerator.swift (lines 140-156)
// Adapted for macro AST generation
let testFunction = FunctionDeclSyntax(
  attributes: AttributeListSyntax {
    AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier("Test")))
  },
  modifiers: DeclModifierListSyntax {
    DeclModifierSyntax(name: .keyword(.static))
  },
  funcKeyword: .keyword(.func),
  name: .identifier("test\(typeName)_roundtrip"),
  signature: buildThrowsSignature(),
  body: CodeBlockSyntax {
    // let encoder = JSONEncoder()
    // let decoder = JSONDecoder()
    // let property = Property(generator: Gen<T>.arbitrary) { value in
    //   let encoded = try encoder.encode(value)
    //   let decoded = try decoder.decode(T.self, from: encoded)
    //   return decoded == value
    // }
    // try checkProperty(property, iterations: config.iterations)
  }
)
```

### Pattern 3: Protocol Conformance Checking
**What:** Verify type conforms to required protocols (Codable, Equatable, Hashable)
**When to use:** Before generating roundtrip tests to ensure type supports required operations
**Example:**
```swift
// Source: Swift Forums discussion on conformance checking
// https://forums.swift.org/t/check-if-type-conforms-to-a-protocol/65425
func checkConformance(
  _ declaration: some DeclGroupSyntax,
  conformsTo protocolName: String
) -> Bool {
  guard let inheritanceClause = declaration.inheritanceClause else {
    return false
  }

  return inheritanceClause.inheritedTypes.contains { inherited in
    inherited.type.as(IdentifierTypeSyntax.self)?.name.text == protocolName
  }
}
```

### Pattern 4: Encoder/Decoder Strategy Enum
**What:** Type-safe representation of encoding strategies (.json, .plist, .custom)
**When to use:** Parsing macro arguments for encoding strategy selection
**Example:**
```swift
enum EncodingStrategy {
  case json
  case propertyList
  case custom(encoder: ExprSyntax, decoder: ExprSyntax)

  static func parse(from expr: ExprSyntax) -> Self {
    if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
      switch memberAccess.declName.baseName.text {
      case "json": return .json
      case "plist": return .propertyList
      default: break
      }
    }
    // Parse .custom(encoder: X, decoder: Y)
    return .json  // default
  }
}
```

### Anti-Patterns to Avoid
- **String interpolation for AST generation:** Never use `"""triple quotes"""` to build code; always use SwiftSyntax builders (see Sources/InvariantSwiftMacros/CLAUDE.md)
- **Runtime protocol checking:** SwiftSyntax works on syntax, not types; conformance checking must analyze inheritance clauses, not query type system
- **Force-unwrapping in library code:** Macros should emit diagnostics and return `[]` on errors, never crash (see PropertyMacro.swift error handling)
- **Ignoring trivia:** Preserve leading/trailing trivia for proper formatting in generated code

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST construction | String concatenation | SwiftSyntax builders (`FunctionDeclSyntax`, `CodeBlockSyntax`) | Trivia preservation, type safety, syntax validation |
| Protocol conformance checking | Type reflection at runtime | Static analysis of `inheritanceClause` | Macros operate on syntax trees, not runtime types |
| Test name generation | Manual string building | `ASTBuilders.makeFunction()` utility | Existing project pattern, consistent naming |
| Encoder/decoder instantiation | Hardcoded expressions | Reuse Ghostwriter's pattern (lines 147-152) | Already tested, handles config properly |
| Property test boilerplate | Generate from scratch | Follow PropertyMacro.swift structure | 18+ existing macros use this pattern |
| Diagnostic emission | Custom error messages | `MacroContext.error()` / `context.diagnose()` | Consistent error reporting, IDE integration |

**Key insight:** InvariantSwift already has 90% of the infrastructure needed. Ghostwriter generates Codable roundtrip tests as strings; this phase moves that logic into a macro for better ergonomics and compile-time safety.

## Common Pitfalls

### Pitfall 1: Hash Value Non-Determinism
**What goes wrong:** Hash values are seeded with random value at program launch, making `hashValue` tests flaky
**Why it happens:** Swift 4.2+ uses SipHash with random seeding for security (prevents hash collision attacks)
**How to avoid:** Document that hash stability tests verify `a.hashValue == a.hashValue` (same instance, same run), not cross-run stability. For deterministic testing, set `SWIFT_DETERMINISTIC_HASHING=1` environment variable.
**Warning signs:** Test passes locally but fails in CI; hash values differ between test runs

**Sources:**
- [Swift 4.2 improves Hashable with a new Hasher struct – Hacking with Swift](https://www.hackingwithswift.com/articles/115/swift-4-2-improves-hashable-with-a-new-hasher-struct)
- [Simpler, more secure hashing – available from Swift 4.2](https://www.hackingwithswift.com/swift/4.2/hashable)

### Pitfall 2: Macro Conformance Checking Limitations
**What goes wrong:** Cannot reliably detect protocol conformance for types defined in other modules or with conditional conformances
**Why it happens:** SwiftSyntax operates on syntax trees, not semantic type information; extension conformances may be in different files
**How to avoid:** Check `inheritanceClause` on the declaration being annotated. Emit diagnostic if missing required conformances rather than silently generating invalid code. Generate tests that will fail at compile-time if conformance is actually missing (e.g., `try encoder.encode(value)` will fail if not Codable).
**Warning signs:** Macro expansion succeeds but generated code doesn't compile; "Type 'X' does not conform to protocol 'Codable'" errors

**Sources:**
- [Check if type conforms to a protocol - Swift Forums](https://forums.swift.org/t/check-if-type-conforms-to-a-protocol/65425)
- [Is it possible to check in a Macro expansion if all stored properties conform to a protocol - Swift Forums](https://forums.swift.org/t/is-it-possible-to-check-in-a-marco-expansion-if-all-stored-properties-the-type-conform-to-a-protocol/65939)

### Pitfall 3: Equatable vs Structural Equality
**What goes wrong:** Codable roundtrip test requires `Equatable`, but some types implement custom equality that may not match field-by-field comparison
**Why it happens:** Developers override `==` to ignore certain fields (e.g., timestamps, IDs) or use fuzzy equality (e.g., floating-point tolerance)
**How to avoid:** Document that `@Roundtrip(via: .json)` requires `Equatable` conformance and uses `==` for verification. For types with custom equality, roundtrip may pass even if some fields don't survive encoding. Consider providing `@Roundtrip(strict: true)` option that uses structural comparison.
**Warning signs:** Roundtrip test passes but manual inspection shows fields lost during encoding; false negatives in testing

**Sources:**
- [Testing custom Codable implementations | Swift by Sundell](https://www.swiftbysundell.com/tips/testing-custom-codable-implementations/)
- [Swift Codable Testing · paul-samuels.com](https://paul-samuels.com/blog/2019/01/07/swift-codable-testing/)

### Pitfall 4: Encoder Configuration Ignored
**What goes wrong:** JSONEncoder/PropertyListEncoder have default configurations that may not match production usage (date encoding, key strategies, etc.)
**Why it happens:** Generated test uses default encoder settings, but app uses custom configuration
**How to avoid:** Provide `.custom(encoder: MyEncoder(), decoder: MyDecoder())` strategy for full control. Document that `.json` and `.plist` use default configurations. Consider adding `encoderSetup: (JSONEncoder) -> Void` closure parameter for common customizations.
**Warning signs:** Tests pass but production encoding fails; date formats differ between test and runtime

**Sources:**
- [Encoding and decoding JSON in Swift](https://www.ralfebert.com/ios/json-handling-in-swift/)
- Swift Evolution SE-0167: [swift-evolution/proposals/0167-swift-encoders.md](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0167-swift-encoders.md)

### Pitfall 5: Gen<T>.arbitrary Requirement
**What goes wrong:** Generated test assumes `Gen<T>.arbitrary` exists for the annotated type, but user hasn't defined it
**Why it happens:** Macro generates `Property(generator: Gen<User>.arbitrary)` but `User` doesn't conform to `Generatable`
**How to avoid:** Emit diagnostic if type doesn't have `@Arbitrary` macro or explicit generator. Suggest adding `@Arbitrary` to the type. Alternatively, allow `@Roundtrip(generator: myCustomGen)` parameter to override.
**Warning signs:** Macro expansion succeeds but generated code fails with "Type 'Gen<User>' has no member 'arbitrary'"

**Sources:**
- Existing InvariantSwift pattern: `@Arbitrary` macro generates `.arbitrary` static property (ArbitraryMacro.swift)
- PropertyMacro.swift uses `Gen<T>.arbitrary` implicitly (lines 195-200)

## Code Examples

Verified patterns from official sources and existing codebase:

### Codable Roundtrip Test Pattern
```swift
// Source: Ghostwriter TestGenerator.swift (lines 140-156)
// InvariantSwift's existing Codable roundtrip test generation
/// Codable roundtrip: encoding and decoding preserves value.
/// Pattern: Codable encode/decode roundtrip preserves value
@PropertyTest
func test_User_codableRoundtrip(value: User) throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  let encoded = try encoder.encode(value)
  let decoded = try decoder.decode(User.self, from: encoded)

  #expect(decoded == value, "Codable roundtrip should preserve value")
}
```

### Hash Stability Test Pattern
```swift
// Source: Hashable best practices
// Note: Tests hash consistency within a single run, not across runs
@PropertyTest
func test_Point_hashStability(value: Point) {
  let hash1 = value.hashValue
  let hash2 = value.hashValue

  #expect(hash1 == hash2, "Hash value should be stable within same run")
}

// Optional: Set insertion/retrieval roundtrip
@PropertyTest
func test_Point_setRoundtrip(value: Point) {
  var set = Set<Point>()
  set.insert(value)

  #expect(set.contains(value), "Set should contain inserted value")
}
```

### Macro Declaration Pattern
```swift
// Source: PropertyMacroDeclaration.swift (lines 5-10)
// Recommended @Roundtrip public API
@attached(peer, names: suffixed(_RoundtripTest))
public macro Roundtrip(
  via strategy: RoundtripStrategy = .json,
  iterations: Int = 100,
  seed: UInt64? = nil,
  maxShrinks: Int = 1000
) = #externalMacro(module: "InvariantSwiftMacros", type: "RoundtripMacro")

public enum RoundtripStrategy: Sendable {
  case json
  case propertyList
  case hash
  case custom(encoder: Any, decoder: Any)  // Type-erased for macro usage
}
```

### AST Builder Pattern for Test Function
```swift
// Source: PropertyMacro.swift (lines 72-105)
// Recommended approach for generating test function
private static func buildRoundtripTestFunction(
  typeName: String,
  strategy: EncodingStrategy,
  config: RoundtripConfig
) -> FunctionDeclSyntax {

  let testBody = buildRoundtripTestBody(
    typeName: typeName,
    strategy: strategy,
    config: config
  )

  return FunctionDeclSyntax(
    attributes: AttributeListSyntax {
      AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("Test")),
        leftParen: .leftParenToken(),
        arguments: .argumentList(
          LabeledExprListSyntax {
            LabeledExprSyntax(
              expression: StringLiteralExprSyntax(
                content: "\(typeName) roundtrip (\(strategy.description))"
              )
            )
          }
        ),
        rightParen: .rightParenToken()
      )
    },
    modifiers: DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.static))
    },
    funcKeyword: .keyword(.func),
    name: .identifier("test\(typeName)_roundtrip_\(strategy.suffix)"),
    signature: buildThrowsSignature(),
    body: testBody
  )
}
```

### Protocol Conformance Check
```swift
// Source: Swift Forums, adapted to InvariantSwift patterns
private static func verifyConformances(
  _ declaration: some DeclGroupSyntax,
  required: [String],
  context: MacroContext
) -> Bool {
  guard let inheritanceClause = declaration.inheritanceClause else {
    context.error(
      "Type must conform to \(required.joined(separator: ", "))",
      at: declaration
    )
    return false
  }

  let conformedProtocols = inheritanceClause.inheritedTypes.compactMap {
    $0.type.as(IdentifierTypeSyntax.self)?.name.text
  }

  let missing = required.filter { !conformedProtocols.contains($0) }

  if !missing.isEmpty {
    context.warning(
      "Type may not conform to required protocols: \(missing.joined(separator: ", ")). " +
      "If conformance is in an extension, this warning can be ignored.",
      at: declaration
    )
  }

  return true  // Proceed anyway; compile-time errors will catch actual issues
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Codable test writing | Ghostwriter auto-generation | ISP-0009 (2025) | Reduces boilerplate but requires CLI invocation |
| Ghostwriter CLI | @Roundtrip macro | ISP-0011 (this phase) | Compile-time generation, better IDE integration |
| String-based test generation | SwiftSyntax AST builders | SwiftSyntax 600.0 | Type-safe, trivia-preserving code generation |
| XCTest framework | Swift Testing | WWDC 2024 | Modern testing with @Test, #expect, parameterization |
| SwiftCheck/Fox libraries | InvariantSwift | 2024-2025 | Native Swift 6, Sendable support, macro integration |

**Deprecated/outdated:**
- XCTest assertions in new code: Use Swift Testing's `#expect()` instead
- String interpolation for macro code generation: Use SwiftSyntax builders exclusively
- Standalone property-based testing libraries (SwiftCheck, Fox): InvariantSwift provides integrated solution with better Swift 6 support

**Sources:**
- [SwiftCheck - GitHub](https://github.com/typelift/SwiftCheck)
- [Fox - Property Based Testing Library - GitHub](https://github.com/jeffh/Fox)
- [Swift Testing - Apple Developer](https://developer.apple.com/xcode/swift-testing)

## Open Questions

Things that couldn't be fully resolved:

1. **Should @Roundtrip support conditional encoding strategies based on type?**
   - What we know: PropertyListEncoder doesn't support all types that JSONEncoder does (e.g., custom Date encoding)
   - What's unclear: How to automatically select appropriate encoder for a type
   - Recommendation: Start with explicit strategy parameter, document limitations. Phase 2 could add auto-detection.

2. **How to handle custom Encoder configurations in macro API?**
   - What we know: Closures can't be passed to macros (need to be serializable)
   - What's unclear: Best way to expose encoder customization (date strategies, key encoding, etc.)
   - Recommendation: Provide `.custom(encoder: MyEncoder(), decoder: MyDecoder())` for full control. Document that users should define custom encoder instances if they need non-default configuration.

3. **Should hash stability tests verify Set/Dictionary insertion behavior?**
   - What we know: Hash stability implies successful Set insertion/retrieval roundtrip
   - What's unclear: Whether additional Set/Dictionary tests provide value vs complexity
   - Recommendation: Phase 1 implements basic `hashValue == hashValue` test. Phase 2 adds optional `.hashWithCollections` strategy for comprehensive testing.

4. **How to handle types with non-trivial Equatable implementations?**
   - What we know: Some types implement fuzzy equality (floating-point tolerance, ignoring certain fields)
   - What's unclear: Whether structural comparison option is worth the complexity
   - Recommendation: Phase 1 uses `==` operator. Document limitation. Consider `@Roundtrip(strict: true)` in future if user demand exists.

## Sources

### Primary (HIGH confidence)
- InvariantSwift codebase:
  - `Sources/InvariantSwift/Ghostwriter/TestGenerator.swift` (lines 140-156) - Existing Codable roundtrip implementation
  - `Sources/InvariantSwiftMacros/PropertyMacro/PropertyMacro.swift` - Peer macro pattern
  - `Sources/InvariantSwiftMacros/ArbitraryMacro/ArbitraryMacro.swift` - Member + extension macro pattern
  - `Sources/InvariantSwift/Macros/PropertyMacroDeclaration.swift` (lines 5-10) - Public macro declaration pattern
  - `Sources/InvariantSwiftMacros/CLAUDE.md` - Macro development guidelines

- Official Apple documentation:
  - [Swift Testing - Xcode - Apple Developer](https://developer.apple.com/xcode/swift-testing)
  - Swift Evolution SE-0167: [swift-evolution/proposals/0167-swift-encoders.md](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0167-swift-encoders.md)

- Official Swift community:
  - [swift-evolution/proposals/0389-attached-macros.md](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md) - Attached macros specification

### Secondary (MEDIUM confidence)
- Swift Forums (verified by official Swift.org domain):
  - [Check if type conforms to a protocol - Swift Forums](https://forums.swift.org/t/check-if-type-conforms-to-a-protocol/65425) - Protocol conformance checking
  - [Is it possible to check in a Macro expansion if all stored properties conform to a protocol - Swift Forums](https://forums.swift.org/t/is-it-possible-to-check-in-a-marco-expansion-if-all-stored-properties-the-type-conform-to-a-protocol/65939) - Property conformance checking

- Community best practices (established Swift developers):
  - [Swift Codable Testing · paul-samuels.com](https://paul-samuels.com/blog/2019/01/07/swift-codable-testing/) - Roundtrip testing patterns
  - [Testing custom Codable implementations | Swift by Sundell](https://www.swiftbysundell.com/tips/testing-custom-codable-implementations/) - Encode/decode test approach
  - [Encoding and decoding JSON in Swift](https://www.ralfebert.com/ios/json-handling-in-swift/) - JSONEncoder/JSONDecoder usage

- Swift language features:
  - [Swift 4.2 improves Hashable with a new Hasher struct – Hacking with Swift](https://www.hackingwithswift.com/articles/115/swift-4-2-improves-hashable-with-a-new-hasher-struct) - Hash seeding behavior
  - [Simpler, more secure hashing – available from Swift 4.2](https://www.hackingwithswift.com/swift/4.2/hashable) - Hashable determinism

### Tertiary (LOW confidence)
- General Swift macro resources:
  - [Swift Macros: Extend Swift with New Kinds of Expressions - avanderlee.com](https://www.avanderlee.com/swift/macros/) - General macro introduction
  - [Swift Macro Expansion Testing | Livefront](https://livefront.com/writing/swift-macro-expansion-testing/) - Testing approaches

- Alternative property-based testing libraries (for comparison):
  - [SwiftCheck - GitHub](https://github.com/typelift/SwiftCheck) - QuickCheck port (older, pre-Swift 6)
  - [Fox - Property Based Testing Library - GitHub](https://github.com/jeffh/Fox) - Objective-C/Swift library (older)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official Apple frameworks (Foundation, SwiftSyntax) and existing InvariantSwift infrastructure
- Architecture: HIGH - Directly verified from InvariantSwift codebase (18+ existing macros follow same pattern)
- Pitfalls: MEDIUM to HIGH - Hash non-determinism HIGH (official Swift docs), conformance checking MEDIUM (Swift Forums, not official docs), Equatable semantics MEDIUM (community best practices)

**Research date:** 2026-01-23
**Valid until:** 60 days (stable Swift 6 features, macro APIs are mature, Codable/Hashable haven't changed since Swift 4.2)

**Key gaps identified:**
- No official Swift documentation on macro-time protocol conformance checking (relies on community patterns)
- Limited examples of encoder configuration in macro APIs (novel problem for this phase)
- Hash stability testing patterns are well-established but not documented in official Swift guides

**Research confidence:** 85% - High confidence in architecture and implementation patterns (verified from codebase), medium confidence in edge cases (community sources, not official documentation).
