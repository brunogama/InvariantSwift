# Design: Replay token

## Principles
- Replay MUST be stable and minimal: enough to reproduce, not a full log.
- Replay MUST be deterministic within a toolchain and package version.

## Token Fields
Recommended fields:
- `seed`: UInt64
- `iterations`: Int
- `sizeSchedule`: [Int] or a seed for size schedule
- `minimal`: encoded minimal counterexample payload (type-dependent)
- `shrinkTrace`: optional path indices or fingerprints

## Type Encoding
For arbitrary types, the runner SHOULD support:
- Codable-based encoding when available
- or a user-supplied encoder/decoder hook

## Risks
- Replay across versions is not guaranteed unless an explicit compatibility policy is adopted.
