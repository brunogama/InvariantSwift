# Delta for Generators

## ADDED Requirements

### Requirement: flatMap Preserves Shrinking
`Gen.flatMap` MUST preserve shrinking such that both the outer value and the dependent inner value can be minimized.

#### Scenario: Outer value shrinks
- GIVEN `Gen<Int>` that produces 100
- AND a dependent generator based on that Int
- WHEN the property fails for the produced value
- THEN shrinking attempts simpler outer Int values (e.g. smaller magnitude) before exhausting inner-only shrinks

#### Scenario: Inner value shrinks deterministically
- GIVEN a dependent generator that produces a collection based on the outer value
- WHEN the outer value is fixed during shrink search
- THEN the inner generator produces deterministic shrink candidates
