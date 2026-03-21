import InvariantSwiftTesting
import InvariantSwiftMacroAPI
import Testing

@RuleBasedTest(maxSteps: 5, maxExamples: 3)
struct CounterRuleBasedDogfood: Sendable {
  var balance: Int = 0

  @Rule
  mutating func increment() {
    balance += 1
  }

  @Invariant
  func countNeverDropsBelowZero() -> Bool {
    balance >= 0
  }
}

@PropertyTest("sync property dogfood", iterations: 1, seed: 13)
func syncPropertyDogfoodsPublicEntryPoint(value: Int) {
  #expect(String(value).isEmpty == false)
}

@PropertyTest("regression property dogfood", iterations: 1, seed: 17)
@Regression(replayFirst: false, maxExamples: 1)
func regressionPropertyDogfoodsGeneratedComposition(value: Int) {
  #expect(String(value).isEmpty == false)
}

@Suite("Generated Macro Dogfooding Tests")
struct GeneratedMacroDogfoodingTests {
  @Test("rule based test macro generates runnable state machines")
  @MainActor
  func ruleBasedTestMacroGeneratesRunnableStateMachines() async throws {
    try await CounterRuleBasedDogfood.runTest()
    #expect(!CounterRuleBasedDogfood.rules.isEmpty)
    #expect(!CounterRuleBasedDogfood.invariants.isEmpty)
  }
}
