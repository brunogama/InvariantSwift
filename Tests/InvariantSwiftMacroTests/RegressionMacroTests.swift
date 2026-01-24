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
          @Test("testSorting")
          static func run() throws {
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
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(
              counterexample: let counterexample,
              iterations: let iterations,
              shrunk: let shrunk,
              reason: _,
              seed: let seed
            ):
              Issue.record(
                Comment(
                  stringLiteral:
                    "Property failed after \\(iterations) iterations.\\n" +
                    "Counterexample: array = \\(counterexample)\\n" +
                    "Shrunk to: array = \\(shrunk)\\nSeed: \\(seed)"
                )
              )

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gaveUp"))
            }
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
          @Test("testNoReplay")
          static func run() throws {
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
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(
              counterexample: let counterexample,
              iterations: let iterations,
              shrunk: let shrunk,
              reason: _,
              seed: let seed
            ):
              Issue.record(
                Comment(
                  stringLiteral:
                    "Property failed after \\(iterations) iterations.\\n" +
                    "Counterexample: value = \\(counterexample)\\n" +
                    "Shrunk to: value = \\(shrunk)\\nSeed: \\(seed)"
                )
              )

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gaveUp"))
            }
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
          @Test("testLimited")
          static func run() throws {
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
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(
              counterexample: let counterexample,
              iterations: let iterations,
              shrunk: let shrunk,
              reason: _,
              seed: let seed
            ):
              Issue.record(
                Comment(
                  stringLiteral:
                    "Property failed after \\(iterations) iterations.\\n" +
                    "Counterexample: value = \\(counterexample)\\n" +
                    "Shrunk to: value = \\(shrunk)\\nSeed: \\(seed)"
                )
              )

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gaveUp"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Regression with all parameters expands correctly")
  func testAllParameters() {
    assertMacroExpansion(
      """
      @PropertyTest
      @Regression(replayFirst: true, maxExamples: 10)
      func testFull(x: Int, y: Int) -> Bool {
        x + y == y + x
      }
      """,
      expandedSource: """
        func testFull(x: Int, y: Int) -> Bool {
          x + y == y + x
        }

        private enum testFull_PropertyTest {
          @Test("testFull")
          static func run() throws {
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
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(
              counterexample: let counterexample,
              iterations: let iterations,
              shrunk: let shrunk,
              reason: _,
              seed: let seed
            ):
              Issue.record(
                Comment(
                  stringLiteral:
                    "Property failed after \\(iterations) iterations.\\n" +
                    "Counterexample: (x, y) = \\(counterexample)\\n" +
                    "Shrunk to: (x, y) = \\(shrunk)\\nSeed: \\(seed)"
                )
              )

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gaveUp"))
            }
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
          @Test("testAsync")
          static func run() async throws {
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
            let result = await runPropertyAsync(property, config: config)
            switch result {
            case .success:
              break

            case .failure(
              counterexample: let counterexample,
              iterations: let iterations,
              shrunk: let shrunk,
              reason: _,
              seed: let seed
            ):
              Issue.record(
                Comment(
                  stringLiteral:
                    "Property failed after \\(iterations) iterations.\\n" +
                    "Counterexample: value = \\(counterexample)\\n" +
                    "Shrunk to: value = \\(shrunk)\\nSeed: \\(seed)"
                )
              )

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gaveUp"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - RegressionExtractor Tests

  @Test("RegressionExtractor extracts default config when no args")
  func testExtractorDefaultConfig() {
    let source: DeclSyntax = """
      @Regression
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: funcDecl)
    #expect(config != nil)
    #expect(config?.replayFirst == true)
    #expect(config?.maxExamples == nil)
  }

  @Test("RegressionExtractor extracts replayFirst: false")
  func testExtractorReplayFirstFalse() {
    let source: DeclSyntax = """
      @Regression(replayFirst: false)
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: funcDecl)
    #expect(config != nil)
    #expect(config?.replayFirst == false)
  }

  @Test("RegressionExtractor extracts maxExamples")
  func testExtractorMaxExamples() {
    let source: DeclSyntax = """
      @Regression(maxExamples: 42)
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: funcDecl)
    #expect(config != nil)
    #expect(config?.maxExamples == 42)
  }

  @Test("RegressionExtractor returns nil when no @Regression")
  func testExtractorNoAttribute() {
    let source: DeclSyntax = """
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: funcDecl)
    #expect(config == nil)
  }

  @Test("hasRegressionAttribute returns true when present")
  func testHasRegressionAttributeTrue() {
    let source: DeclSyntax = """
      @Regression
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    #expect(RegressionExtractor.hasRegressionAttribute(funcDecl) == true)
  }

  @Test("hasRegressionAttribute returns false when absent")
  func testHasRegressionAttributeFalse() {
    let source: DeclSyntax = """
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let funcDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    #expect(RegressionExtractor.hasRegressionAttribute(funcDecl) == false)
  }
}
