import SwiftSyntax
import SwiftSyntaxBuilder
import Testing

@testable import InvariantSwiftMacros

@Suite("Generator inference type identity")
struct GeneratorInferenceTests {
  @Test("Custom member types keep their full qualification")
  func qualifiedCustomType() throws {
    let type = TypeSyntax(
      stringLiteral: "InvariantSwiftAdvanced.TelemetrySystem.EventType"
    )

    let generator = GeneratorInference.infer(for: type)

    #expect(
      generator.trimmedDescription
        == "InvariantSwiftAdvanced.TelemetrySystem.EventType.arbitrary"
    )
    let arbitraryAccess = try #require(generator.as(MemberAccessExprSyntax.self))
    let eventTypeAccess = try #require(arbitraryAccess.base?.as(MemberAccessExprSyntax.self))
    #expect(eventTypeAccess.declName.baseName.text == "EventType")
    #expect(eventTypeAccess.base?.is(MemberAccessExprSyntax.self) == true)
  }

  @Test("Qualified standard library types still use primitive generators")
  func qualifiedPrimitiveType() {
    let type = TypeSyntax(stringLiteral: "Swift.Int")

    let generator = GeneratorInference.infer(for: type)

    #expect(generator.trimmedDescription == "Gen<Int>.int")
  }
}
