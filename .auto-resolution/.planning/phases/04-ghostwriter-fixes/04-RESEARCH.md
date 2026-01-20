# Phase 4: Ghostwriter Fixes - Research

**Researched:** 2026-01-23
**Domain:** SwiftSyntax AST analysis, code generation, compile verification
**Confidence:** HIGH

## Summary

Phase 4 addresses three key issues with Ghostwriter: access level filtering, auto-generating missing `@Arbitrary` conformances, and compile-testing generated output. Research reveals the codebase already has partial implementations that can be extended:

1. **Access Level Filtering**: `SwiftSyntaxTypeExtractor.swift` already extracts `isPublic` boolean, but needs refinement to handle all five access levels (`private`, `fileprivate`, `internal`, `public`, `open`) with proper defaults.

2. **Auto-Generate @Arbitrary**: `TestCodeGenerator.swift` already generates `Arbitrary` extensions for types lacking them. The pattern is correct but needs better type introspection and error handling for complex/nested types.

3. **Compile-Test Infrastructure**: Swift compiler can be invoked programmatically via `swiftc -typecheck` for verification without full compilation.

**Primary recommendation:** Enhance existing `SwiftSyntaxTypeExtractor` with full `AccessLevel` enum, add compile verification as an optional post-generation step.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftSyntax | 602.0.0 | AST parsing and code generation | Official Swift toolchain library |
| SwiftParser | 602.0.0 | Swift source parsing | Part of swift-syntax package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation | system | Process spawning for compile tests | Always available |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftSyntax | SourceKitten | SourceKitten is external dep, SwiftSyntax already present |
| Process-based compile | Swift Driver API | Driver API more complex, Process simpler for MVP |

**Installation:** Already in Package.swift dependencies.

## Architecture Patterns

### Recommended Project Structure

No new files needed. Modifications to existing files:

```
Sources/
├── GhostwriterCLI/
│   ├── SwiftSyntaxTypeExtractor.swift  # Add AccessLevel enum
│   ├── TestCodeGenerator.swift         # Enhanced @Arbitrary generation
│   └── GhostwriterCLI.swift           # Add --include-internal flag
├── InvariantSwift/
│   └── Ghostwriter/
│       ├── TypeInfo.swift              # Add AccessLevel if shared
│       └── CompileVerifier.swift       # NEW: Optional compile verification
```

### Pattern 1: Access Level Extraction from SwiftSyntax

**What:** Extract full access level from `DeclModifierListSyntax`
**When to use:** During type extraction from AST
**Source:** Official Swift ObservableMacro implementation

```swift
// Based on official Swift macro patterns
public enum AccessLevel: String, Codable, Sendable, Comparable {
  case `private`
  case `fileprivate`
  case `internal`  // Default when not specified
  case `public`
  case `open`

  public var isPubliclyAccessible: Bool {
    self == .public || self == .open
  }

  // Comparable for filtering: private < fileprivate < internal < public < open
  public static func < (lhs: AccessLevel, rhs: AccessLevel) -> Bool {
    let order: [AccessLevel] = [.private, .fileprivate, .internal, .public, .open]
    return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
  }
}

// Extraction from DeclModifierListSyntax
func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
  for modifier in modifiers {
    switch modifier.name.tokenKind {
    case .keyword(.private): return .private
    case .keyword(.fileprivate): return .fileprivate
    case .keyword(.internal): return .internal
    case .keyword(.public): return .public
    case .keyword(.open): return .open
    default: continue
    }
  }
  return .internal  // Swift default
}
```

### Pattern 2: Compile Verification via Process

**What:** Invoke Swift compiler to type-check generated code
**When to use:** After generating test file, before writing to disk
**Source:** Swift compiler documentation

```swift
// Compile verification using swiftc -typecheck
public struct CompileVerifier: Sendable {

  public enum VerificationResult: Sendable {
    case success
    case failed(errors: [CompileError])
  }

  public struct CompileError: Sendable {
    let line: Int
    let column: Int
    let message: String
  }

  /// Verify generated code compiles with the test target context
  public static func verify(
    code: String,
    importModules: [String] = ["Foundation", "Testing", "InvariantSwift"]
  ) async throws -> VerificationResult {
    // Write to temp file
    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("GhostwriterVerify_\(UUID()).swift")
    try code.write(to: tempFile, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempFile) }

    // Run swiftc -typecheck
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
    process.arguments = ["swiftc", "-typecheck", tempFile.path]

    let errorPipe = Pipe()
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
      return .success
    }

    // Parse errors from stderr
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
    let errors = parseCompilerErrors(errorOutput)

    return .failed(errors: errors)
  }
}
```

