// MARK: - Executable Protocol Law Definitions

import InvariantSwiftExpansionSupport

extension PatternDefinitions {
  static let codableRoundtrip = PatternDefinition.body(
    "Codable roundtrip: JSON encoding and decoding preserves value.",
    parameters: ["value"],
    isThrowing: true
  ) { typeName in
    [
      binding(
        "encoded",
        call("JSONEncoder")
          .method(
            "encode",
            arguments: [.unlabeled(id("value"))]
          )
          .trying()
      ),
      binding(
        "decoded",
        call("JSONDecoder")
          .method(
            "decode",
            arguments: [.unlabeled(member(typeName, "self")), .labeled("from", id("encoded"))]
          )
          .trying()
      ),
      expect(binary(id("decoded"), "==", id("value")), "JSON roundtrip must preserve value"),
    ]
  }

  static let comparableTrichotomy = PatternDefinition.body(
    "Comparable trichotomy: exactly one of <, ==, and > holds.",
    parameters: ["a", "b"]
  ) { _ in
    [
      binding("isLess", binary(id("a"), "<", id("b"))),
      binding("isEqual", binary(id("a"), "==", id("b"))),
      binding("isGreater", binary(id("b"), "<", id("a"))),
      binding("exactlyOne", .exactlyOneTrue([id("isLess"), id("isEqual"), id("isGreater")])),
      expect(id("exactlyOne"), "Exactly one ordering relation must hold"),
    ]
  }

  static let comparableDerivedOperators = PatternDefinition.body(
    "Comparable derived operators agree with < and ==.",
    parameters: ["a", "b"]
  ) { _ in
    [
      binding("lessOrEqual", binary(id("a"), "<=", id("b"))),
      binding(
        "derivedLessOrEqual",
        binary(
          binary(id("a"), "<", id("b")),
          "||",
          binary(id("a"), "==", id("b"))
        )
      ),
      expect(binary(id("lessOrEqual"), "==", id("derivedLessOrEqual")), "<= must agree"),
      expect(
        binary(binary(id("a"), ">", id("b")), "==", binary(id("b"), "<", id("a"))),
        "> must reverse <"
      ),
      expect(
        binary(binary(id("a"), ">=", id("b")), "==", binary(id("b"), "<=", id("a"))),
        ">= must reverse <="
      ),
    ]
  }

  static let losslessStringRoundtrip = PatternDefinition.body(
    "Lossless string conversion round-trips every value.",
    parameters: ["value"]
  ) { typeName in
    [
      binding("description", call("String", [.labeled("describing", id("value"))])),
      binding("decoded", call(typeName, [.unlabeled(id("description"))])),
      expect(binary(id("decoded"), "==", id("value")), "String conversion must round-trip"),
    ]
  }

  static let rawRepresentableRoundtrip = PatternDefinition.body(
    "RawRepresentable review followed by preview preserves the value.",
    parameters: ["value"]
  ) { typeName in
    [
      binding("decoded", call(typeName, [.labeled("rawValue", member("value", "rawValue"))])),
      expect(binary(id("decoded"), "==", id("value")), "rawValue must round-trip"),
    ]
  }

  static let collectionCountDistance = PatternDefinition.expectation(
    "Collection count equals the distance between its bounds.",
    parameters: ["value"],
    message: "count must equal the distance between bounds"
  ) { _ in
    binary(
      member("value", "count"),
      "==",
      id("value").method(
        "distance",
        arguments: [
          .labeled("from", member("value", "startIndex")),
          .labeled("to", member("value", "endIndex")),
        ]
      )
    )
  }

  static let collectionEmptyBounds = PatternDefinition.body(
    "Collection emptiness agrees with count and index bounds.",
    parameters: ["value"]
  ) { _ in
    [
      binding("hasZeroCount", binary(member("value", "count"), "==", id("0"))),
      binding(
        "hasEmptyBounds",
        binary(
          member("value", "startIndex"),
          "==",
          member("value", "endIndex")
        )
      ),
      expect(
        binary(member("value", "isEmpty"), "==", id("hasZeroCount")),
        "isEmpty must agree with count"
      ),
      expect(
        binary(member("value", "isEmpty"), "==", id("hasEmptyBounds")),
        "isEmpty must agree with bounds"
      ),
    ]
  }

