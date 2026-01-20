# Tasks

- [ ] 1. Create `DiffEngine` module in `Presentation`
  - [ ] Implement String diffing (Myers/LCS)
  - [ ] Implement Collection diffing (Array)
  - [ ] Implement Dictionary diffing (Key-based)
  - [ ] Implement Reflection diffing (Struct/Class)
- [ ] 2. Add `diff` field to `FailureReport`
  - [ ] Update struct definition
  - [ ] Update `init` and `Builder`
- [ ] 3. Integrate into `FailureReporter`
  - [ ] Update `formatVerboseMessage` to show diff
- [ ] 4. Update `expectNoDifference`
  - [ ] Use `DiffEngine` to generate message
- [ ] 5. Add tests for `DiffEngine`
  - [ ] Test string diffs
  - [ ] Test nested struct diffs
  - [ ] Verify stability (sorting)
