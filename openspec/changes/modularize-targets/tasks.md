# Tasks

## Implementation
- [ ] 1. Refactor Package.swift: define new targets and products
- [ ] 2. Move files into target-aligned directories or adjust target source paths
- [ ] 3. Ensure macros and SwiftSyntax deps do not leak into core products
- [ ] 4. Add smoke tests: importing each product compiles on iOS/macOS

## Validation
- [ ] Run unit tests for affected targets
- [ ] Add/adjust tests to cover new requirements and scenarios
- [ ] Ensure failure output includes replay token when applicable
