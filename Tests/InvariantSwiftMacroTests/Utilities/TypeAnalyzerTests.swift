import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class TypeAnalyzerTests: XCTestCase {

  // MARK: - Type Name Extraction

  func testSimpleTypeName() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertEqual(TypeAnalyzer.typeName(from: type), "Int")
  }

  func testOptionalTypeName() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = TypeSyntax(SyntaxFactory.optionalType(wrapped))
    XCTAssertEqual(TypeAnalyzer.typeName(from: optional), "String?")
  }

  func testArrayTypeName() {
    let element = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let array = TypeSyntax(SyntaxFactory.arrayType(element))
    XCTAssertEqual(TypeAnalyzer.typeName(from: array), "[Int]")
  }

  // MARK: - Optional Detection

  func testIsOptionalWithOptionalSyntax() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = TypeSyntax(SyntaxFactory.optionalType(wrapped))
    XCTAssertTrue(TypeAnalyzer.isOptional(optional))
  }

  func testIsOptionalWithNonOptional() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertFalse(TypeAnalyzer.isOptional(type))
  }

  func testUnwrapOptional() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = TypeSyntax(SyntaxFactory.optionalType(wrapped))

    let unwrapped = TypeAnalyzer.unwrapOptional(optional)
    XCTAssertNotNil(unwrapped)
    XCTAssertEqual(unwrapped?.trimmedDescription, "String")
  }

  func testUnwrapNonOptional() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertNil(TypeAnalyzer.unwrapOptional(type))
  }

  // MARK: - Array Detection

  func testIsArrayWithArraySyntax() {
    let element = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let array = TypeSyntax(SyntaxFactory.arrayType(element))
    XCTAssertTrue(TypeAnalyzer.isArray(array))
  }

  func testIsArrayWithNonArray() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertFalse(TypeAnalyzer.isArray(type))
  }

  func testArrayElementType() {
    let element = TypeSyntax(SyntaxFactory.simpleType("String"))
    let array = TypeSyntax(SyntaxFactory.arrayType(element))

    let extracted = TypeAnalyzer.arrayElementType(array)
    XCTAssertNotNil(extracted)
    XCTAssertEqual(extracted?.trimmedDescription, "String")
  }

  // MARK: - Primitive Detection

  func testIsPrimitiveInt() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertTrue(TypeAnalyzer.isPrimitive(type))
  }

  func testIsPrimitiveString() {
    let type = TypeSyntax(SyntaxFactory.simpleType("String"))
    XCTAssertTrue(TypeAnalyzer.isPrimitive(type))
  }

  func testIsPrimitiveBool() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Bool"))
    XCTAssertTrue(TypeAnalyzer.isPrimitive(type))
  }

  func testIsPrimitiveDouble() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Double"))
    XCTAssertTrue(TypeAnalyzer.isPrimitive(type))
  }

  func testIsPrimitiveUUID() {
    let type = TypeSyntax(SyntaxFactory.simpleType("UUID"))
    XCTAssertTrue(TypeAnalyzer.isPrimitive(type))
  }

  func testIsNotPrimitiveCustomType() {
    let type = TypeSyntax(SyntaxFactory.simpleType("MyCustomType"))
    XCTAssertFalse(TypeAnalyzer.isPrimitive(type))
  }

  // MARK: - Base Type Name

  func testBaseTypeNameSimple() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    XCTAssertEqual(TypeAnalyzer.baseTypeName(from: type), "Int")
  }

  func testBaseTypeNameOptional() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = TypeSyntax(SyntaxFactory.optionalType(wrapped))
    XCTAssertEqual(TypeAnalyzer.baseTypeName(from: optional), "String")
  }

  func testBaseTypeNameArray() {
    let element = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let array = TypeSyntax(SyntaxFactory.arrayType(element))
    XCTAssertEqual(TypeAnalyzer.baseTypeName(from: array), "Array")
  }
}
