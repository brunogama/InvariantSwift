# Detailed Implementation Tasks

## Phase 1: Foundation & Validation (Weeks 1-2)

### Task 1.1: Validate Existing `ShrinkTree<T>` Implementation
**Objective**: Ensure `Core/ShrinkTree.swift` is complete and correct for canonicalization
- [ ] 1.1.1 Run existing tests for `ShrinkTree<T>` (in `Tests/FunctionalTesting/`)
- [ ] 1.1.2 Verify all methods exist: `map`, `flatMap`, `filter`, `findMinimal`, `prune`, `take`
- [ ] 1.1.3 Verify `ShrinkTree.from(_ value:T, shrink:Shrink<T>)` bridge works correctly
- [ ] 1.1.4 Add tests for edge cases: empty children, leaf nodes, nested flatMap
- **Acceptance**: All new tests pass; 100% coverage of `ShrinkTree<T>` methods

### Task 1.2: Document Migration from `Node<A>` to `ShrinkTree<T>`
**Objective**: Plan deprecation and removal of duplicate `Node` type from `Advanced/ShrinkTrees.swift`
- [ ] 1.2.1 Map `Node<A>` capabilities to `ShrinkTree<T>` equivalents
- [ ] 1.2.2 Identify all code using `Node<A>` (grep results)
- [ ] 1.2.3 Create deprecation strategy document (for review)
- [ ] 1.2.4 Determine if `TreeGen<A>` stays or converts to `Gen<T> -> ShrinkTree<T>`
- **Acceptance**: Clear migration path documented; no ambiguity

### Task 1.3: Enhance `ShrinkTree` with Performance Controls
**Objective**: Add safety guardrails to prevent tree explosion
- [ ] 1.3.1 Add `prune(maxDepth:)` method (already exists; verify correctness)
- [ ] 1.3.2 Add `limitBreadth(_ maxChildren:)` method to cap children per node
- [ ] 1.3.3 Add `limitTotal(_ maxNodes:)` method to prune to N-node budget
- [ ] 1.3.4 Add tests verifying pruned trees respect limits
- **Acceptance**: All methods working; tests confirm trees don't exceed limits

## Phase 2: PropertyRunner Integration (Weeks 2-3)

### Task 2.1: Implement BFS Shrink Search with Budget
**Objective**: Add deterministic shrink search to replace greedy strategy
- [ ] 2.1.1 Create `ShrinkSearch` struct/class to encapsulate BFS logic
- [ ] 2.1.2 Implement breadth-first traversal with stable ordering
- [ ] 2.1.3 Add budget tracking (nodes visited, time elapsed)
- [ ] 2.1.4 Implement predicate-based filtering (find failing candidates)
- [ ] 2.1.5 Add determinism tests: same input → same output
- **Acceptance**: BFS produces minimal counterexample; deterministic tests pass

### Task 2.2: Update `PropertyRunner` to Use `ShrinkTree`-Based Search
**Objective**: Replace greedy shrinking with BFS in main test runner
- [ ] 2.2.1 Locate shrinking code in `Testing/PropertyRunner.swift` (current implementation)
- [ ] 2.2.2 Add `ShrinkTree.from(failingValue, shrink:)` conversion
- [ ] 2.2.3 Replace greedy loop with `ShrinkSearch.findMinimal(budget:)`
- [ ] 2.2.4 Add configuration: `maxShrinkNodes`, `maxShrinkDepth` (with sensible defaults)
- [ ] 2.2.5 Update failure output to show shrink path + steps
- [ ] 2.2.6 Verify old property tests still pass with new search
- **Acceptance**: All existing tests pass; new search reports at least as minimal counterexamples

### Task 2.3: Ensure Backward Compatibility
**Objective**: Keep `Shrink<T>` working for existing code
- [ ] 2.3.1 Document that `Shrink<T>` is legacy (but stable)
- [ ] 2.3.2 Mark `Shrink<T>` API with deprecation notices where appropriate
- [ ] 2.3.3 Ensure `ShrinkTree.from()` works for all existing shrinkers
- [ ] 2.3.4 Run full test suite; confirm no regressions
- **Acceptance**: Existing code using `Shrink<T>` works unchanged

## Phase 3: Core Shrinker Implementations (Weeks 3-4)

### Task 3.1: Reference Shrinking for `Int` and `Double`
**Objective**: Provide canonical shrinkers that produce `ShrinkTree`
- [ ] 3.1.1 Verify `Shrink.towards(target:, value:)` is correct for `Int`
- [ ] 3.1.2 Verify `Shrink.towards(target:, value:)` is correct for `Double`
- [ ] 3.1.3 Create `ShrinkTree`-returning versions in `Generators/`
- [ ] 3.1.4 Add tests: shrinking toward 0 produces expected sequence
- [ ] 3.1.5 Add tests: shrinking respects range boundaries
- **Acceptance**: Shrinkers work; tests confirm convergence toward target

### Task 3.2: Reference Shrinking for `String`
**Objective**: String shrinker that removes characters and reduces length
- [ ] 3.2.1 Design shrinking strategy: remove chars, then halve length
- [ ] 3.2.2 Implement `Shrink.string() -> ShrinkTree<String>`
- [ ] 3.2.3 Add tests: empty string is leaf, non-empty has children
- [ ] 3.2.4 Add tests: all shrinks are actual substrings
- [ ] 3.2.5 Verify deterministic ordering (same string always produces same tree)
- **Acceptance**: Shrinker produces correct trees; edge cases handled

