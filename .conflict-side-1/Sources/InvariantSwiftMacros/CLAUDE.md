# CLAUDE.md - InvariantSwift Macros

> **Sub-package CLAUDE.md** for `Sources/InvariantSwiftMacros/`
>
> Parent: [../../CLAUDE.md](../../CLAUDE.md) | See also: [AGENTS.md](AGENTS.md)

## Package Identity

| Attribute | Value |
|-----------|-------|
| **Purpose** | Swift macro implementations for property-based testing |
| **Framework** | SwiftSyntax 600.0.1+, SwiftCompilerPlugin |
| **Exports** | `@PropertyTest`, `@Arbitrary`, `@Gen`, `@Contract`, `@StateMachine`, etc. |
| **Entry Point** | `MacroPlugin.swift` |

---

## Setup & Commands

### Build & Test

```bash
# Build macros
swift build

# Run macro tests
swift test --filter InvariantSwiftMacroTests

# Run single test
swift test --filter "PropertyMacroTests/testBasicPropertyExpansion"
```

### Pre-PR Checklist

```bash
swift build -Xswiftc -warnings-as-errors && \
swift test --filter InvariantSwiftMacroTests && \
swiftlint lint --strict Sources/InvariantSwiftMacros/
```

---

## Directory Structure

```
InvariantSwiftMacros/
├── MacroPlugin.swift            # Plugin entry point (registers all macros)
├── PropertyMacro/               # @PropertyTest, @AsyncProperty macros
│   ├── PropertyMacro.swift
│   └── AsyncPropertyTestMacro.swift
├── ArbitraryMacro/              # @Arbitrary for struct generation
├── GenMacro/                    # @Gen DSL for custom generators
├── LabelMacro/                  # @Label for test naming
├── CompositeMacro/              # Composite generator macros
├── RuleBasedTestMacro/          # @RuleBasedTest for stateful testing
├── StateMachineMacro/           # @StateMachine for state machines
├── Utilities/                   # Shared AST helpers (14 files)
│   ├── ASTBuilders.swift
│   ├── TypeExtraction.swift
│   └── DiagnosticEmitter.swift
├── BusinessRuleMacro.swift      # Business rule testing
├── ContractMacro.swift          # Contract testing
├── DifferentialTestMacro.swift  # Differential testing
├── DeriveGenMacro.swift         # Generator derivation
├── LawCheckedMacro.swift        # Mathematical law verification
├── ReproduceMacro.swift         # Reproduce failing tests
├── TargetMacro.swift            # Target filtering
└── FuzzableMacro.swift          # Fuzzing support
```

---

## Architecture & Patterns

### 🚨 CRITICAL: Pure SwiftSyntax Only

**NEVER use string interpolation for code generation.**

### ❌ FORBIDDEN Pattern

```swift
// This is BANNED - never do this
return DeclSyntax(stringLiteral: """
  func test_\(name)() {
    // ...
  }
""")
```

### ✅ REQUIRED: Use AST Builders

```swift
// See: PropertyMacro/PropertyMacro.swift
FunctionDeclSyntax(
  name: .identifier("test_\(propertyName)"),
  signature: FunctionSignatureSyntax(
    parameterClause: FunctionParameterClauseSyntax(parameters: [])
  ),
  body: CodeBlockSyntax { ... }
)
```

### ✅ DO: Use Utilities/ASTBuilders

```swift
// See: Utilities/ASTBuilders.swift
let funcDecl = ASTBuilders.makeFunction(
  name: "testProperty",
  body: [statement1, statement2]
)
```

### ✅ DO: Pattern for MemberMacro

```swift
// See: ArbitraryMacro/ArbitraryMacro.swift
public struct ArbitraryMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Build AST nodes...
  }
}
```

### ✅ DO: Emit Diagnostics for Errors

```swift
// See: Utilities/DiagnosticEmitter.swift
context.diagnose(Diagnostic(
  node: node,
  message: MacroError.invalidUsage("@PropertyTest requires a function returning Bool")
))
return []  // Return empty, never throw
```

---

## Key Files (Touch Points)

| File | Purpose | Priority |
|------|---------|----------|
| `MacroPlugin.swift` | Plugin entry point, registers all macros | High |
| `PropertyMacro/PropertyMacro.swift` | Main @PropertyTest implementation | High |
| `ArbitraryMacro/ArbitraryMacro.swift` | Derives generators for structs | High |
| `Utilities/ASTBuilders.swift` | Reusable AST construction helpers | High |
| `Utilities/TypeExtraction.swift` | Extract type info from declarations | Medium |
| `Utilities/DiagnosticEmitter.swift` | Error reporting | Medium |
| `BusinessRuleMacro.swift` | Business rule testing (large) | Medium |
| `LawCheckedMacro.swift` | Mathematical law verification (large) | Medium |

---

## Quick Find Commands (JIT Index)

### Find Macro Definitions

```bash
# Find all macro definitions
rg -n "struct.*Macro.*:.*Macro" .

# Find macro registrations
rg -n "providingMacros" MacroPlugin.swift

# Find specific macro
rg -n "PropertyMacro|ArbitraryMacro|StateMachineMacro" .
```

### Find AST Patterns

```bash
# Find AST builder usage
rg -n "Syntax\(" --type swift

# Find diagnostic messages
rg -n "Diagnostic\(|diagnose\(" .

# Find type extraction
rg -n "TypeSyntax|TypeExprSyntax" Utilities/
```

### Find Tests

```bash
# Find test for a macro
rg -n "@Test.*MacroName" ../../Tests/InvariantSwiftMacroTests/

# Find all macro expansion tests
rg -n "assertMacroExpansion" ../../Tests/InvariantSwiftMacroTests/
```

---

## Testing Macros

### Test Pattern

```swift
// See: Tests/InvariantSwiftMacroTests/PropertyMacroTests.swift
import SwiftSyntaxMacrosTestSupport

@Test("@PropertyTest generates test function")
func testPropertyExpansion() throws {
  assertMacroExpansion(
    """
    @PropertyTest
    func commutative(a: Int, b: Int) -> Bool {
      a + b == b + a
    }
    """,
    expandedSource: """
    func commutative(a: Int, b: Int) -> Bool {
      a + b == b + a
    }
    
    @Test("commutative")
    func test_commutative() async throws {
      // Generated test body...
    }
    """,
    macros: testMacros
  )
}
```

### Run Macro Tests

```bash
swift test --filter InvariantSwiftMacroTests
```

---

## Common Gotchas

1. **Trivia matters**: Preserve leading/trailing trivia for proper formatting in expanded code
2. **SwiftSyntax versions**: Pin to 600.0.1 for Swift 6.0/6.1/6.2 compatibility
3. **No runtime dependencies**: Macro targets CANNOT import InvariantSwift library
4. **Error handling**: Return empty array with diagnostic, NEVER throw from expansion
5. **Compile time**: Keep macro expansions fast; avoid complex loops or heavy processing
6. **Whitespace sensitivity**: Macro expansion tests are whitespace-sensitive; match expected output exactly

---

## Excluded from Linting

The following directories are excluded from SwiftLint due to inherent verbosity of AST builders:

- `RuleBasedTestMacro/` (see `.swiftlint.yml` line 16)

---

## Related Documents

- [AGENTS.md](AGENTS.md) - General AI agent conventions for this directory
- [../../CLAUDE.md](../../CLAUDE.md) - Root project guidance
- [docs/MACROS.md](../../docs/MACROS.md) - Macro documentation
- [Tests/InvariantSwiftMacroTests/](../../Tests/InvariantSwiftMacroTests/) - Macro tests