### Pattern 3: Arbitrary Extension Auto-Generation

**What:** Generate `Arbitrary` conformance for types without it
**When to use:** When type has generatable properties but no `@Arbitrary` attribute

```swift
// Current pattern in TestCodeGenerator.swift (to enhance)
public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
  let propGenerators = type.properties.map { prop in
    "\(prop.name): \(generatorExpression(for: prop.typeName))"
  }

  return """
    extension \(type.name): Arbitrary {
      public static var arbitrary: Gen<\(type.name)> {
        Gen.compose { composer in
          \(type.name)(
            \(propGenerators.joined(separator: ",\n        "))
          )
        }
      }
    }
    """
}
```

### Anti-Patterns to Avoid

- **Generating tests for inaccessible types:** Types with `private`/`fileprivate`/`internal` access cannot be tested from separate test target.
- **Assuming all properties are generatable:** Must check each property type against known generators before attempting generation.
- **Ignoring nested types:** Nested types (e.g., `Outer.Inner`) need qualified names and may have different access levels.
- **Hard-coding module imports:** Generated tests may need different imports based on source module.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Access level keywords | String matching | `TokenKind.keyword()` enum | SwiftSyntax has exhaustive keyword enum |
| Type-checking code | Custom parser | `swiftc -typecheck` | Compiler knows all rules |
| Process spawning | Custom exec | Foundation `Process` | Standard Swift pattern |
| Temp file handling | Manual cleanup | `defer { try? removeItem }` | Ensures cleanup on all paths |

**Key insight:** SwiftSyntax already handles all the hard AST work. The challenge is using its APIs correctly, not reimplementing them.

## Common Pitfalls

### Pitfall 1: Default Access Level

**What goes wrong:** Assuming `internal` only when no modifier present, but Swift has complex defaulting rules.
**Why it happens:** Extension members, protocol requirements, and nested types have different defaults.
**How to avoid:** For Ghostwriter's purposes, treat "no explicit access level" as `internal` since that's the most common case for types.
**Warning signs:** Tests fail to compile because type is actually `private` due to being nested in private type.

### Pitfall 2: Generic Type Generation

**What goes wrong:** Generating `@Arbitrary` for generic types like `Container<T>` without constraining `T`.
**Why it happens:** Generic parameters need their own `Arbitrary` conformance which may not exist.
**How to avoid:** Skip generic types in auto-generation, or require explicit `@Arbitrary` annotation.
**Warning signs:** Compiler error "Type 'T' does not conform to protocol 'Arbitrary'".

### Pitfall 3: Compile Verification Module Context

**What goes wrong:** `swiftc -typecheck` fails because generated code imports modules not available.
**Why it happens:** Test file imports `@testable import MyModule` but verification runs without module context.
**How to avoid:** Make compile verification optional, or run it within SPM test context.
**Warning signs:** "No such module 'MyModule'" errors during verification.

### Pitfall 4: Property Access Level vs Type Access Level

**What goes wrong:** Generating tests for `public struct` but properties are all `private`.
**Why it happens:** A type can be public but have no public initializer or accessible properties.
**How to avoid:** Check for public initializer presence (`hasPublicInit`) before generating tests.
**Warning signs:** Compiler error "initializer is inaccessible due to 'internal' protection level".

### Pitfall 5: Extension Conformances Not Merged

**What goes wrong:** Type declared in one file with conformances added via extension in another file not detected.
**Why it happens:** Single-file analysis misses cross-file conformances.
**How to avoid:** Use `SwiftSyntaxTypeExtractor.mergeConformances()` (already implemented).
**Warning signs:** Tests not generated for types that clearly conform to Codable/Equatable.

## Code Examples

Verified patterns from existing codebase:

### Access Level Check (Current - Boolean Only)
```swift
// Source: SwiftSyntaxTypeExtractor.swift line 247-248
let isPublic = modifiers.contains { modifier in
  modifier.name.text == "public" || modifier.name.text == "open"
}
```

### Full Access Level Extraction (Recommended Pattern)
```swift
// Based on official Swift ObservableMacro
func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
  for modifier in modifiers {
    switch modifier.name.tokenKind {
    case .keyword(let keyword):
      switch keyword {
      case .private: return .private
      case .fileprivate: return .fileprivate
      case .internal: return .internal
      case .public: return .public
      case .open: return .open
      default: continue
      }
    default: continue
    }
  }
  return .internal
}
```

