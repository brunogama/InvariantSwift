# MCP Server Setup Guide for InvariantSwift

Complete setup guide for Model Context Protocol (MCP) servers optimized for InvariantSwift development.

---

## Quick Start (5 Minutes)

### 1. Install Core MCP Servers

```bash
# Internet Research (Exa Search)
claude mcp add exa-search -- npx -y @upwinded/exa-mcp

# Web Scraping (Firecrawl)
claude mcp add firecrawl -- npx -y @mendable/firecrawl-mcp

# Codebase Analysis (Repomix)
claude mcp add repomix -- npx -y @repomix/mcp

# Complex Thinking (Sequential Thinking)
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# Memory (Project-Scoped)
claude mcp add memory --scope project -- npx -y @modelcontextprotocol/server-memory

# GitHub Integration
claude mcp add github -- npx -y @modelcontextprotocol/server-github
```

### 2. Verify Installation

```bash
claude mcp list
```

Expected output:
```
✓ exa-search
✓ firecrawl
✓ repomix
✓ sequential-thinking
✓ memory (project scope)
✓ github
```

### 3. Test MCP Servers

Start Claude Code and test:
```
Ask Claude: "Use exa-search to find recent papers on property-based testing"
Ask Claude: "Use repomix to analyze the InvariantSwift codebase structure"
Ask Claude: "Use memory to remember: We use Swift 6.0 with strict concurrency"
```

---

## Detailed Setup

### MCP Server #1: Exa Search

**Purpose**: Internet research for property-based testing patterns, algorithms, academic papers.

**Installation**:
```bash
claude mcp add exa-search -- npx -y @upwinded/exa-mcp
```

**Configuration**: Requires Exa API key.

Create `.env.local`:
```bash
EXA_API_KEY=your_exa_api_key_here
```

Get API key: https://exa.ai (Free tier: 1000 searches/month)

**Usage Examples**:
```
"Use exa-search to find Swift property testing libraries similar to QuickCheck"
"Search for academic papers on shrinking algorithms for property-based testing"
"Find Swift Evolution proposals related to macros"
```

**When to Use**:
- Researching property testing patterns
- Finding academic papers (QuickCheck, Hedgehog, Hypothesis)
- Discovering Swift libraries
- Swift Evolution proposal research

---

### MCP Server #2: Firecrawl

**Purpose**: Deep web scraping for documentation (SwiftSyntax API, Swift.org, Apple docs).

**Installation**:
```bash
claude mcp add firecrawl -- npx -y @mendable/firecrawl-mcp
```

**Configuration**: Requires Firecrawl API key.

Add to `.env.local`:
```bash
FIRECRAWL_API_KEY=your_firecrawl_api_key_here
```

Get API key: https://firecrawl.dev (Free tier: 500 pages/month)

**Usage Examples**:
```
"Use firecrawl to scrape SwiftSyntax documentation for MacroExpansionContext API"
"Fetch the latest Swift Testing documentation from swift.org"
"Get Apple's documentation for Swift concurrency"
```

