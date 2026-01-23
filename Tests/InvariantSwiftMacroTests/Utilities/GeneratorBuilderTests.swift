import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class GeneratorBuilderTests: XCTestCase {

  // MARK: - Primitive Generators

  func testPrimitiveInt() {
    let gen = GeneratorBuilder.primitive("Int")
    XCTAssertNotNil(gen)
    XCTAssertTrue(gen!.description.contains("int"))
  }

  func testPrimitiveString() {
    let gen = GeneratorBuilder.primitive("String")
    XCTAssertNotNil(gen)
    XCTAssertTrue(gen!.description.contains("string"))
  }

  func testPrimitiveBool() {
    let gen = GeneratorBuilder.primitive("Bool")
    XCTAssertNotNil(gen)
    XCTAssertTrue(gen!.description.contains("bool"))
  }

  func testPrimitiveDouble() {
    let gen = GeneratorBuilder.primitive("Double")
    XCTAssertNotNil(gen)
    XCTAssertTrue(gen!.description.contains("double"))
  }

  func testPrimitiveUUID() {
    let gen = GeneratorBuilder.primitive("UUID")
    XCTAssertNotNil(gen)
    XCTAssertTrue(gen!.description.contains("uuid"))
  }

  func testPrimitiveUnknown() {
    let gen = GeneratorBuilder.primitive("CustomType")
    XCTAssertNil(gen)
  }

  // MARK: - Composite Generators

  func testOptionalGenerator() {
    let inner = ExprSyntax(SyntaxFactory.declRef("innerGen"))
    let gen = GeneratorBuilder.optional(inner)

    XCTAssertTrue(gen.description.contains("optional"))
    XCTAssertTrue(gen.description.contains("innerGen"))
  }

  func testArrayGenerator() {
    let element = ExprSyntax(SyntaxFactory.declRef("elementGen"))
    let gen = GeneratorBuilder.array(element)

    XCTAssertTrue(gen.description.contains("array"))
    XCTAssertTrue(gen.description.contains("elementGen"))
  }

  func testSetGenerator() {
    let element = ExprSyntax(SyntaxFactory.declRef("elementGen"))
    let gen = GeneratorBuilder.set(element)

    XCTAssertTrue(gen.description.contains("set"))
    XCTAssertTrue(gen.description.contains("elementGen"))
  }

  func testDictionaryGenerator() {
    let keyGen = ExprSyntax(SyntaxFactory.declRef("keyGen"))
    let valueGen = ExprSyntax(SyntaxFactory.declRef("valueGen"))
    let gen = GeneratorBuilder.dictionary(keys: keyGen, values: valueGen)

    XCTAssertTrue(gen.description.contains("dictionary"))
    XCTAssertTrue(gen.description.contains("keyGen"))
    XCTAssertTrue(gen.description.contains("valueGen"))
  }

  func testZipGenerator() {
    let gens = [
      ExprSyntax(SyntaxFactory.declRef("gen1")),
      ExprSyntax(SyntaxFactory.declRef("gen2")),
    ]
    let gen = GeneratorBuilder.zip(gens)

    XCTAssertTrue(gen.description.contains("zip"))
    XCTAssertTrue(gen.description.contains("gen1"))
    XCTAssertTrue(gen.description.contains("gen2"))
  }

  func testArbitraryRef() {
    let gen = GeneratorBuilder.arbitraryRef("MyType")

    XCTAssertTrue(gen.description.contains("MyType"))
    XCTAssertTrue(gen.description.contains("arbitrary"))
  }

  // MARK: - Type Inference

  func testInferInt() {
    let type = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let gen = GeneratorBuilder.infer(for: type)

    XCTAssertTrue(gen.description.contains("int"))
  }

  func testInferOptionalString() {
    let wrapped = TypeSyntax(SyntaxFactory.simpleType("String"))
    let optional = TypeSyntax(SyntaxFactory.optionalType(wrapped))
    let gen = GeneratorBuilder.infer(for: optional)

    XCTAssertTrue(gen.description.contains("optional"))
  }

  func testInferArrayInt() {
    let element = TypeSyntax(SyntaxFactory.simpleType("Int"))
    let array = TypeSyntax(SyntaxFactory.arrayType(element))
    let gen = GeneratorBuilder.infer(for: array)

    XCTAssertTrue(gen.description.contains("array"))
  }

  func testInferCustomType() {
    let type = TypeSyntax(SyntaxFactory.simpleType("MyCustomType"))
    let gen = GeneratorBuilder.infer(for: type)

    // Should fall back to Type.arbitrary
    XCTAssertTrue(gen.description.contains("MyCustomType"))
    XCTAssertTrue(gen.description.contains("arbitrary"))
  }
}
