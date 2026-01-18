# AGENTS.md - InvariantSwift Macros

> **Sub-package AGENTS.md** for `Sources/InvariantSwiftMacros/`

## Package Identity

**Purpose:** Swift macro implementations for property-based testing  
**Framework:** SwiftSyntax 600.0.1+, SwiftCompilerPlugin  
**Exports:** `@Property`, `@Arbitrary`, `@Gen`, `@Contract`, `@DifferentialTest`, `@RuleBasedTest`, `@StateMachine`

---

## Setup & Run

```bash
# Build macros
swift build

# Run macro tests
swift test --filter InvariantSwiftMacroTests

# Single test
swift test --filter "PropertyMacroTests/testBasicPropertyExpansion"
```

---

## Directory Structure

```
InvariantSwiftMacros/
├── PropertyMacro/           # @Property, @AsyncProperty macros
│   ├── PropertyMacro.swift
│   └── AsyncPropertyTestMacro.swift
├── ArbitraryMacro/          # @Arbitrary for struct generation
├── GenMacro/                # @Gen DSL for custom generators
├── LabelMacro/              # @Label for test naming
├── CompositeMacro/          # Composite generator macros
├── RuleBasedTestMacro/      # @RuleBasedTest for stateful testing
├── StateMachineMacro/       # @StateMachine for state machines
├── Utilities/               # Shared AST helpers
├── MacroPlugin.swift        # Plugin entry point
├── BusinessRuleMacro.swift  # Business rule testing
├── ContractMacro.swift      # Contract testing
├── DifferentialTestMacro.swift
├── DeriveGenMacro.swift
├── LawCheckedMacro.swift
├── ReproduceMacro.swift
├── TargetMacro.swift
└── FuzzableMacro.swift
```

---

## Patterns & Conventions

### 🚨 CRITICAL: Pure SwiftSyntax Only

**NEVER use string interpolation for code generation.**

### ❌ FORBIDDEN
```swift
// This is BANNED
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
import struct ASTBuilders

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

### ✅ DO: Emit diagnostics for errors
```swift
// See: Utilities/DiagnosticEmitter.swift
context.diagnose(Diagnostic(
  node: node,
  message: MacroError.invalidUsage("@Property requires a function returning Bool")
))
return []
```

---

## Touch Points / Key Files

| File | Purpose |
|------|---------|
| `MacroPlugin.swift` | Plugin entry point, registers all macros |
| `PropertyMacro/PropertyMacro.swift` | Main @Property implementation |
| `ArbitraryMacro/ArbitraryMacro.swift` | Derives generators for structs |
| `Utilities/ASTBuilders.swift` | Reusable AST construction helpers |
| `Utilities/TypeExtraction.swift` | Extract type info from declarations |
| `Utilities/DiagnosticEmitter.swift` | Error reporting |

---

## JIT Index Hints

```bash
# Find all macro definitions
rg -n "struct.*Macro.*:.*Macro" .

# Find macro registrations
rg -n "providingMacros" MacroPlugin.swift

# Find AST builder usage
rg -n "Syntax\(" --type swift

# Find diagnostic messages
rg -n "Diagnostic\(|diagnose\(" .

# Find test for a macro
rg -n "@Test.*MacroName" ../../Tests/InvariantSwiftMacroTests/
```

---

## Common Gotchas

1. **Trivia matters** - Preserve leading/trailing trivia for proper formatting
2. **SwiftSyntax versions** - Pin to 600.0.1 for Swift 6.0/6.1/6.2 compat
3. **No runtime dependencies** - Macros cannot import InvariantSwift library
4. **Error handling** - Return empty array with diagnostic, never throw from expansion
5. **Compile time** - Keep macro expansions fast; avoid complex loops

---

## Testing Macros

### Test Pattern
```swift
// See: Tests/InvariantSwiftMacroTests/PropertyMacroTests.swift
@Test("@Property generates test function")
func testPropertyExpansion() throws {
  assertMacroExpansion(
    """
    @Property
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

## Pre-PR Checks

```bash
swift build -Xswiftc -warnings-as-errors && \
swift test --filter InvariantSwiftMacroTests && \
swiftlint lint --strict Sources/InvariantSwiftMacros/
```

---

## Excluded from Linting

The following directories are excluded from SwiftLint due to inherent verbosity of AST builders:
- `RuleBasedTestMacro/` (see `.swiftlint.yml` line 16)
