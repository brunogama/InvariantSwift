func testBasicProperty(x: Int) {
  x >= Int.min
}

private enum testBasicProperty_PropertyTest {
  @Test("testBasicProperty") static func run() throws {
    let generator: Gen<Int> = Gen<Int>.int
    let property = Property(generator: generator) { (x: Int) in
      x >= Int.min
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    let result = runPropertySynchronously(property, config: config)
    switch result {
    case .success:
      break
    case .failure(let counterexample, let iterations, let shrunk, reason: _, let seed):
      Issue.record(
        Comment(
          rawValue:
            "Property failed after \(iterations) iterations. Original: x=\(counterexample) | Shrunk: x=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )
    case .gaveUp(discarded: _, iterations: _):
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
