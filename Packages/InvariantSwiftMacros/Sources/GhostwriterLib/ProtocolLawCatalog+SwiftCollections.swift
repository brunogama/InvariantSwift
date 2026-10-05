extension ProtocolLawCatalog {
  static let swiftCollectionEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "CaseIterable",
      tier: .one,
      laws: [
        law(
          "case-iterable.contains-generated-value",
          "allCases contains every generated value",
          pattern: "caseIterableContainsValue"
        ),
        law(
          "case-iterable.unique",
          "allCases has no duplicates when the value is Hashable"
        ),
        law(
          "case-iterable.stable-count",
          "allCases is finite and stable across calls",
          pattern: "caseIterableStableCount"
        ),
      ],
      capabilities: ["membership", "uniqueness under duplication", "count invariants"],
      notes: "Payload-free nonempty enums get a generator from their declared cases. "
        + "Other CaseIterable types need an existing generator."
    ),
    entry(
      "Identifiable",
      tier: .two,
      laws: [
        law(
          "identifiable.id-stability",
          "id is stable across copies and mutations that do not change identity"
        ),
        law(
          "identifiable.collection-uniqueness",
          "IDs are distinct in collections that declare a unique-ID invariant"
        ),
      ],
      capabilities: ["state-machine invariants", "uniqueness"],
      notes: "A lens over non-ID fields can verify that unrelated mutation preserves id."
    ),
    entry(
      "OptionSet",
      tier: .one,
      laws: [
        law("option-set.set-algebra", "All SetAlgebra laws hold"),
        law("option-set.raw-value-roundtrip", "rawValue initialization round-trips"),
        law(
          "option-set.union-bits",
          "union agrees with rawValue bitwise OR",
          pattern: "optionSetBitwiseOperations"
        ),
        law("option-set.intersection-bits", "intersection agrees with rawValue bitwise AND"),
        law(
          "option-set.symmetric-difference-bits",
          "symmetricDifference agrees with rawValue bitwise XOR",
          pattern: "optionSetSymmetricDifferenceBits"
        ),
        law(
          "option-set.membership-mutation",
          "Nonempty elements obey insert and remove membership laws",
          pattern: "optionSetMembershipMutation"
        ),
      ],
      capabilities: ["SetAlgebra laws", "SMT bit-vectors", "prism round-trip"],
      notes: "OptionSet has a bit-vector algebra and is a strong SMT target."
    ),
    entry(
      "SetAlgebra",
      tier: .one,
      laws: [
        law(
          "set-algebra.commutative-associative-idempotent",
          "Union and intersection are commutative, associative, and idempotent",
          pattern: "setAlgebraIdempotence"
        ),
        law(
          "set-algebra.identities",
          "s union empty == s and s intersection empty == empty",
          pattern: "setAlgebraUnionIdentity"
        ),
        law(
          "set-algebra.absorption",
          "s union (s intersection t) == s",
          pattern: "setAlgebraAbsorption"
        ),
        law(
          "set-algebra.distributivity",
          "Union and intersection distribute",
          pattern: "setAlgebraDistributivity"
        ),
        law(
          "set-algebra.de-morgan-subtraction",
          "Subtraction obeys the corresponding De Morgan relationships"
        ),
        law("set-algebra.insert-membership", "x is a member after inserting x"),
        law("set-algebra.remove-membership", "x is not a member after removing x"),
        law(
          "set-algebra.insert-result",
          "insert(x).inserted equals whether x was absent before insertion"
        ),
        law(
          "set-algebra.subset",
          "s is a subset of t exactly when s union t equals t",
          pattern: "setAlgebraSubsetDisjoint"
        ),
        law(
          "set-algebra.disjoint",
          "s is disjoint with t exactly when their intersection is empty"
        ),
        law(
          "set-algebra.symmetric-difference",
          "a symmetricDifference b == (a union b) subtracting (a intersection b)",
          pattern: "setAlgebraSymmetricDifference"
        ),
      ],
      capabilities: [
        "Boolean algebra", "membership", "metamorphic add and remove",
        "linearizable add, remove, and contains model",
      ],
      notes: "Applies to Set, OptionSet, IndexSet, CharacterSet, and custom sets. "
        + "Concurrent checks require a Sendable or actor-isolated subject."
    ),
    entry(
      "Sequence",
      tier: .one,
      laws: [
        law("sequence.functor-identity", "map(identity) preserves the elements"),
        law(
          "sequence.functor-composition",
          "map(g composed with f) agrees with map(f).map(g)"
        ),
        law("sequence.array-flat-map-monad", "Array-valued flatMap obeys monad laws"),
        law(
          "sequence.filter-identity-fusion",
          "filter(always true) preserves elements and successive filters fuse with and"
        ),
        law(
          "sequence.reduce-concatenation",
          "A monoidal reduce over concatenation equals combining the separate reductions"
        ),
        law(
          "sequence.underestimated-count-bound",
          "underestimatedCount does not exceed the number of iterated elements",
          pattern: "sequenceUnderestimatedCount"
        ),
        law(
          "sequence.contains-first",
          "contains(x) agrees with first(where: { $0 == x }) being non-nil"
        ),
        law("sequence.elements-equal-reflexive", "elementsEqual is reflexive"),
        law(
          "sequence.reverse-involution",
          "Materializing reversed().reversed() preserves the elements"
        ),
        law(
          "sequence.zip-enumerated-count",
          "zip count is the smaller input count and enumerated count is the base count"
        ),
        law(
          "sequence.sorted",
          "sorted output is ordered, preserves the multiset, and is idempotent"
        ),
        law(
          "sequence.all-satisfy",
          "allSatisfy(p) agrees with the absence of an element that fails p"
        ),
      ],
      capabilities: [
        "Functor and Monad law harness", "metamorphic sorting and search", "traversal laws",
        "Boolean algebra",
      ],
      notes: "The existing Gen functor and monad harness can be reused after materializing "
        + "single-pass sequences."
    ),
    entry(
      "IteratorProtocol",
      tier: .two,
      laws: [
        law(
          "iterator.nil-is-terminal",
          "After next() returns nil, later calls return nil when the iterator documents this"
        ),
        law(
          "iterator.underlying-count",
          "The number of yielded elements equals the underlying model count"
        ),
      ],
      capabilities: ["state-machine model testing"],
      notes: "Model next() as a state-machine command."
    ),
    entry(
      "Collection",
      tier: .one,
      laws: [
        law(
          "collection.count-distance",
          "count == distance(from: startIndex, to: endIndex)",
          pattern: "collectionCountDistance"
        ),
        law(
          "collection.empty-bounds",
          "isEmpty, count == 0, and startIndex == endIndex are equivalent",
          pattern: "collectionEmptyBounds"
        ),
        law(
          "collection.indices",
          "indices are ordered and their count equals count",
          pattern: "collectionIndicesCount"
        ),
        law(
          "collection.index-after",
          "index(after:) advances strictly toward endIndex for a valid non-end index"
        ),
        law(
          "collection.offset-index",
          "index(i, offsetBy: n) agrees with n repeated index(after:) steps"
        ),
        law("collection.first-subscript", "For a nonempty collection, self[startIndex] == first"),
        law(
          "collection.prefix-drop-first",
          "prefix(n) followed by dropFirst(n) reconstructs the elements"
        ),
        law(
          "collection.split-joined",
          "Under separator and empty-subsequence preconditions, split then joined round-trips"
        ),
        law(
          "collection.slice-subscript",
          "A slice subscript returns the same element as its base at a shared valid index"
        ),
      ],
      capabilities: [
        "size preservation", "structural invariants", "ordering invariants",
        "traversal structure preservation",
      ],
      notes: "Ghostwriter can emit a generic conformance suite for custom collections."
    ),
    entry(
      "BidirectionalCollection",
      tier: .one,
      laws: [
        law(
          "bidirectional-collection.index-roundtrip",
          "index(before: index(after: i)) == i for a valid non-end index",
          pattern: "bidirectionalIndexRoundtrip"
        ),
        law(
          "bidirectional-collection.last",
          "For a nonempty collection, last == self[index(before: endIndex)]"
        ),
        law(
          "bidirectional-collection.reverse-involution",
          "Materializing reversed().reversed() preserves elements"
        ),
        law(
          "bidirectional-collection.suffix-decomposition",
          "A valid prefix and suffix decomposition reconstructs the elements"
        ),
        law(
          "bidirectional-collection.negative-distance",
          "Distance is negative when traversing backward"
        ),
      ],
      capabilities: ["round-trip", "structure preservation"]
    ),
    entry(
      "RandomAccessCollection",
      tier: .two,
      laws: [
        law(
          "random-access-collection.offset-index",
          "index(i, offsetBy: n) agrees with repeated index(after:) steps"
        ),
        law(
          "random-access-collection.distance-antisymmetry",
          "distance(from: a, to: b) == -distance(from: b, to: a)",
          pattern: "randomAccessDistanceAntisymmetry"
        ),
      ],
      capabilities: ["arithmetic identity on indices"],
      notes: "Constant-time complexity is a performance contract, not an algebraic law."
    ),
    entry(
      "MutableCollection",
      tier: .one,
      laws: [
        law(
          "mutable-collection.subscript-lens",
          "Subscript set and get obey Put-Get, Get-Put, and Put-Put"
        ),
        law("mutable-collection.swap-involution", "swapAt(i, j) twice is the identity"),
        law("mutable-collection.swap-multiset", "swapAt preserves the element multiset"),
        law(
          "mutable-collection.partition",
          "partition creates predicate-separated regions and preserves the multiset"
        ),
        law("mutable-collection.sort", "sort() produces the same elements as sorted()"),
        law("mutable-collection.reverse", "reverse() produces the same elements as reversed()"),
      ],
      capabilities: ["lens laws", "permutation preservation", "sorting metamorphics"],
      notes: "Array index lenses from LensSystem can supply the subscript lens laws."
    ),
    entry(
      "RangeReplaceableCollection",
      tier: .one,
      laws: [
        law(
          "range-replaceable-collection.append",
          "append(x) increases count by one and makes x the last element"
        ),
        law(
          "range-replaceable-collection.insert-remove",
          "Inserting at a valid index and removing that index restores the elements"
        ),
        law("range-replaceable-collection.remove-all", "removeAll() produces an empty value"),
        law(
          "range-replaceable-collection.replace-count",
          "replaceSubrange updates count by removed count and inserted count"
        ),
        law(
          "range-replaceable-collection.concatenation-monoid",
          "+ is associative and an empty collection is its identity"
        ),
        law(
          "range-replaceable-collection.repeating-count",
          "init(repeating: count:).count equals the requested nonnegative count"
        ),
        law(
          "range-replaceable-collection.append-contents",
          "append(contentsOf:) agrees with concatenation"
        ),
      ],
      capabilities: [
        "length additivity", "state-machine model against Array", "monoid laws",
      ],
      notes: "ContractTestRunner can compare random command sequences against an Array model."
    ),
    entry(
      "LazySequenceProtocol / LazyCollectionProtocol",
      conformances: ["LazySequenceProtocol", "LazyCollectionProtocol"],
      tier: .two,
      laws: [
        law("lazy-sequence.map-equivalence", "lazy.map(f) yields the same elements as map(f)"),
        law(
          "lazy-sequence.filter-equivalence",
          "lazy.filter(p) yields the same elements as filter(p)"
        ),
        law(
          "lazy-sequence.deferred-evaluation",
          "Transformation closures are not called before iteration"
        ),
      ],
      capabilities: ["equivalence relation", "call-counting invariant"]
    ),
    entry(
      "StringProtocol",
      tier: .one,
      laws: [
        law(
          "string-protocol.character-boundary-additivity",
          "Character counts add only when concatenation does not merge grapheme boundaries"
        ),
        law(
          "string-protocol.utf8-additivity",
          "(a + b).utf8.count == a.utf8.count + b.utf8.count"
        ),
        law("string-protocol.lowercase-idempotence", "lowercased() is idempotent"),
        law("string-protocol.prefix", "hasPrefix(p) agrees with starts(with: p)"),
        law("string-protocol.substring-materialization", "String(Substring) preserves contents"),
      ],
      capabilities: ["string length additivity", "case idempotence", "string metamorphics"],
      notes: "Character count and case-change length claims need an ASCII restriction or a "
        + "Unicode-aware boundary precondition. UTF-8 count is additive without that restriction."
    ),
  ]
}
