# Technical Research: SwiftLint IDE Plugin with Rule-Based Fix Templates

## Strategic Summary

Three viable approaches exist for building a production-quality SwiftLint IDE plugin with fix suggestions: (1) **VS Code Extension** using LSP diagnostics with code actions, (2) **Copilot-for-Xcode-style Background Service** with Accessibility API overlay, or (3) **SourceKit-LSP Fork/Extension** adding SwiftLint as a diagnostic provider. The VS Code approach is recommended for fastest path to production; the Background Service approach is required for native Xcode integration but significantly more complex.

**Critical Finding**: XcodeKit Source Editor Extensions **cannot** show inline errors, warnings, or quick fixes. They only support menu-triggered text transformations. For true Xcode integration with inline diagnostics, you must use the Background Service + Accessibility API pattern (like Copilot for Xcode).

---

## Requirements

- Display SwiftLint violations inline in the editor (errors, warnings)
- Provide 3 rule-based fix suggestions per violation
- Production-quality: robust, well-tested, daily use
- IDE integration: Xcode or VS Code (or both)

---

## Approach 1: VS Code Extension with Code Actions

**How it works:** Build a VS Code extension that runs SwiftLint in the background, parses JSON output, converts violations to VS Code diagnostics, and provides CodeAction commands with pre-defined fix templates per rule.

**Libraries/tools:**
- `vscode` extension API (TypeScript)
- `swiftlint --reporter json` for machine-readable output
- VS Code `DiagnosticCollection` for inline errors
- VS Code `CodeActionProvider` for quick fixes

**Pros:**
- LSP-native diagnostics and code actions work seamlessly
- Mature ecosystem with excellent documentation
- Can distribute via VS Code Marketplace
- Existing `vscode-swiftlint` extension as reference implementation
- TypeScript allows rapid iteration

**Cons:**
- Not native Xcode - many Swift developers prefer Xcode
- Requires users to use VS Code or Cursor
- Must maintain separate tooling from Xcode workflow

**Best when:** Team uses VS Code/Cursor for Swift, or targeting cross-platform developers

**Complexity:** S (Small)

---

## Approach 2: Background Service + Accessibility API (Copilot for Xcode Pattern)

**How it works:** Create a macOS host app with a background service that monitors Xcode via Accessibility API, detects file changes, runs SwiftLint, and renders a floating overlay window near the cursor showing violations and fix options. Uses XPC for inter-process communication.

**Libraries/tools:**
- Swift (100% native)
- macOS Accessibility API (`AXUIElement`)
- XPC Services for process isolation
- AppKit for overlay windows
- Launch Agents for background service
- Optional: XcodeKit Source Editor Extension for menu commands

**Pros:**
- Works in native Xcode - matches developer workflow
- Full control over UI presentation
- Can show inline-style overlays near code
- Same architecture as Copilot for Xcode (proven at scale)
- No VS Code dependency

**Cons:**
- Significantly more complex to build
- Requires Accessibility permissions (user approval)
- Must handle Xcode version updates carefully
- Two-app architecture (host + service) adds complexity
- macOS sandboxing challenges

**Best when:** Must have native Xcode integration, willing to invest in complex architecture

**Complexity:** L (Large)

---

## Approach 3: SourceKit-LSP Extension/Fork

**How it works:** Fork or extend SourceKit-LSP to add SwiftLint as an additional diagnostic provider. Leverage SourceKit-LSP's existing `codeActionsInline` capability to embed fix suggestions directly in diagnostics. Works with any LSP-compatible editor (VS Code, Neovim, Emacs).

**Libraries/tools:**
- Swift (SourceKit-LSP codebase)
- `swift-syntax` for AST-aware fixes
- LSP `textDocument/publishDiagnostics` with code actions
- SwiftPM for distribution

**Pros:**
- Leverages existing LSP infrastructure
- Works across multiple editors simultaneously
- Deep integration with Swift toolchain
- Code actions are LSP-native
- Community contribution path to upstream

**Cons:**
- SourceKit-LSP codebase is complex
- Maintaining a fork is ongoing burden
- Upstream may not accept SwiftLint integration
- SwiftLint violations may conflict with SourceKit diagnostics

**Best when:** Want editor-agnostic solution, comfortable with Swift compiler toolchain

**Complexity:** L (Large)

---

## Approach 4: Xcode Source Editor Extension (Limited)

**How it works:** Standard XcodeKit Source Editor Extension that adds menu commands like "Lint File" and "Fix All SwiftLint Issues".

**Libraries/tools:**
- `XcodeKit` framework
- Swift
- SwiftLint CLI

**Pros:**
- Official Apple API
- Simple to implement
- App Store distributable
- Works in Xcode natively

**Cons:**
- **CANNOT show inline diagnostics** - only menu-triggered text transforms
- User must manually invoke from Editor menu
- No visual feedback for violations
- Essentially just a SwiftLint wrapper with extra steps

**Best when:** Only need batch fix commands, not real-time feedback

**Complexity:** S (Small) - but does not meet requirements

---

## Comparison

| Aspect | VS Code Extension | Background Service | SourceKit-LSP Fork | XcodeKit Extension |
|--------|-------------------|--------------------|--------------------|-------------------|
| Complexity | S | L | L | S |
| Inline Errors | Yes | Yes (overlay) | Yes | **No** |
| Code Actions | Yes | Yes | Yes | **No** (menu only) |
| Xcode Native | No | Yes | Partial | Yes |
| Maintenance | Low | High | High | Low |
| Distribution | Marketplace | Notarization | Swift toolchain | App Store |
| Time to MVP | 1-2 weeks | 6-8 weeks | 4-6 weeks | 1 week |

---

## Recommendation

