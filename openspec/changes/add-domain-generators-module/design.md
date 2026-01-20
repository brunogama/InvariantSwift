# Design Notes

- Targets:
  - Core: `InvariantSwift`
  - Domain: `InvariantSwiftDomainGenerators` (no heavy deps)
  - Optional: `InvariantSwiftFakeryGenerators` (depends on Fakery)

- Validation:
  - Keep formatting simple and correct; avoid overfitting to real-world address edge cases.
