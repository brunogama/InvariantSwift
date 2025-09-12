import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FunctionalTestingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    PropertyTestMacro.self,
    // DeriveGenMacro.self,  // Temporarily disabled
    // LawCheckedMacro.self, // Temporarily disabled
  ]
}
