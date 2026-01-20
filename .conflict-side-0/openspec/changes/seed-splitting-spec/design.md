# Design

## Key decisions
- Replay tokens are versioned and forward compatible
- Token format defaults to base64url(JSON) for debuggability

## Open questions
- Should shrinkTrace be included by default or only under debug/trace mode?
