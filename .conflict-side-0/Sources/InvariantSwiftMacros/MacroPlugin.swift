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
    LawCheckedMacro.self,
    LabelMacro.self,
    StateMachineMacro.self,
    CommandMacro.self,
    AsyncPropertyTestMacro.self,
    DrawMacro.self,
    CompositeMacro.self,
    RuleBasedTestMacro.self,
    RuleMacro.self,
    PreconditionMacro.self,
    InvariantMacro.self,
    BundleMacro.self,
    RegressionMacro.self,
    ReproduceMacro.self,
    DifferentialTestMacro.self,
    ContractMacro.self,
    TestContractMacro.self,
    LawMacro.self,
    FuzzableMacro.self,
    StructuredInputMacro.self,
    TargetMacro.self,
    IdempotentMacro.self,
    DeterministicMacro.self,
    PureMacro.self,
    EquivalenceMacro.self,
    TimeoutMacro.self,
    ShrinkTowardsMacro.self,
  ]
}