### Task 3.3: Reference Shrinking for `Array<T>`
**Objective**: Array shrinker that removes elements and shrinks individual values
- [ ] 3.3.1 Design strategy: remove elements, then shrink individual elements
- [ ] 3.3.2 Implement `Shrink.array<T>(_ elementShrink:) -> ShrinkTree<[T]>`
- [ ] 3.3.3 Add tests: empty array is leaf, non-empty has children
- [ ] 3.3.4 Add tests: all shrinks are shorter or internally shrunk
- [ ] 3.3.5 Add tests: combined shrinking (remove + shrink element)
- **Acceptance**: Array shrinker works for nested structures

### Task 3.4: Reference Shrinking for Collections (`Set`, `Dictionary`)
**Objective**: Extend shrinking to standard collections
- [ ] 3.4.1 Implement `Shrink.set<T>() -> ShrinkTree<Set<T>>`
- [ ] 3.4.2 Implement `Shrink.dictionary<K, V>() -> ShrinkTree<[K:V]>`
- [ ] 3.4.3 Add tests for each collection type
- **Acceptance**: Collections shrink correctly

## Phase 4: Testing & Validation (Weeks 4-5)

### Task 4.1: Determinism & Reproducibility Tests
**Objective**: Verify shrinking is deterministic and can be replayed
- [ ] 4.1.1 Create test: `testShrinkDeterminism` – same value always produces same shrink path
- [ ] 4.1.2 Create test: `testShrinkPathReproducibility` – replay from shrink path works
- [ ] 4.1.3 Create test: `testBudgetTermination` – search stops at maxNodes/maxDepth
- [ ] 4.1.4 Create test: `testCyclicShrinkGraphTermination` – no infinite loops
- **Acceptance**: All tests pass; shrinking is deterministic and bounded

### Task 4.2: Minimality & Correctness Tests
**Objective**: Verify that shrunken counterexamples are actually minimal
- [ ] 4.2.1 Test: `testMinimalityInt` – shrinking finds the smallest failing int
- [ ] 4.2.2 Test: `testMinimalityArray` – shrinking finds smallest failing array
- [ ] 4.2.3 Test: `testMinimalityString` – shrinking finds shortest failing string
- [ ] 4.2.4 Compare old vs new shrinking for common properties
- **Acceptance**: BFS finds equal or better minimality than greedy

### Task 4.3: Performance & Regression Tests
**Objective**: Ensure no significant performance regressions
- [ ] 4.3.1 Create benchmarks: shrink time for Int (1M–1B range)
- [ ] 4.3.2 Create benchmarks: shrink time for String (100–10K chars)
- [ ] 4.3.3 Create benchmarks: shrink time for Array (100–10K elements)
- [ ] 4.3.4 Establish baseline (old greedy) vs new (BFS) performance
- [ ] 4.3.5 Document trade-offs if any regression observed
- **Acceptance**: Performance acceptable; document any deviations

### Task 4.4: Integration Tests with Swift Testing
**Objective**: End-to-end testing with macro-generated properties
- [ ] 4.4.1 Create property: `prop_intIdentity` with @PropertyTest
- [ ] 4.4.2 Create property: `prop_arrayReversal` with nested values
- [ ] 4.4.3 Create property: `prop_stringLengthPreservation` for strings
- [ ] 4.4.4 Verify shrink output is presented correctly in test reports
- **Acceptance**: Integration tests pass; output is clear and minimal

## Phase 5: Documentation & Cleanup (Weeks 5-6)

### Task 5.1: Update API Documentation
**Objective**: Reflect new shrinking approach in docs
- [ ] 5.1.1 Update `CLAUDE.md` section on shrinking
- [ ] 5.1.2 Update API docs for `ShrinkTree<T>`
- [ ] 5.1.3 Add migration guide: `Shrink<T>` → `ShrinkTree<T>`
- [ ] 5.1.4 Update `docs/COOKBOOK.md` with shrinking examples
- **Acceptance**: Docs are clear; users understand the new model

### Task 5.2: Deprecation & Cleanup
**Objective**: Remove duplicate types if feasible; mark legacy code
- [ ] 5.2.1 Decide: Keep `Node<A>` with deprecation marker or remove?
- [ ] 5.2.2 If deprecating: add `@available` annotation with migration message
- [ ] 5.2.3 Update all internal code to use `ShrinkTree` only
- [ ] 5.2.4 Remove or archive `Advanced/ShrinkTrees.swift` if no longer needed
- **Acceptance**: Codebase uses single canonical type

### Task 5.3: Validation & Sign-Off
**Objective**: Run full validation suite before marking complete
- [ ] 5.3.1 `swift build -Xswiftc -warnings-as-errors` passes
- [ ] 5.3.2 `swift test` passes with 100% coverage on shrinking code
- [ ] 5.3.3 `swiftlint lint --strict` passes
- [ ] 5.3.4 Run `openspec validate fix-shrinking-foundations --strict`
- [ ] 5.3.5 Performance benchmarks meet acceptance criteria
- **Acceptance**: All quality gates pass; ready for merge

## Dependency & Sequencing

**Strict order**:
1. Phase 1 must complete before Phase 2 (canonicalization first)
2. Phase 2 must complete before Phase 3 (runner integration before new shrinkers)
3. Phase 3 & 4 can overlap (shrinkers and tests in parallel)
4. Phase 5 depends on Phases 1-4

**Parallelizable**:
- Tasks 3.1, 3.2, 3.3, 3.4 can be worked on concurrently
- Tasks 4.1, 4.2, 4.3 can be worked on concurrently
