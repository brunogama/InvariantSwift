import InvariantSwiftExperimental

// Smoke test: Verify InvariantSwiftExperimental can be imported and experimental features are available
let gen = Gen<Int>.int
let property = Property(generator: gen) { _ in true }
