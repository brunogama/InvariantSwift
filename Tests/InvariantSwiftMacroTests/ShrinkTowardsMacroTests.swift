import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

/// Tests for @ShrinkTowards macro.
///
/// @ShrinkTowards is a marker macro that PropertyMacro extracts metadata from.
/// These tests verify the macro compiles correctly and can be used on parameters.
@Suite("@ShrinkTowards Macro Tests")
struct ShrinkTowardsMacroTests {

  let testMacros: [String: Macro.Type] = [
    "ShrinkTowards": ShrinkTowardsMacro.self
  ]

  // MARK: - Basic Macro Expansion Tests

  @Test("@ShrinkTowards(0) on Int parameter accepts correctly")
  func testIntegerShrinkTowardsZero() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(0)
      var count: Int
      """,
      expandedSource: """
        var count: Int
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards(1) on Int parameter accepts correctly")
  func testIntegerShrinkTowardsOne() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(1)
      var count: Int
      """,
      expandedSource: """
        var count: Int
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards(\"\") on String parameter accepts correctly")
  func testStringShrinkTowardsEmpty() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards("")
      var name: String
      """,
      expandedSource: """
        var name: String
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards(\"test\") on String parameter accepts correctly")
  func testStringShrinkTowardsValue() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards("test")
      var name: String
      """,
      expandedSource: """
        var name: String
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards(0.0) on Double parameter accepts correctly")
  func testDoubleShrinkTowardsZero() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(0.0)
      var value: Double
      """,
      expandedSource: """
        var value: Double
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards(true) on Bool parameter accepts correctly")
  func testBoolShrinkTowardsTrue() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(true)
      var flag: Bool
      """,
      expandedSource: """
        var flag: Bool
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards on negative integer")
  func testNegativeInteger() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(-10)
      var offset: Int
      """,
      expandedSource: """
        var offset: Int
        """,
      macros: testMacros
    )
  }

  @Test("@ShrinkTowards on large integer")
  func testLargeInteger() throws {
    assertMacroExpansion(
      """
      @ShrinkTowards(100)
      var maximum: Int
      """,
      expandedSource: """
        var maximum: Int
        """,
      macros: testMacros
    )
  }

  // MARK: - ShrinkHintExtractor Tests

  @Test("Extract hint from parameter with integer target")
  func testExtractIntegerHint() {
    let source = """
      func test(@ShrinkTowards(10) count: Int) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.count == 1)
    #expect(hints[0].parameterName == "count")
    #expect(hints[0].targetValue == "10")
    #expect(hints[0].targetType == "Int")
  }

  @Test("Extract hint from parameter with string target")
  func testExtractStringHint() {
    let source = """
      func test(@ShrinkTowards("test") name: String) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.count == 1)
    #expect(hints[0].parameterName == "name")
    #expect(hints[0].targetValue == "\"test\"")
    #expect(hints[0].targetType == "String")
  }

  @Test("Extract multiple hints from multiple parameters")
  func testExtractMultipleHints() {
    let source = """
      func test(
        @ShrinkTowards(0) min: Int,
        @ShrinkTowards(100) max: Int
      ) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.count == 2)
    #expect(hints[0].parameterName == "min")
    #expect(hints[0].targetValue == "0")
    #expect(hints[1].parameterName == "max")
    #expect(hints[1].targetValue == "100")
  }

  @Test("No hints extracted from unannotated parameters")
  func testNoHintsWithoutAnnotation() {
    let source = """
      func test(count: Int, name: String) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.isEmpty)
  }

  @Test("Extract hint from labeled parameter")
  func testExtractFromLabeledParameter() {
    let source = """
      func test(@ShrinkTowards(5) withCount count: Int) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.count == 1)
    #expect(hints[0].parameterName == "count")  // Internal name, not label
    #expect(hints[0].targetValue == "5")
  }

  @Test("Extract hint from unlabeled parameter")
  func testExtractFromUnlabeledParameter() {
    let source = """
      func test(@ShrinkTowards(42) _ value: Int) -> Bool {
        true
      }
      """

    guard let funcDecl = try? FunctionDeclSyntax(stringLiteral: source) else {
      Issue.record("Failed to parse function declaration")
      return
    }
    let hints = ShrinkHintExtractor.extractHints(from: funcDecl)

    #expect(hints.count == 1)
    #expect(hints[0].parameterName == "value")
    #expect(hints[0].targetValue == "42")
  }
}
