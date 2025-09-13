import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FunctionalTestingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    PropertyTestMacro.self,
    FunctorLawsMacro.self,
    ApplicativeLawsMacro.self,
    MonadLawsMacro.self,
    CustomLawsMacro.self,
    DeriveLawMacro.self,
    AlgebraicLawsMacro.self,
    // Phase 1 Core Business Macros
    BusinessRuleMacro.self,
    SmartGeneratorMacro.self,
    TestAllCasesMacro.self,
    // DeriveGenMacro.self,  // Temporarily disabled
    // LawCheckedMacro.self, // Temporarily disabled
  ]
}
