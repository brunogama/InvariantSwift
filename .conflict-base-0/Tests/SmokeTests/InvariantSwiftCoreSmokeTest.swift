import InvariantSwiftCore

// Smoke test: Verify InvariantSwiftCore can be imported and basic types are available
let gen = Gen<Int>.int
let property = Property(generator: gen) { _ in true }
