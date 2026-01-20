# Replay and Determinism

## Goal
A failing property must be reproducible by copy-pasting a replay token.

## Replay token
Define a stable structure:
- `seed`
- `iterations`
- `sizeSchedule` (or size strategy identifier + parameters)
- optional: `rngAlgorithmId` for forward compatibility

Encode as:
- compact string (base64url / hex) OR JSON printed on failure

## RNG handling
- Use a stable RNG implementation with test vectors.
- For composite generators, split RNG deterministically (e.g., derive child seeds from parent RNG state).

## Deterministic shrinking
Shrinking order must be stable:
- stable ordering of candidates
- deterministic BFS queue order
- deterministic stopping conditions
