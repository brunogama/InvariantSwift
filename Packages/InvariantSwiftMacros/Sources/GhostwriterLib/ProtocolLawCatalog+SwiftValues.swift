extension ProtocolLawCatalog {
  static let swiftValueEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "Equatable",
      tier: .one,
      laws: [
        law("equatable.reflexivity", "a == a", pattern: "equatableReflexive"),
        law("equatable.symmetry", "a == b implies b == a", pattern: "equatableSymmetric"),
        law(
          "equatable.transitivity",
          "a == b and b == c implies a == c"
        ),
        law(
          "equatable.negation",
          "a != b is equivalent to !(a == b)",
          pattern: "equatableNegation"
        ),
        law(
          "equatable.substitutability",
          "Equality is consistent with Hashable and Comparable behavior"
        ),
      ],
      capabilities: ["forAll", "implication ==>", "Boolean algebra"],
      notes: "Needs Gen<Self>. Transitivity needs dependent generation or a small domain. "
        + "Exclude NaN from ordinary Equatable suites or use an explicit NaN mode."
    ),
    entry(
      "Hashable",
      tier: .one,
      laws: [
        law(
          "hashable.equal-values-equal-hashes",
          "a == b implies a.hashValue == b.hashValue within one process and seed"
        ),
        law(
          "hashable.hash-into-determinism",
          "hash(into:) is deterministic within one run"
        ),
        law("hashable.equatable-consistency", "Hashing is consistent with Equatable"),
      ],
      capabilities: ["forAll", "implication"],
      notes: "Generate a value, then copy or re-encode it to obtain an equal value with "
        + "distinct identity. Never assert that unequal values have different hashes."
    ),
    entry(
      "Comparable",
      tier: .one,
      laws: [
        law("comparable.irreflexivity", "!(a < a)", pattern: "comparableIrreflexive"),
        law(
          "comparable.asymmetry",
          "a < b implies !(b < a)",
          pattern: "comparableAsymmetric"
        ),
        law(
          "comparable.transitivity",
          "a < b and b < c implies a < c",
          pattern: "comparableTransitive"
        ),
        law(
          "comparable.totality",
          "Exactly one of a < b, a == b, and a > b holds",
          pattern: "comparableTrichotomy"
        ),
        law(
          "comparable.derived-operators",
          "<=, >, and >= agree with < and ==",
          pattern: "comparableDerivedOperators"
        ),
        law(
          "comparable.min-max",
          "min and max agree with the ordering",
          pattern: "comparableMinMax"
        ),
        law(
          "comparable.sorted",
          "sorted() is ordered, preserves the multiset, and is idempotent"
        ),
      ],
      capabilities: [
        "forAll", "metamorphic sorting idempotence, size, and permutation",
        "ordering invariants",
      ],
      notes: "Exclude NaN for FloatingPoint, or use isTotallyOrdered(belowOrEqualTo:) "
        + "with explicit NaN semantics."
    ),
    entry(
      "Strideable",
      tier: .one,
      laws: [
        law(
          "strideable.distance-advance-roundtrip",
          "a.advanced(by: a.distance(to: b)) == b"
        ),
        law(
          "strideable.zero-identity",
          "a.advanced(by: 0) == a for Equatable non-floating values",
          pattern: "strideableZeroIdentity"
        ),
        law(
          "strideable.distance-antisymmetry",
          "a.distance(to: b) == -b.distance(to: a)"
        ),
        law(
          "strideable.positive-step-ordering",
          "For n > 0, a.advanced(by: n) > a when ordering and bounds permit"
        ),
      ],
      capabilities: ["forAll", "arithmetic identity", "monotonicity"],
      notes: "Guard overflow and representability with an implication precondition."
    ),
    entry(
      "RangeExpression",
      tier: .two,
      laws: [
        law("range-expression.bounds", "Valid expressions resolve inside collection bounds"),
        law(
          "range-expression.membership",
          "contains(x) agrees with membership in the range returned by relative(to:)"
        ),
      ],
      capabilities: ["forAll", "membership invariants"],
      notes: "Applies to ClosedRange, Range, and PartialRange variants. Out-of-bounds "
        + "expressions are outside this law's precondition."
    ),
    entry(
      "AdditiveArithmetic",
      tier: .one,
      laws: [
        law("additive-arithmetic.commutativity", "a + b == b + a"),
        law("additive-arithmetic.associativity", "(a + b) + c == a + (b + c)"),
        law(
          "additive-arithmetic.zero-identity",
          "a + .zero == a for non-NaN values",
          pattern: "additiveZeroIdentity"
        ),
        law("additive-arithmetic.self-subtraction", "a - a == .zero"),
        law("additive-arithmetic.add-subtract-roundtrip", "(a + b) - b == a"),
        law("additive-arithmetic.assignment", "+= and -= agree with + and -"),
      ],
      capabilities: [
        "arithmetic commutativity, associativity, and identity", "SMT for Int",
        "floating-point tolerance modes",
      ],
      notes: "For integers, guard overflow or use wrapping operators. For floating-point "
        + "associativity, use relative or ULP tolerance."
    ),
    entry(
      "Numeric",
      tier: .one,
      laws: [
        law(
          "numeric.multiplication-commutativity",
          "Types declaring commutative multiplication satisfy a * b == b * a"
        ),
        law(
          "numeric.multiplication-associativity",
          "Types declaring associative multiplication satisfy (a * b) * c == a * (b * c)"
        ),
        law("numeric.one-identity", "Types declaring a multiplicative unit satisfy a * 1 == a"),
        law("numeric.zero-annihilation", "Opt-in zero law: a * 0 == 0"),
        law("numeric.distributivity", "Opt-in law: a * (b + c) == a * b + a * c"),
        law("numeric.exactly-roundtrip", "init?(exactly:) round-trips exact values"),
        law("numeric.nonnegative-magnitude", "magnitude >= 0"),
      ],
      capabilities: ["arithmetic laws", "SMT QF_LIA for linear terms", "FP tolerance"],
      notes: "Numeric supplies operations, not universal algebraic axioms. Enable these laws "
        + "only for a declared algebraic structure. Guard integer overflow and use an explicit "
        + "floating-point tolerance. SMT support is limited to linear QF_LIA terms."
    ),
    entry(
      "SignedNumeric",
      tier: .one,
      laws: [
        law("signed-numeric.double-negation", "-(-a) == a"),
        law("signed-numeric.additive-inverse", "a + (-a) == 0"),
        law("signed-numeric.negate", "negate() agrees with prefix -"),
      ],
      capabilities: ["arithmetic", "implication excluding the minimum value"],
      notes: "Integer minimum negation traps. Require a != .min."
    ),
    entry(
      "BinaryInteger",
      tier: .one,
      laws: [
        law(
          "binary-integer.division-recomposition",
          "For b != 0, (a / b) * b + a % b == a"
        ),
        law(
          "binary-integer.remainder-sign",
          "The sign of a % b is the sign of a or the remainder is zero"
        ),
        law(
          "binary-integer.bitwise-identities",
          "a & a == a, a | 0 == a, a ^ a == 0, and ~~a == a",
          pattern: "binaryIntegerBitwiseIdentity"
        ),
        law("binary-integer.de-morgan", "~(a & b) == ~a | ~b", pattern: "binaryIntegerDeMorgan"),
        law("binary-integer.shift-recovery", "a << n >> n recovers representable low bits"),
        law(
          "binary-integer.bit-count-bounds",
          "trailingZeroBitCount and nonzeroBitCount remain within bit-width bounds"
        ),
        law(
          "binary-integer.conversion-monotonicity",
          "truncatingIfNeeded and clamping initializers obey their documented bounds"
        ),
        law(
          "binary-integer.is-multiple",
          "For b != 0, a.isMultiple(of: b) is equivalent to a % b == 0"
        ),
        law(
          "binary-integer.quotient-remainder",
          "quotientAndRemainder agrees with / and %"
        ),
      ],
      capabilities: [
        "SMT bit-vector AND, OR, XOR, shifts, and negation", "SMT division and remainder",
        "arithmetic and implication",
      ],
      notes: "A strong SMT target. Bit-vector operations require a bit-vector theory, "
        + "rather than a QF_LIA-only encoding."
    ),
    entry(
      "FixedWidthInteger",
      tier: .one,
      laws: [
        law(
          "fixed-width-integer.adding-overflow",
          "addingReportingOverflow agrees with &+ and its overflow flag",
          pattern: "fixedWidthOverflow"
        ),
        law("fixed-width-integer.full-width-product", "multipliedFullWidth is exact"),
        law(
          "fixed-width-integer.full-width-division",
          "dividingFullWidth inverts a representable multipliedFullWidth result"
        ),
        law(
          "fixed-width-integer.byte-swap-involution",
          "a.byteSwapped.byteSwapped == a",
          pattern: "fixedWidthByteSwap"
        ),
        law(
          "fixed-width-integer.endian-roundtrip",
          "Endian conversions round-trip",
          pattern: "fixedWidthEndianRoundtrip"
        ),
        law(
          "fixed-width-integer.leading-zero-relation",
          "leadingZeroBitCount agrees with bitWidth and the highest set bit"
        ),
        law(
          "fixed-width-integer.modular-ring",
          "&+, &-, and &* obey modular ring laws",
          pattern: "fixedWidthModularArithmetic"
        ),
        law(
          "fixed-width-integer.shift-rotate",
          "Masked shift round-trips; rotation requires a custom API"
        ),
      ],
      capabilities: ["SMT bit-vector", "arithmetic ring laws", "round-trip"],
      notes: "Wrapping operators provide exact modular arithmetic laws."
    ),
    entry(
      "SignedInteger / UnsignedInteger",
      conformances: ["SignedInteger", "UnsignedInteger"],
      tier: .two,
      laws: [
        law(
          "unsigned-integer.nonnegative",
          "UnsignedInteger values are nonnegative and magnitude equals self"
        ),
        law(
          "signed-integer.signum",
          "signum is in {-1, 0, 1} and reconstructs non-minimum values with magnitude"
        ),
      ],
      capabilities: ["bounds", "arithmetic"]
    ),
    entry(
      "FloatingPoint",
      tier: .one,
      laws: [
        law(
          "floating-point.nan-reflexivity",
          "x.isNaN is equivalent to x != x",
          pattern: "floatingPointNaN"
        ),
        law("floating-point.signed-zero", "+0 == -0 while their signs differ"),
        law("floating-point.zero-addition", "x + 0 == x outside signed-zero edge cases"),
        law("floating-point.next-up", "x.nextUp > x for finite non-maximal x"),
        law(
          "floating-point.rounding-bounds",
          "x.rounded(.down) <= x <= x.rounded(.up)"
        ),
        law("floating-point.square-root", "squareRoot(x)^2 approximates x for x >= 0"),
        law(
          "floating-point.remainder-bounds",
          "remainder and truncatingRemainder obey their documented bounds"
        ),
        law("floating-point.adding-product", "addingProduct approximates a + b * c"),
        law("floating-point.positive-ulp", "ulp > 0 for finite values"),
        law("floating-point.total-order", "isTotallyOrdered defines a total order"),
        law("floating-point.min-max-nan", "min and max follow documented NaN semantics"),
      ],
      capabilities: [
        "ULP, relative, and absolute tolerance", "signed-zero equivalence",
        "explicit NaN and infinity semantics", "finite-only and IEEE generators",
      ],
      notes: "Use exact equality only where IEEE 754 guarantees it. Route other laws "
        + "through an explicit tolerance policy."
    ),
    entry(
      "BinaryFloatingPoint",
      tier: .one,
      laws: [
        law(
          "binary-floating-point.bit-pattern-roundtrip",
          "Reconstructing from sign, exponent, and significand bit patterns preserves bits"
        ),
        law(
          "binary-floating-point.float-widening",
          "Double(Float(x)) == x for every non-NaN Float x"
        ),
        law(
          "binary-floating-point.component-reconstruction",
          "significand * 2^exponent reconstructs finite nonzero x"
        ),
        law("binary-floating-point.random-bounds", "random(in:) returns a value in range"),
      ],
      capabilities: ["round-trip", "floating-point modes", "bounds"]
    ),
    entry(
      "ExpressibleBy*Literal (Integer/Float/String/Array/Dictionary/Boolean/Nil/Unicode/"
        + "ExtendedGraphemeCluster/StringInterpolation)",
      conformances: [
        "ExpressibleByIntegerLiteral", "ExpressibleByFloatLiteral",
        "ExpressibleByStringLiteral", "ExpressibleByArrayLiteral",
        "ExpressibleByDictionaryLiteral", "ExpressibleByBooleanLiteral",
        "ExpressibleByNilLiteral", "ExpressibleByUnicodeScalarLiteral",
        "ExpressibleByExtendedGraphemeClusterLiteral", "ExpressibleByStringInterpolation",
      ],
      tier: .three,
      laws: [
        law(
          "literal-expressible.initializer-consistency",
          "Literal initialization agrees with a paired designated initializer"
        ),
        law(
          "literal-expressible.array-elements",
          "Array literal initialization preserves the supplied elements"
        ),
      ],
      capabilities: ["forAll equality"],
      notes: "Generate only when Ghostwriter can pair the literal with a non-literal initializer."
    ),
    entry(
      "LosslessStringConvertible",
      tier: .one,
      laws: [
        law(
          "lossless-string-convertible.value-roundtrip",
          "T(String(describing: x)) == x",
          pattern: "losslessStringRoundtrip"
        ),
        law(
          "lossless-string-convertible.parse-stability",
          "Any parsed value's description parses back to an equal value"
        ),
      ],
      capabilities: ["round-trip", "implication"],
      notes: "Any Equatable LosslessStringConvertible type can use the value round-trip law."
    ),
    entry(
      "CustomStringConvertible / CustomDebugStringConvertible",
      conformances: ["CustomStringConvertible", "CustomDebugStringConvertible"],
      tier: .three,
      laws: [
        law("custom-string-convertible.determinism", "Description is deterministic"),
        law(
          "custom-string-convertible.equality",
          "Equal values have equal descriptions when the type documents this behavior"
        ),
      ],
      capabilities: ["forAll", "invariant discovery for non-empty and length bounds"],
      notes: "These are weak laws. Prefer mined invariants that the type documents."
    ),
  ]
}
