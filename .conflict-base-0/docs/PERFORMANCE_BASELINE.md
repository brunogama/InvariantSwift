# Performance Baseline

**Generator and shrinking performance metrics for InvariantSwift.**

---

## Benchmark Environment

- **Platform**: macOS 14+, Swift 6.0+
- **Hardware**: Apple Silicon (M-series)
- **Configuration**: Release build, optimizations enabled

## Generator Performance

### Primitive Generators

| Generator | Target | Typical |
|-----------|--------|---------|
| `Gen.int` | 15,000+ ops/sec | ~18,000 ops/sec |
| `Gen.bool` | 20,000+ ops/sec | ~25,000 ops/sec |
| `Gen.double` | 15,000+ ops/sec | ~17,000 ops/sec |
| `Gen.string` (avg 20 chars) | 8,000+ ops/sec | ~10,000 ops/sec |

### Collection Generators

| Generator | Target | Typical |
|-----------|--------|---------|
| `Gen.array(of: Gen.int)` (size 10) | 5,000+ ops/sec | ~6,500 ops/sec |
| `Gen.array(of: Gen.int)` (size 50) | 2,000+ ops/sec | ~2,800 ops/sec |
| `Gen.dictionary` (10 pairs) | 2,000+ ops/sec | ~2,500 ops/sec |

### Memory Usage

| Generator | Per-Generation Overhead |
|-----------|------------------------|
| `Gen.int` | ~48 bytes |
| `Gen.string(20)` | ~120 bytes |
| `Gen.array(10)` | ~200 bytes |

## Shrinking Performance

### Shrink Time Targets

| Value Size | Target | Typical |
|------------|--------|---------|
| Int (0-1000) | <10ms | ~3ms |
| Array (10 elements) | <50ms | ~20ms |
| Array (100 elements) | <200ms | ~80ms |
| Nested structures | <500ms | varies |

### Shrink Space Complexity

The lazy shrink tree implementation maintains **O(log n)** memory for the shrinking path, not O(n) for all candidates.

## Property Test Performance

### End-to-End Metrics

| Configuration | Target Time |
|---------------|-------------|
| 100 iterations, simple property | <100ms |
| 1000 iterations, simple property | <500ms |
| 100 iterations with shrinking | <200ms |

## Optimization Tips

1. **Use appropriate sizes**: `Size.small` for quick tests
2. **Limit shrink depth**: Set `maxShrinks` reasonably
3. **Avoid complex predicates**: Keep property checks fast
4. **Use parallel shrinking**: For multi-core speedup

## Measuring Your Tests

Use `StatisticsCollector` to measure your own test performance:

```swift
let collector = StatisticsCollector(testName: "myTest")
collector.startGenerationPhase()
// ... run ...
collector.endGenerationPhase()

let stats = collector.finalize()
print("Avg gen time: \(stats.averageGenerationTimeMs)ms")
```
