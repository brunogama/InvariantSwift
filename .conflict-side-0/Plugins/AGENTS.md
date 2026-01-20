# AGENTS.md - Plugins

> **Sub-package AGENTS.md** for `Plugins/`

## Package Identity

**Purpose:** Swift Package Manager command plugins for InvariantSwift  
**Framework:** Swift Package Manager Plugin API  
**Commands:** `swift package invariant`, `swift package ghostwrite`

---

## Directory Structure

```
Plugins/
├── InvariantSwiftPlugin/    # Main property testing plugin
│   └── InvariantSwiftPlugin.swift
└── GhostwriterPlugin/       # Auto-test generation plugin
    └── GhostwriterPlugin.swift
```

---

## Plugin Overview

### InvariantSwiftPlugin

**Command:** `swift package invariant`

Runs property-based tests with advanced features like coverage tracking and reporting.

```bash
# Run with default settings
swift package invariant

# With options (see --help for all)
swift package invariant --iterations 5000 --coverage
```

**Permissions:**
- Write to package directory (test reports, coverage data)
- Network connections (telemetry, coverage upload)

### GhostwriterPlugin

**Command:** `swift package ghostwrite`

Automatically generates property tests from source code analysis.

```bash
# Generate tests for all targets
swift package ghostwrite

# Generate for specific target
swift package ghostwrite --target MyTarget
```

**Permissions:**
- Write to package directory (generated test files)

---

## Plugin Development Patterns

### ✅ DO: Use CommandPlugin Protocol

```swift
// See: InvariantSwiftPlugin/InvariantSwiftPlugin.swift
import PackagePlugin

@main
struct InvariantSwiftPlugin: CommandPlugin {
  func performCommand(
    context: PluginContext,
    arguments: [String]
  ) async throws {
    // Get the tool
    let tool = try context.tool(named: "FuncTestCLI")
    
    // Build arguments
    var args: [String] = []
    
    // Execute
    let result = try await Process.run(tool.path, arguments: args)
  }
}
```

### ✅ DO: Handle Xcode context

```swift
#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension InvariantSwiftPlugin: XcodeCommandPlugin {
  func performCommand(
    context: XcodePluginContext,
    arguments: [String]
  ) throws {
    // Xcode-specific implementation
  }
}
#endif
```

### ❌ DON'T: Access file system outside package directory

Plugins can only write to locations granted by permissions.

---

## Testing Plugins

Plugins cannot have unit tests directly. To test:

1. Build the package: `swift build`
2. Run the plugin manually: `swift package invariant --help`
3. Verify output on a test project

---

## JIT Index Hints

```bash
# Find plugin entry points
rg -n "@main" Plugins/

# Find tool invocations
rg -n "context.tool" Plugins/

# Find permission declarations in Package.swift
rg -n "permissions:" Package.swift

# Find plugin capabilities
rg -n "capability:" Package.swift
```

---

## Common Gotchas

1. **Tool dependency** - Plugins depend on `FuncTestCLI`; it must build first
2. **Sandboxing** - Plugins run in a sandbox; limited file system access
3. **No test target** - Plugins cannot be tested with `swift test`
4. **Path handling** - Use `context.package.directory` for relative paths

---

## Pre-PR Checks

```bash
swift build && swift package invariant --help && swift package ghostwrite --help
```
