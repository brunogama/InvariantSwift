# ISP-0005: Differential Testing

- **Status:** Implemented
- **Priority:** P2 (Medium)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce `@DifferentialTest` macro for comparing two implementations against each other, automatically finding inputs where they diverge.

## Motivation

### The Problem

When refactoring, optimizing, or migrating code, you need to verify the new implementation behaves identically to the old one. Traditional approaches:

**Manual Testing:**
```swift
func testParserEquivalence() {
    let inputs = ["simple", "with spaces", "special!@#", ...]
    for input in inputs {
        XCTAssertEqual(oldParser(input), newParser(input))
    }
}
```
- Limited coverage
- Easy to miss edge cases
- Doesn't scale

**Property Test (Verbose):**
```swift
@PropertyTest
func testParserEquivalence(input: String) {
    let oldResult = oldParser(input)
    let newResult = newParser(input)
    #expect(oldResult == newResult)
}
```
- Better, but still boilerplate
- Doesn't express intent clearly
- Custom comparison logic is awkward

### The Solution

Declarative differential testing:

```swift
@DifferentialTest(
    reference: OldParser.parse,
    candidate: NewOptimizedParser.parse
)
func testParserMigration(input: String) { }

// With custom comparison
@DifferentialTest(
    reference: legacyAPI,
    candidate: modernAPI,
    comparing: { $0.normalized == $1.normalized }
)
func testAPIMigration(request: Request) { }
```

## Detailed Design

### The `@DifferentialTest` Macro

```swift
/// Compare two implementations for equivalence
@attached(body)
@attached(peer, names: named(test))
public macro DifferentialTest<Input, Output>(
    reference: (Input) throws -> Output,
    candidate: (Input) throws -> Output,
    comparing: ((Output, Output) -> Bool)? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "DifferentialTestMacro")
  where Output: Equatable

/// Async variant
@attached(body)
@attached(peer, names: named(test))
public macro DifferentialTest<Input, Output>(
    reference: (Input) async throws -> Output,
    candidate: (Input) async throws -> Output,
    comparing: ((Output, Output) -> Bool)? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "DifferentialTestMacro")
  where Output: Equatable

/// Multiple inputs variant
@attached(body)
@attached(peer, names: named(test))
public macro DifferentialTest<each Input, Output>(
    reference: (repeat each Input) throws -> Output,
    candidate: (repeat each Input) throws -> Output,
    comparing: ((Output, Output) -> Bool)? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "DifferentialTestMacro")
  where Output: Equatable
```

### Expansion Example

**Input:**
```swift
@DifferentialTest(
    reference: OldSort.sort,
    candidate: NewSort.sort
)
func testSortEquivalence(array: [Int]) { }
```

**Expands to:**
```swift
@Test(arguments: PropertyRunner.cases(for: [Int].self, count: 100))
func testSortEquivalence(array: [Int]) {
    let referenceResult: [Int]
    let candidateResult: [Int]
    
    // Capture reference result
    do {
        referenceResult = try OldSort.sort(array)
    } catch {
        Issue.record("Reference threw: \(error)")
        return
    }
    
    // Capture candidate result
    do {
        candidateResult = try NewSort.sort(array)
    } catch {
        Issue.record("""
            Candidate threw but reference succeeded.
            Input: \(array)
            Reference result: \(referenceResult)
            Candidate error: \(error)
            """)
        return
    }
    
    // Compare
    guard referenceResult == candidateResult else {
        Issue.record("""
            Implementations differ!
            Input: \(array)
            Reference: \(referenceResult)
            Candidate: \(candidateResult)
            Diff: \(diff(referenceResult, candidateResult))
            """)
        return
    }
}
```

### Error Behavior Modes

```swift
public enum ErrorBehavior {
    /// Both must throw the same error
    case mustMatch
    
    /// Both must throw (error type doesn't matter)
    case bothThrowOrBothSucceed
    
    /// Candidate may throw fewer errors than reference
    case candidateMaySucceedMore
    
    /// Ignore errors entirely
    case ignoreErrors
}

@DifferentialTest(
    reference: strictValidator,
    candidate: lenientValidator,
    errorBehavior: .candidateMaySucceedMore
)
func testValidatorMigration(input: String) { }
```

### Custom Comparison

For non-`Equatable` types or semantic equivalence:

```swift
// Floating point tolerance
@DifferentialTest(
    reference: oldCalculation,
    candidate: optimizedCalculation,
    comparing: { abs($0 - $1) < 0.0001 }
)
func testCalculation(values: [Double]) { }

// Structural equivalence
@DifferentialTest(
    reference: oldParser,
    candidate: newParser,
    comparing: { $0.ast.normalized == $1.ast.normalized }
)
func testParser(source: String) { }

// Set equivalence (order doesn't matter)
@DifferentialTest(
    reference: oldQuery,
    candidate: newQuery,
    comparing: { Set($0) == Set($1) }
)
func testQuery(filter: Filter) { }
```

### Differential Result Type

```swift
public struct DifferentialResult<Output> {
    public let input: Any
    public let referenceOutput: Result<Output, Error>
    public let candidateOutput: Result<Output, Error>
    
    public var diverges: Bool {
        switch (referenceOutput, candidateOutput) {
        case (.success(let r), .success(let c)):
            return r != c
        case (.failure, .failure):
            return false  // Both failed (configurable)
        default:
            return true   // One failed, one succeeded
        }
    }
}
```

### Batch Differential Testing

For testing multiple function pairs:

