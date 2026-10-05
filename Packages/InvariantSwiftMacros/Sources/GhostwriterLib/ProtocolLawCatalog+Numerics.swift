extension ProtocolLawCatalog {
  static let numericsEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "AlgebraicField (swift-numerics)",
      conformances: ["AlgebraicField"],
      module: "Numerics",
      tier: .one,
      laws: [
        law(
          "algebraic-field.field-axioms",
          "Addition and multiplication are commutative and associative, and distribute"
        ),
        law(
          "algebraic-field.reciprocal",
          "For nonzero a, a * a.reciprocal approximates 1"
        ),
        law(
          "algebraic-field.division-reciprocal",
          "For nonzero b, a / b approximates a * b.reciprocal"
        ),
      ],
      capabilities: ["arithmetic laws", "floating-point tolerance", "implication a != 0"],
      notes: "Complex values use a relative tolerance."
    ),
    entry(
      "ElementaryFunctions / RealFunctions / Real (swift-numerics)",
      conformances: ["ElementaryFunctions", "RealFunctions", "Real"],
      module: "Numerics",
      tier: .one,
      laws: [
        law("real-functions.exp-log", "For x > 0, exp(log(x)) approximates x"),
        law("real-functions.pythagorean", "sin(x)^2 + cos(x)^2 approximates 1"),
        law(
          "real-functions.exp-addition",
          "exp(a + b) approximates exp(a) * exp(b) within finite bounds"
        ),
        law("real-functions.zero-power", "pow(x, 0) == 1 where the operation is defined"),
        law("real-functions.square-root", "For x >= 0, sqrt(x)^2 approximates x"),
        law("real-functions.atan2-bounds", "atan2 returns an angle in its documented range"),
        law(
          "real-functions.hypot-bound",
          "hypot(a, b) >= max(abs(a), abs(b)) for finite values"
        ),
        law("real-functions.monotonicity", "exp and log are monotone on their valid domains"),
      ],
      capabilities: ["ULP tolerance", "monotonicity metamorphic", "bounds"]
    ),
    entry(
      "swift-collections types (Deque, OrderedSet, OrderedDictionary, Heap, BitSet, "
        + "TreeSet/TreeDictionary)",
      conformances: [
        "Deque", "OrderedSet", "OrderedDictionary", "Heap", "BitSet", "TreeSet",
        "TreeDictionary",
      ],
      module: "Collections",
      tier: .one,
      laws: [
        law("swift-collections.deque-model", "Deque command sequences agree with Array"),
        law(
          "swift-collections.ordered-set",
          "OrderedSet obeys SetAlgebra while preserving documented order"
        ),
        law(
          "swift-collections.heap-sort",
          "Repeated popMin produces the same ordered elements as sorted()"
        ),
        law("swift-collections.bit-set-model", "BitSet operations agree with Set<Int>"),
        law(
          "swift-collections.persistent-tree-snapshot",
          "Mutating a tree collection leaves an earlier value snapshot unchanged"
        ),
      ],
      capabilities: ["model-based state machine", "SetAlgebra", "sorting metamorphics"],
      notes: "These are concrete types rather than protocols. Ghostwriter can select them by name."
    ),
  ]
}
