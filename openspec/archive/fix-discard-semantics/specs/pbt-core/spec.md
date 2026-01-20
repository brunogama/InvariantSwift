# Delta for PBT Core

## MODIFIED Requirements

### Requirement: Assumptions Are Represented As Discards
The system MUST represent failed assumptions as discarded cases counted by the runner. The system MUST stop and return a "gave up" result when discarded cases exceed `maxDiscarded`.

#### Scenario: Runner discards and gives up
- GIVEN a property with an assumption that rarely holds
- WHEN the runner executes with `maxDiscarded = D`
- THEN the runner returns gaveUp after D discards without evaluating the predicate for those discarded inputs

#### Scenario: Runner does not emit invalid values
- GIVEN a property with assumption A
- WHEN the runner reports a counterexample
- THEN the reported counterexample satisfies A
