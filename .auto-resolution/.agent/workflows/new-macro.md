---
description: Scaffold a new SwiftSyntax macro with tests
---

# New Macro Workflow

Create a new macro: $ARGUMENTS

## Steps

### 1. Create Macro Implementation

Location: `Sources/InvariantSwiftMacros/$ARGUMENTSMacro.swift`

```swift
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftCompilerPlugin

/// $ARGUMENTS macro implementation.
public struct $ARGUMENTSMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // 🚨 CRITICAL: Use AST builders, NOT string interpolation
    
    // Build the expansion using SwiftSyntax
    let funcDecl = FunctionDeclSyntax(
      name: .identifier("generated_function"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(parameters: [])
      ),
      body: CodeBlockSyntax {
        // ...
      }
    )
    
    return [DeclSyntax(funcDecl)]
  }
}
```

### 2. Register in MacroPlugin

Edit `Sources/InvariantSwiftMacros/MacroPlugin.swift`:

```swift
@main
struct InvariantSwiftMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    // ... existing macros
    $ARGUMENTSMacro.self,  // Add this
  ]
}
```

### 3. Add Macro Declaration

Edit `Sources/InvariantSwift/Macros/MacroDeclarations.swift` (or appropriate file):

```swift
@attached(peer, names: arbitrary)
public macro $ARGUMENTS() = #externalMacro(
  module: "InvariantSwiftMacros",
  type: "$ARGUMENTSMacro"
)
```

### 4. Create Tests

Location: `Tests/InvariantSwiftMacroTests/$ARGUMENTSMacroTests.swift`

```swift
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import InvariantSwiftMacros

@Suite("$ARGUMENTS Macro Tests")
struct $ARGUMENTSMacroTests {
  
  let testMacros: [String: Macro.Type] = [
    "$ARGUMENTS": $ARGUMENTSMacro.self,
  ]
  
  @Test("basic expansion")
  func testBasicExpansion() throws {
    assertMacroExpansion(
      """
      @$ARGUMENTS
      func example() {
      }
      """,
      expandedSource: """
      func example() {
      }
      
      // Expected generated code here
      """,
      macros: testMacros
    )
  }
}
```

// turbo
### 5. Run Tests
```bash
swift test --filter "$ARGUMENTSMacroTests"
```

## 🚨 Critical Rules

1. **NEVER use string interpolation for code generation**
   ```swift
   // ❌ FORBIDDEN
   DeclSyntax(stringLiteral: "func \(name)() { }")
   
   // ✅ REQUIRED
   FunctionDeclSyntax(name: .identifier(name), ...)
   ```

2. **Preserve trivia** - Keep leading/trailing whitespace for formatting

3. **Return empty array on error** - Never throw from expansion
   ```swift
   context.diagnose(Diagnostic(node: node, message: MyError.invalid))
   return []
   ```

4. **No runtime dependencies** - Macros cannot import InvariantSwift

## Checklist

- [ ] Uses SwiftSyntax AST builders (NOT string interpolation)
- [ ] Registered in MacroPlugin.swift
- [ ] Declaration added to Macros/
- [ ] Tests use assertMacroExpansion
- [ ] Tests are whitespace-accurate
- [ ] Error cases emit diagnostics
