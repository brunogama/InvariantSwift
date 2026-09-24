extension ProtocolLawCatalog {
  static let foundationEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "SortComparator",
      module: "Foundation",
      tier: .one,
      laws: [
        law(
          "sort-comparator.reflexivity",
          "Within the comparator's documented domain, compare(a, a) == .orderedSame"
        ),
        law(
          "sort-comparator.reversal-symmetry",
          "compare(a, b) is the reversed result of compare(b, a)"
        ),
        law("sort-comparator.transitivity", "The strict ordering is transitive"),
        law("sort-comparator.reverse-order", "Setting order to reverse flips comparison results"),
        law(
          "sort-comparator.key-path",
          "A forward KeyPathComparator using the default comparator agrees with its key"
        ),
      ],
      capabilities: ["Comparable-style order laws", "sorting metamorphics"],
      notes: "Apply order axioms only within the comparator's documented domain."
    ),
    entry(
      "FormatStyle / ParseableFormatStyle / ParseStrategy",
      conformances: ["FormatStyle", "ParseableFormatStyle", "ParseStrategy"],
      module: "Foundation",
      tier: .one,
      laws: [
        law(
          "format-style.parse-roundtrip",
          "A documented parseable round trip reconstructs x to the format's precision"
        ),
        law(
          "format-style.determinism",
          "A deterministic style returns the same output for fixed input and configuration"
        ),
        law(
          "format-style.nonempty",
          "Output is nonempty for values whose documented representation is nonempty"
        ),
        law(
          "format-style.environment-invariance",
          "Locale and time-zone invariance holds only where documented"
        ),
      ],
      capabilities: [
        "round-trip", "floating-point and date precision tolerance",
        "implication for valid ranges",
      ],
      notes: "Round-trip, determinism, and nonempty output are opt-in contracts for custom "
        + "styles. Fix locale, calendar, and time zone in generators. Date round-trips only to "
        + "the precision retained by the style."
    ),
    entry(
      "DataProtocol / MutableDataProtocol / ContiguousBytes",
      conformances: ["DataProtocol", "MutableDataProtocol", "ContiguousBytes"],
      module: "Foundation",
      tier: .two,
      laws: [
        law(
          "data-protocol.region-concatenation",
          "Concatenating regions produces the same bytes as Array(self)"
        ),
        law(
          "data-protocol.region-count",
          "count equals the sum of the region byte counts"
        ),
        law("data-protocol.copy-bytes", "copyBytes agrees with element iteration"),
        law(
          "contiguous-bytes.unsafe-bytes",
          "withUnsafeBytes exposes the same byte sequence as Array(self)"
        ),
      ],
      capabilities: ["size additivity", "equivalence"]
    ),
    entry(
      "ReferenceConvertible / _ObjectiveCBridgeable",
      conformances: ["ReferenceConvertible", "_ObjectiveCBridgeable"],
      module: "Foundation",
      tier: .two,
      laws: [
        law(
          "objective-c-bridge.roundtrip",
          "Bridging a Swift value to its reference type and back preserves the value"
        ),
        law(
          "objective-c-bridge.hash-equality",
          "Documented equality and hash relationships survive bridging"
        ),
      ],
      capabilities: ["round-trip", "Hashable laws"],
      notes: "Examples include Date, URL, and Data with their Foundation reference types."
    ),
    entry(
      "NSCopying / NSMutableCopying",
      conformances: ["NSCopying", "NSMutableCopying"],
      module: "Foundation",
      tier: .two,
      laws: [
        law(
          "ns-copying.equality",
          "A value-preserving copy contract makes the copy equivalent to the original"
        ),
        law(
          "ns-copying.independence",
          "A copy documented as independent leaves the original unchanged when mutated"
        ),
        law(
          "ns-copying.idempotence",
          "Under value equivalence, copying a copy preserves the original value"
        ),
      ],
      capabilities: ["equivalence", "state-machine isolation"],
      notes: "NSCopying and NSMutableCopying do not require isEqual equality, deep-copy "
        + "independence, or value idempotence. Supply these as explicit type contracts."
    ),
    entry(
      "NSSecureCoding / NSCoding",
      conformances: ["NSSecureCoding", "NSCoding"],
      module: "Foundation",
      tier: .one,
      laws: [
        law(
          "ns-coding.archive-roundtrip",
          "A value-preserving archive contract reconstructs equivalent persisted state"
        )
      ],
      capabilities: ["round-trip"],
      notes: "NSCoding does not define object equality or require transient state to round-trip. "
        + "The suite needs a project-supplied equivalence over persisted state."
    ),
    entry(
      "Dimension / UnitConverter (Measurement)",
      conformances: ["Dimension", "UnitConverter", "Measurement"],
      module: "Foundation",
      tier: .one,
      laws: [
        law(
          "measurement.unit-roundtrip",
          "Within a converter's finite domain, compatible-unit conversion round-trips"
        ),
        law(
          "measurement.base-unit-roundtrip",
          "Within a converter's finite domain, base-unit conversion round-trips"
        ),
        law(
          "measurement.addition-commutativity",
          "Finite compatible measurements add commutatively under a chosen tolerance"
        ),
        law(
          "unit-converter-linear.roundtrip",
          "A nondegenerate UnitConverterLinear round-trips finite supported values"
        ),
      ],
      capabilities: ["round-trip", "floating-point tolerance", "arithmetic"],
      notes: "Custom UnitConverter implementations must explicitly declare their supported "
        + "domain and inverse contract. Exclude NaN, infinity, and degenerate coefficients."
    ),
    entry(
      "Calendar / Date arithmetic (value types, protocol-like surface)",
      conformances: ["Calendar", "Date"],
      module: "Foundation",
      tier: .two,
      laws: [
        law(
          "calendar.fixed-unit-roundtrip",
          "Successful representable additions of n fixed seconds and -n seconds round-trip"
        ),
        law(
          "calendar.component-difference",
          "dateComponents(from:to:) agrees with date(byAdding:) on constrained components"
        ),
        law("calendar.start-of-day-idempotence", "startOfDay is idempotent"),
      ],
      capabilities: ["round-trip with implication", "idempotence"],
      notes: "Require both date(byAdding:) calls to succeed. Do not apply fixed-unit "
        + "round-trips to months across daylight-saving changes or short months. Constrain each "
        + "generated component explicitly."
    ),
  ]
}
