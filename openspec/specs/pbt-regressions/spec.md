# Capability: pbt-regressions

## Purpose
Regression bank storage and replay-first behavior.

## MODIFIED Requirements
### Requirement: Documentation is source-of-truth
The implementation MUST conform to the requirements and scenarios in this capability spec.

#### Scenario: Spec-first execution
Given an agent is asked to implement work for this capability
When the agent begins work
Then it MUST read this spec and any active change deltas before editing code.
