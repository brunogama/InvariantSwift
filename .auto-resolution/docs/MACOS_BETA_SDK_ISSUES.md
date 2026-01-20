# macOS Beta SDK: Testing Framework Loading Issue

## Problem Description

When running CLI executables that depend on the Swift Testing framework on macOS 26 beta SDK, the runtime fails to load the Testing framework:

```
dyld[87184]: Library not loaded: @rpath/Testing.framework/Versions/A/Testing
  Referenced from: .build/arm64-apple-macosx/debug/FuncTestCLI
  Reason: tried: '/usr/lib/swift/Testing.framework/Versions/A/Testing' (no such file, not in dyld cache)
```

### Root Cause

The Swift Testing framework is available at compile time (via Xcode toolchain) but not installed in the system runtime paths on macOS 26 beta. This is a known issue with pre-release SDKs where:

1. The Testing.framework is bundled with Xcode but not the macOS system
2. The dynamic linker (`dyld`) cannot find the framework at runtime
3. The `@rpath` search paths don't include the Xcode toolchain location

### Affected Scenarios

- ✅ `swift build` - Works
- ✅ `swift test` - Works (test runner handles framework loading)
- ❌ `swift run <executable>` - Fails if executable imports Testing
- ❌ Direct executable invocation - Fails

---

## Workarounds and Alternatives

### Option 1: Use GhostwriterPlugin (Recommended) ✅

Use the standalone Ghostwriter SPM plugin instead of the CLI:

```bash
# Generate tests for a source directory
swift package --allow-writing-to-package-directory ghostwrite Sources/Models/

# Preview without writing (dry run)
swift package --allow-writing-to-package-directory ghostwrite --dry-run --verbose

# Show help
swift package --allow-writing-to-package-directory ghostwrite --help
```

**Pros:** Works with current SDK, no Testing framework dependency at runtime
**Cons:** Requires `--allow-writing-to-package-directory` flag

### Option 2: Run with DYLD_FRAMEWORK_PATH

Set the framework search path to include Xcode's Testing framework:

```bash
export DYLD_FRAMEWORK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks:$DYLD_FRAMEWORK_PATH"
swift run FuncTestCLI ghostwrite --help
```

**Pros:** Quick fix
**Cons:** Must set for every invocation, may not work with SIP restrictions

### Option 3: Separate the CLI Target

Refactor the CLI to not directly import the Testing framework. Instead:

1. Create a `GhostwriterCore` library without Testing dependency
2. Have `FuncTestCLI` only import `GhostwriterCore`
3. Testing-dependent code stays in test targets only

```swift
// Package.swift
.target(
    name: "GhostwriterCore",
    dependencies: ["InvariantSwift"],  // No Testing import
    path: "Sources/GhostwriterCore"
),
.executableTarget(
    name: "FuncTestCLI",
    dependencies: ["GhostwriterCore"]  // Works without Testing
)
```

**Pros:** Clean separation, CLI works everywhere
**Cons:** Requires refactoring

### Option 4: Wait for Stable SDK

The Testing framework will be properly installed in system paths when:

1. macOS 26 exits beta (expected Feb 2026)
2. A stable Swift toolchain is released for macOS 26

**Pros:** No code changes needed
**Cons:** Waiting required

### Option 5: Use Static Linking (Advanced)

Build with static linking to embed all dependencies:

```bash
swift build -c release --static-swift-stdlib
```

**Pros:** Self-contained executable
**Cons:** Larger binary, may not work for all frameworks

---

## Current Status

For the InvariantSwift project:

| Feature | Status | Workaround |
|---------|--------|------------|
| `swift build` | ✅ Works | N/A |
| `swift test` | ✅ Works* | Use `make test-safe` for SIGTRAP handling |
| `swift run FuncTestCLI` | ❌ Fails | Use SPM plugin or set DYLD_FRAMEWORK_PATH |
| Ghostwriter functionality | ✅ Implemented | Can be tested via unit tests |

*Tests may crash during cleanup due to separate beta SDK issue

---

## Recommended Action

For now, the recommended approach is:

1. **Use `make test-safe`** for running tests (handles SIGTRAP crashes)
2. **Use the SPM plugin** for CLI functionality
3. **Wait for stable SDK** for direct CLI execution

The Ghostwriter implementation is complete and functional - only the CLI execution path is affected by this SDK limitation.
