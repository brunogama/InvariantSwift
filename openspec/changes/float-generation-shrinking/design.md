# Design

## Key decisions
- Default mode is finiteOnly
- Shrinker never introduces NaN unless starting from NaN and mode allows it

## Open questions
- Should approx-equality live in core or in a separate Assertions module?
