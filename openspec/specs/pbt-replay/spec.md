# Replay Specification

## Purpose

Define how failing cases are reproduced deterministically via `ReplayToken` (seed, config, and optional counterexample).

## Definitions

- **ReplayToken**: Serializable struct capturing seed, iterations, size, maxDiscarded
- **Seed**: Deterministic RNG seed for reproducible generation

---

## Requirements

### Requirement: Failure Output Includes Reproduction Data

On failure, the system MUST report a reproduction recipe sufficient to rerun the same failure.

#### Scenario: Failure includes seed and minimal example

- GIVEN a failing property
- WHEN the run completes with `.failure`
- THEN the result includes `seed: Seed` and the `shrunk: T` counterexample

### Requirement: Replay Reproduces the Same Failure

The system MUST allow rerunning a property with a provided replay token to reproduce the same failure.

#### Scenario: Replay token reproduces

- GIVEN a failing run that emitted a replay token
- WHEN the property is rerun using that token's seed
- THEN the property fails with the same counterexample

### Requirement: Token Is Serializable

The replay token MUST be encodable to a copy-pasteable string and parseable back.

#### Scenario: Round-trip encoding

- GIVEN a `ReplayToken`
- WHEN `encode()` is called
- AND `parse()` is called on the result
- THEN the parsed token equals the original

---

## ReplayToken API

```swift
public struct ReplayToken {
  let seed: UInt64
  let iterations: Int
  let size: Int
  let maxDiscarded: Int
  let counterexample: String?
  
  func encode() -> String          // Base64url JSON
  static func parse(_ s: String) -> ReplayToken?
  var replaySnippet: String        // Copy-pasteable Swift code
}
```

---

## Known Limitations

1. **Size progression not captured**: Token stores single size, not per-iteration progression
2. **Shrink path not captured**: Exact shrink path is not serialized (relies on deterministic shrink order)
3. **Type-specific counterexample**: Requires `counterexample` to be manually serialized for complex types
