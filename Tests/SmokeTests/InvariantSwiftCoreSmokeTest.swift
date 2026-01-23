import InvariantSwiftCore

// Smoke test: Verify InvariantSwiftCore can be imported and basic types are available
let smokeCoreGen = Gen<Int>.int
let smokeCoreProperty = Property(generator: smokeCoreGen) { _ in true }
