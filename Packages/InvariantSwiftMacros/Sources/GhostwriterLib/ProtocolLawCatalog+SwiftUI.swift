extension ProtocolLawCatalog {
  static let swiftUIEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "VectorArithmetic",
      module: "SwiftUI",
      tier: .one,
      laws: [
        law("vector-arithmetic.additive", "AdditiveArithmetic laws hold"),
        law("vector-arithmetic.scale-one", "scale(by: 1) is the identity"),
        law("vector-arithmetic.scale-zero", "scale(by: 0) produces .zero"),
        law(
          "vector-arithmetic.scale-composition",
          "Scaling by a and then b approximates scaling by a * b"
        ),
        law(
          "vector-arithmetic.magnitude",
          "magnitudeSquared >= 0 and is zero exactly for the zero vector"
        ),
        law("vector-arithmetic.scale-distributivity", "Scaling distributes over addition"),
      ],
      capabilities: ["arithmetic laws", "floating-point tolerance", "bounds"],
      notes: "Applies to AnimatablePair, EmptyAnimatableData, and custom animatable data."
    ),
    entry(
      "Animatable",
      module: "SwiftUI",
      tier: .one,
      laws: [
        law(
          "animatable.data-lens",
          "animatableData set and get obey Get-Put, Put-Get, and Put-Put"
        ),
        law(
          "animatable.vector-arithmetic",
          "animatableData obeys its VectorArithmetic laws"
        ),
      ],
      capabilities: ["lens laws", "VectorArithmetic laws"],
      notes: "Treat animatableData as a lens and generate the standard lens-law suite."
    ),
    entry(
      "PreferenceKey",
      module: "SwiftUI",
      tier: .one,
      laws: [
        law("preference-key.associativity", "reduce is associative"),
        law("preference-key.identity", "defaultValue is an identity for reduce"),
        law(
          "preference-key.grouping",
          "Sequential reduction agrees with pairwise grouping"
        ),
      ],
      capabilities: [
        "associativity and identity", "permutation metamorphic when commutativity is intended",
      ],
      notes: "Call reduce(value:nextValue:) directly without constructing a view hierarchy."
    ),
    entry(
      "EnvironmentKey / FocusedValueKey / ContainerValueKey",
      conformances: ["EnvironmentKey", "FocusedValueKey", "ContainerValueKey"],
      module: "SwiftUI",
      tier: .three,
      laws: [
        law("swiftui-value-key.default-stability", "defaultValue is pure and stable")
      ],
      capabilities: ["forAll"],
      notes: "This is a low-value suite unless the default is computed."
    ),
    entry(
      "Layout",
      module: "SwiftUI",
      tier: .one,
      laws: [
        law(
          "layout.size-determinism",
          "sizeThatFits is deterministic for the same proposal and subviews"
        ),
        law(
          "layout.proposal-monotonicity",
          "Size is monotone in the proposal when the layout documents this behavior"
        ),
        law("layout.placement-bounds", "placeSubviews keeps subviews within declared bounds"),
        law(
          "layout.proposal-bounds",
          "sizeThatFits(.zero) does not exceed sizeThatFits(.infinity) when monotone"
        ),
        law(
          "layout.cache-equivalence",
          "Cached and freshly computed layout results are equivalent"
        ),
      ],
      capabilities: ["monotonicity", "bounds invariants", "equivalence relation"],
      notes: "Generation needs a supported LayoutSubviews test double."
    ),
    entry(
      "Shape / InsettableShape",
      conformances: ["Shape", "InsettableShape"],
      module: "SwiftUI",
      tier: .two,
      laws: [
        law(
          "shape.path-bounds",
          "For bounded shapes, path(in: rect).boundingRect stays within rect"
        ),
        law("shape.path-determinism", "Path generation is deterministic"),
        law(
          "insettable-shape.composition",
          "inset(by: 0) is identity and successive insets compose additively"
        ),
        law("shape.size-that-fits", "sizeThatFits agrees with documented sizing behavior"),
      ],
      capabilities: ["bounds", "associative-like composition", "floating-point tolerance"]
    ),
    entry(
      "Transferable (CoreTransferable)",
      conformances: ["Transferable"],
      module: "CoreTransferable",
      tier: .one,
      laws: [
        law(
          "transferable.representation-roundtrip",
          "Importing an exported value reconstructs it for each declared representation"
        )
      ],
      capabilities: ["round-trip"],
      notes: "Covers CodableRepresentation, DataRepresentation, and ProxyRepresentation."
    ),
    entry(
      "View / ViewModifier",
      conformances: ["View", "ViewModifier"],
      module: "SwiftUI",
      tier: .three,
      laws: [
        law(
          "swiftui-view.model-state-machine",
          "The observable model driving the view preserves its declared state invariants"
        )
      ],
      capabilities: ["state-machine"],
      notes: "Generate tests for the observable model rather than treating View as algebraic."
    ),
  ]
}
