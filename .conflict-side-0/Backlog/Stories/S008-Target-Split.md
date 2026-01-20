---
id: S008
epic: E004
priority: P1
title: Split runtime core from macros/CLI to reduce dependency leakage
status: done
owners: ["llm"]
dependencies: ["S005"]
files:
  - Package.swift
  - Sources/**
---

## Scope
- Introduce `InvariantCore` target with no SwiftSyntax deps.
- Make `InvariantSwift` re-export or depend on core.
- Ensure tests compile.
