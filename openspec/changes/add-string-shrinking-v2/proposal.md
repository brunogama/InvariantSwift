# Change: add-string-shrinking-v2

    ## Why
    Strings are the most common counterexample type; weak shrinking makes the framework feel amateur.

    ## What Changes
    - Implement a structured String ShrinkTree:
  - shrink length first (remove chunks, then single removals)
  - shrink characters by class (whitespace -> alnum -> minimal ascii), with Unicode-safe mode
- Ensure determinism and termination.

    ## Impact
    - Better minimal counterexamples for parsing/serialization properties. No breaking API changes.

    ## Non-Goals
    - N/A

    ## Risks
    - Unicode handling can explode search space; must bound steps and keep termination guarantees.
