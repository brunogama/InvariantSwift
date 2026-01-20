# ISP-0008: Targeted Property Testing

- **Status:** Implemented
- **Priority:** P2 (Medium)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.0+

## Summary

Introduce the `#target()` directive to guide property test generation toward interesting inputs by optimizing for specified metrics, similar to Hypothesis's `target()` function.

## Motivation

### The Problem

Standard property testing generates inputs uniformly (or based on size). This means:

1. **Interesting regions are rare**: If bugs hide in 0.01% of the input space, random testing is unlikely to find them
2. **No feedback loop**: Generator doesn't learn from execution
3. **Wasted iterations**: Most inputs explore similar code paths

**Example: Testing an Optimizer**
```swift
@PropertyTest
func testOptimizer(program: Program) {
    let optimized = optimize(program)
    #expect(equivalent(program, optimized))
}
```

Random `Program` generation might produce:
- 90% trivial programs (few instructions)
- 9% slightly interesting programs
- 1% complex programs that stress the optimizer

The bugs are probably in that 1%!

### The Solution

**Targeted testing** biases generation toward inputs that maximize specified metrics:

```swift
@PropertyTest
func testOptimizer(program: Program) {
    let optimized = optimize(program)
    
    // Guide generation toward complex programs
    #target(program.instructionCount, label: "instruction count")
    #target(program.nestingDepth, label: "nesting depth")
    #target(optimized.optimizationsPeformed, label: "optimizations")
    
    #expect(equivalent(program, optimized))
}
```

The framework will bias future generation toward inputs that increase these metrics.

## Detailed Design

### The `#target` Directive

```swift
/// Record a metric to optimize during generation
@freestanding(expression)
public macro target(
    _ value: some Comparable & Numeric,
    label: String? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "TargetMacro")

/// Target with custom comparison
@freestanding(expression)
public macro target<T: Comparable>(
    _ value: T,
    label: String? = nil,
    comparing: (T, T) -> Bool = (<)
) = #externalMacro(module: "InvariantSwiftMacros", type: "TargetMacro")

/// Target toward a specific value (minimize distance)
@freestanding(expression)
public macro target<T: Numeric>(
    _ value: T,
    toward goal: T,
    label: String? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "TargetMacro")
```

### How It Works

1. **Run Phase**: Execute test, record target values
2. **Score Phase**: Compute how "interesting" the input was
3. **Feedback Phase**: Adjust generation to favor higher-scoring regions
4. **Iterate**: Repeat, climbing toward interesting inputs

```swift
// Conceptual implementation
struct TargetedRunner {
    var bestInputs: PriorityQueue<ScoredInput>
    var targetHistory: [String: [Double]]
    
    func runIteration(generator: Gen<Input>) -> Result {
        // Bias toward mutations of best inputs
        let input: Input
        if Double.random(in: 0...1) < 0.3 && !bestInputs.isEmpty {
            input = mutate(bestInputs.randomElement()!.input)
        } else {
            input = generator.sample()
        }
        
        // Run test, collect targets
        var targets: [String: Double] = [:]
        let result = runTest(input, targetCollector: &targets)
        
        // Score this input
        let score = computeScore(targets)
        if score > bestInputs.minScore {
            bestInputs.insert(ScoredInput(input: input, score: score))
        }
        
        return result
    }
    
    func computeScore(_ targets: [String: Double]) -> Double {
        // Normalize each target against historical best
        targets.map { key, value in
            let best = targetHistory[key]?.max() ?? value
            return value / best
        }.reduce(0, +)
    }
}
```

### Configuration

```swift
public struct TargetedConfig {
    /// Fraction of iterations to spend exploring vs exploiting
    public var explorationRate: Double = 0.3
    
    /// How many best inputs to keep
    public var elitePoolSize: Int = 100
    
    /// Mutation strategy for elite inputs
    public var mutationStrategy: MutationStrategy = .combined
    
    /// Target normalization
    public var normalization: Normalization = .relative
}

@PropertyTest(targeted: TargetedConfig(explorationRate: 0.5))
func testWithCustomConfig(input: Input) { ... }
```

### Multiple Targets

When multiple targets are specified, the framework balances between them:

```swift
@PropertyTest
func testCompiler(source: SourceFile) {
    let result = compile(source)
    
    #target(source.lineCount, label: "lines")
    #target(source.functionCount, label: "functions")
    #target(result.warnings.count, label: "warnings")
    #target(result.optimizationTime, label: "compile time")
    
    #expect(result.isValid)
}
```

**Balancing strategies:**
- **Pareto front**: Find inputs optimal in at least one dimension
- **Weighted sum**: Combine with configurable weights
- **Lexicographic**: Prioritize targets in order

```swift
@PropertyTest(targetStrategy: .pareto)
func testMultiObjective(input: Input) { ... }

@PropertyTest(targetStrategy: .weighted([
    "lines": 2.0,
    "complexity": 1.0
]))
func testWeighted(input: Input) { ... }
```

### Targeting Specific Values

Sometimes you want to hit a specific value, not maximize:

```swift
@PropertyTest
func testBoundaryConditions(array: [Int]) {
    // Try to find arrays where sort has to do a lot of work
    #target(array.inversions, toward: array.count * (array.count - 1) / 2)
    
    // Try to find arrays with specific size
    #target(array.count, toward: 100)
    
    let sorted = array.sorted()
    #expect(sorted.isSorted)
}
```

### Integration with Coverage Guidance

Targeted testing + coverage guidance = powerful combination:

```swift
@PropertyTest
@CoverageGuided  // Existing feature
func testCombined(input: ComplexInput) {
    // Coverage guidance explores new code paths
    // Targeting explores "interesting" inputs within each path
    
    #target(input.complexity)
    
    process(input)
}
```

