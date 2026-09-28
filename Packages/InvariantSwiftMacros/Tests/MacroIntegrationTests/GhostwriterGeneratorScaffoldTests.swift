// MARK: - Ghostwriter Generator Scaffold Tests
// Tests for the `--generate-generators` scaffold output.

import Foundation
import Testing
@testable import GhostwriterLib

@Suite("Ghostwriter Generator Scaffold Tests")
struct GhostwriterGeneratorScaffoldTests {
  private let generator = TestCodeGenerator()

  private func failableInitType() -> ExtractedTypeInfo {
    ExtractedTypeInfo(
      name: "Money",
      kind: "struct",
      sourceFile: "Money.swift",
      line: 1,
      conformances: ["Hashable"],
      hasArbitraryAttribute: false,
      properties: [
        ExtractedProperty(
          name: "rawValue",
          typeName: "String",
          isOptional: false,
          isMutable: false,
          hasDefaultValue: false,
          accessLevel: .internal
        )
      ],
      methods: [
        ExtractedMethod(
          name: "init?",
          returnType: nil,
          parameters: [
            ExtractedParameter(label: "canonical", name: "canonical", typeName: "String")
          ],
          accessLevel: .public,
          isStatic: false,
          isMutating: false,
          isThrowing: false,
          isAsync: false
        )
      ],
      genericParameters: [],
      accessLevel: .public
    )
  }

  @Test("Scaffolds conform to the cross-module Generatable protocol")
  func scaffoldsConformToGeneratable() {
    let code = generator.generateGeneratorScaffold(for: failableInitType())

    #expect(code.contains("extension Money: InvariantSwiftCore.Generatable"))
    #expect(!code.contains("@retroactive"))
  }

  @Test("Scaffolds wrap guidance in a closed comment and compile")
  func scaffoldCommentIsClosedAndSyntaxValid() {
    let code = generator.generateGeneratorScaffold(for: failableInitType())

    #expect(code.contains("/* TODO: Ghostwriter scaffold:"))
    #expect(code.contains("*/"))
    #expect(code.contains("fatalError("))

    let opens = code.components(separatedBy: "/*").count - 1
    let closes = code.components(separatedBy: "*/").count - 1
    #expect(opens == closes, "unbalanced block comment in scaffold")

    #expect(
      CompileVerifier().verifySyntax(code: code, fileName: "MoneyGenerators.swift").success
    )
  }

  @Test("Scaffold guidance points at the validating initializer")
  func scaffoldGuidanceMentionsTheInitializer() {
    let code = generator.generateGeneratorScaffold(for: failableInitType())

    #expect(code.contains("plain memberwise initializer"))
    #expect(code.contains("validating initializer"))
  }

  @Test("Law tests for a user-provided conformance omit a duplicate extension")
  func userProvidedConformanceDoesNotDuplicate() throws {
    var type = failableInitType()
    type = SwiftSyntaxTypeExtractor.mergeConformances(
      types: [type],
      extensions: ["Money": ["InvariantSwiftCore.Generatable"]]
    ).first!

    let code = generator.generateTestFile(
      types: [type],
      sourceFile: "Money.swift",
      consumerModule: "Domain"
    )

    #expect(code.contains("test6_Domain_5_Money_equatableReflexive"))
    #expect(
      !code.contains("extension Money"),
      "law tests must not re-emit the user-provided conformance"
    )
  }
}
