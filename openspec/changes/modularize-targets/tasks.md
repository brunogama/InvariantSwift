# Tasks

## Implementation
- [x] 1. Refactor Package.swift: define new targets and products
- [x] 2. Move files into target-aligned directories or adjust target source paths
- [x] 3. Ensure macros and SwiftSyntax deps do not leak into core products
- [x] 4. Add smoke tests: importing each product compiles on iOS/macOS

## Validation
- [x] Run unit tests for affected targets
- [x] Add/adjust tests to cover new requirements and scenarios
- [x] Ensure failure output includes replay token when applicable
