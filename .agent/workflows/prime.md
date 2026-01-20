---
description: Initialize project context and validate setup
---

# Prime Workflow

Initialize project context and validate setup.

## Steps

// turbo
### 1. View Project Structure
```bash
eza Sources/ --tree --level=2
```

// turbo
### 2. Read Project Overview
Read the README.md file to understand project purpose and setup.

// turbo
### 3. Read Development Guidelines
Read CLAUDE.md and AGENTS.md to understand:
- Code conventions
- Testing requirements
- Build commands
- Security rules

// turbo
### 4. Validate Build
```bash
swift build 2>&1 | head -20
```

// turbo
### 5. Run Quick Test
```bash
swift test --filter GeneratorTests 2>&1 | tail -10
```

## Summary

After running this workflow, you will have:
- Understanding of project structure
- Knowledge of coding conventions
- Validated build environment