**When to Use**:
- SwiftSyntax API documentation (frequently updated)
- Swift.org blog posts and announcements
- Apple documentation (when Ref MCP doesn't have it)
- GitHub repository READMEs

---

### MCP Server #3: Repomix

**Purpose**: Codebase analysis, packaging entire codebases for AI analysis.

**Installation**:
```bash
claude mcp add repomix -- npx -y @repomix/mcp
```

**Configuration**: No API key required.

**Usage Examples**:
```
"Use repomix to analyze the InvariantSwift codebase structure"
"Package Sources/InvariantSwiftMacros/ for detailed analysis"
"Generate a dependency graph of InvariantSwift targets"
```

**When to Use**:
- Understanding large codebases
- Analyzing dependency relationships
- Finding code patterns across entire project
- Before major refactoring (see full context)

**Pro Tip**: Combine with sequential-thinking for architectural analysis:
```
"Use sequential-thinking and repomix to analyze if we should split InvariantSwift into multiple packages"
```

---

### MCP Server #4: Sequential Thinking

**Purpose**: Complex refactoring decisions respecting RULES.md budgets, architectural choices.

**Installation**:
```bash
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking
```

**Configuration**: No API key required.

**Usage Examples**:
```
"Use sequential-thinking to decide if Gen.swift should be split (approaching 400 line budget)"
"Analyze trade-offs: Should we use async generators or sync generators with async wrappers?"
"Plan refactoring of shrinking algorithm to reduce cyclomatic complexity from 12 to 8"
```

**When to Use**:
- Budget-constrained refactoring decisions (RULES.md)
- Architectural trade-offs (performance vs simplicity)
- Complex API design decisions
- Before major changes (plan with thinking first)

**Critical**: Always use for refactoring when approaching budget limits:
- Function >50 lines → "Use sequential-thinking to plan splitting this function"
- File >350 lines → "Use sequential-thinking to plan file split strategy"
- Complexity >8 → "Use sequential-thinking to reduce complexity"

---

### MCP Server #5: Memory (Project-Scoped)

**Purpose**: Track decisions, rationale, architectural choices across sessions.

**Installation**:
```bash
claude mcp add memory --scope project -- npx -y @modelcontextprotocol/server-memory
```

**Configuration**: Stores data in `.claude/memory/` (gitignore recommended).

Add to `.gitignore`:
```
.claude/memory/
```

**Usage Examples**:

**Storing Memories** (use `#` prefix):
```
# Remember: We decided to use SwiftSyntax 602.0.0+ for Swift 6.0/6.1/6.2 compatibility
# Remember: Coverage enforcement is strict 99% - use SKIP=swift-coverage-guard only for exceptional cases
# Remember: ISP-0011 planned for Ghostwriter v2 with AI-powered test generation
# Remember: Gen.swift approaching 400 lines - next PR should split into Gen+Helpers.swift
```

**Querying Memories**:
```
Ask: "What did we decide about SwiftSyntax versions?"
Ask: "Why is coverage 99% and not 95%?"
Ask: "What's the plan for ISP-0011?"
Ask: "Which files are approaching budget limits?"
```

**When to Use**:
- After architectural decisions
- When hitting budget limits (record rationale for not splitting yet)
- ISP proposal decisions
- Refactoring plans spanning multiple sessions

**Pro Tip**: Use memory with sequential-thinking:
```
"Use sequential-thinking to decide file split strategy, then use memory to record the decision"
```

---

### MCP Server #6: GitHub

**Purpose**: Issue/PR management, ISP proposal tracking, CI failure investigation.

**Installation**:
```bash
claude mcp add github -- npx -y @modelcontextprotocol/server-github
```

**Configuration**: Requires GitHub Personal Access Token.

Add to `.env.local`:
```bash
GITHUB_TOKEN=ghp_your_github_token_here
```

Get token: https://github.com/settings/tokens (scopes: `repo`, `read:org`)

**Usage Examples**:
```
"Use github to list open issues labeled 'ISP-proposal'"
"Create GitHub issue for ISP-0011: AI-Powered Ghostwriter"
"Check CI failures for PR #42"
"List recent releases and their changelog"
```

**When to Use**:
- Creating ISP proposal issues
- Tracking ISP implementation status
- CI/CD failure investigation
- Release management

---

## Optional MCP Servers

### Semly RAG (Advanced Codebase QA)

**Purpose**: RAG (Retrieval-Augmented Generation) for codebase Q&A.

**Installation**:
```bash
claude mcp add semly-rag -- npx -y semly-rag
```

**Usage**:
```
"Use semly-rag to find where shrinking is implemented in InvariantSwift"
"How does Gen.flatMap work internally?"
```

**Note**: Similar to repomix but optimized for Q&A. Use repomix for full context, semly-rag for specific questions.

---

## Project .mcp.json Configuration

Create `.mcp.json` in project root (commit to git for team sharing):

```json
{
  "$schema": "https://modelcontextprotocol.io/schema/mcp.json",
  "mcpServers": {
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {
        "MEMORY_SCOPE": "project",
        "MEMORY_DIR": "${PROJECT_ROOT}/.claude/memory"
      }
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "sequential-thinking": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

**Benefits**:
- Team-wide consistent MCP configuration
- Version-controlled MCP setup
- Environment variable templating

---

## Environment Variables

Create `.env.local` (gitignored) with API keys:

```bash
# Exa Search
EXA_API_KEY=your_exa_api_key_here

# Firecrawl
FIRECRAWL_API_KEY=your_firecrawl_api_key_here

# GitHub
GITHUB_TOKEN=ghp_your_github_token_here
```

**Security**:
- `.env.local` is in `.gitignore`
- Never commit API keys
- Use personal tokens (not shared team tokens)

---

## MCP Usage Patterns

### Pattern 1: Research → Implement → Document

```
1. Research: "Use exa-search to find shrinking algorithms for recursive types"
2. Implement: Write code based on research
3. Document: "Update docs/COOKBOOK.md with shrinking pattern"
4. Remember: "# Remember: We use integrated shrinking (ISP-0002) not separate shrink trees"
```

### Pattern 2: Complex Refactoring

```
1. Analyze: "Use repomix to analyze Gen.swift and its dependencies"
2. Think: "Use sequential-thinking to plan splitting Gen.swift respecting RULES.md budgets"
3. Remember: "# Remember: Gen.swift split plan: Gen+Core, Gen+Combinators, Gen+Helpers"
4. Implement: Split files according to plan
5. Verify: "/validate-pr to ensure quality gates pass"
```

### Pattern 3: ISP Proposal Workflow

```
1. Research: "Use exa-search for similar features in other property testing libraries"
2. Create Proposal: "/create-isp 'Proposal Title'"
3. Track: "Use github to create issue linking to ISP-0011"
4. Remember: "# Remember: ISP-0011 discussion scheduled for next sprint"
5. Document: Update ISP with decisions from discussion
```

### Pattern 4: Bug Investigation

```
1. Search: "Use repomix to find all usages of problematic API"
2. Analyze: "Use sequential-thinking to understand why bug occurs"
3. Fix: Implement fix respecting budgets
4. Test: "/run-tests ComponentTests"
5. Document: "Update COOKBOOK.md with gotcha if pattern is non-obvious"
```

---

## Troubleshooting

### Issue: MCP Server Not Found

```bash
# Check if installed
claude mcp list

# Reinstall
claude mcp remove <server-name>
claude mcp add <server-name> -- npx -y <package>
```

### Issue: API Key Not Working

```bash
# Verify .env.local exists
cat .env.local

# Verify MCP can read environment
echo $EXA_API_KEY  # Should print key
```

### Issue: Memory Not Persisting

```bash
# Check memory directory
ls -la .claude/memory/

# Verify scope
claude mcp list | grep memory
# Should show: memory (project scope)
```

### Issue: GitHub MCP Fails

```bash
# Test GitHub token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Verify token scopes include 'repo'
```

---

## MCP Best Practices

### DO:
- ✅ Use exa-search for research before implementing
- ✅ Use sequential-thinking for budget-constrained refactoring
- ✅ Use memory to track decisions (use `#` prefix)
- ✅ Use repomix before major architectural changes
- ✅ Use github for ISP proposal tracking

### DON'T:
- ❌ Don't use Firecrawl for every documentation lookup (use Ref MCP first)
- ❌ Don't use repomix for single-file analysis (use Read tool)
- ❌ Don't store secrets in memory (use .env.local)
- ❌ Don't rely on memory across different Claude Code instances (memory is session-local)

### Performance Tips:
- Exa Search is fast (~1-2 seconds per query)
- Firecrawl is slow (~5-10 seconds per page)
- Repomix is medium (~10-30 seconds for full codebase)
- Sequential-thinking adds thinking time but improves decision quality
- Memory is instant (local file storage)

---

## Cost Management

### Free Tiers:
| MCP Server | Free Tier | Cost Beyond |
|------------|-----------|-------------|
| Exa Search | 1000 searches/month | $20/mo for 10K |
| Firecrawl | 500 pages/month | $29/mo for 5K |
| Repomix | Unlimited (local) | N/A |
| Sequential Thinking | Unlimited (local) | N/A |
| Memory | Unlimited (local) | N/A |
| GitHub | Unlimited (with token) | N/A |

**Recommendation**: Free tiers are sufficient for solo development. Upgrade if team usage.

---

## Integration with Claude Code Features

### MCP + Hooks

Hooks can trigger MCP server usage:

```json
{
  "UserPromptSubmit": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "if [[ \"$CLAUDE_USER_PROMPT\" =~ \"research\" ]]; then echo 'Hint: Use exa-search or firecrawl for research' && exit 0; fi"
        }
      ]
    }
  ]
}
```

### MCP + Custom Commands

Custom commands can leverage MCP servers:

```markdown
# /research-pattern command
1. Use exa-search to find pattern
2. Use sequential-thinking to evaluate applicability
3. Use memory to record decision
```

### MCP + Subagents

Subagents have access to ALL MCP servers (as specified):

```
macro-dev agent → Can use firecrawl for SwiftSyntax docs
test-gen agent → Can use repomix for codebase analysis
docs agent → Can use exa-search for related work
```

---

## Verification Checklist

After setup, verify all MCP servers work:

- [ ] `claude mcp list` shows all 6 servers
- [ ] Exa Search: "Use exa-search to find property testing papers" → Returns results
- [ ] Firecrawl: "Use firecrawl to scrape swift.org homepage" → Returns HTML/markdown
- [ ] Repomix: "Use repomix to analyze Sources/ directory" → Returns structure
- [ ] Sequential Thinking: "Use sequential-thinking to plan a complex refactoring" → Returns step-by-step plan
- [ ] Memory: "# Remember: Test memory" → "Ask: What did I ask you to remember?" → Returns "Test memory"
- [ ] GitHub: "Use github to list open issues" → Returns issue list

---

## Support

- **Claude Code Docs**: https://docs.anthropic.com/claude/docs/claude-code
- **MCP Specification**: https://modelcontextprotocol.io
- **InvariantSwift Issues**: https://github.com/YOUR_ORG/InvariantSwift/issues

---

## Next Steps

1. ✅ Install all 6 core MCP servers (5 minutes)
2. ✅ Create `.env.local` with API keys
3. ✅ Test each MCP server (verify checklist above)
4. ✅ Review `.mcp.json` and commit to git
5. ✅ Start using MCP servers in your workflow (see usage patterns)
6. 📖 Read [CLAUDE.md](CLAUDE.md) for full Claude Code integration guide

**Happy coding with AI superpowers!** 🚀
