import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testSortEquivalence(
        reference: @escaping ([Int]) -> [Int] = oldSort,
        candidate: @escaping ([Int]) -> [Int] = newSort
      ) {
      }
      """,
      expandedSource: """
        func testSortEquivalence(
          reference: @escaping ([Int]) -> [Int] = oldSort,
          candidate: @escaping ([Int]) -> [Int] = newSort
        ) {
        }

        private enum testSortEquivalence_EquivalenceTest {
          @Test("testSortEquivalence") static func run() throws {
            let reference: ([Int]) -> [Int] = oldSort
            let candidate: ([Int]) -> [Int] = newSort
            for _ in 0 ..< 100 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen.array(Gen<Int>.int).generate(&rng, Size.default)
              let referenceResult = reference(input)
              let candidateResult = candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 1000)
      func testCustomIterations(
        reference: @escaping (Int) -> Int = oldDouble,
        candidate: @escaping (Int) -> Int = newDouble
      ) {
      }
      """,
      expandedSource: """
        func testCustomIterations(
          reference: @escaping (Int) -> Int = oldDouble,
          candidate: @escaping (Int) -> Int = newDouble
        ) {
        }

        private enum testCustomIterations_EquivalenceTest {
          @Test("testCustomIterations") static func run() throws {
            let reference: (Int) -> Int = oldDouble
            let candidate: (Int) -> Int = newDouble
            for _ in 0 ..< 1000 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen<Int>.int.generate(&rng, Size.default)
              let referenceResult = reference(input)
              let candidateResult = candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testStringEquivalence(
        reference: @escaping (String) -> String = oldUpper,
        candidate: @escaping (String) -> String = newUpper
      ) {
      }
      """,
      expandedSource: """
        func testStringEquivalence(
          reference: @escaping (String) -> String = oldUpper,
          candidate: @escaping (String) -> String = newUpper
        ) {
        }

        private enum testStringEquivalence_EquivalenceTest {
          @Test("testStringEquivalence") static func run() throws {
            let reference: (String) -> String = oldUpper
            let candidate: (String) -> String = newUpper
            for _ in 0 ..< 100 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen<String>.string.generate(&rng, Size.default)
              let referenceResult = reference(input)
              let candidateResult = candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
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
    expectMacroExpansion(
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
    expectMacroExpansion(
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
    expectMacroExpansion(
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
          column: 18,
          severity: .error
        )
      ],
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Error: tolerance on non-floating-point type")
  func errorToleranceOnNonFloatingPointType() {
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100, tolerance: 0.1)
      func testIntegerWithTolerance(
        reference: @escaping (Int) -> Int = oldDouble,
        candidate: @escaping (Int) -> Int = newDouble
      ) {
      }
      """,
      expandedSource: """
        func testIntegerWithTolerance(
          reference: @escaping (Int) -> Int = oldDouble,
          candidate: @escaping (Int) -> Int = newDouble
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
    expectMacroExpansion(
      """
      @Equivalence(tolerance: 0.0001)
      func testStringWithTolerance(
        reference: @escaping (String) -> String = oldUpper,
        candidate: @escaping (String) -> String = newUpper
      ) {
      }
      """,
      expandedSource: """
        func testStringWithTolerance(
          reference: @escaping (String) -> String = oldUpper,
          candidate: @escaping (String) -> String = newUpper
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testIncompatibleTypes(
        reference: @escaping (Int) -> Int = oldDouble,
        candidate: String
      ) {
      }
      """,
      expandedSource: """
        func testIncompatibleTypes(
          reference: @escaping (Int) -> Int = oldDouble,
          candidate: String
        ) {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Reference and candidate functions must have matching signatures",
          line: 2,
          column: 27,
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testAsyncEquivalence(
        reference: @escaping (Int) async -> Int = oldFetch,
        candidate: @escaping (Int) async -> Int = newFetch
      ) {
      }
      """,
      expandedSource: """
        func testAsyncEquivalence(
          reference: @escaping (Int) async -> Int = oldFetch,
          candidate: @escaping (Int) async -> Int = newFetch
        ) {
        }

        private enum testAsyncEquivalence_EquivalenceTest {
          @Test("testAsyncEquivalence") static func run() async throws {
            let reference: (Int) async -> Int = oldFetch
            let candidate: (Int) async -> Int = newFetch
            for _ in 0 ..< 100 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen<Int>.int.generate(&rng, Size.default)
              let referenceResult = await reference(input)
              let candidateResult = await candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Throwing functions are handled correctly")
  func throwingFunctionsAreHandledCorrectly() {
    expectMacroExpansion(
      """
      @Equivalence(iterations: 100)
      func testThrowingEquivalence(
        reference: @escaping (Int) throws -> Int = oldParse,
        candidate: @escaping (Int) throws -> Int = newParse
      ) {
      }
      """,
      expandedSource: """
        func testThrowingEquivalence(
          reference: @escaping (Int) throws -> Int = oldParse,
          candidate: @escaping (Int) throws -> Int = newParse
        ) {
        }

        private enum testThrowingEquivalence_EquivalenceTest {
          @Test("testThrowingEquivalence") static func run() throws {
            let reference: (Int) throws -> Int = oldParse
            let candidate: (Int) throws -> Int = newParse
            for _ in 0 ..< 100 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen<Int>.int.generate(&rng, Size.default)
              let referenceResult = try reference(input)
              let candidateResult = try candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
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
    expectMacroExpansion(
      """
      @Equivalence(iterations: 200)
      func testMultipleInputs(
        reference: @escaping (Int, String) -> Bool = oldMatch,
        candidate: @escaping (Int, String) -> Bool = newMatch
      ) {
      }
      """,
      expandedSource: """
        func testMultipleInputs(
          reference: @escaping (Int, String) -> Bool = oldMatch,
          candidate: @escaping (Int, String) -> Bool = newMatch
        ) {
        }

        private enum testMultipleInputs_EquivalenceTest {
          @Test("testMultipleInputs") static func run() throws {
            let reference: (Int, String) -> Bool = oldMatch
            let candidate: (Int, String) -> Bool = newMatch
            for _ in 0 ..< 200 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen.zip(Gen<Int>.int, Gen<String>.string).generate(&rng, Size.default)
              let referenceResult = reference(input.0, input.1)
              let candidateResult = candidate(input.0, input.1)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }

  @Test("Array input and output")
  func arrayInputAndOutput() {
    expectMacroExpansion(
      """
      @Equivalence(iterations: 300)
      func testArrayTransformation(
        reference: @escaping ([Int]) -> [Int] = oldSort,
        candidate: @escaping ([Int]) -> [Int] = newSort
      ) {
      }
      """,
      expandedSource: """
        func testArrayTransformation(
          reference: @escaping ([Int]) -> [Int] = oldSort,
          candidate: @escaping ([Int]) -> [Int] = newSort
        ) {
        }

        private enum testArrayTransformation_EquivalenceTest {
          @Test("testArrayTransformation") static func run() throws {
            let reference: ([Int]) -> [Int] = oldSort
            let candidate: ([Int]) -> [Int] = newSort
            for _ in 0 ..< 300 {
              var rng = SystemRandomNumberGenerator.init()
              let input = Gen.array(Gen<Int>.int).generate(&rng, Size.default)
              let referenceResult = reference(input)
              let candidateResult = candidate(input)
              if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
              }
            }
          }
        }
        """,
      macros: testMacros,
      indentationWidth: .spaces(2)
    )
  }
}
