import InvariantSwift

// Smoke test: Verify InvariantSwift can be imported and re-exports core + generators
let gen = Gen<Int>.int
let arrayGen = Gen.array(Gen<String>.string)
let property = Property(generator: gen) { _ in true }
