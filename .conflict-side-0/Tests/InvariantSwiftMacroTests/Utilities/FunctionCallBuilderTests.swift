import SwiftSyntax
import SwiftSyntaxBuilder
import XCTest

import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class FunctionCallBuilderTests: XCTestCase {

  // MARK: - Basic Function Calls

  func testSimpleFunctionCall() {
    let call = FunctionCallBuilder("myFunction").build()

    XCTAssertTrue(call.description.contains("myFunction"))
    XCTAssertTrue(call.arguments.isEmpty)
  }

  func testFunctionCallWithUnlabeledArg() {
    let call = FunctionCallBuilder("print")
      .arg(ref: "value")
      .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("print"))
    XCTAssertTrue(desc.contains("value"))
  }

  func testFunctionCallWithLabeledArg() {
    let call = FunctionCallBuilder("configure")
      .arg("name", ref: "value")
      .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("name"))
    XCTAssertTrue(desc.contains("value"))
  }

  func testFunctionCallWithIntArg() {
    let call = FunctionCallBuilder("setCount")
      .arg("count", int: 42)
      .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("count"))
    XCTAssertTrue(desc.contains("42"))
  }

  func testFunctionCallWithStringArg() {
    let call = FunctionCallBuilder("setName")
      .arg("name", string: "hello")
      .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("name"))
    XCTAssertTrue(desc.contains("hello"))
  }

  func testFunctionCallWithBoolArg() {
    let call = FunctionCallBuilder("setEnabled")
      .arg("enabled", bool: true)
      .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("enabled"))
    XCTAssertTrue(desc.contains("true"))
  }

  // MARK: - Static Member Calls

  func testTypeMemberCall() {
    let call = FunctionCallBuilder(type: "Gen", member: "int").build()

    let desc = call.description
    XCTAssertTrue(desc.contains("Gen"))
    XCTAssertTrue(desc.contains("int"))
  }

  // MARK: - Multiple Arguments

  func testMultipleArguments() {
    let call = FunctionCallBuilder("configure")
      .arg("a", int: 1)
      .arg("b", int: 2)
      .arg("c", int: 3)
      .build()

    XCTAssertEqual(call.arguments.count, 3)
  }

  // MARK: - Gen Helpers

  func testGenZip() {
    let gens = [
      ExprSyntax(SyntaxFactory.declRef("gen1")),
      ExprSyntax(SyntaxFactory.declRef("gen2")),
    ]
    let call = FunctionCallBuilder.genZip(gens).build()

    let desc = call.description
    XCTAssertTrue(desc.contains("Gen"))
    XCTAssertTrue(desc.contains("zip"))
    XCTAssertTrue(desc.contains("gen1"))
    XCTAssertTrue(desc.contains("gen2"))
  }

  func testGenPure() {
    let value = ExprSyntax(SyntaxFactory.intLiteral(42))
    let call = FunctionCallBuilder.genPure(value).build()

    let desc = call.description
    XCTAssertTrue(desc.contains("Gen"))
    XCTAssertTrue(desc.contains("pure"))
    XCTAssertTrue(desc.contains("42"))
  }

  func testInitCall() {
    let call = FunctionCallBuilder.initCall(
      type: "Person",
      arguments: [
        (label: "name", value: ExprSyntax(SyntaxFactory.stringLiteral("John"))),
        (label: "age", value: ExprSyntax(SyntaxFactory.intLiteral(30))),
      ]
    )
    .build()

    let desc = call.description
    XCTAssertTrue(desc.contains("Person"))
    XCTAssertTrue(desc.contains("name"))
    XCTAssertTrue(desc.contains("age"))
  }

  // MARK: - Build Variants

  func testBuildExpr() {
    let expr = FunctionCallBuilder("test").buildExpr()
    XCTAssertTrue(expr.is(FunctionCallExprSyntax.self))
  }
}
