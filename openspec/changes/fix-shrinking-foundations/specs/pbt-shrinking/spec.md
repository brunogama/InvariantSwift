# Delta for Shrinking

## ADDED Requirements

### Requirement: ShrinkTree Representation
The system MUST represent shrinking as a tree of candidates to enable deterministic traversal and composition.

#### Scenario: A shrinker returns a tree
- GIVEN a shrinker for type T
- WHEN called with a value V
- THEN it returns a ShrinkTree with root value V and zero or more child candidates

### Requirement: Deterministic Shrink Search
The system MUST use a deterministic shrink search that yields the same minimal counterexample under the same inputs.

#### Scenario: BFS yields stable minimal counterexample
- GIVEN a failing value V and its shrink tree
- WHEN shrink search is executed twice with the same ordering and limits
- THEN the minimal counterexample produced is identical
