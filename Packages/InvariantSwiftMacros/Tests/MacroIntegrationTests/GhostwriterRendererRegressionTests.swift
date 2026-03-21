import Testing
@testable import GhostwriterLib

@Suite("Ghostwriter Renderer Regression Tests")
struct GhostwriterRendererRegressionTests {

  @Test("Generated property tests preserve planned parameters")
  func generatedPropertyTestsPreserveParameters() {
    let generator = TestCodeGenerator()
    let type = ExtractedTypeInfo(
      name: "Point",
      kind: "struct",
      sourceFile: "Point.swift",
      line: 1,
      conformances: ["Equatable"],
      hasArbitraryAttribute: false,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .public
    )

    let code = generator.generateTest(for: type, pattern: .equatableSymmetric)

    #expect(code.contains("func testPoint_equatableSymmetric(a: Point, b: Point)"))
    #expect(code.contains("#expect"))
    #expect(code.contains("b == a"))
  }

  @Test("Generated files include runtime and macro imports")
  func generatedFilesIncludeRuntimeAndMacroImports() {
    let generator = TestCodeGenerator()
    let file = generator.generateTestFile(
      types: [
        ExtractedTypeInfo(
          name: "Point",
          kind: "struct",
          sourceFile: "Point.swift",
          line: 1,
          conformances: ["Equatable"],
          hasArbitraryAttribute: false,
          properties: [],
          methods: [],
          genericParameters: [],
          accessLevel: .public
        )
      ],
      sourceFile: "Point.swift"
    )

    #expect(file.contains("import InvariantSwiftTesting"))
    #expect(file.contains("import InvariantSwiftMacroAPI"))
  }

  @Test("Generated arbitrary extensions emit TODO comments once")
  func generatedArbitraryExtensionsEmitTodoComments() {
    let generator = TestCodeGenerator()
    let type = ExtractedTypeInfo(
      name: "Widget",
      kind: "struct",
      sourceFile: "Widget.swift",
      line: 1,
      conformances: [],
      hasArbitraryAttribute: false,
      properties: [
        ExtractedProperty(
          name: "dependency",
          typeName: "CustomDependency",
          isOptional: false,
          isMutable: false,
          hasDefaultValue: false,
          accessLevel: .internal
        )
      ],
      methods: [],
      genericParameters: [],
      accessLevel: .internal
    )

    let result = generator.generateArbitraryExtensionResult(for: type)

    #expect(result.todoProperties == ["dependency"])
    #expect(result.code.contains("/* TODO: supply generator for CustomDependency */"))
    #expect(!result.code.contains("composer.generate(using: composer.generate(using:"))
  }
}
