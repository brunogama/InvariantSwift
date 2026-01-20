---
description: Analyze and fix a GitHub issue by number
---

# Fix GitHub Issue Workflow

Analyze and fix GitHub issue: $ARGUMENTS

## Steps

// turbo
### 1. Get Issue Details
```bash
gh issue view $ARGUMENTS
```

### 2. Understand the Problem
- Read the issue description and comments
- Identify the expected vs actual behavior
- Note any reproduction steps

### 3. Search Codebase
- Use `rg` to find relevant files
- Read CLAUDE.md in relevant directories for patterns
- Understand the existing implementation

### 4. Implement Fix
- Follow established patterns from CLAUDE.md
- Use SwiftSyntax AST builders if editing macros (NO string interpolation)
- Ensure Sendable conformance for generators

### 5. Write/Update Tests
- Add tests that verify the fix
- Use Swift Testing (`@Test`, `@Suite`)
- Use deterministic seeds for reproducibility

// turbo
### 6. Quality Checks
```bash
swift build -Xswiftc -warnings-as-errors && \
swiftlint lint --strict && \
swift test
```

### 7. Create Commit
- Use Conventional Commits: `fix(component): description`
- Reference issue: `Fixes #$ARGUMENTS`

### 8. Create PR
```bash
gh pr create --title "Fix #$ARGUMENTS: [description]" --body "Fixes #$ARGUMENTS"
```

## Important
- Follow testing and code quality standards from CLAUDE.md
- If the fix requires API changes, update documentation
- If unsure about approach, ask before implementing
