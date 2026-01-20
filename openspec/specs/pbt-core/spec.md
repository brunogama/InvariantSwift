# Capability: pbt-core

## Purpose
Define the core PBT contract: deterministic generation, explicit evaluation outcomes, assumptions/discards,
and stable failure reporting.

## ADDED Requirements
### Requirement: Deterministic evaluation
Given a `Seed` and `PropertyConfig`
The runner MUST generate the same sequence of test inputs across runs on the same platform/toolchain.

#### Scenario: Seed reproduces values
Given a property with fixed `seed` and `iterations`
When the property is run twice
Then the generated inputs MUST be identical in the same order.

### Requirement: Assumptions are explicit and discard-aware
Assumptions MUST be expressed as discards (not hidden generator filtering), and discards MUST be tracked.

#### Scenario: Discarded inputs never count as passes
Given a property that discards some inputs
When the property is run
Then discarded inputs MUST NOT be counted as passing iterations.

#### Scenario: Give up after too many discards
Given `maxDiscarded` is configured
When the property discards more than `maxDiscarded` inputs
Then the runner MUST return a "gave up" outcome with discard counts.

### Requirement: Failure output is actionable
On failure, the framework MUST emit a stable failure report containing:
- minimal counterexample (post-shrink)
- replay token (seed/config sufficient to reproduce)
- failure reason (predicate failed / threw error / timed out)

#### Scenario: Copy-paste reproduction
Given a failing property run
When the failure is reported
Then the output MUST include a replay token usable to reproduce the same failure.
