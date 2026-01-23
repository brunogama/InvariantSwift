import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Foundation
@testable import InvariantSwiftMacros
import InvariantSwiftCore

final class MacroGoldenTests: XCTestCase {
  let testMacros: [String: Macro.Type] = [
    "PropertyTest": PropertyTestMacro.self,
    "Arbitrary": ArbitraryMacro.self,
    "Gen": GenMacro.self,
    "Label": LabelMacro.self,
  ]

  func testPropertyTestBasicGolden() throws {
    try assertGolden(
      macro: "PropertyTest",
      testCase: "Basic"
    )
  }

  func testArbitraryStructGolden() throws {
    try assertGolden(
      macro: "Arbitrary",
      testCase: "Struct"
    )
  }

  func testPropertyTestComplexGolden() throws {
    try assertGolden(
      macro: "PropertyTest",
      testCase: "Complex"
    )
  }

  func testPropertyTestWithConfigGolden() throws {
    try assertGolden(
      macro: "PropertyTest",
      testCase: "WithConfig"
    )
  }

  func testPropertyTestAsyncGolden() throws {
    try assertGolden(
      macro: "PropertyTest",
      testCase: "Async"
    )
  }

  func testArbitraryEnumGolden() throws {
    try assertGolden(
      macro: "Arbitrary",
      testCase: "Enum"
    )
  }

  func testArbitraryWithOptionalGolden() throws {
    try assertGolden(
      macro: "Arbitrary",
      testCase: "WithOptional"
    )
  }

  func testGenSimpleParameterGolden() throws {
    try assertGolden(
      macro: "Gen",
      testCase: "SimpleParameter"
    )
  }

  func testGenMultipleParametersGolden() throws {
    try assertGolden(
      macro: "Gen",
      testCase: "MultipleParameters"
    )
  }

  func testLabelSimpleLabelGolden() throws {
    try assertGolden(
      macro: "Label",
      testCase: "SimpleLabel"
    )
  }

  // MARK: - Helper Methods

  /// Validates that a macro expansion matches the content of a golden file.
  ///
  /// - Parameters:
  ///   - macro: The name of the macro directory in Resources/Golden (e.g., "PropertyTest").
  ///   - testCase: The name of the test case file without extension (e.g., "Basic").
  private func assertGolden(
    macro: String,
    testCase: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    // Locate source and golden files
    guard
      let sourceURL = Bundle.module.url(
        forResource: testCase,
        withExtension: "swift",
        subdirectory: "Resources/Golden/\(macro)"
      )
    else {
      XCTFail("Could not find source file for \(macro)/\(testCase)", file: file, line: line)
      return
    }

    guard
      let goldenURL = Bundle.module.url(
        forResource: testCase,
        withExtension: "golden.swift",
        subdirectory: "Resources/Golden/\(macro)"
      )
    else {
      XCTFail("Could not find golden file for \(macro)/\(testCase)", file: file, line: line)
      return
    }

    // Read file contents
    let sourceContent = try String(contentsOf: sourceURL, encoding: .utf8)
    let goldenContent = try String(contentsOf: goldenURL, encoding: .utf8)

    // Perform expansion assertion
    assertMacroExpansion(
      sourceContent,
      expandedSource: goldenContent,
      macros: testMacros,
      file: file,
      line: line
    )
  }
}
