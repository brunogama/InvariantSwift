import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import InvariantSwiftMacros

private let propertyFailurePattern =
  "case .failure(counterexample: let counterexample, iterations: let iterations, "
  + "shrunk: let shrunk, reason: _, seed: let seed):"
private let propertyFailureComment =
  #"Comment(rawValue: "Property failed after \(iterations) iterations. Original: "#
  + #"n=\(counterexample) | Shrunk: n=\(shrunk) | "# + #"Seed: \(seed.rawValue)")"#

/// Integration tests verifying @PropertyTest macro works with classification API
final class PropertyTestMacroClassificationTests: XCTestCase {

  // MARK: - Compilation Tests

  /// Verify @PropertyTest generates code compatible with ClassifyingProperty
  // swiftlint:disable vertical_whitespace_between_cases
  func testMacroGeneratesCompatibleCode() throws {
    // The @PropertyTest macro should generate code that works with both
    // Property<T> and ClassifyingProperty<T> since they share the same
    // checkProperty function interface

    assertMacroExpansion(
      """
      @PropertyTest("Integer range property")
      func testInRange(n: Int) {
        #expect(n >= 0)
      }
      """,
      expandedSource: """
        func testInRange(n: Int) {
          #expect(n >= 0)
        }

        private enum testInRange_PropertyTest {
            @Test("testInRange") static func run() throws {
                let generator: Gen<Int> = Gen<Int>.int
                let property = Property(generator: generator) { (n: Int) in
                  #expect(n >= 0)
                  return true
                }
                let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
                let result = runPropertySynchronously(property, config: config)
                switch result {
                case .success:
                    break
                \(propertyFailurePattern)
                    Issue.record(\(propertyFailureComment))
                case .gaveUp(discarded: _, iterations: _):
                    Issue.record(Comment(stringLiteral: "Property test gaveUp"))
                }
            }
        }
        """,
      macros: ["PropertyTest": PropertyTestMacro.self]
    )
  }
  // swiftlint:enable vertical_whitespace_between_cases
}
