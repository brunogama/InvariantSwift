# Change: add-classification-reporting

    ## Why
    PBT without input distribution feedback leads to false confidence (tests only cover a narrow slice).

    ## What Changes
    - Add `classify` and `cover` APIs usable inside property bodies.
- Track classification counters and coverage percentages during runs.
- Extend failure/success reports to include classification distribution.
- Optionally fail a property if required cover thresholds are not met.

    ## Impact
    - Improves diagnostic power without changing existing generator APIs.
- Adds new reporting fields; existing outputs remain backward compatible unless strict coverage is enabled.

    ## Non-Goals
    - N/A

    ## Risks
    - Incorrect aggregation in parallel runs; must keep deterministic ordering for report output.
