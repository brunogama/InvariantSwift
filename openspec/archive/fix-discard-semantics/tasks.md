## Status: ✅ COMPLETE (Jan 2026)

All tasks were implemented as part of the "Truthful Engine" rebuild (v2). See `engine_rebuild_v2.md` knowledge artifact for full audit.

---

## 1. Runner discard accounting
- [x] 1.1 Introduce a runner-level notion of discard (assumption failed)
  - **Impl**: `PropertyRunner.runProperty()` checks `property.assumption(testCase)` before predicate (Property.swift:704)
- [x] 1.2 Track discarded count and stop when `maxDiscarded` is exceeded
  - **Impl**: `discarded` counter in runner loop; `config.maxDiscarded` check (Property.swift:706-707)
- [x] 1.3 Return a `gaveUp` result with discarded/iteration metadata
  - **Impl**: `PropertyResult.gaveUp(discarded: Int, iterations: Int)` enum case (Property.swift:198)

## 2. Remove unsafe suchThat usage for assumptions
- [x] 2.1 Deprecate or restrict `Gen.suchThat` for use as assumptions
  - **Impl**: `@available(*, deprecated)` annotation + `fatalError` on exhaustion (Generator.swift:1399-1430)
- [x] 2.2 Update `Property.filter` to register an assumption predicate instead of filtering generation
  - **Impl**: `Property` struct has `assumption: (T) -> Bool` field (Property.swift:252); `EvaluatingProperty` supports `.discard(reason:)`

## 3. Tests
- [x] 3.1 Add unit tests demonstrating old behavior (invalid value can slip through) and new behavior (discarded)
  - **Impl**: Tests in `Tests/FunctionalTesting/` verify discard semantics
- [x] 3.2 Add integration test ensuring `gaveUp` is emitted when assumptions are too restrictive
  - **Impl**: `PropertyRunnerTests` includes gaveUp scenarios

## 4. Developer UX
- [x] 4.1 Failure output includes discarded count and gives guidance (increase maxDiscarded or adjust assumption)
  - **Impl**: `PrettyPrint.swift:888`, CLI outputs in `FuncTestCLI/main.swift`, `PropertyTestIntegration.swift:226-228`

---

## Next Steps
- [ ] Archive this change folder to `openspec/archive/fix-discard-semantics/`
- [ ] Verify spec delta is merged into `openspec/specs/pbt-core/spec.md`
