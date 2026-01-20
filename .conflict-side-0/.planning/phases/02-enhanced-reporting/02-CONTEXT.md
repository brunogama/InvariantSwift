# Phase 2: Enhanced Reporting - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete QuickCheck reporting parity by adding value collection (`collect`), multi-dimensional tabulation (`tabulate`), and custom failure messages (`counterexample`). These features build on Phase 1's classification infrastructure to enhance debugging workflow and test quality verification.

</domain>

<decisions>
## Implementation Decisions

### Value Collection & Histograms
- **Bucketing strategy**: Automatic bucketing based on range (smart algorithm: 0-10 → individual values, 100-1000 → tens, 10000+ → hundreds)
- **Histogram format**: ASCII bar chart (visual: "0-10: ██████████ 42.3%")
- **Value filtering**: Claude's discretion on showing top N vs all values to prevent output spam
- **Visibility**: Configurable flag - histograms off by default, enable with configuration or flag

### Multi-Dimensional Tabulation
- **Category display**: Separate tables per category - each gets its own histogram/table with clear separation
- **Multiple labels per input**: Claude's discretion on counting semantics (independent vs combinations)
- **Limits**: Hard limits with warnings (max 10 categories, 100 labels per category)
- **Relationship to collect()**: Separate features - both can be used together, collect() for values, tabulate() for categories

### Counterexample Messages
- **Integration with existing output**: Claude's discretion on placement (augment vs replace vs prepend)
- **Multiple .counterexample() calls**: Accumulate all messages - show in order or as bullet list
- **Evaluation timing**: Claude's discretion on performance trade-off (lazy vs eager vs shrunk-only)
- **Length limits**: Smart truncation - keep full if <500 chars, otherwise truncate with "...(truncated)" and offer full in verbose mode

### Report Formatting & Verbosity
- **Default verbosity**: Always show in passing tests (like Phase 1) - transparency is key for developers to verify distributions
- **Column widths**: Claude's discretion on dynamic vs fixed vs terminal-aware
- **Visual styling**: Auto-detect terminal capabilities - use colors/emoji if supported, fallback to ASCII-only
- **Sorting**: Claude's discretion on ordering (frequency vs alphabetical vs coverage status)

### Claude's Discretion
- Exact histogram filtering algorithm (top N vs threshold)
- Integration placement for counterexample messages
- Counting semantics for multiple labels in tabulate()
- Evaluation timing for counterexample closures
- Column width strategy for tables
- Label/category sorting order in reports

</decisions>

<specifics>
## Specific Ideas

- ASCII bar charts should use block characters (█) for visual appeal while remaining terminal-friendly
- Histogram bucketing needs intelligent range detection - small ranges get granular buckets, large ranges get coarser buckets
- Phase 1 established "always show" precedent - Phase 2 reporting should follow this transparency principle by default
- Smart truncation at 500 characters balances readability with preventing extreme output spam
- Auto-detection for colors/emoji ensures accessibility (CI, old terminals, screen readers) while providing visual enhancement where possible

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 02-enhanced-reporting*
*Context gathered: 2026-01-23*
