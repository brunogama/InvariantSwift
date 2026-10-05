extension ProtocolLawCatalog {
  static let swiftRuntimeEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "Hasher / RandomNumberGenerator",
      conformances: ["Hasher", "RandomNumberGenerator"],
      tier: .two,
      laws: [
        law(
          "hasher.same-sequence-process-determinism",
          "Within one process, equal ordered combine calls produce equal final hashes"
        ),
        law(
          "random-number-generator.range",
          "Int.random(in:using:) returns a value inside a nonempty requested range"
        ),
        law(
          "random-number-generator.upper-bound",
          "For upperBound > 0, Int.random(in: 0..<upperBound, using:) stays below it"
        ),
        law(
          "random-number-generator.seed-determinism",
          "A generator documented as deterministically seeded repeats a sequence for a seed"
        ),
      ],
      capabilities: [
        "bounds", "streaming distribution mean and variance",
        "chi-like uniformity checks with streaming statistics",
      ],
      notes: "RandomNumberGenerator requires next(), not next(upperBound:). Range laws use "
        + "standard-library random(in:using:) APIs. Seed replay is an opt-in contract. "
        + "Hasher determinism is process-local and never implies collision freedom. Statistical "
        + "checks require an explicit false-positive budget."
    ),
    entry(
      "SIMD / SIMDScalar",
      conformances: ["SIMD", "SIMDScalar"],
      tier: .one,
      laws: [
        law(
          "simd.integer-lane-ring",
          "Fixed-width integer lanes obey ring laws when arithmetic uses wrapping operators"
        ),
        law(
          "simd.lane-wise-addition",
          "Vector addition agrees lane-wise under the same overflow or tolerance policy"
        ),
        law(
          "simd.replacing-mask",
          "replacing(with:where:) obeys element-wise mask selection"
        ),
        law(
          "simd.lane-wise-min-max",
          "Supported min and max operations agree lane-wise under the chosen NaN policy"
        ),
        law(
          "simd.reductions",
          "Supported vector reductions agree with Array under the same arithmetic policy"
        ),
        law("simd.floating-lanes", "Floating-point lane laws use an explicit tolerance"),
      ],
      capabilities: ["arithmetic laws", "SMT bit-vectors", "floating-point modes"]
    ),
    entry(
      "Codable (Encodable & Decodable)",
      conformances: ["Codable", "Encodable", "Decodable"],
      tier: .one,
      laws: [
        law(
          "codable.value-roundtrip",
          "A value-preserving Codable contract makes decode(encode(x)) equivalent to x"
        ),
        law(
          "codable.sorted-key-determinism",
          "A deterministic Encodable value has stable sorted-key bytes for a fixed encoder"
        ),
        law(
          "codable.canonical-data-roundtrip",
          "For valid input and a fixed codec, re-encoding agrees with its canonical form"
        ),
        law(
          "codable.arbitrary-data-safety",
          "An opt-in decoder robustness contract returns or throws for arbitrary bytes"
        ),
      ],
      capabilities: ["round-trip", "implication", "shrinking to a minimal failing value"],
      notes: "Generation requires Encodable and Decodable plus a project-supplied equivalence. "
        + "Codable alone does not promise value preservation, canonical bytes, or crash freedom "
        + "for custom implementations. Configure nonconforming floating-point strategies for "
        + "NaN and infinity."
    ),
    entry(
      "Encoder / Decoder / CodingKey",
      conformances: ["Encoder", "Decoder", "CodingKey"],
      tier: .two,
      laws: [
        law(
          "coding-key.string-roundtrip",
          "A key with lossless string construction reconstructs from its stringValue"
        ),
        law(
          "coding-key.integer-roundtrip",
          "A key with lossless integer construction reconstructs from a non-nil intValue"
        ),
        law(
          "coder.primitive-roundtrip",
          "A paired custom Encoder and Decoder round-trip supported primitive values"
        ),
      ],
      capabilities: ["round-trip", "prism"],
      notes: "CodingKey reconstruction laws are opt-in semantic contracts. The coder suite "
        + "targets deliberately paired implementations such as CBOR and MessagePack."
    ),
    entry(
      "Error",
      tier: .three,
      laws: [
        law(
          "error.contract-outcome",
          "A declared throwing API contract maps each tested condition to its expected outcome"
        )
      ],
      capabilities: ["implication", "contracts"],
      notes: "Error conformance alone supplies no precondition-to-outcome contract. "
        + "Result<T, E: Error> can also use bifunctor laws."
    ),
    entry(
      "TextOutputStream / TextOutputStreamable",
      conformances: ["TextOutputStream", "TextOutputStreamable"],
      tier: .three,
      laws: [
        law(
          "text-output-stream.concatenation",
          "A call-insensitive stream may opt into write(a); write(b) equaling write(a + b)"
        ),
        law(
          "text-output-streamable.description",
          "output(to:) agrees with description when the type documents that relationship"
        ),
      ],
      capabilities: ["monoid homomorphism"],
      notes: "TextOutputStream permits call-sensitive implementations, so concatenation is an "
        + "opt-in contract over captured output rather than a protocol law."
    ),
  ]
}
