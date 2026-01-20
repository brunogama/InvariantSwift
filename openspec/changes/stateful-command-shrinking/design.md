# Design

## Key decisions
- Sequence shrinking uses the same chunk-removal strategy as collections v2
- Commands provide their own shrinkers; derivation can be added later

## Open questions
- Should macro derivation for commands be part of this change or separate?
