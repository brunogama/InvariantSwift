---
id: S005
epic: E001
priority: P0
title: Add replay token output and determinism tests
status: todo
owners: ["llm"]
dependencies: ["S001","S004"]
files:
  - Sources/InvariantSwift/Core/Property.swift
  - Sources/InvariantSwift/Core/*
  - Tests/FunctionalTesting/**
---

## Scope
- Introduce `Replay` token type (Codable) capturing seed and config.
- Include replay token in failure results.
- Add determinism tests.

## Acceptance criteria
- Same replay token reproduces same failing case and same shrink result.
