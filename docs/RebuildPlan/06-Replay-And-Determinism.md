# Replay and Determinism

## Replay token
A replay token must include:
- seed
- iteration count
- size schedule parameters
- (optional) shrink search parameters

### Format
Use a stable, machine-readable encoding (JSON) and a short “copy/paste” string.

Example:

```json
{"seed":123,"iterations":200,"size":{"kind":"linear","cap":100}}
```

## Size schedule
Make size scheduling explicit and configurable:
- linear (current behavior)
- exponential
- fixed

## RNG splitting
For better compositional determinism, add RNG splitting utilities for combinators (zip/tuple) so combined generators do not accidentally couple values.
