# Design Notes

- Keep `InvariantSwift` as the main user-facing product for convenience.
- Make experimental features opt-in via explicit import.
- Use `_exported import` carefully; prefer explicit docs and minimal re-exports.
