---
id: S003
epic: E002
priority: P0
title: Introduce ShrinkTree and adapt existing shrinkers
status: done
owners: ["llm"]
dependencies: []
files:
  - Sources/InvariantSwift/Core/Generator.swift
  - Sources/InvariantSwift/Core/Property.swift
  - Tests/FunctionalTesting/**
---

## Problem
`Shrink.contramap` and `Shrink.flatMap` are placeholders; composed generators do not shrink.

## Scope
- Add `ShrinkTree<T>` type.
- Provide adapters from current `Shrink<T>` list model to `ShrinkTree`.
- Ensure deterministic child ordering.

## Acceptance criteria
- A mapped generator can still shrink using tree mapping.
- A flatMapped generator shrinks (at least base value) without relying on stubbed `Shrink.flatMap`.
