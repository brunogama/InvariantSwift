# Pretty-Printing and Diff System

InvariantSwift provides a comprehensive pretty-printing and diff system for displaying test failures, counterexamples, and value comparisons.

## Overview

The system is built on Wadler's "A Prettier Printer" algorithm and provides:

- Structured formatting with syntax highlighting
- Diff visualization for before/after comparisons
- Smart truncation and folding for large structures
- Cycle detection for reference types
- Deterministic output for reproducible diffs

## PrettyPrintable Protocol

Conform to `PrettyPrintable` to customize how your types are displayed:

```swift
struct User: PrettyPrintable {
  let name: String
  let age: Int
  
  func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    .group(
      .concat(
        .text("User("),
        .nest(2, .concat([
          .line,
          .text("name: \"\(name)\","),
          .line,
          .text("age: \(age)")
        ])),
        .line,
        .text(")")
      )
    )
  }
}
```

Built-in conformances are provided for:
- `String`, `Int`, `Double`, `Bool`
- `Array<T>` where `T: PrettyPrintable`
- `Dictionary<K, V>` where both are `PrettyPrintable`
- `Optional<T>` where `T: PrettyPrintable`

## Diff System

Compare values with detailed diff output:

```swift
let printer = PrettyPrinter(config: .testOutput)
let diff = printer.diff(title: "User changed", old: user1, new: user2)
print(diff)
```

Output:
```
Diff: User changed
  - age: 30
  + age: 31

(First: -, Second: +)
```

### DiffFormat Options

Two formats are available:

| Format | Removed | Added | Unchanged | Best For |
|--------|---------|-------|-----------|----------|
| `.default` | `-` | `+` | ` ` | Terminal |
| `.proportional` | `−` (U+2212) | `+` | figure space | Xcode |

```swift
// Terminal output
printer.diff(title: "Test", old: a, new: b, format: .default)

// Xcode output (better alignment)
printer.diff(title: "Test", old: a, new: b, format: .proportional)
```

### Collection Diff with Collapse

When diffing arrays, unchanged elements are collapsed for readability:

```swift
let before = ["a", "b", "c", "d", "e", "f"]
let after = ["a", "b", "c", "X", "e", "f"]
let diff = before.diff(other: after)
```

Output:
```
  ... (3 unchanged)
- d
+ X
  ... (2 unchanged)
```

Disable collapse for full output:
```swift
before.diff(other: after, collapseUnchanged: false, collapseThreshold: 0)
```

## Test Assertions

### expectNoDifference

Assert two values are equal with diff-based failure messages:

```swift
expectNoDifference(actual, expected)
expectNoDifference(user1, user2, "Users should match")
```

On failure, shows exactly what differs:
```
Difference detected:

- age: 30
+ age: 31

(First: -, Second: +)
```

### expectDifference

Assert a value changes in expected ways:

```swift
var counter = Counter(count: 0)

expectDifference(counter) {
  counter.increment()
} changes: {
  $0.count = 1
}
```

Non-exhaustive mode (omit operation to verify final state):
```swift
counter.increment()
expectDifference(counter) {
  $0.count = 1
}
```

Async operations:
```swift
await expectDifference(asyncCounter) {
  await asyncCounter.increment()
} changes: {
  $0.count = 1
}
```

## Cycle Detection

The `ObjectTracker` struct detects circular references in class graphs:

```swift
class Node {
  var name: String
  var next: Node?
  init(name: String) { self.name = name }
}

let a = Node(name: "A")
let b = Node(name: "B")
a.next = b
b.next = a  // Cycle!

var tracker = ObjectTracker()
// When printing:
// Node #1 (name: "A", next: Node #2 (name: "B", next: ↩︎ (see #1)))
```

## Deterministic Output

Dictionary and Set output is sorted by key/element string representation for reproducible diffs:

```swift
let dict = ["zebra": 1, "apple": 2, "mango": 3]
let printer = PrettyPrinter()

// Always outputs in alphabetical order:
// {"apple": 2, "mango": 3, "zebra": 1}
printer.print(dict)
```

## Configuration

`PrettyConfig` controls output behavior:

```swift
let config = PrettyConfig(
  pageWidth: 80,       // Line wrap width
  ribbonWidth: 60,     // Text before line breaks
  enableColors: true,  // ANSI color codes
  maxDepth: 10,        // Nesting depth limit
  maxLength: 100,      // Collection element limit
  indentSize: 2        // Spaces per indent level
)

let printer = PrettyPrinter(config: config)
```

Presets:
- `.testOutput` - Optimized for test failures (colors, moderate limits)
- `.compact` - Minimal output (no colors, smaller limits)

## Integration with Property Testing

Property test failures automatically use `PrettyPrinter` for formatted output:

```swift
@PropertyTest
func testSorting(xs: [Int]) {
  let sorted = xs.sorted()
  #expect(sorted.count == xs.count)
}
```

On failure:
```
Property failed after 42 iterations (predicateFailed).

Counterexample:
  [3, 1, 2]

Shrunk counterexample:
  [1]

Seed: 12345
```

## API Reference

### Types

| Type | Description |
|------|-------------|
| `Doc` | Document representation for pretty-printing |
| `PrettyConfig` | Configuration for output behavior |
| `PrettyPrinter` | Core printing engine |
| `DiffFormat` | Format options for diff output |
| `StructuredDiff` | Diff representation for complex types |
| `ObjectTracker` | Cycle detection for reference types |

### Protocols

| Protocol | Description |
|----------|-------------|
| `PrettyPrintable` | Types that can be pretty-printed |
| `Diffable` | Types that can be diffed |

### Functions

| Function | Description |
|----------|-------------|
| `prettyPrint(_:)` | Global pretty-print function |
| `prettyDiff(_:old:new:format:)` | Global diff function |
| `expectNoDifference(_:_:_:format:)` | Assert no difference |
| `expectDifference(_:_:format:operation:changes:)` | Assert expected changes |
