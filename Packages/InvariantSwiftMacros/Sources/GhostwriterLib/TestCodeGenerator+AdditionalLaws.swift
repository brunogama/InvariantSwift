import InvariantSwiftExpansionSupport

extension PatternDefinitions {
  static let sequenceUnderestimatedCount = PatternDefinition.expectation(
    "Sequence underestimatedCount never exceeds the number of elements.",
    parameters: ["value"],
    message: "underestimatedCount must be a lower bound"
  ) { _ in
    binary(
      member("value", "underestimatedCount"),
      "<=",
      member(call("Array", [.unlabeled(id("value"))]), "count")
    )
  }

  static let collectionIndicesCount = PatternDefinition.expectation(
    "Collection indices count agrees with collection count.",
    parameters: ["value"],
    message: "indices.count must equal count"
  ) { _ in
    binary(member(member("value", "indices"), "count"), "==", member("value", "count"))
  }

  static let comparableMinMax = PatternDefinition.body(
    "Comparable min and max agree with ordering.",
    parameters: ["a", "b"]
  ) { _ in
    let minimum = call("min", [.unlabeled(id("a")), .unlabeled(id("b"))])
    let maximum = call("max", [.unlabeled(id("a")), .unlabeled(id("b"))])
    return [
      expect(binary(minimum, "<=", id("a")), "min must not exceed a"),
      expect(binary(minimum, "<=", id("b")), "min must not exceed b"),
      expect(binary(maximum, ">=", id("a")), "max must not be below a"),
      expect(binary(maximum, ">=", id("b")), "max must not be below b"),
    ]
  }

  static let setAlgebraAbsorption = PatternDefinition.expectation(
    "Union absorbs intersection.",
    parameters: ["a", "b"],
    message: "Absorption must hold"
  ) { _ in
    binary(setCall("union", id("a"), setCall("intersection", id("a"), id("b"))), "==", id("a"))
  }

  static let setAlgebraDistributivity = PatternDefinition.body(
    "Union and intersection distribute.",
    parameters: ["a", "b", "c"]
  ) { _ in
    [
      expect(
        binary(
          setCall("intersection", id("a"), setCall("union", id("b"), id("c"))),
          "==",
          setCall(
            "union",
            setCall("intersection", id("a"), id("b")),
            setCall("intersection", id("a"), id("c"))
          )
        ),
        "Intersection must distribute over union"
      ),
      expect(
        binary(
          setCall("union", id("a"), setCall("intersection", id("b"), id("c"))),
          "==",
          setCall(
            "intersection",
            setCall("union", id("a"), id("b")),
            setCall("union", id("a"), id("c"))
          )
        ),
        "Union must distribute over intersection"
      ),
    ]
  }

  static let setAlgebraSubsetDisjoint = PatternDefinition.body(
    "Subset and disjoint predicates agree with operations.",
    parameters: ["a", "b"]
  ) { typeName in
    [
      binding(
        "subsetByUnion",
        binary(setCall("union", id("a"), id("b")), "==", id("b"))
      ),
      expect(
        binary(
          setCall("isSubset", id("a"), id("b"), label: "of"),
          "==",
          id("subsetByUnion")
        ),
        "Subset must agree with union"
      ),
      binding(
        "emptyIntersection",
        binary(setCall("intersection", id("a"), id("b")), "==", call(typeName))
      ),
      expect(
        binary(
          setCall("isDisjoint", id("a"), id("b"), label: "with"),
          "==",
          id("emptyIntersection")
        ),
        "Disjoint must agree with empty intersection"
      ),
    ]
  }

  static let setAlgebraSymmetricDifference = PatternDefinition.expectation(
    "Symmetric difference equals union minus intersection.",
    parameters: ["a", "b"],
    message: "Symmetric difference must agree"
  ) { _ in
    binary(
      setCall("symmetricDifference", id("a"), id("b")),
      "==",
      setCall(
        "subtracting",
        setCall("union", id("a"), id("b")),
        setCall("intersection", id("a"), id("b"))
      )
    )
  }

  static let binaryIntegerDeMorgan = PatternDefinition.body(
    "Bitwise complement obeys De Morgan's law.",
    parameters: ["a", "b"]
  ) { _ in
    [
      binding("intersection", binary(id("a"), "&", id("b"))),
      binding(
        "complementUnion",
        binary(.prefix(op: "~", expression: id("a")), "|", .prefix(op: "~", expression: id("b")))
      ),
      expect(
        binary(.prefix(op: "~", expression: id("intersection")), "==", id("complementUnion")),
        "Bitwise De Morgan law must hold"
      ),
    ]
  }

  static let fixedWidthOverflow = PatternDefinition.body(
    "Reported addition agrees with wrapping addition.",
    parameters: ["a", "b"]
  ) { _ in
    [
      binding(
        "reported",
        id("a").method("addingReportingOverflow", arguments: [.unlabeled(id("b"))])
      ),
      expect(
        binary(member("reported", "partialValue"), "==", binary(id("a"), "&+", id("b"))),
        "Partial value must equal wrapping addition"
      ),
      .ifStatement(
        condition: not(member("reported", "overflow")),
        body: [
          expect(
            binary(binary(id("a"), "+", id("b")), "==", member("reported", "partialValue")),
            "Non-overflowing addition must agree"
          )
        ]
      ),
    ]
  }

  static let fixedWidthEndianRoundtrip = PatternDefinition.body(
    "Endian conversions round-trip.",
    parameters: ["value"]
  ) { typeName in
    [
      expect(
        binary(
          call(typeName, [.labeled("bigEndian", member("value", "bigEndian"))]),
          "==",
          id("value")
        ),
        "Big endian must round-trip"
      ),
      expect(
        binary(
          call(typeName, [.labeled("littleEndian", member("value", "littleEndian"))]),
          "==",
          id("value")
        ),
        "Little endian must round-trip"
      ),
    ]
  }

  static let caseIterableStableCount = PatternDefinition.body(
    "CaseIterable allCases count is stable.",
    parameters: ["value"]
  ) { typeName in
    [
      binding("firstCount", member(member(typeName, "allCases"), "count")),
      binding("secondCount", member(member(typeName, "allCases"), "count")),
      expect(binary(id("firstCount"), "==", id("secondCount")), "allCases count must be stable"),
    ]
  }

  static let optionSetSymmetricDifferenceBits = PatternDefinition.expectation(
    "OptionSet symmetric difference agrees with rawValue XOR.",
    parameters: ["a", "b"],
    message: "Symmetric difference must agree with rawValue XOR"
  ) { _ in
    binary(
      member(setCall("symmetricDifference", id("a"), id("b")), "rawValue"),
      "==",
      binary(member("a", "rawValue"), "^", member("b", "rawValue"))
    )
  }
}

private func setCall(
  _ method: String,
  _ base: ExpansionExpr,
  _ argument: ExpansionExpr,
  label: String? = nil
) -> ExpansionExpr {
  base.method(method, arguments: [label.map { .labeled($0, argument) } ?? .unlabeled(argument)])
}
