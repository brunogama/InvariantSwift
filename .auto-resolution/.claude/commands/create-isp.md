# Create ISP Proposal

Create a new InvariantSwift Proposal (ISP) following the established format.

## Steps

1. **Parse Proposal Title** from `$ARGUMENTS`:
   - Example: "Stateful Property Testing"
   - No args: Ask user for title

2. **Determine Next ISP Number**:
   ```bash
   # Find highest ISP number
   ls docs/proposals/ISP-*.md | sort -V | tail -1
   # Next number: ISP-0011, ISP-0012, etc.
   ```

3. **Read ISP Template** from existing proposals:
   ```bash
   # Use ISP-0001 as template
   cat docs/proposals/ISP-0001-scheduler-race-condition-testing.md
   ```

4. **Create New ISP File**:
   - Filename: `docs/proposals/ISP-${NUMBER}-${SLUG}.md`
   - Slug: lowercase, hyphenated title

5. **Fill Template Sections**:
   ```markdown
   # ISP-${NUMBER}: ${TITLE}
   
   ## Metadata
   - **Status**: Draft
   - **Author**: [From user context or ask]
   - **Created**: $(date +%Y-%m-%d)
   - **Updated**: $(date +%Y-%m-%d)
   
   ## Summary
   [One-paragraph summary]
   
   ## Motivation
   [Why is this needed? What problem does it solve?]
   
   ## Proposed Solution
   [High-level design]
   
   ## Detailed Design
   [API design, implementation approach]
   
   ## Impact
   - **Breaking Changes**: Yes/No
   - **API Additions**: List new public APIs
   - **Dependencies**: Any new dependencies
   
   ## Alternatives Considered
   [Other approaches and why rejected]
   
   ## References
   - Related ISPs
   - External papers/libraries
   ```

6. **Update Proposal Index**:
   - Add entry to `docs/proposals/README.md` (if exists)
   - Or list in root `README.md`

7. **Suggest Next Steps**:
   - Create GitHub issue linking to ISP
   - Schedule discussion
   - Prototype implementation

## Usage

```
/create-isp "Stateful Property Testing"
/create-isp "Ghostwriter AI Integration"
/create-isp
```

## Existing ISP Proposals

- ISP-0001: Scheduler Race Condition Testing
- ISP-0002: Composite Generators
- ISP-0003: Rule-Based Stateful Testing
- ISP-0004: Example Database Reproduce
- ISP-0005: Differential Testing
- ISP-0006: Contract Testing
- ISP-0007: libFuzzer Integration
- ISP-0008: Targeted Property Testing
- ISP-0009: Ghostwriter
- ISP-0010: Faker Integration

## Notes

- Proposals follow RFC 2119 language (MUST, SHOULD, MAY)
- Status lifecycle: Draft → Accepted → Implemented → Rejected
- All ISPs are tracked in version control
- Use OpenSpec workflow for complex proposals (see `@/openspec/AGENTS.md`)
