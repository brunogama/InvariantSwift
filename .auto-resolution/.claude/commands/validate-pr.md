# Validate PR Before Submission

Run full validation pipeline before creating a pull request.

## Steps

1. **Run Formatting**:
   ```bash
   swift-format -i --configuration .swift-format --recursive ./Sources ./Tests
   echo "✅ Code formatted"
   ```

2. **Run Linting**:
   ```bash
   swiftlint lint --fix --config .swiftlint.yml
   swiftlint lint --strict --config .swiftlint.yml
   echo "✅ Linting passed (strict mode)"
   ```

3. **Build with Warnings as Errors**:
   ```bash
   swift build -Xswiftc -warnings-as-errors
   echo "✅ Build passed (zero warnings)"
   ```

4. **Run All Tests**:
   ```bash
   swift test | xcbeautify
   echo "✅ All tests passed"
   ```

5. **Check Coverage**:
   ```bash
   swift test --enable-code-coverage
   scripts/check-coverage.sh
   echo "✅ Coverage >= 99%"
   ```

6. **Check Documentation** (optional, warning only):
   ```bash
   python3 check_docs.py --verbose || true
   echo "⚠️  Documentation check complete (warnings only)"
   ```

7. **Git Status Check**:
   ```bash
   git status --porcelain
   # Warn if uncommitted changes exist
   ```

8. **Summary Report**:
   ```
   ✅ Formatting: PASSED
   ✅ Linting: PASSED (0 violations)
   ✅ Build: PASSED (0 warnings)
   ✅ Tests: PASSED (X/X tests)
   ✅ Coverage: PASSED (99.X%)
   ⚠️  Docs: XX undocumented APIs
   
   Ready to commit and push!
   ```

## Usage

```
/validate-pr
```

**This command runs ALL quality gates.** Equivalent to:
```bash
make validate && scripts/check-coverage.sh && python3 check_docs.py
```

## Pre-Commit Hooks

This command replicates what pre-commit hooks will check:
1. ✨ swift-format
2. 🤠 swiftlint (fix + strict)
3. 🧪 swift test
4. 📊 coverage >= 99%
5. ⚠️ warnings-as-errors

**Advantage**: Run validation BEFORE committing (pre-commit hooks run during `git commit`).

## Bypass Options

If validation fails and you need to commit anyway (EXCEPTIONAL):
```bash
# Skip specific hook
SKIP=swift-coverage-guard git commit -m "..."

# Skip all hooks (STRONGLY DISCOURAGED, blocked by Claude Code hooks)
# git commit --no-verify  # BLOCKED
```

## Notes

- Runs the same checks as GitHub Actions CI
- Catches issues before commit, saving time
- Use before every PR creation
- Recommended alias: `alias validate='/validate-pr'`
- Pre-commit hooks ensure quality, but this command is faster feedback
