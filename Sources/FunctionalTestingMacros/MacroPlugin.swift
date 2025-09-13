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
    // DeriveGenMacro.self,  // Temporarily disabled
    // LawCheckedMacro.self, // Temporarily disabled
  ]
}
