---
id: S004
epic: E002
priority: P0
title: Replace greedy-first shrinking with BFS default search
status: todo
owners: ["llm"]
dependencies: ["S003"]
files:
  - Sources/InvariantSwift/Core/Property.swift
  - Tests/FunctionalTesting/**
---

## Problem
Greedy-first shrinking often yields non-minimal counterexamples.

## Scope
- Implement BFS shrink search over `ShrinkTree`.
- Provide configuration to select strategy.

## Acceptance criteria
- On crafted examples, BFS finds smaller counterexamples than greedy-first.
- Deterministic across runs.
