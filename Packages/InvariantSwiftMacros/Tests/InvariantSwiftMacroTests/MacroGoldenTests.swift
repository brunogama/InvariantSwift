import XCTest
import SwiftParser
import SwiftSyntaxMacroExpansion
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

  func testPropertyTestWithTraitsGolden() throws {
    try assertGolden(
      macro: "PropertyTest",
      testCase: "WithTraits"
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

    if ProcessInfo.processInfo.environment["INVARIANTSWIFT_RECORD_GOLDEN"] == "1" {
      try record(expansionOf: sourceContent, macro: macro, testCase: testCase, file: file)
      return
    }

    // Perform expansion assertion
    assertMacroExpansion(
      sourceContent,
      expandedSource: goldenContent,
      macros: testMacros,
      file: file,
      line: line
    )
  }

  /// Expands `source` and writes the result over the checked-in golden file.
  ///
  /// Run `INVARIANTSWIFT_RECORD_GOLDEN=1 swift test --package-path Packages/InvariantSwiftMacros
  /// --filter MacroGoldenTests` after deliberately changing a macro's output, then read the
  /// diff before committing it. Without this the goldens can only be edited by hand, which is
  /// how they came to disagree with every expansion they describe.
  ///
  /// The expansion below is the one `assertMacroExpansion` performs, so what is recorded is
  /// what the assertion will compare against.
  private func record(
    expansionOf source: String,
    macro: String,
    testCase: String,
    file: StaticString
  ) throws {
    let parsed = Parser.parse(source: source)
    let context = BasicMacroExpansionContext(
      sourceFiles: [parsed: .init(moduleName: "TestModule", fullFilePath: "test.swift")]
    )
    let expanded = parsed.expand(
      macroSpecs: testMacros.mapValues { MacroSpec(type: $0) },
      contextGenerator: { syntax in
        BasicMacroExpansionContext(
          sharingWith: context,
          lexicalContext: syntax.allMacroLexicalContexts()
        )
      },
      indentationWidth: .spaces(4)
    )

    // Bundle.module points at the copy inside the build products, so derive the
    // source path from this file's location instead.
    let destination = URL(fileURLWithPath: "\(file)")
      .deletingLastPathComponent()
      .appendingPathComponent("Resources/Golden/\(macro)/\(testCase).golden.swift")

    let text = expanded.description.drop(while: \.isNewline)
    try (String(text).trimmingTrailingNewlines() + "\n")
      .write(to: destination, atomically: true, encoding: .utf8)
    print("recorded golden: \(destination.path)")
  }
}

extension String {
  fileprivate func trimmingTrailingNewlines() -> String {
    var copy = self
    while copy.last?.isNewline == true { copy.removeLast() }
    return copy
  }
}
