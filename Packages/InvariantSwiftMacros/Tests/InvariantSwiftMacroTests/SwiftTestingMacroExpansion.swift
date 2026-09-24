import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// `assertMacroExpansion` for suites written against Swift Testing.
///
/// The version in SwiftSyntaxMacrosTestSupport reports through XCTest, so calling it
/// from a `@Test` function makes Swift Testing record "An API was misused: Replace
/// XCTest API such as 'XCTAssert' with a Swift Testing equivalent" alongside whatever
/// the test was actually checking. That came to 112 warnings in this target, which is
/// enough noise to hide a real one.
///
/// SwiftSyntaxMacrosGenericTestSupport does the same comparison but hands failures to
/// a closure instead of assuming a test framework, so this reports them as `Issue`s.
/// Failures now carry the calling test's source location rather than this file's.
///
/// The XCTest-based suites in this target keep using the XCTest version; it is correct
/// for them and warns about nothing.
func expectMacroExpansion(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  macros: [String: Macro.Type],
  applyFixIts: [String]? = nil,
  fixedSource expectedFixedSource: String? = nil,
  testModuleName: String = "TestModule",
  testFileName: String = "test.swift",
  indentationWidth: Trivia = .spaces(4),
  sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
  assertMacroExpansion(
    originalSource,
    expandedSource: expectedExpandedSource,
    diagnostics: diagnostics,
    macroSpecs: macros.mapValues { MacroSpec(type: $0) },
    applyFixIts: applyFixIts,
    fixedSource: expectedFixedSource,
    testModuleName: testModuleName,
    testFileName: testFileName,
    indentationWidth: indentationWidth,
    failureHandler: { failure in
      Issue.record(Comment(rawValue: failure.message), sourceLocation: sourceLocation)
    }
  )
}
