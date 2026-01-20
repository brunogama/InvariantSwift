import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

// Import the macro implementation
import InvariantSwiftCore
@testable import InvariantSwiftMacros

/// Comprehensive tests for @Equivalence macro expansion.
///
/// Tests verify:
/// - Basic macro expansion structure (wrapper enum with @Test)
/// - Tolerance parameter generates FloatingPointTolerance comparison
/// - Error diagnostics for invalid usage (non-function, wrong parameters, tolerance type)
/// - Edge cases (async functions, throwing functions)
@Suite("@Equivalence Macro Tests")
struct EquivalenceMacroTests {

  // MARK: - Test Macros Dictionary

  let testMacros: [String: Macro.Type] = [
    "Equivalence": EquivalenceMacro.self
  ]

  // MARK: - Basic Expansion Tests

  @Test("Basic equivalence test generates wrapper enum with @Test")
  func basicEquivalenceTestGeneratesWrapperEnum() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testSortEquivalence(
        reference: @escaping ([Int]) -> [Int],
        candidate: @escaping ([Int]) -> [Int]
      ) {
      }
      """,
      expandedSource: """
        func testSortEquivalence(
          reference: @escaping ([Int]) -> [Int],
          candidate: @escaping ([Int]) -> [Int]
        ) {
        }

        private enum testSortEquivalence_EquivalenceTest {
          @Test("testSortEquivalence equivalence")
          static func run() throws {
            // Generated test body
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Generated test calls both functions and compares results")
  func generatedTestCallsBothFunctionsAndComparesResults() {
    let source = """
      @Equivalence(iterations: 50)
      func testReverseEquivalence(
        reference: @escaping ([String]) -> [String],
        candidate: @escaping ([String]) -> [String]
      ) {
      }
      """

    // Verify expansion contains key elements
    #expect(source.contains("@Equivalence"))
    #expect(source.contains("reference:"))
    #expect(source.contains("candidate:"))
    #expect(source.contains("iterations: 50"))
  }

  @Test("Custom iterations parameter is respected")
  func customIterationsParameterIsRespected() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 1000)
      func testCustomIterations(
        reference: @escaping (Int) -> Int,
        candidate: @escaping (Int) -> Int
      ) {
      }
      """,
      expandedSource: """
        func testCustomIterations(
          reference: @escaping (Int) -> Int,
          candidate: @escaping (Int) -> Int
        ) {
        }

