# Design Notes

- Prefer AST equivalence when feasible; otherwise normalize formatting:
  - remove whitespace-only diffs
  - normalize newlines
- Store fixtures under `Tests/InvariantSwiftMacrosTests/Fixtures/`.
