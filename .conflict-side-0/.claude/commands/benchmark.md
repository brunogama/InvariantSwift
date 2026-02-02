# Run Performance Benchmarks

Run performance benchmarks for generators, shrinking, or specific components.

## Steps

1. **Parse Target** from `$ARGUMENTS`:
   - Benchmark name: `GeneratorBenchmarks`, `ShrinkBenchmarks`
   - Component: `Gen` → run related benchmarks
   - No args: Run all benchmarks

2. **Build Release Mode** (benchmarks require optimizations):
   ```bash
   swift build -c release --product Benchmarks
   ```

3. **Run Benchmarks**:
   ```bash
   # All benchmarks
   swift run -c release Benchmarks
   
   # Specific benchmark
   swift run -c release Benchmarks --filter ${BENCHMARK_NAME}
   
   # JSON output (for analysis)
   swift run -c release Benchmarks --format json > /tmp/benchmark-results.json
   ```

4. **Parse Results**:
   - Extract metrics: operations/sec, time/operation, memory usage
   - Compare against baseline (if exists in `docs/PERFORMANCE_BASELINE.md`)
   - Flag regressions (>10% slower than baseline)

5. **Report Results**:
   - Summary table: benchmark name, ops/sec, time
   - Comparison to baseline (if available)
   - Memory usage trends
   - Suggest optimizations if regressions found

## Usage

```
/benchmark                           # All benchmarks
/benchmark GeneratorBenchmarks       # Specific suite
/benchmark --json                    # JSON output
/benchmark Gen                       # Component-specific
```

## Benchmark Structure

```swift
// Benchmarks/GeneratorBenchmarks.swift
import Benchmark
import InvariantSwift

let benchmarks = {
  Benchmark("Gen.int performance") { benchmark in
    for _ in benchmark.scaledIterations {
      _ = Gen.int.sample(size: 100)
    }
  }
}
```

## Performance Baselines

See `docs/PERFORMANCE_BASELINE.md` for reference metrics:
- Generator sampling: ~1M ops/sec
- Shrinking: ~100K shrink steps/sec
- Property checks: ~10K checks/sec

## Notes

- Benchmarks use `swift-benchmark` package
- Always run in release mode (`-c release`)
- Results vary by hardware (document system specs)
- Use `make benchmark` or `make benchmark-json` shortcuts
- Track regressions in ISP proposals for optimizations
