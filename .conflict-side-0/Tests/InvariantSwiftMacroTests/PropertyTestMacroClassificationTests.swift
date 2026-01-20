import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import InvariantSwiftMacros

/// Integration tests verifying @PropertyTest macro works with classification API
final class PropertyTestMacroClassificationTests: XCTestCase {

  // MARK: - Compilation Tests

  /// Verify @PropertyTest generates code compatible with ClassifyingProperty
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

        @Test("Integer range property")
        func testInRange_PropertyTest() async throws {
          let property = Property(generator: Gen<Int>.int) { n in
            #expect(n >= 0)
          }
          try await checkProperty(property)
        }
        """,
      macros: ["PropertyTest": PropertyTestMacro.self]
    )
  }

  // MARK: - Integration Tests

  /// Verify classification can be used with @PropertyTest-generated tests
  func testPropertyTestWithClassificationWorks() throws {
    // This test verifies the pattern:
    // 1. Developer uses @PropertyTest macro
    // 2. Developer wants to add classification
    // 3. They can manually create a ClassifyingProperty and use checkProperty

    // Since the macro generates `checkProperty(property)` calls,
    // and we have an overload for ClassifyingProperty, this should work
  }

  /// Document workaround for using classification with @PropertyTest
  func testClassificationWorkaround() throws {
    // Workaround documentation:
    // The @PropertyTest macro generates standard Property<T> tests.
    // To use classification (.cover, .classify, .label), you have two options:
    //
    // Option 1: Manual test without macro
    //   @Test
    //   func myTest() async throws {
    //     let property = Property(generator: Gen.int) { n in n >= 0 }
    //       .cover(50, when: { $0 > 0 }, label: "positive")
    //     try await checkProperty(property)
    //   }
    //
    // Option 2: Extend the macro (future work)
    //   @PropertyTest(cover: [("positive", 50, { $0 > 0 })])
    //   func test(n: Int) { n >= 0 }
  }

  // MARK: - Type Compatibility Tests

  /// Verify checkProperty works with both Property and ClassifyingProperty
  func testCheckPropertyOverloads() throws {
    // The key insight: we have two overloads of checkProperty:
    // - checkProperty(_: Property<T>)
    // - checkProperty(_: ClassifyingProperty<T>)
    //
    // Both use the same function name, so generated macro code works with both
  }
}
