# Capability: pbt-shrinking

## Purpose
Define ShrinkTree semantics and the search strategy used to find minimal counterexamples.

## ADDED Requirements
### Requirement: ShrinkTree is total and finite per node
For a given root value and shrink function, each node MUST produce a finite list of candidate children.

#### Scenario: No infinite child generation
Given a ShrinkTree node
When its children are enumerated
Then enumeration MUST terminate.

### Requirement: Search strategy is explicit and deterministic
The runner MUST use a deterministic shrink search strategy (e.g., BFS-with-pruning or greedy-with-backtracking)
and MUST document which one is used.

#### Scenario: Same shrink result for same seed
Given the same failing input and config
When shrink is run twice
Then the minimal result MUST be identical.

### Requirement: Shrink respects failure preservation
A shrink step MUST only accept a candidate if the property still fails for that candidate.

#### Scenario: Shrink never "fixes" the failure
Given an initial failing input
When shrinking
Then the chosen minimal input MUST still fail the property.