### Filtering Testable Types (Current)
```swift
// Source: GhostwriterCLI.swift lines 186-193
let testableTypes = mergedTypes.filter { type in
  let patterns = generator.detectPatterns(for: type)
  guard !patterns.isEmpty else { return false }
  guard type.isPublic else { return false }  // Skip internal types
  return type.hasArbitraryAttribute
    || isKnownGeneratableType(type.name)
    || canAutoGenerateArbitrary(for: type)
}
```

### Arbitrary Extension Generation (Current)
```swift
// Source: TestCodeGenerator.swift lines 134-149
public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
  let propGenerators = type.properties.map { prop in
    "\(prop.name): \(generatorExpression(for: prop.typeName))"
  }

  return """
    extension \(type.name): Arbitrary {
      public static var arbitrary: Gen<\(type.name)> {
        Gen.compose { composer in
          \(type.name)(
            \(propGenerators.joined(separator: ",\n        "))
          )
        }
      }
    }
    """
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Regex-based parsing | SwiftSyntax AST | Already in codebase | More accurate type extraction |
| Boolean isPublic | Full AccessLevel enum | This phase | Fine-grained access control |
| Generate-and-hope | Compile verification | This phase | Guaranteed compilable output |

**Deprecated/outdated:**
- Regex-based `SourceAnalyzer.swift` (still present but GhostwriterCLI uses SwiftSyntax version)

## Hypothesis Ghostwriter Comparison

Hypothesis (Python) Ghostwriter provides several patterns InvariantSwift can learn from:

| Feature | Hypothesis | InvariantSwift Current | InvariantSwift Target |
|---------|------------|----------------------|----------------------|
| Roundtrip tests | encode/decode pairs | Codable roundtrip | Same |
| Idempotence | `f(f(x)) == f(x)` | Detected via method names | Same |
| Binary ops | Associativity, commutativity | Limited | Can expand |
| Missing types | `st.nothing()` + TODO comment | Skip or warn | Add TODO comments |
| Access control | N/A (Python) | isPublic boolean | Full AccessLevel enum |

**Key Hypothesis pattern to adopt:** When type cannot be generated, emit code with `// TODO: supply generator for UnknownType` rather than silently skipping.

## Open Questions

Things that couldn't be fully resolved:

1. **Module Import Discovery**
   - What we know: Generated tests need correct imports
   - What's unclear: How to automatically discover which modules to import based on source file
   - Recommendation: Use source file's existing imports + standard test imports

2. **Nested Type Access Level Inheritance**
   - What we know: Nested types can have different access than parent
   - What's unclear: Swift's exact rules for effective access level of nested types
   - Recommendation: Use explicit access level if present, else inherit from parent type

3. **Package Access Level (Swift 5.9+)**
   - What we know: Swift 5.9 added `package` access level
   - What's unclear: Whether tests in same package can access `package` types
   - Recommendation: Treat `package` as equivalent to `internal` for test generation purposes

## Sources

### Primary (HIGH confidence)
- Existing codebase: `SwiftSyntaxTypeExtractor.swift`, `TestCodeGenerator.swift`, `GhostwriterCLI.swift`
- [Swift ObservableMacro implementation](https://github.com/swiftlang/swift/blob/main/lib/Macros/Sources/ObservationMacros/ObservableMacro.swift) - Access level filtering pattern
- [SwiftSyntax documentation](https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftsyntax) - DeclModifierListSyntax API
- [Swift compiler documentation](https://github.com/apple/swift/blob/main/docs/Driver.md) - `swiftc -typecheck` option

### Secondary (MEDIUM confidence)
- [Hypothesis Ghostwriter documentation](https://hypothesis.readthedocs.io/en/latest/reference/integrations.html) - Test generation patterns
- [SwiftLee SwiftSyntax guide](https://www.avanderlee.com/swift/swiftsyntax-parse-and-generate-swift-source-code/) - General SwiftSyntax patterns

### Tertiary (LOW confidence)
- Web search results for compile verification patterns (needs validation)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Already using swift-syntax 602.0.0
- Architecture: HIGH - Enhancing existing implementations
- Access level extraction: HIGH - Pattern verified from official Swift macros
- Compile verification: MEDIUM - Standard approach but needs testing
- Pitfalls: MEDIUM - Based on general Swift knowledge, not all verified

**Research date:** 2026-01-23
**Valid until:** 60 days (stable domain, SwiftSyntax API unlikely to change)