  static let bidirectionalIndexRoundtrip = PatternDefinition.body(
    "Advancing then retreating a valid collection index preserves it.",
    parameters: ["value"]
  ) { _ in
    [
      .ifStatement(
        condition: not(member("value", "isEmpty")),
        body: [
          binding(
            "next",
            id("value").method(
              "index",
              arguments: [.labeled("after", member("value", "startIndex"))]
            )
          ),
          binding(
            "previous",
            id("value").method(
              "index",
              arguments: [.labeled("before", id("next"))]
            )
          ),
          expect(
            binary(id("previous"), "==", member("value", "startIndex")),
            "Advancing then retreating must preserve the index"
          ),
        ]
      )
    ]
  }

  static let setAlgebraIdempotence = PatternDefinition.body(
    "SetAlgebra union and intersection are commutative, associative, and idempotent.",
    parameters: ["a", "b", "c"]
  ) { _ in
    [
      expect(
        binary(apply("union", to: id("a"), id("a")), "==", id("a")),
        "Union must be idempotent"
      ),
      expect(
        binary(apply("intersection", to: id("a"), id("a")), "==", id("a")),
        "Intersection must be idempotent"
      ),
      expect(
        binary(
          apply("union", to: id("a"), id("b")),
          "==",
          apply("union", to: id("b"), id("a"))
        ),
        "Union must be commutative"
      ),
      expect(
        binary(
          apply("intersection", to: id("a"), id("b")),
          "==",
          apply("intersection", to: id("b"), id("a"))
        ),
        "Intersection must be commutative"
      ),
      binding("unionAB", apply("union", to: id("a"), id("b"))),
      binding("unionBC", apply("union", to: id("b"), id("c"))),
      expect(
        binary(
          apply("union", to: id("unionAB"), id("c")),
          "==",
          apply("union", to: id("a"), id("unionBC"))
        ),
        "Union must be associative"
      ),
      binding("intersectionAB", apply("intersection", to: id("a"), id("b"))),
      binding("intersectionBC", apply("intersection", to: id("b"), id("c"))),
      expect(
        binary(
          apply("intersection", to: id("intersectionAB"), id("c")),
          "==",
          apply("intersection", to: id("a"), id("intersectionBC"))
        ),
        "Intersection must be associative"
      ),
    ]
  }

  static let setAlgebraUnionIdentity = PatternDefinition.body(
    "SetAlgebra empty is the union identity and intersection zero.",
    parameters: ["value"]
  ) { typeName in
    [
      binding("empty", call(typeName)),
      expect(
        binary(apply("union", to: id("value"), id("empty")), "==", id("value")),
        "Empty must be the union identity"
      ),
      expect(
        binary(apply("intersection", to: id("value"), id("empty")), "==", id("empty")),
        "Intersection with empty must be empty"
      ),
    ]
  }

  static let binaryIntegerBitwiseIdentity = PatternDefinition.body(
    "BinaryInteger bitwise operators obey identity laws.",
    parameters: ["value"]
  ) { _ in
    [
      expect(
        binary(binary(id("value"), "&", id("value")), "==", id("value")),
        "value & value must equal value"
      ),
      expect(
        binary(binary(id("value"), "|", id("0")), "==", id("value")),
        "value | 0 must equal value"
      ),
      expect(
        binary(binary(id("value"), "^", id("value")), "==", id("0")),
        "value ^ value must equal zero"
      ),
      binding("complement", .prefix(op: "~", expression: id("value"))),
      binding("restored", .prefix(op: "~", expression: id("complement"))),
      expect(binary(id("restored"), "==", id("value")), "Double complement must restore value"),
    ]
  }

