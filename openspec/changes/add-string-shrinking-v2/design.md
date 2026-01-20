# Design Notes

- Strategy order:
  1) Reduce length by removing halves (delta-debugging)
  2) Reduce length by removing smaller chunks
  3) Simplify remaining characters

- Unicode:
  - Default to scalar-safe operations (Swift `String` indices)
  - Offer `asciiOnly` generator and shrinker for deterministic char-class simplification
