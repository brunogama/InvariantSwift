import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

import InvariantCore
@testable import InvariantSwiftMacros

final class SyntaxFactoryTests: XCTestCase {

  // MARK: - Identifier Tests

  func testIdentifier() {
    let token = SyntaxFactory.identifier("myVar")
    XCTAssertEqual(token.text, "myVar")
  }

  func testDeclRef() {
    let expr = SyntaxFactory.declRef("someVariable")
    XCTAssertEqual(expr.baseName.text, "someVariable")
  }

  func testMemberAccessWithBase() {
    let base = ExprSyntax(SyntaxFactory.declRef("object"))
    let access = SyntaxFactory.memberAccess(base: base, member: "property")

    XCTAssertEqual(access.declName.baseName.text, "property")
  }

  func testMemberAccessWithType() {
    let access = SyntaxFactory.memberAccess(type: "Gen", member: "int")

    // Should create Gen.int
    XCTAssertEqual(access.declName.baseName.text, "int")
    XCTAssertNotNil(access.base)
  }

  // MARK: - Type Syntax Tests

  func testSimpleType() {
    let type = SyntaxFactory.simpleType("Int")
    XCTAssertEqual(type.name.text, "Int")
  }

  func testGenericType() {
    let type = SyntaxFactory.genericType(
      "Gen",
      arguments: [TypeSyntax(SyntaxFactory.simpleType("Int"))]
    )

    // Verify the description contains the expected structure
    let description = type.trimmedDescription
    XCTAssertTrue(description.contains("Gen"))
    XCTAssertTrue(description.contains("Int"))
  }

  func testOptionalType() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = SyntaxFactory.optionalType(wrapped)

    XCTAssertEqual(optional.wrappedType.trimmedDescription, "String")
  }

  func testArrayType() {
    let element = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let array = SyntaxFactory.arrayType(element)

    XCTAssertEqual(array.element.trimmedDescription, "Int")
  }

  // MARK: - Literal Tests

  func testIntLiteral() {
    let literal = SyntaxFactory.intLiteral(42)
    XCTAssertEqual(literal.literal.text, "42")
  }

  func testStringLiteral() {
    let literal = SyntaxFactory.stringLiteral("hello")
    XCTAssertTrue(literal.description.contains("hello"))
  }

  func testBoolLiteralTrue() {
    let literal = SyntaxFactory.boolLiteral(true)
    XCTAssertEqual(literal.literal.tokenKind, .keyword(.true))
  }

  func testBoolLiteralFalse() {
    let literal = SyntaxFactory.boolLiteral(false)
    XCTAssertEqual(literal.literal.tokenKind, .keyword(.false))
  }

  func testNilLiteral() {
    let literal = SyntaxFactory.nilLiteral()
    XCTAssertTrue(literal.description.contains("nil"))
  }
}
