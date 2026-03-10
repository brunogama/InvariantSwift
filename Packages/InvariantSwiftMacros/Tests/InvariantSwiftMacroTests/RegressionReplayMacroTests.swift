import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

private let replayTestMacros: [String: Macro.Type] = [
  "PropertyTest": PropertyTestMacro.self,
  "Property": PropertyMacro.self,
  "Regression": RegressionMacro.self,
]

private let allParametersSource = """
  @PropertyTest
  @Regression(replayFirst: true, maxExamples: 10)
  func testFull(x: Int, y: Int) -> Bool {
    x + y == y + x
  }
  """

private let allParametersExpansion = """
  func testFull(x: Int, y: Int) -> Bool {
    x + y == y + x
  }

  private enum testFull_PropertyTest {
    @Test(
      "testFull",
      InvariantSwiftPropertyExecutionTrait(
        testName: "testFull",
        labels: ["x", "y"],
        configuredSeed: nil
      ),
      .tags(.invariantSwiftPropertyBased)
    ) static func run() throws {
      let generator: Gen<(Int, Int)> = Gen<Int>.int.flatMap { x in
        Gen<Int>.int.map { y in (x, y) }
      }
      let property = Property(generator: generator) { (x: Int, y: Int) in
        let (x, y) = (x, y)
        x + y == y + x
        return true
      }
      let config = PropertyConfig(
        iterations: 100,
        maxShrinks: 1000,
        failingExampleDatabase: FailingExampleDatabase.shared,
        testIdentifier: TestIdentifier(
          module: "",
          file: String(describing: #file),
          function: String(describing: #function),
          signature: ""
        ),
        replayFirst: true,
        maxReplayExamples: 10
      )
      try executeGeneratedPropertyTest(
        property,
        config: config,
        testName: "testFull",
        labels: ["x", "y"],
        persistFailures: true
      )
    }
  }
  """

private let exposeCasesAsTestsSource = """
  @PropertyTest
  @Regression(exposeCasesAsTests: true, maxExamples: 2)
  func testReplayable(value: Int) -> Bool {
    value > 0
  }
  """

private let exposeCasesAsTestsExpansion = """
  func testReplayable(value: Int) -> Bool {
    value > 0
  }

  private enum testReplayable_PropertyTest {
    @Test(
      "testReplayable",
      InvariantSwiftPropertyExecutionTrait(
        testName: "testReplayable",
        labels: ["value"],
        configuredSeed: nil
      ),
      .tags(.invariantSwiftPropertyBased)
    ) static func run() throws {
      let generator: Gen<Int> = Gen<Int>.int
      let property = Property(generator: generator) { (value: Int) in
        value > 0
        return true
      }
      let config = PropertyConfig(
        iterations: 100,
        maxShrinks: 1000,
        failingExampleDatabase: FailingExampleDatabase.shared,
        testIdentifier: TestIdentifier(
          module: "",
          file: String(describing: #file),
          function: String(describing: #function),
          signature: ""
        ),
        replayFirst: true,
        maxReplayExamples: 2
      )
      try executeGeneratedPropertyTest(
        property,
        config: config,
        testName: "testReplayable",
        labels: ["value"],
        persistFailures: true
      )
    }

    @Test(
      "testReplayable regressions",
      InvariantSwiftPropertyExecutionTrait(
        testName: "testReplayable regressions",
        labels: ["value"],
        configuredSeed: nil
      ),
      .tags(
        .invariantSwiftPropertyBased,
        .invariantSwiftPropertyReplay
      ),
      arguments: try await FailurePersistenceManager().loadReplayFailures(
        forTest: "testReplayable",
        maxExamples: 2
      )
    ) static func replay(failure: PersistedFailure) throws {
      let generator: Gen<Int> = Gen<Int>.int
      let property = Property(generator: generator) { (value: Int) in
        value > 0
        return true
      }
      let config = PropertyConfig(
        iterations: 100,
        maxShrinks: 1000,
        failingExampleDatabase: FailingExampleDatabase.shared,
        testIdentifier: TestIdentifier(
          module: "",
          file: String(describing: #file),
          function: String(describing: #function),
          signature: ""
        ),
        replayFirst: true,
        maxReplayExamples: 2
      )
      try executePersistedFailureReplay(
        property,
        baseConfig: config,
        persistedFailure: failure,
        testName: "testReplayable",
        labels: ["value"]
      )
    }
  }
  """

@Suite("@Regression Replay Macro Tests")
struct RegressionReplayMacroTests {
  @Test("@Regression with all parameters expands correctly")
  func testAllParameters() {
    assertMacroExpansion(
      allParametersSource,
      expandedSource: allParametersExpansion,
      macros: replayTestMacros
    )
  }

  @Test("@Regression with exposeCasesAsTests generates replay wrapper")
  func testExposeCasesAsTests() {
    assertMacroExpansion(
      exposeCasesAsTestsSource,
      expandedSource: exposeCasesAsTestsExpansion,
      macros: replayTestMacros
    )
  }
}
