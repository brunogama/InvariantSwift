# Design Notes

## APIs
- `context.classify(_ label: String, when condition: Bool)`
- `context.cover(_ percent: Double, _ label: String, when condition: Bool)`
- Property body returns `PropertyEvaluation`; context side-effects are collected separately.

## Determinism
- Store classification labels in insertion order for reporting, but sort by label for stable output.

## Output
- Extend `FailureReport` to include `classificationSummary` and `coverageSummary`.
