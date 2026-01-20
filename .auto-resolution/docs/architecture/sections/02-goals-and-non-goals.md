# Goals and Non-Goals

### 2.1 Goals

1. **Comprehensive Test Generation** - Automatically generate diverse test cases across primitive, collection, and custom types
2. **Mathematical Rigor** - Verify functional programming laws (Functor, Applicative, Monad) through property testing
3. **Coverage-Guided Testing** - Achieve 99%+ code coverage through intelligent input generation biased toward uncovered code paths
4. **Swift 6 Compliance** - Full support for Swift 6 strict concurrency with actor isolation and Sendable constraints
5. **Zero-Cost Abstractions** - Maintain high performance (10,000+ generations/second) with minimal memory footprint
6. **Developer Ergonomics** - Provide intuitive APIs and macros (`@PropertyTest`, `@BusinessRule`) that hide mathematical complexity
7. **Advanced Testing Capabilities** - Support model-based testing, lens systems, linearizability testing, and SMT solver constraints
8. **Seamless Integration** - Integrate with Swift Testing framework and SPM plugin system

### 2.2 Non-Goals

1. Deterministic fuzzing (focus on property testing, not mutation testing)
2. Distributed testing across multiple machines
3. Network-based test coordination
4. GUI-based test result visualization
5. Runtime instrumentation or bytecode modification

### 2.3 Success Metrics

| Metric | Target | Current | Notes |
|--------|--------|---------|-------|
| Code Coverage | 99% | 95%+ | Dog food tests verify framework itself |
| Generation Throughput | 10,000+ gen/sec | On-track | Measured with primitive types |
| Memory Footprint | <10MB per 1000 iterations | On-track | Lazy evaluation strategy |
| Shrinking Efficiency | <5% overhead vs generation | On-track | Tree-based shrinking algorithm |
| API Usability | <5min to write property test | On-track | Macro support reduces boilerplate |
| Swift 6 Compliance | 100% strict concurrency | 100% | Enforced via compiler warnings |

---