**For production quality with maximum reach: VS Code Extension (Approach 1)**

Given:
- Production quality requirement
- Rule-based templates (deterministic, not AI)
- Clear path to completion

The VS Code extension approach provides the best balance of:
1. Native support for diagnostics + code actions (LSP)
2. Existing reference implementation (`vscode-swiftlint`)
3. Straightforward architecture
4. Rapid iteration in TypeScript

**If Xcode is non-negotiable:** Approach 2 (Background Service) is the only viable path for true inline diagnostics, but expect 4-6x development effort.

---

## Implementation Context

<claude_context>
<chosen_approach>
- name: VS Code Extension with Code Actions
- libraries: vscode@^1.85.0, @types/vscode@^1.85.0
- install: |
    npm init -y
    npm install --save-dev @types/vscode typescript @vscode/vsce
    npx yo code  # VS Code extension generator
</chosen_approach>
<architecture>
- pattern: Provider-based architecture with DiagnosticCollection + CodeActionProvider
- components:
  - SwiftLintRunner: Executes swiftlint --reporter json, parses output
  - DiagnosticConverter: Maps SwiftLint violations to VS Code Diagnostic[]
  - FixTemplateRegistry: Rule -> Fix[] mapping with 3 suggestions per rule
  - CodeActionProvider: Returns CodeAction[] for each diagnostic
  - ConfigurationManager: Handles swiftlint path, config file location
- data_flow: |
    File change -> SwiftLintRunner -> JSON violations -> DiagnosticConverter
    -> DiagnosticCollection (shows errors) -> User clicks lightbulb
    -> CodeActionProvider -> FixTemplateRegistry -> Apply edit
</architecture>
<files>
- create:
  - src/extension.ts (entry point, activation)
  - src/swiftlint/runner.ts (CLI execution)
  - src/swiftlint/parser.ts (JSON violation parsing)
  - src/diagnostics/converter.ts (violation -> Diagnostic)
  - src/diagnostics/provider.ts (DiagnosticCollection management)
  - src/fixes/registry.ts (rule -> fix templates)
  - src/fixes/codeActionProvider.ts (CodeActionProvider implementation)
  - src/fixes/templates/*.ts (per-rule fix templates)
  - src/config/settings.ts (extension settings)
- structure: |
    swiftlint-fixer/
    ├── src/
    │   ├── extension.ts
    │   ├── swiftlint/
    │   ├── diagnostics/
    │   ├── fixes/
    │   └── config/
    ├── package.json
    ├── tsconfig.json
    └── README.md
- reference:
  - https://github.com/vknabel/vscode-swiftlint (existing implementation)
  - VS Code extension samples
</files>
<implementation>
- start_with: SwiftLintRunner + basic DiagnosticCollection (show errors first)
- order:
  1. Extension scaffolding + activation
  2. SwiftLintRunner executes CLI, captures JSON
  3. DiagnosticConverter creates VS Code diagnostics
  4. Test: violations appear as squiggles
  5. FixTemplateRegistry with 5-10 common rules
  6. CodeActionProvider returns fixes
  7. Test: lightbulb shows 3 options per violation
  8. Expand FixTemplateRegistry to all correctable rules
  9. Settings for swiftlint path, auto-fix on save
  10. Package and publish
- gotchas:
  - SwiftLint JSON output includes `file`, `line`, `character`, `severity`, `type`, `rule_id`
  - Diagnostics need correct Range (0-indexed in VS Code)
  - Code actions must return workspace edits, not just text
  - Some rules have no obvious fix - provide "suppress with comment" as fallback
  - Consider debouncing file change events
- testing:
  - Unit test parser with sample JSON
  - Unit test FixTemplateRegistry with rule coverage
  - Integration test with real Swift files
  - E2E: manually verify in VS Code
</implementation>
</claude_context>

**Next Action:** Scaffold VS Code extension with extension generator, implement SwiftLintRunner, and verify diagnostics appear for a test Swift file.

---

## Fix Template Architecture

For the 3 solutions per violation requirement, each rule maps to a `FixTemplate`:

```typescript
interface FixTemplate {
  ruleId: string;
  fixes: [Fix, Fix, Fix]; // Exactly 3 options
}

interface Fix {
  title: string;           // "Remove trailing whitespace"
  edit: TextEdit | null;   // null = no auto-fix available
  isPreferred?: boolean;   // First option typically preferred
}
```

**Example for `trailing_whitespace`:**
```typescript
{
  ruleId: "trailing_whitespace",
  fixes: [
    { title: "Remove trailing whitespace", edit: removeWhitespace, isPreferred: true },
    { title: "Disable rule for this line", edit: addDisableComment },
    { title: "Disable rule for entire file", edit: addFileDisableComment }
  ]
}
```

**Fallback for rules without clear fixes:**
1. "Disable rule for this line"
2. "Disable rule for entire file"
3. "View rule documentation"

---

## Sources

- [vknabel/vscode-swiftlint](https://github.com/vknabel/vscode-swiftlint) - Existing VS Code SwiftLint extension
- [NSHipster: XcodeKit](https://nshipster.com/xcode-source-extensions/) - XcodeKit limitations documentation
- [intitni/CopilotForXcode](https://github.com/intitni/CopilotForXcode) - Background service architecture reference
- [SourceKit-LSP Extensions](https://github.com/swiftlang/sourcekit-lsp/blob/main/Contributor%20Documentation/LSP%20Extensions.md) - LSP code actions support
- [SwiftLint Rule Directory](https://realm.github.io/SwiftLint/rule-directory.html) - Rule catalog (~255 rules)
- [p-x9/SwiftLintXcodePlugin](https://github.com/p-x9/SwiftLintXcodePlugin) - XPC-based Xcode integration
