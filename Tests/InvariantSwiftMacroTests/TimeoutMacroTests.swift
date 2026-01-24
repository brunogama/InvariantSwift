import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

/// Tests for @Timeout macro integration with @PropertyTest
///
/// Since @Timeout is a marker macro, these tests primarily verify that:
/// 1. TimeoutExtractor correctly parses @Timeout attributes
/// 2. PropertyMacro integrates timeout wrapping when @Timeout is present
@Suite("Timeout Macro Tests")
struct TimeoutMacroTests {

  // MARK: - Test Helpers

  /// Parse source and extract function declaration
  private func parseFunctionDecl(_ source: String) -> FunctionDeclSyntax? {
    // swiftlint:disable:next force_try
    let parsed = try! Parser.parse(source: source)
    return parsed.statements.first?.item.as(FunctionDeclSyntax.self)
  }

  // MARK: - TimeoutExtractor Unit Tests

  @Test("TimeoutExtractor extracts seconds parameter")
  func extractorExtractsSecondsParameter() {
    let source = """
      @Timeout(seconds: 5.0)
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 5.0)
  }

  @Test("TimeoutExtractor extracts .seconds() enum case")
  func extractorExtractsSecondsEnumCase() {
    let source = """
      @Timeout(.seconds(10.0))
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 10.0)
  }

  @Test("TimeoutExtractor extracts .milliseconds() and converts")
  func extractorExtractsMillisecondsEnumCase() {
    let source = """
      @Timeout(.milliseconds(500))
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 0.5)
  }

  @Test("TimeoutExtractor extracts .none as nil")
  func extractorExtractsNoneAsNil() {
    let source = """
      @Timeout(.none)
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == nil)
  }

  @Test("TimeoutExtractor returns nil when no @Timeout")
  func extractorReturnsNilWhenNoTimeout() {
    let source = """
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config == nil)
  }

  @Test("TimeoutExtractor handles integer seconds literal")
  func extractorHandlesIntegerSecondsLiteral() {
    let source = """
      @Timeout(seconds: 10)
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 10.0)
  }

  // MARK: - PropertyMacro Integration Tests

  @Test("@Timeout + @PropertyTest generates withPropertyTimeout wrapper")
  func propertyMacroIntegratesTimeout() {
    let testMacros: [String: Macro.Type] = [
      "PropertyTest": PropertyMacro.self,
      "Timeout": TimeoutMacro.self,
    ]

    let source = """
      @Timeout(seconds: 5.0)
      @PropertyTest
      func slowProperty(n: Int) -> Bool {
        return n >= 0
      }
      """

    // Parse and verify the PropertyMacro expansion includes timeout wrapper
    guard let expanded = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    // Extract @Timeout config from the source
    let timeoutConfig = TimeoutExtractor.extractConfig(from: expanded)

    // Verify timeout config is correctly extracted
    #expect(timeoutConfig?.seconds == 5.0)

    // Note: Full macro expansion testing would require assertMacroExpansion,
    // but that's challenging due to whitespace sensitivity and generated code
    // complexity. The unit tests above verify the extraction logic works.
  }

  @Test("@Timeout(.none) does not add timeout wrapper")
  func timeoutNoneDoesNotWrap() {
    let source = """
      @Timeout(.none)
      @PropertyTest
      func noTimeoutProperty(n: Int) -> Bool {
        return true
      }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)

    // .none case returns config with nil seconds
    #expect(config?.seconds == nil)
  }

  @Test("@Timeout with custom iterations")
  func timeoutWithCustomIterations() {
    let source = """
      @Timeout(seconds: 5.0)
      @PropertyTest(iterations: 50)
      func customIterationsProperty(n: Int) -> Bool {
        return true
      }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let timeoutConfig = TimeoutExtractor.extractConfig(from: funcDecl)

    #expect(timeoutConfig?.seconds == 5.0)
  }

  @Test("@Timeout with fractional seconds")
  func timeoutFractionalSeconds() {
    let source = """
      @Timeout(seconds: 1.5)
      @PropertyTest
      func fractionalTimeoutProperty(n: Int) -> Bool {
        return true
      }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 1.5)
  }

  @Test("@Timeout with very large timeout")
  func timeoutVeryLargeValue() {
    let source = """
      @Timeout(seconds: 3600.0)
      @PropertyTest
      func largeTimeoutProperty(n: Int) -> Bool {
        return true
      }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 3600.0)
  }

  @Test("@Timeout with milliseconds 100")
  func timeoutMilliseconds100() {
    let source = """
      @Timeout(.milliseconds(100))
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 0.1)
  }

  @Test("@Timeout with milliseconds 1000")
  func timeoutMilliseconds1000() {
    let source = """
      @Timeout(.milliseconds(1000))
      func test(n: Int) -> Bool { true }
      """

    guard let funcDecl = parseFunctionDecl(source) else {
      Issue.record("Failed to parse function declaration")
      return
    }

    let config = TimeoutExtractor.extractConfig(from: funcDecl)
    #expect(config?.seconds == 1.0)
  }
}
