import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftParser
import XCTest
import InvariantCore
@testable import InvariantSwiftMacros

final class GenMacroDSLTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "Property": PropertyMacro.self,
    "Gen": GenMacro.self,
  ]

  func testPropertyWithGenFirstNameEmitsCorrectGenerator() {
    let source = """
      @Property
      func testUser(@Gen(.firstName) name: String) {
          #expect(!name.isEmpty)
      }
      """

    let sf = Parser.parse(source: source)
    let funcDecl = sf.statements.first!.item.as(FunctionDeclSyntax.self)!
    let params = ParameterExtractor.extract(from: funcDecl)

    XCTAssertEqual(params.count, 1)
    let generator = GenAttributeExtractor.resolveGenerator(for: params[0])
    XCTAssertEqual(generator.description, "Gen.fake.name.firstName")
  }

  func testPropertyWithGenFullPathEmailEmitsCorrectGenerator() {
    let source = """
      @Property
      func testEmail(@Gen(.fake.internet.email) email: String) {
          #expect(email.contains("@"))
      }
      """

    let sf = Parser.parse(source: source)
    let funcDecl = sf.statements.first!.item.as(FunctionDeclSyntax.self)!
    let params = ParameterExtractor.extract(from: funcDecl)

    XCTAssertEqual(params.count, 1)
    let generator = GenAttributeExtractor.resolveGenerator(for: params[0])
    XCTAssertEqual(generator.description, "Gen.fake.internet.email")
  }

  func testPropertyWithMultipleGenParamsEmitsCorrectGenerators() {
    let source = """
      @Property
      func testPerson(@Gen(.firstName) name: String, @Gen(.city) city: String) {
          #expect(!name.isEmpty)
          #expect(!city.isEmpty)
      }
      """

    let sf = Parser.parse(source: source)
    let funcDecl = sf.statements.first!.item.as(FunctionDeclSyntax.self)!
    let params = ParameterExtractor.extract(from: funcDecl)

    XCTAssertEqual(params.count, 2)

    let gen1 = GenAttributeExtractor.resolveGenerator(for: params[0])
    XCTAssertEqual(gen1.description, "Gen.fake.name.firstName")

    let gen2 = GenAttributeExtractor.resolveGenerator(for: params[1])
    XCTAssertEqual(gen2.description, "Gen.fake.address.city")
  }

  func testPropertyWithGenProductNameEmitsCorrectGenerator() {
    let source = """
      @Property
      func testProduct(@Gen(.fake.commerce.productName) product: String) {
          #expect(!product.isEmpty)
      }
      """

    let sf = Parser.parse(source: source)
    let funcDecl = sf.statements.first!.item.as(FunctionDeclSyntax.self)!
    let params = ParameterExtractor.extract(from: funcDecl)

    XCTAssertEqual(params.count, 1)
    let generator = GenAttributeExtractor.resolveGenerator(for: params[0])
    XCTAssertEqual(generator.description, "Gen.fake.commerce.productName")
  }

  func testPropertyWithGenShorthandParagraphEmitsCorrectGenerator() {
    let source = """
      @Property
      func testText(@Gen(.paragraph) text: String) {
          #expect(!text.isEmpty)
      }
      """

    let sf = Parser.parse(source: source)
    let funcDecl = sf.statements.first!.item.as(FunctionDeclSyntax.self)!
    let params = ParameterExtractor.extract(from: funcDecl)

    XCTAssertEqual(params.count, 1)
    let generator = GenAttributeExtractor.resolveGenerator(for: params[0])
    XCTAssertEqual(generator.description, "Gen.fake.lorem.paragraph")
  }

  func testParseShorthandFirstName() {
    let expr = parseExpr(".firstName")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.firstName) = parsed else {
      XCTFail("Expected .fake(.firstName), got \(String(describing: parsed))")
      return
    }
  }

  func testParseShorthandCity() {
    let expr = parseExpr(".city")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.city) = parsed else {
      XCTFail("Expected .fake(.city), got \(String(describing: parsed))")
      return
    }
  }

  func testParseShorthandUsername() {
    let expr = parseExpr(".username")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.username) = parsed else {
      XCTFail("Expected .fake(.username), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxFirstName() {
    let expr = parseExpr(".fake.name.firstName")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.firstName) = parsed else {
      XCTFail("Expected .fake(.firstName), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxEmail() {
    let expr = parseExpr(".fake.internet.email")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.email) = parsed else {
      XCTFail("Expected .fake(.email), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxCity() {
    let expr = parseExpr(".fake.address.city")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.city) = parsed else {
      XCTFail("Expected .fake(.city), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxCompanyName() {
    let expr = parseExpr(".fake.company.name")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.companyName) = parsed else {
      XCTFail("Expected .fake(.companyName), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxProductName() {
    let expr = parseExpr(".fake.commerce.productName")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.productName) = parsed else {
      XCTFail("Expected .fake(.productName), got \(String(describing: parsed))")
      return
    }
  }

  func testParseFakeChainSyntaxWord() {
    let expr = parseExpr(".fake.lorem.word")
    let parsed = GeneratorDSL.parseExpression(expr)
    guard case .fake(.word) = parsed else {
      XCTFail("Expected .fake(.word), got \(String(describing: parsed))")
      return
    }
  }

  private func parseExpr(_ source: String) -> ExprSyntax {
    let sourceFile = Parser.parse(source: "let _ = \(source)")
    let varDecl = sourceFile.statements.first!.item.as(VariableDeclSyntax.self)!
    return varDecl.bindings.first!.initializer!.value
  }

  private func parseAttribute(_ source: String) -> AttributeSyntax {
    let sourceFile = Parser.parse(source: "\(source) var x: Int")
    let varDecl = sourceFile.statements.first!.item.as(VariableDeclSyntax.self)!
    return varDecl.attributes.first!.as(AttributeSyntax.self)!
  }

  func testParseAttributeShorthandFirstName() {
    let attr = parseAttribute("@Gen(.firstName)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.firstName)")
      return
    }
    guard case .fake(.firstName) = parsed else {
      XCTFail("Expected .fake(.firstName), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.name.firstName")
  }

  func testParseAttributeFullPathFirstName() {
    let attr = parseAttribute("@Gen(.fake.name.firstName)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.fake.name.firstName)")
      return
    }
    guard case .fake(.firstName) = parsed else {
      XCTFail("Expected .fake(.firstName), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.name.firstName")
  }

  func testParseAttributeFullPathEmail() {
    let attr = parseAttribute("@Gen(.fake.internet.email)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.fake.internet.email)")
      return
    }
    guard case .fake(.email) = parsed else {
      XCTFail("Expected .fake(.email), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.internet.email")
  }

  func testParseAttributeShorthandCity() {
    let attr = parseAttribute("@Gen(.city)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.city)")
      return
    }
    guard case .fake(.city) = parsed else {
      XCTFail("Expected .fake(.city), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.address.city")
  }

  func testParseAttributeFullPathProductName() {
    let attr = parseAttribute("@Gen(.fake.commerce.productName)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.fake.commerce.productName)")
      return
    }
    guard case .fake(.productName) = parsed else {
      XCTFail("Expected .fake(.productName), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.commerce.productName")
  }

  func testParseAttributeShorthandCompanyName() {
    let attr = parseAttribute("@Gen(.companyName)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.companyName)")
      return
    }
    guard case .fake(.companyName) = parsed else {
      XCTFail("Expected .fake(.companyName), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.company.name")
  }

  func testParseAttributeShorthandSentence() {
    let attr = parseAttribute("@Gen(.sentence)")
    guard let parsed = GeneratorDSL.parse(from: attr) else {
      XCTFail("Failed to parse @Gen(.sentence)")
      return
    }
    guard case .fake(.sentence) = parsed else {
      XCTFail("Expected .fake(.sentence), got \(parsed)")
      return
    }
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.lorem.sentence")
  }

  func testParseFakeChainFirstName() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.firstName)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.name.firstName")
  }

  func testParseFakeChainEmail() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.email)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.internet.email")
  }

  func testParseFakeChainCity() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.city)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.address.city")
  }

  func testParseFakeChainCompanyName() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.companyName)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.company.name")
  }

  func testParseFakeChainProductName() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.productName)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.commerce.productName")
  }

  func testParseFakeChainWord() {
    let parsed = GeneratorDSL.ParsedGenerator.fake(.word)
    let code = GeneratorDSL.generateCode(for: parsed)
    XCTAssertEqual(code.description, "Gen.fake.lorem.word")
  }

  func testAllNameGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.firstName, "Gen.fake.name.firstName"),
      (.lastName, "Gen.fake.name.lastName"),
      (.fullName, "Gen.fake.name.fullName"),
      (.namePrefix, "Gen.fake.name.prefix"),
      (.nameSuffix, "Gen.fake.name.suffix"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }

  func testAllAddressGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.city, "Gen.fake.address.city"),
      (.streetName, "Gen.fake.address.streetName"),
      (.streetAddress, "Gen.fake.address.streetAddress"),
      (.zipCode, "Gen.fake.address.zipCode"),
      (.state, "Gen.fake.address.state"),
      (.country, "Gen.fake.address.country"),
      (.latitude, "Gen.fake.address.latitude"),
      (.longitude, "Gen.fake.address.longitude"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }

  func testAllInternetGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.email, "Gen.fake.internet.email"),
      (.username, "Gen.fake.internet.username"),
      (.domainName, "Gen.fake.internet.domainName"),
      (.url, "Gen.fake.internet.url"),
      (.ipV4Address, "Gen.fake.internet.ipV4Address"),
      (.ipV6Address, "Gen.fake.internet.ipV6Address"),
      (.password, "Gen.fake.internet.password"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }

  func testAllCompanyGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.companyName, "Gen.fake.company.name"),
      (.companySuffix, "Gen.fake.company.suffix"),
      (.catchPhrase, "Gen.fake.company.catchPhrase"),
      (.bs, "Gen.fake.company.bs"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }

  func testAllCommerceGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.productName, "Gen.fake.commerce.productName"),
      (.price, "Gen.fake.commerce.price"),
      (.color, "Gen.fake.commerce.color"),
      (.department, "Gen.fake.commerce.department"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }

  func testAllLoremGenerators() {
    let generators: [(GeneratorDSL.FakeGenerator, String)] = [
      (.word, "Gen.fake.lorem.word"),
      (.sentence, "Gen.fake.lorem.sentence"),
      (.paragraph, "Gen.fake.lorem.paragraph"),
    ]

    for (fakeGen, expected) in generators {
      let code = GeneratorDSL.generateCode(for: .fake(fakeGen))
      XCTAssertEqual(code.description, expected, "Failed for \(fakeGen)")
    }
  }
}