### Reporting

After test completion, show target statistics:

```
✅ testOptimizer passed (100 examples)

Target Statistics:
  instruction count:
    min: 1, max: 847, median: 124
    Found inputs with 847 instructions (iteration 67)
    
  nesting depth:
    min: 0, max: 12, median: 3
    Found inputs with depth 12 (iteration 89)
    
  optimizations:
    min: 0, max: 23, median: 5
    Found inputs triggering 23 optimizations (iteration 91)

Coverage: 78% of branches (up from 45% without targeting)
```

### Adaptive Generation

The framework can use targets to tune generator parameters:

```swift
@PropertyTest
func testWithAdaptiveSize(array: [Int]) {
    // Target array size correlates with bugs found
    #target(array.count, label: "size")
    
    // Framework learns: larger arrays find more bugs
    // Future iterations: increase size parameter automatically
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Compiler/Optimizer Testing**
   ```swift
   @PropertyTest
   func testOptimizer(ast: AST) {
       #target(ast.nodeCount)
       #target(ast.depth)
       #target(countOptimizations(ast))
   }
   ```

2. **Performance Edge Cases**
   ```swift
   @PropertyTest
   func testHashMap(operations: [Op]) {
       let map = HashMap()
       for op in operations { map.apply(op) }
       
       #target(map.collisionCount)
       #target(map.longestChain)
       
       #expect(map.isConsistent)
   }
   ```

3. **Parser Stress Testing**
   ```swift
   @PropertyTest
   func testParser(source: String) {
       #target(source.count)
       #target(countNesting(source))
       #target(countEdgeCases(source))  // Unicode, escapes, etc.
       
       _ = try? parse(source)
   }
   ```

4. **Numerical Algorithms**
   ```swift
   @PropertyTest
   func testMatrixInversion(matrix: Matrix) {
       #target(matrix.conditionNumber)  // Ill-conditioned = harder
       
       let inverse = matrix.inverse()
       #expect((matrix * inverse).isIdentity(tolerance: 1e-10))
   }
   ```

5. **State Machine Exploration**
   ```swift
   @PropertyTest
   func testStateMachine(inputs: [Input]) {
       var machine = StateMachine()
       var statesVisited: Set<State> = []
       
       for input in inputs {
           machine.process(input)
           statesVisited.insert(machine.currentState)
       }
       
       #target(statesVisited.count, label: "states visited")
       #expect(machine.isValid)
   }
   ```

### ❌ When NOT to Use

1. **Uniform coverage needed** — Targeting biases away from some regions
2. **Simple properties** — Overhead not worth it
3. **No meaningful metric** — Need something to optimize
4. **Very fast tests** — Overhead of tracking may dominate

## Importance

### Why This Matters

1. **Find Rare Bugs**
   - Guides testing toward edge cases
   - Explores extreme regions of input space
   - Finds bugs that random testing misses

2. **Efficient Exploration**
   - Don't waste iterations on boring inputs
   - Learn what "interesting" means for each test
   - Adaptive improvement over time

3. **Quantifiable Progress**
   - See how well you're exploring
   - Track metrics over time
   - Identify when testing is "stuck"

4. **Proven Technique**
   - Hypothesis's `target()` is widely used
   - Academic research validates effectiveness
   - Complement to coverage guidance

### Research Background

| Paper | Key Finding |
|-------|-------------|
| DART (2005) | Directed search finds more bugs |
| SAGE (2008) | Coverage + targeting for security |
| AFLSmart (2019) | Structure-aware fuzzing with targets |
| Hypothesis (2020) | Targeting in property testing |

## Implementation Notes

### Phase 1: Basic Targeting
- Single numeric target
- Simple maximize/minimize
- Basic feedback loop

### Phase 2: Multi-Target
- Multiple simultaneous targets
- Pareto optimization
- Weighted combinations

### Phase 3: Integration
- Combine with coverage guidance
- Adaptive generator tuning
- Rich reporting

### Phase 4: Advanced
- Machine learning-based prediction
- Transfer learning between tests
- Persistent target history

### Performance Considerations

- Target recording: O(1) per invocation
- Score computation: O(targets)
- Elite pool management: O(log n)
- Memory: O(elite_size * input_size)

## Alternatives Considered

### 1. Automatic Target Inference
```swift
// Framework automatically targets code coverage, branch coverage, etc.
@PropertyTest(autoTarget: true)
func test(input: Input) { ... }
```
- **Rejected**: Less flexible, doesn't capture domain knowledge

### 2. Annotation-Based
```swift
@Target(\.complexity)
@Target(\.size)
@PropertyTest
func test(input: Input) { ... }
```
- **Rejected**: Can't compute targets from test execution

### 3. Separate Fitness Function
```swift
@PropertyTest(fitness: { input in input.complexity + input.size })
func test(input: Input) { ... }
```
- **Rejected**: Duplicates test body logic, easy to desync

## References

- [Hypothesis target() Documentation](https://hypothesis.readthedocs.io/en/latest/details.html#targeted-example-generation)
- [Coverage-Guided Fuzzing with libFuzzer](https://llvm.org/docs/LibFuzzer.html#coverage-guided)
- [Swarm Testing](https://www.cs.utah.edu/~regehr/papers/swarm12.pdf) — Diverse configuration testing
- [Targeted Property-Based Testing](https://dl.acm.org/doi/10.1145/3092703.3092711) — ISSTA 2017
- [American Fuzzy Lop Technical Details](https://lcamtuf.coredump.cx/afl/technical_details.txt)
