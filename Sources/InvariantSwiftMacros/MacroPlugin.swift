import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct InvariantSwiftMacroPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    PropertyTestMacro.self,
    PropertyMacro.self,
    GenMacro.self,
    BusinessRuleMacro.self,
    DeriveGenMacro.self,
    ArbitraryMacro.self,
    LabelMacro.self,
  ]
}
