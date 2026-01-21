# Design

## Key decisions
- Isolation is opt-in and macOS-host only
- Helper executable is packaged as a separate target to avoid iOS impact

## Open questions
- Packaging: SwiftPM executable target vs bundled tool in plugin?
