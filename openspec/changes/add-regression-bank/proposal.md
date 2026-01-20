# Change: add-regression-bank

    ## Why
    When CI finds a minimal counterexample, the fastest feedback loop is to rerun that case first on subsequent runs.

    ## What Changes
    - Persist minimal counterexamples + replay tokens to a Regression Bank on failure.
- On subsequent runs, execute stored regressions before random exploration.
- Provide an API to opt-in/out and to clear or list regressions.

    ## Impact
    - Dramatically reduces time-to-detect for previously found bugs.
- Introduces filesystem I/O; must be opt-in by default for library users.

    ## Non-Goals
    - N/A

    ## Risks
    - Storage format must be stable; avoid storing opaque Swift object graphs unless Codable is explicit.
