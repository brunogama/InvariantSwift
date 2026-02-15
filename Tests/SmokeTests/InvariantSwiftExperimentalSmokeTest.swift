import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced

// Smoke test: Verify InvariantSwiftExperimental can be imported and experimental features are available
let smokeExperimentalGen = Gen<Int>.int
let smokeExperimentalProperty = Property(generator: smokeExperimentalGen) { _ in true }
