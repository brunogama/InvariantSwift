extension ProtocolLawCatalog {
  static let swiftValueRoundtripEntries: [ProtocolLawCatalogEntry] = [
    entry(
      "RawRepresentable",
      tier: .one,
      laws: [
        law(
          "raw-representable.review-preview",
          "T(rawValue: x.rawValue) == x",
          pattern: "rawRepresentableRoundtrip"
        ),
        law(
          "raw-representable.preview-review",
          "A successful T(rawValue: r) exposes rawValue r"
        ),
      ],
      capabilities: ["round-trip", "prism preview-review and review-preview"],
      notes: "Treat rawValue as review and init?(rawValue:) as preview in prism laws."
    )
  ]
}
