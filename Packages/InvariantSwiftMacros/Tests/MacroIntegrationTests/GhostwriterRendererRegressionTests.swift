import Foundation
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

    #expect(code.contains("func test5_Point_equatableSymmetric(a: Point, b: Point)"))
    #expect(code.contains("#expect"))
    #expect(code.contains("b == a"))
    #expect(CompileVerifier().verifySyntax(code: code, fileName: "PointTests.swift").success)
  }

  @Test("Negated order comparisons retain their operand grouping")
  func negatedComparisonGrouping() {
    let type = ExtractedTypeInfo(
      name: "Point",
      kind: "struct",
      sourceFile: "Point.swift",
      line: 1,
      conformances: ["Comparable"],
      hasArbitraryAttribute: false,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .public
    )
    let code = TestCodeGenerator().generateTest(for: type, pattern: .comparableAsymmetric)

    #expect(code.contains("!(b < a)"))
    #expect(CompileVerifier().verifySyntax(code: code, fileName: "PointTests.swift").success)
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
    #expect(file.contains("@Suite(\"Point Property Tests\")"))
    #expect(file.contains("private struct GhostwriterSuite_"))
    #expect(file.contains("  @PropertyTest func"))
  }

  @Test("Generated headers are stable and use project-relative source paths")
  func generatedHeadersAreStable() {
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Fixtures/Point.swift").path
    let generator = TestCodeGenerator()
    let first = generator.generateTestFile(types: [], sourceFile: source)
    let second = generator.generateTestFile(types: [], sourceFile: source)
    let otherSource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Fixtures/Other.swift").path
    let firstSuite = generator.plannedFile(types: [], sourceFile: source).suiteTypeName
    let otherSuite = generator.plannedFile(types: [], sourceFile: otherSource).suiteTypeName

    #expect(first == second)
    #expect(first.contains("// Source: Fixtures/Point.swift"))
    #expect(!first.contains("// Generated:"))
    #expect(firstSuite != otherSuite)
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
    #expect(
      result.code.contains(
        "extension Widget: InvariantSwiftCore.Generatable"
      )
    )
    #expect(result.code.contains("/* TODO: supply generator for CustomDependency */"))
    #expect(!result.code.contains("composer.generate(using: composer.generate(using:"))
    #expect(
      CompileVerifier().verifySyntax(code: result.code, fileName: "WidgetTests.swift").success
    )
  }
}
