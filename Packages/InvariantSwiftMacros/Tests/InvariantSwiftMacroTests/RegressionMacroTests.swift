import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

// MARK: - Test Macros

private let testMacros: [String: Macro.Type] = [
  "PropertyTest": PropertyTestMacro.self,
  "Property": PropertyMacro.self,
  "Regression": RegressionMacro.self,
  "Reproduce": ReproduceMacro.self,
]

// MARK: - Regression Macro Tests

@Suite("@Regression Macro Tests")
struct RegressionMacroTests {

  // MARK: - Basic Expansion

  @Test("@Regression with default parameters expands correctly")
  func testDefaultParameters() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression
      func testSorting(array: [Int]) -> Bool {
        array.sorted().isSorted
      }
      """,
      expandedSource: """
        func testSorting(array: [Int]) -> Bool {
          array.sorted().isSorted
        }

        private enum testSorting_PropertyTest {
          @Test(
            "testSorting",
            InvariantSwiftPropertyExecutionTrait(
              testName: "testSorting",
              labels: ["array"],
              configuredSeed: nil
            ),
            .tags(.invariantSwiftPropertyBased)
          ) static func run() throws {
            let generator: Gen<[Int]> = Gen<Int>.int.array()
            let property = Property(generator: generator) { (array: [Int]) in
              array.sorted().isSorted
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
              replayFirst: true
            )
            try executeGeneratedPropertyTest(
              property,
              config: config,
              testName: "testSorting",
              labels: ["array"],
              persistFailures: true
            )
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Regression with replayFirst: false expands correctly")
  func testReplayFirstFalse() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression(replayFirst: false)
      func testNoReplay(value: Int) -> Bool {
        value >= 0
      }
      """,
      expandedSource: """
        func testNoReplay(value: Int) -> Bool {
          value >= 0
        }

        private enum testNoReplay_PropertyTest {
          @Test(
            "testNoReplay",
            InvariantSwiftPropertyExecutionTrait(
              testName: "testNoReplay",
              labels: ["value"],
              configuredSeed: nil
            ),
            .tags(.invariantSwiftPropertyBased)
          ) static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { (value: Int) in
              value >= 0
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
              replayFirst: false
            )
            try executeGeneratedPropertyTest(
              property,
              config: config,
              testName: "testNoReplay",
              labels: ["value"],
              persistFailures: true
            )
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Regression with maxExamples expands correctly")
  func testMaxExamples() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression(maxExamples: 5)
      func testLimited(value: String) -> Bool {
        !value.isEmpty
      }
      """,
      expandedSource: """
        func testLimited(value: String) -> Bool {
          !value.isEmpty
        }

        private enum testLimited_PropertyTest {
          @Test(
            "testLimited",
            InvariantSwiftPropertyExecutionTrait(
              testName: "testLimited",
              labels: ["value"],
              configuredSeed: nil
            ),
            .tags(.invariantSwiftPropertyBased)
          ) static func run() throws {
            let generator: Gen<String> = Gen<String>.string
            let property = Property(generator: generator) { (value: String) in
              !value.isEmpty
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
              maxReplayExamples: 5
            )
            try executeGeneratedPropertyTest(
              property,
              config: config,
              testName: "testLimited",
              labels: ["value"],
              persistFailures: true
            )
          }
        }
        """,
      macros: testMacros
    )
  }


  // MARK: - Marker Macro Behavior

  @Test("@Regression alone returns empty (marker macro)")
  func testMarkerMacroReturnsEmpty() {
    assertMacroExpansion(
      """
      @Regression
      func standalone(value: Int) -> Bool {
        value > 0
      }
      """,
      expandedSource: """
        func standalone(value: Int) -> Bool {
          value > 0
        }
        """,
      macros: ["Regression": RegressionMacro.self]
    )
  }

  // MARK: - Mutual Exclusion

  @Test("@Regression and @Reproduce together emits diagnostic")
  func testMutualExclusion() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression
      @Reproduce(seed: 0xDEADBEEF)
      func testConflict(value: Int) -> Bool {
        value != 0
      }
      """,
      expandedSource: """
        func testConflict(value: Int) -> Bool {
          value != 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Reproduce and @Regression cannot be used together on the same function",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Edge Cases

  @Test("@Regression with async function expands correctly")
  func testAsyncFunction() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression
      func testAsync(value: Int) async -> Bool {
        await Task.yield()
        return value >= 0
      }
      """,
      expandedSource: """
        func testAsync(value: Int) async -> Bool {
          await Task.yield()
          return value >= 0
        }

        private enum testAsync_PropertyTest {
          @Test(
            "testAsync",
            InvariantSwiftPropertyExecutionTrait(
              testName: "testAsync",
              labels: ["value"],
              configuredSeed: nil
            ),
            .tags(.invariantSwiftPropertyBased)
          ) static func run() async throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { (value: Int) in
              await Task.yield()
              return value >= 0
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
              replayFirst: true
            )
            try await executeGeneratedPropertyTestAsync(
              property,
              config: config,
              testName: "testAsync",
              labels: ["value"],
              timeoutSeconds: nil,
              persistFailures: true
            )
          }
        }
        """,
      macros: testMacros
    )
  }

}
