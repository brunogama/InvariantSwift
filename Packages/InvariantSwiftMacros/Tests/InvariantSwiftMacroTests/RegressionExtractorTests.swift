import SwiftSyntax
import Testing

@testable import InvariantSwiftMacros

@Suite("@Regression Extractor Tests")
struct RegressionExtractorTests {
  @Test("RegressionExtractor extracts default config when no args")
  func extractorDefaultConfig() {
    let source: DeclSyntax = """
      @Regression
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: functionDecl)
    #expect(config != nil)
    #expect(config?.replayFirst == true)
    #expect(config?.maxExamples == nil)
  }

  @Test("RegressionExtractor extracts replayFirst: false")
  func extractorReplayFirstFalse() {
    let source: DeclSyntax = """
      @Regression(replayFirst: false)
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: functionDecl)
    #expect(config != nil)
    #expect(config?.replayFirst == false)
  }

  @Test("RegressionExtractor extracts maxExamples")
  func extractorMaxExamples() {
    let source: DeclSyntax = """
      @Regression(maxExamples: 42)
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: functionDecl)
    #expect(config != nil)
    #expect(config?.maxExamples == 42)
  }

  @Test("RegressionExtractor extracts exposeCasesAsTests")
  func extractorExposeCasesAsTests() {
    let source: DeclSyntax = """
      @Regression(exposeCasesAsTests: true)
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: functionDecl)
    #expect(config != nil)
    #expect(config?.exposeCasesAsTests == true)
  }

  @Test("RegressionExtractor returns nil when no @Regression")
  func extractorNoAttribute() {
    let source: DeclSyntax = """
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    let config = RegressionExtractor.extractConfig(from: functionDecl)
    #expect(config == nil)
  }

  @Test("hasRegressionAttribute returns true when present")
  func hasRegressionAttributeTrue() {
    let source: DeclSyntax = """
      @Regression
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    #expect(RegressionExtractor.hasRegressionAttribute(functionDecl) == true)
  }

  @Test("hasRegressionAttribute returns false when absent")
  func hasRegressionAttributeFalse() {
    let source: DeclSyntax = """
      func test(x: Int) -> Bool { x > 0 }
      """
    guard let functionDecl = source.as(FunctionDeclSyntax.self) else {
      Issue.record("Failed to parse function")
      return
    }

    #expect(RegressionExtractor.hasRegressionAttribute(functionDecl) == false)
  }
}