```swift
@DifferentialTestSuite
struct MathMigration {
    @DifferentialTest(reference: OldMath.sin, candidate: NewMath.sin)
    func testSin(x: Double) { }
    
    @DifferentialTest(reference: OldMath.cos, candidate: NewMath.cos)
    func testCos(x: Double) { }
    
    @DifferentialTest(reference: OldMath.sqrt, candidate: NewMath.sqrt)
    func testSqrt(x: Double) { }
}
```

### Integration with Custom Differ

Show meaningful diffs for complex types:

```swift
@DifferentialTest(
    reference: oldSerializer,
    candidate: newSerializer,
    differ: JSONDiffer()  // Custom diff visualization
)
func testSerializer(model: DataModel) { }

public protocol Differ<T> {
    func diff(_ lhs: T, _ rhs: T) -> String
}

public struct JSONDiffer: Differ<Data> {
    public func diff(_ lhs: Data, _ rhs: Data) -> String {
        // Pretty-print JSON diff
    }
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Algorithm Optimization**
   ```swift
   @DifferentialTest(
       reference: bubbleSort,      // Known correct
       candidate: quickSort        // Optimized
   )
   func testSortingOptimization(array: [Int]) { }
   ```

2. **Parser Migration**
   ```swift
   @DifferentialTest(
       reference: RegexParser.parse,
       candidate: SwiftParsingParser.parse,
       comparing: { $0.tokens == $1.tokens }
   )
   func testParserRewrite(source: String) { }
   ```

3. **API Version Upgrade**
   ```swift
   @DifferentialTest(
       reference: { try await APIV1.fetch($0) },
       candidate: { try await APIV2.fetch($0) }
   )
   func testAPIUpgrade(request: Request) async { }
   ```

4. **Database Query Rewrite**
   ```swift
   @DifferentialTest(
       reference: rawSQLQuery,
       candidate: ormQuery,
       comparing: { Set($0.rows) == Set($1.rows) }
   )
   func testORMEquivalence(filter: QueryFilter) { }
   ```

5. **Serialization Format Change**
   ```swift
   @DifferentialTest(
       reference: { try JSONEncoder().encode($0) },
       candidate: { try MessagePackEncoder().encode($0) },
       comparing: { decode($0) == decode($1) }
   )
   func testSerializationEquivalence(model: Model) { }
   ```

6. **Compiler/Interpreter**
   ```swift
   @DifferentialTest(
       reference: interpretAST,
       candidate: compileAndRun
   )
   func testCompilerCorrectness(program: Program) { }
   ```

### ❌ When NOT to Use

1. **No reference implementation** — Need something to compare against
2. **Intentionally different behavior** — New version is supposed to differ
3. **Non-deterministic functions** — Random, time-dependent results
4. **Performance testing** — Use benchmarks instead

## Importance

### Why This Matters

1. **Safe Refactoring**
   - Confidently rewrite code knowing tests will catch regressions
   - Find edge cases human review misses
   - Reduce fear of optimization

2. **Migration Confidence**
   - Library upgrades
   - Language version changes
   - Framework migrations
   - Database schema changes

3. **Bug Discovery**
   - Finds inputs where implementations diverge
   - Often uncovers bugs in BOTH implementations
   - Minimal failing cases via shrinking

4. **Documentation**
   - Explicitly states "these should be equivalent"
   - Captures semantic contracts
   - Serves as specification

### Real-World Examples

| Scenario | Bug Found |
|----------|-----------|
| Sort optimization | New sort was unstable (equal elements reordered) |
| JSON parser rewrite | Unicode escape handling differed |
| Math library migration | Edge case: `sin(π)` precision loss |
| ORM query builder | NULL handling in WHERE clauses |
| Compression algorithm | Off-by-one in buffer sizing |

## Implementation Notes

### Phase 1: Core Macro
- Basic `@DifferentialTest` for `Equatable` outputs
- Synchronous functions
- Default error behavior

### Phase 2: Enhanced Features
- Custom comparers
- Async support
- Error behavior modes
- Custom differs

### Phase 3: Tooling
- Diff visualization in test output
- Statistics on divergence
- Integration with coverage

### Failure Reporting

```
❌ Differential test failed: testSortEquivalence

Input: [3, 1, 2, 1]

Reference (OldSort.sort):
  [1, 1, 2, 3]

Candidate (NewSort.sort):
  [1, 2, 1, 3]

Diff:
  Index 1: expected 1, got 2
  Index 2: expected 2, got 1

Note: Candidate sort appears unstable (equal elements reordered)

To reproduce:
  @Reproduce(seed: 12345, path: "0:2:1")
```

## Alternatives Considered

### 1. Inline Comparison
```swift
@PropertyTest
func testEquiv(x: Int) {
    #expectEqual(reference: old(x), candidate: new(x))
}
```
- **Rejected**: Doesn't capture intent as clearly

### 2. Protocol-Based
```swift
protocol DifferentialTestable {
    associatedtype Input
    associatedtype Output
    static func reference(_: Input) -> Output
    static func candidate(_: Input) -> Output
}
```
- **Rejected**: Too much boilerplate

### 3. Automatic Discovery
```swift
// Automatically compare all functions named `old_*` vs `new_*`
@AutoDifferentialTest
struct Migration { ... }
```
- **Rejected**: Too magical, hard to control

## References

- [Differential Testing for Software](https://dl.acm.org/doi/10.1145/318774.318813) — McKeeman, 1998
- [Csmith: Randomized Differential Testing](https://www.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf) — Found hundreds of compiler bugs
- [QuickFuzz: Grammar-Based Differential Testing](https://github.com/CIFASIS/QuickFuzz)
- [Hypothesis Differential Testing Guide](https://hypothesis.works/articles/hypothesis-vs-static-types/)
