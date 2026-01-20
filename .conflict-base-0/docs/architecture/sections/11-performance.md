# Performance

### 11.1 Performance Requirements

| Operation | P50 | P95 | P99 | Target Load |
|-----------|-----|-----|-----|------------|
| Gen value (Int) | <1µs | <10µs | <100µs | 100K gen/sec |
| Gen value (String) | <5µs | <50µs | <500µs | 10K gen/sec |
| Gen value ([Int]) | <10µs | <100µs | <1ms | 1K gen/sec |
| Predicate execution | <1µs | <10µs | <1ms | Var by user code |
| Shrinking iteration | <10µs | <100µs | <1ms | 100 shrinks/sec |
| Property setup | <1ms | <5ms | <10ms | Per test start |

### 11.2 Bottlenecks and Mitigations

| Bottleneck | Impact | Mitigation |
|------------|--------|------------|
| RNG entropy for large values | High for collection generation | Seed-based determinism reduces entropy cost |
| Predicate evaluation cost | User-dependent | Runner caches results during shrinking |
| Shrinking tree size for complex types | Memory spikes | Lazy shrinking evaluation |
| Type erasure overhead | Minimal (~5%) | Generic specialization in release builds |

### 11.3 Caching Strategy

| Cache | Purpose | TTL | Invalidation |
|-------|---------|-----|--------------|
| Generated values | Reuse across shrinking | Single property run | Next property test |
| Predicate results | Avoid re-evaluation during shrinking | Single shrinking session | New shrinking attempt |
| Coverage symbols | Track explored paths | Across all test runs (in session) | Session end |

### 11.4 Load Testing

- **Tool**: Custom benchmarks in `swift test` with timing
- **Baseline**: Measured in commit history
- **Target Load**: 10,000 generations/second sustained

---
