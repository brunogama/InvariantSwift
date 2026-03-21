import Foundation
import Testing

@Suite("Property Macro Integration Tests")
struct PropertyMacroIntegrationTests {
  @Test("external packages can compile and run property test macros")
  func externalPackagesCanCompileAndRunPropertyTestMacros() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(
      source: propertyMacroFixtureSource()
    )
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.runTests(in: package)
    #expect(result.terminationStatus == 0, Comment(rawValue: result.output))
  }

  @Test("failing property macros emit Swift Testing attachments")
  func failingPropertyMacrosEmitSwiftTestingAttachments() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(
      source: failingPropertyMacroFixtureSource()
    )
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.runTests(in: package)
    let attachments = try MacroRuntimeFixtureSupport.attachmentFileNames(
      in: package.attachmentsDirectory
    )

    #expect(result.terminationStatus != 0, "Fixture should fail to exercise attachments")
    #expect(attachments.contains("property-run.json"), Comment(rawValue: result.output))
    #expect(attachments.contains("counterexample.txt"), Comment(rawValue: result.output))
    #expect(attachments.contains("shrunk-counterexample.txt"), Comment(rawValue: result.output))
  }

  @Test("external packages can run rule based test macros")
  func externalPackagesCanRunRuleBasedTestMacros() throws {
    let package = try MacroRuntimeFixtureSupport.makePackage(
      source: ruleBasedMacroFixtureSource()
    )
    defer { try? FileManager.default.removeItem(at: package.directory) }

    let result = try MacroRuntimeFixtureSupport.runTests(in: package)
    #expect(result.terminationStatus == 0, Comment(rawValue: result.output))
  }
}

private extension PropertyMacroIntegrationTests {
  func propertyMacroFixtureSource() -> String {
    """
    import InvariantSwiftTesting
    import InvariantSwiftMacroAPI
    import Testing

    @PropertyTest("sync property fixture", iterations: 3, seed: 11)
    func syncPropertyFixture(value: Int) {
      #expect(String(value).isEmpty == false)
    }

    @PropertyTest("regression property fixture", iterations: 2, seed: 17)
    @Regression(replayFirst: false, maxExamples: 1, exposeCasesAsTests: true)
    func regressionPropertyFixture(value: Int) {
      #expect(String(value).isEmpty == false)
    }
    """
  }

  func failingPropertyMacroFixtureSource() -> String {
    """
    import InvariantSwiftTesting
    import InvariantSwiftMacroAPI
    import Testing

    @PropertyTest("failing property fixture", iterations: 1, seed: 21)
    func failingPropertyFixture(value: Int) -> Bool {
      return String(value) == ""
    }
    """
  }

  func ruleBasedMacroFixtureSource() -> String {
    """
    import Foundation
    import InvariantSwiftTesting
    import InvariantSwiftMacroAPI
    import Testing

    @RuleBasedTest(maxSteps: 3, maxExamples: 2)
    struct CounterFixture: Sendable {
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

    @Test("rule based macro fixture runs")
    @MainActor
    func verifyRuleBasedFixture() async throws {
      try await CounterFixture.runTest()
      #expect(!CounterFixture.rules.isEmpty)
      #expect(!CounterFixture.invariants.isEmpty)
    }
    """
  }
}
