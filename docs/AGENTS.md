# AGENTS.md - Documentation & Proposals

> **Sub-package AGENTS.md** for `docs/`

## Package Identity

**Purpose:** Project documentation, proposals, and guides  
**Format:** Markdown with code examples

---

## Directory Structure

```
docs/
├── proposals/                   # ISP proposals (ISP-0001 through ISP-0010)
│   ├── README.md               # Proposal process
│   ├── ISP-0001-*.md          # Scheduler race testing
│   ├── ISP-0002-*.md          # Composite generators
│   ├── ISP-0003-*.md          # Rule-based stateful testing
│   ├── ISP-0004-*.md          # Example database
│   ├── ISP-0005-*.md          # Differential testing
│   ├── ISP-0006-*.md          # Contract testing
│   ├── ISP-0007-*.md          # LibFuzzer integration
│   ├── ISP-0008-*.md          # Targeted property testing
│   ├── ISP-0009-*.md          # Ghostwriter
│   └── ISP-0010-*.md          # Faker integration
├── architecture/               # Architecture decision records
├── examples/                   # Code examples
├── ONBOARDING.md              # New contributor guide
├── COOKBOOK.md                # Usage patterns and recipes
├── GENERATORS.md              # Generator documentation
├── SHRINKING.md               # Shrinking strategies
├── MACROS.md                  # Macro usage guide
├── API_REFERENCE.md           # Public API docs
└── ROADMAP_TASK_BREAKDOWN.md  # Implementation roadmap
```

---

## Proposal Status

| ID | Title | Status |
|----|-------|--------|
| ISP-0001 | Scheduler Race Condition Testing | Implemented |
| ISP-0002 | Composite Generators | Implemented |
| ISP-0003 | Rule-Based Stateful Testing | Implemented |
| ISP-0004 | Example Database & Reproduce | Implemented |
| ISP-0005 | Differential Testing | Implemented |
| ISP-0006 | Contract Testing | Implemented |
| ISP-0007 | LibFuzzer Integration | Implemented |
| ISP-0008 | Targeted Property Testing | Implemented |
| ISP-0009 | Ghostwriter | Implemented |
| ISP-0010 | Faker Integration | Implemented |

---

## Proposal Template

When creating a new proposal:

```markdown
# ISP-00XX: [Title]

- **Status:** Draft | Review | Accepted | Implemented | Rejected
- **Priority:** P1 (Critical) | P2 (High) | P3 (Low)
- **Author:** [Name]
- **Created:** YYYY-MM-DD

## Summary
[One paragraph summary]

## Motivation
[Why this is needed]

## Proposed Solution
[Technical design]

## API Design
[Public API examples]

## Implementation Plan
[Step-by-step implementation]

## Alternatives Considered
[Other approaches evaluated]

## Risks
[Potential issues]
```

---

## Key Documentation Files

| File | Purpose |
|------|---------|
| `ONBOARDING.md` | New contributor setup guide |
| `COOKBOOK.md` | Common patterns and recipes |
| `GENERATORS.md` | How to write generators |
| `SHRINKING.md` | Shrinking strategies explained |
| `MACROS.md` | Macro usage examples |
| `API_REFERENCE.md` | Public API documentation |
| `proposals/README.md` | How to write proposals |

---

## JIT Index Hints

```bash
# Find proposal by topic
rg -l "faker|fuzzer|shrink" docs/proposals/

# Find all implemented proposals
rg -l "Status.*Implemented" docs/proposals/

# Find examples in docs
rg -n "```swift" docs/

# Find architecture decisions
ls docs/architecture/

# Find API documentation
rg -n "public func|public struct" docs/API_REFERENCE.md
```

---

## Documentation Conventions

1. **Code examples** - All examples must be runnable Swift
2. **API docs** - Use `///` comments in source, not separate docs
3. **Proposals** - Follow ISP template above
4. **Changelog** - Update CHANGELOG.md for all changes
