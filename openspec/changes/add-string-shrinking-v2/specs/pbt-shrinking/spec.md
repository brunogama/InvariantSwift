# Capability: pbt-shrinking

## ADDED Requirements
### Requirement: High-quality string shrinking
The framework MUST provide a string shrinking strategy that preferentially reduces length before simplifying characters.

#### Scenario: Length-first shrink
Given a failing string input
When shrinking
Then the minimal result SHOULD be as short as possible while still failing.

### Requirement: Unicode-safe shrink operations
String shrinking MUST NOT produce invalid Unicode sequences and MUST not crash on extended grapheme clusters.

#### Scenario: Unicode stability
Given an input string containing composed characters
When shrinking
Then all candidates MUST be valid Swift `String` values.
