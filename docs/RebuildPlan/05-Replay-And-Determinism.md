# Determinism and replay

## Goal
A failing case must be reproducible from a single, copy-pastable token.

## Replay token contents

- `seed`
- `iterations`
- size schedule parameters (start, growth, cap)
- (optional) shrink strategy id and maxShrinks

## Requirements

- Same replay token produces same failing case and same shrink result.
- Output includes the replay token and minimal counterexample.

## Tests

- Determinism test: run the same property twice with the same replay token and verify identical results.
