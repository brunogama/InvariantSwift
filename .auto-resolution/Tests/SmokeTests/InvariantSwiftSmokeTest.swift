import InvariantSwiftCore
import InvariantSwift

// Smoke test: Verify InvariantSwift can be imported and re-exports core + generators
let smokeInvariantSwiftGen = Gen<Int>.int
let smokeInvariantSwiftArrayGen = Gen<[String]>.array(Gen<String>.string)
let smokeInvariantSwiftProperty = Property(generator: smokeInvariantSwiftGen) { _ in true }
