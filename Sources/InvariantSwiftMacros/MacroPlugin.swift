import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FunctionalTestingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    PropertyTestMacro.self,
    BusinessRuleMacro.self,
    // SmartGeneratorMacro.self,  // Not implemented yet
    // TestAllCasesMacro.self,    // Not implemented yet
    // DeriveGenMacro.self,       // Temporarily disabled
    // LawCheckedMacro.self,      // Temporarily disabled
  ]
}
