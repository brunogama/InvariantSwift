# Capability: pbt-classification

## ADDED Requirements
### Requirement: Classification counters
The framework MUST support recording classification labels for evaluated inputs and MUST report counts.

#### Scenario: Classification summary on success
Given a property records classifications
When the property run completes successfully
Then the summary MUST include each label and its count.

### Requirement: Coverage thresholds
The framework MUST support cover thresholds and MAY fail a run when strict coverage is enabled.

#### Scenario: Strict cover failure
Given strict coverage is enabled and a cover threshold is not met
When the run completes
Then the outcome MUST be a failure with an explanation referencing the unmet threshold.
