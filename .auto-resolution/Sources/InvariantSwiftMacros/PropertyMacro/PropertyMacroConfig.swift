import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Property Macro Configuration

/// Extracted configuration from @Property attribute
public struct PropertyMacroConfig: Sendable {
  public let iterations: Int
  public let seed: UInt64?
  public let maxShrinks: Int
  public let verbose: Bool
  public let detectFlakiness: Bool
  public let flakeRuns: Int
  public let failOnFlaky: Bool

  public static let `default` = Self(
    iterations: 100,
    seed: nil,
    maxShrinks: 1000,
    verbose: false,
    detectFlakiness: false,
    flakeRuns: 100,
    failOnFlaky: false
  )

  public init(
    iterations: Int = 100,
    seed: UInt64? = nil,
    maxShrinks: Int = 1000,
    verbose: Bool = false,
    detectFlakiness: Bool = false,
    flakeRuns: Int = 100,
    failOnFlaky: Bool = false
  ) {
    self.iterations = iterations
    self.seed = seed
    self.maxShrinks = maxShrinks
    self.verbose = verbose
    self.detectFlakiness = detectFlakiness
    self.flakeRuns = flakeRuns
    self.failOnFlaky = failOnFlaky
  }
}

// MARK: - Configuration Extractor

/// Extracts configuration from @Property attribute arguments
public enum PropertyConfigExtractor {

  // swiftlint:disable:next orphaned_doc_comment
  /// Extract config from attribute syntax
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public static func extract(from attribute: AttributeSyntax) -> PropertyMacroConfig {
    guard case .argumentList(let arguments) = attribute.arguments else {
      return .default
    }

    var iterations = PropertyMacroConfig.default.iterations
    var seed: UInt64?
    var maxShrinks = PropertyMacroConfig.default.maxShrinks
    var verbose = PropertyMacroConfig.default.verbose
    var detectFlakiness = PropertyMacroConfig.default.detectFlakiness
    var flakeRuns = PropertyMacroConfig.default.flakeRuns
    var failOnFlaky = PropertyMacroConfig.default.failOnFlaky

    for argument in arguments {
      switch argument.label?.text {
      case "iterations":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          iterations = value
        }

      case "seed":
        if argument.expression.is(NilLiteralExprSyntax.self) {
          seed = nil
        } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = UInt64(intLiteral.literal.text)
        {
          seed = value
        }

      case "maxShrinks":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          maxShrinks = value
        }

      case "verbose":
        if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
          verbose = boolLiteral.literal.tokenKind == .keyword(.true)
        }

      case "detectFlakiness":
        if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
          detectFlakiness = boolLiteral.literal.tokenKind == .keyword(.true)
        }

      case "runs":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          flakeRuns = value
        }

      case "failOnFlaky":
        if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
          failOnFlaky = boolLiteral.literal.tokenKind == .keyword(.true)
        }

      default:
        break
      }
    }

    return PropertyMacroConfig(
      iterations: iterations,
      seed: seed,
      maxShrinks: maxShrinks,
      verbose: verbose,
      detectFlakiness: detectFlakiness,
      flakeRuns: flakeRuns,
      failOnFlaky: failOnFlaky
    )
  }
}
