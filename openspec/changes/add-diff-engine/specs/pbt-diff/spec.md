## ADDED Requirements

### Requirement: Diff Engine Capabilities
The Diff Engine MUST support stable, readable diffs for standard Swift types.

#### Scenario: String Diffing
Given two strings that differ by a few characters
When `DiffEngine.diff` is called
Then it returns a unified diff showing additions and deletions
And it does not output ANSI color codes by default

#### Scenario: Array Diffing
Given two arrays `[1, 2, 3]` and `[1, 5, 3]`
When `DiffEngine.diff` is called
Then it identifies index 1 as changed
And outputs `- 2` and `+ 5` at that index

#### Scenario: Dictionary Diffing
Given two dictionaries with different keys
When `DiffEngine.diff` is called
Then it lists missing keys (in expected but not actual)
And extra keys (in actual but not expected)
And modified values for shared keys
And the output is sorted by key to ensure stability

#### Scenario: Struct Diffing via Reflection
Given two structs with a nested difference
When `DiffEngine.diff` is called
Then it traverses the hierarchy
And shows the field path to the difference
And handles stable field ordering

### Requirement: Failure Reporting Integration
Failure reports MUST include the computed diff to aid debugging.

#### Scenario: Failure Report Integration
Given a `FailureReport` created with a diff string
When it is formatted by `FailureReporter`
Then the diff section is clearly visible
And separated from other sections