  static let fixedWidthModularArithmetic = PatternDefinition.body(
    "FixedWidthInteger wrapping operations obey modular ring laws.",
    parameters: ["a", "b", "c"]
  ) { _ in
    [
      expect(
        binary(binary(id("a"), "&+", id("b")), "==", binary(id("b"), "&+", id("a"))),
        "Wrapping addition must be commutative"
      ),
      expect(
        binary(binary(id("a"), "&*", id("b")), "==", binary(id("b"), "&*", id("a"))),
        "Wrapping multiplication must be commutative"
      ),
      binding("sumAB", binary(id("a"), "&+", id("b"))),
      binding("sumBC", binary(id("b"), "&+", id("c"))),
      expect(
        binary(
          binary(id("sumAB"), "&+", id("c")),
          "==",
          binary(id("a"), "&+", id("sumBC"))
        ),
        "Wrapping addition must be associative"
      ),
      binding("productAB", binary(id("a"), "&*", id("b"))),
      binding("productBC", binary(id("b"), "&*", id("c"))),
      expect(
        binary(
          binary(id("productAB"), "&*", id("c")),
          "==",
          binary(id("a"), "&*", id("productBC"))
        ),
        "Wrapping multiplication must be associative"
      ),
      binding("sum", binary(id("b"), "&+", id("c"))),
      binding("leftProduct", binary(id("a"), "&*", id("sum"))),
      binding("rightProductB", binary(id("a"), "&*", id("b"))),
      binding("rightProductC", binary(id("a"), "&*", id("c"))),
      expect(
        binary(
          id("leftProduct"),
          "==",
          binary(id("rightProductB"), "&+", id("rightProductC"))
        ),
        "Wrapping multiplication must distribute over addition"
      ),
      expect(
        binary(binary(binary(id("a"), "&+", id("b")), "&-", id("b")), "==", id("a")),
        "Wrapping subtraction must invert addition"
      ),
    ]
  }

  static let caseIterableContainsValue = PatternDefinition.expectation(
    "CaseIterable allCases contains every generated value.",
    parameters: ["value"],
    message: "allCases must contain every generated value"
  ) { typeName in
    member(typeName, "allCases").method("contains", arguments: [.unlabeled(id("value"))])
  }

  static let strideableZeroIdentity = PatternDefinition.expectation(
    "Strideable advance by zero preserves the value.",
    parameters: ["value"],
    message: "advanced(by: 0) must preserve the value"
  ) { _ in
    binary(
      id("value").method("advanced", arguments: [.labeled("by", id("0"))]),
      "==",
      id("value")
    )
  }

  static let optionSetBitwiseOperations = PatternDefinition.body(
    "OptionSet operations agree with bitwise RawValue operations.",
    parameters: ["a", "b"]
  ) { _ in
    [
      expect(
        binary(
          member(apply("union", to: id("a"), id("b")), "rawValue"),
          "==",
          binary(member("a", "rawValue"), "|", member("b", "rawValue"))
        ),
        "Union must agree with rawValue OR"
      ),
      expect(
        binary(
          member(apply("intersection", to: id("a"), id("b")), "rawValue"),
          "==",
          binary(member("a", "rawValue"), "&", member("b", "rawValue"))
        ),
        "Intersection must agree with rawValue AND"
      ),
    ]
  }

  static let randomAccessDistanceAntisymmetry = PatternDefinition.expectation(
    "RandomAccessCollection distance is antisymmetric between its bounds.",
    parameters: ["value"],
    message: "Forward and backward distances must be negatives"
  ) { _ in
    let forward = distance(from: member("value", "startIndex"), to: member("value", "endIndex"))
    let backward = distance(from: member("value", "endIndex"), to: member("value", "startIndex"))
    return binary(forward, "==", .prefix(op: "-", expression: backward))
  }

  static let floatingPointNaN = PatternDefinition.body(
    "FloatingPoint NaN classification agrees with non-reflexive equality.",
    parameters: ["value"]
  ) { typeName in
    [
      binding("nan", member(typeName, "nan")),
      expect(member("nan", "isNaN"), "The canonical NaN must report isNaN"),
      expect(binary(id("nan"), "!=", id("nan")), "NaN must not equal itself"),
      expect(
        binary(member("value", "isNaN"), "==", binary(id("value"), "!=", id("value"))),
        "isNaN must agree with non-reflexive equality"
      ),
    ]
  }
}

private func apply(
  _ method: String,
  to base: ExpansionExpr,
  _ argument: ExpansionExpr
) -> ExpansionExpr {
  base.method(method, arguments: [.unlabeled(argument)])
}

private func distance(from start: ExpansionExpr, to end: ExpansionExpr) -> ExpansionExpr {
  id("value").method(
    "distance",
    arguments: [.labeled("from", start), .labeled("to", end)]
  )
}
