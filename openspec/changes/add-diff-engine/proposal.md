# Change: add-diff-engine

    ## Why
    Readable diffs are the difference between 'this is usable' and 'this is noise' for failures.

    ## What Changes
    - Add a diff engine used by FailureReport to present minimal differences:
  - Strings (line/word/char)
  - Arrays (first mismatch index)
  - Dictionaries (missing/extra keys)
  - Structs (field-level via reflection or Codable mirrors)
- Provide stable text output (no random ANSI).

    ## Impact
    - Enhances developer experience. May add reflection cost; should be lazy or opt-in.

    ## Non-Goals
    - N/A

    ## Risks
    - Reflection output order instability; must define a stable sorting strategy.
