# Change: add-macro-expansion-golden-tests

    ## Why
    Macro features break silently across toolchains. Golden tests prevent drift and regressions.

    ## What Changes
    - Add golden tests for macro expansions:
  - `@PropertyTest` expansion matches expected Swift source
  - `@Arbitrary` / `@Gen` / `@Label` expansions match expected output
- Validate expansions across supported Swift toolchains in CI.

    ## Impact
    - Improves stability and user trust. Requires a macro-testing harness.

    ## Non-Goals
    - N/A

    ## Risks
    - Toolchain-specific formatting differences; must normalize or compare AST where possible.