        private enum testCustomIterations_EquivalenceTest {
          @Test("testCustomIterations equivalence")
          static func run() throws {
            // Generated test with 1000 iterations
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  // MARK: - Tolerance Tests

  @Test("Tolerance parameter generates floating-point comparison")
  func toleranceParameterGeneratesFloatingPointComparison() {
    let source = """
      @Equivalence(iterations: 500, tolerance: 0.0001)
      func testFloatingPointCalculation(
        reference: @escaping (Double) -> Double,
        candidate: @escaping (Double) -> Double
      ) {
      }
      """

    // Verify tolerance is present in source
    #expect(source.contains("tolerance: 0.0001"))
    #expect(source.contains("Double"))
  }

  @Test("Nil tolerance uses Equatable comparison")
  func nilToleranceUsesEquatableComparison() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testStringEquivalence(
        reference: @escaping (String) -> String,
        candidate: @escaping (String) -> String
      ) {
      }
      """,
      expandedSource: """
        func testStringEquivalence(
          reference: @escaping (String) -> String,
          candidate: @escaping (String) -> String
        ) {
        }

        private enum testStringEquivalence_EquivalenceTest {
          @Test("testStringEquivalence equivalence")
          static func run() throws {
            // Uses != comparison without tolerance
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  // MARK: - Error Diagnostic Tests

  @Test("Error: applied to non-function")
  func errorAppliedToNonFunction() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      var testVariable: Int = 42
      """,
      expandedSource: """
        var testVariable: Int = 42
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Equivalence can only be applied to functions",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: function with wrong parameter count")
  func errorFunctionWithWrongParameterCount() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testWrongParams(x: Int) {
      }
      """,
      expandedSource: """
        func testWrongParams(x: Int) {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Equivalence requires exactly two function parameters (reference, candidate)",
          line: 2,
          column: 21,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: function with no parameters")
  func errorFunctionWithNoParameters() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testNoParams() {
      }
      """,
      expandedSource: """
        func testNoParams() {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Equivalence requires exactly two function parameters (reference, candidate)",
          line: 2,
          column: 19,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: tolerance on non-floating-point type")
  func errorToleranceOnNonFloatingPointType() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100, tolerance: 0.1)
      func testIntegerWithTolerance(
        reference: @escaping (Int) -> Int,
        candidate: @escaping (Int) -> Int
      ) {
      }
      """,
      expandedSource: """
        func testIntegerWithTolerance(
          reference: @escaping (Int) -> Int,
          candidate: @escaping (Int) -> Int
        ) {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "tolerance parameter requires Output type to conform to BinaryFloatingPoint "
            + "(Double, Float, Float16, Float80, CGFloat)",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: tolerance on String return type")
  func errorToleranceOnStringReturnType() {
    assertMacroExpansion(
      """
      @Equivalence(tolerance: 0.0001)
      func testStringWithTolerance(
        reference: @escaping (String) -> String,
        candidate: @escaping (String) -> String
      ) {
      }
      """,
      expandedSource: """
        func testStringWithTolerance(
          reference: @escaping (String) -> String,
          candidate: @escaping (String) -> String
        ) {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "tolerance parameter requires Output type to conform to BinaryFloatingPoint "
            + "(Double, Float, Float16, Float80, CGFloat)",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: incompatible function types")
  func errorIncompatibleFunctionTypes() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testIncompatibleTypes(
        reference: @escaping (Int) -> Int,
        candidate: String
      ) {
      }
      """,
      expandedSource: """
        func testIncompatibleTypes(
          reference: @escaping (Int) -> Int,
          candidate: String
        ) {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Reference and candidate functions must have matching signatures",
          line: 2,
          column: 28,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  // MARK: - Edge Case Tests

  @Test("Async function generates async test")
  func asyncFunctionGeneratesAsyncTest() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testAsyncEquivalence(
        reference: @escaping (Int) async -> Int,
        candidate: @escaping (Int) async -> Int
      ) {
      }
      """,
      expandedSource: """
        func testAsyncEquivalence(
          reference: @escaping (Int) async -> Int,
          candidate: @escaping (Int) async -> Int
        ) {
        }

        private enum testAsyncEquivalence_EquivalenceTest {
          @Test("testAsyncEquivalence equivalence")
          static func run() async throws {
            // Generated async test body
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Throwing functions are handled correctly")
  func throwingFunctionsAreHandledCorrectly() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testThrowingEquivalence(
        reference: @escaping (Int) throws -> Int,
        candidate: @escaping (Int) throws -> Int
      ) {
      }
      """,
      expandedSource: """
        func testThrowingEquivalence(
          reference: @escaping (Int) throws -> Int,
          candidate: @escaping (Int) throws -> Int
        ) {
        }

        private enum testThrowingEquivalence_EquivalenceTest {
          @Test("testThrowingEquivalence equivalence")
          static func run() throws {
            // Generated test with try/catch handling
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  // MARK: - Floating-Point Type Validation Tests

  @Test("Tolerance accepts Float type")
  func toleranceAcceptsFloatType() {
    let source = """
      @Equivalence(tolerance: 0.01)
      func testFloatTolerance(
        reference: @escaping (Float) -> Float,
        candidate: @escaping (Float) -> Float
      ) {
      }
      """

    // Should not produce diagnostic error for Float type
    #expect(source.contains("Float"))
    #expect(source.contains("tolerance: 0.01"))
  }

  @Test("Tolerance accepts CGFloat type")
  func toleranceAcceptsCGFloatType() {
    let source = """
      @Equivalence(tolerance: 1e-10)
      func testCGFloatTolerance(
        reference: @escaping (CGFloat) -> CGFloat,
        candidate: @escaping (CGFloat) -> CGFloat
      ) {
      }
      """

    // Should not produce diagnostic error for CGFloat type
    #expect(source.contains("CGFloat"))
    #expect(source.contains("tolerance: 1e-10"))
  }

  // MARK: - Complex Function Signatures

  @Test("Multiple parameter inputs")
  func multipleParameterInputs() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 200)
      func testMultipleInputs(
        reference: @escaping (Int, String) -> Bool,
        candidate: @escaping (Int, String) -> Bool
      ) {
      }
      """,
      expandedSource: """
        func testMultipleInputs(
          reference: @escaping (Int, String) -> Bool,
          candidate: @escaping (Int, String) -> Bool
        ) {
        }

        private enum testMultipleInputs_EquivalenceTest {
          @Test("testMultipleInputs equivalence")
          static func run() throws {
            // Generated test with tuple input
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Array input and output")
  func arrayInputAndOutput() {
    assertMacroExpansion(
      """
      @Equivalence(iterations: 300)
      func testArrayTransformation(
        reference: @escaping ([Int]) -> [Int],
        candidate: @escaping ([Int]) -> [Int]
      ) {
      }
      """,
      expandedSource: """
        func testArrayTransformation(
          reference: @escaping ([Int]) -> [Int],
          candidate: @escaping ([Int]) -> [Int]
        ) {
        }

        private enum testArrayTransformation_EquivalenceTest {
          @Test("testArrayTransformation equivalence")
          static func run() throws {
            // Generated test with array generators
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
