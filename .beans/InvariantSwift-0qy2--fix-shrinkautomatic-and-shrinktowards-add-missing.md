---
# InvariantSwift-0qy2
title: Fix Shrink.automatic and Shrink.towards - Add Missing Runtime Methods
status: completed
type: bug
priority: high
created_at: 2026-01-16T22:03:29Z
updated_at: 2026-01-16T22:10:19Z
---

The @Arbitrary macro generates code referencing Shrink.automatic and Shrink.towards(target:) but these methods didn't exist in the runtime. This caused generated code to fail compilation.

## Completed Work

### 1. Added Missing Runtime Methods (Generator.swift)
- Added `Shrink.automatic` static property - returns empty shrink as no-op fallback
- Added `Shrink.towards(_:)` static function - returns target as single shrink candidate

### 2. Implemented Per-Field Shrinking (ArbitraryCodeGen.swift)
- Added `buildPerFieldShrink()` to generate per-field shrinking code
- Added `buildFieldShrinkLoop()` to generate for-loop for each field
- Added `inferShrink(for:)` to GeneratorInference.swift to get shrink from generator

### 3. Generated Code Pattern
```swift
public static var shrink: Shrink<User> {
    Shrink { value in
        var results: [User] = []
        for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
            results.append(User(name: shrunkName, age: value.age))
        }
        for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
            results.append(User(name: value.name, age: shrunkAge))
        }
        return results
    }
}
```

### 4. Updated Tests
- Updated all ArbitraryMacroTests to expect per-field shrinking pattern
- Added 4 tests in RecursiveShrinkingTests.swift for Shrink.automatic and Shrink.towards

## Test Results
- ArbitraryMacroTests: 15 tests pass
- GenMacroDSLTests: 33 tests pass
- RecursiveShrinkingTests: 4 new tests pass
