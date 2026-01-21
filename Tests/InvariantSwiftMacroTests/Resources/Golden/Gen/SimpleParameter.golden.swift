func testWithCustomGen(@Gen(.int(in: 1...100)) positiveNumber: Int) {
  positiveNumber > 0
}

private enum testWithCustomGen_PropertyTest {
  @Test("testWithCustomGen") static func run() throws {
    let generator = Gen<Int>.int(in: 1...100)
    let property = Property(generator: generator) { (positiveNumber: Int) in
      positiveNumber > 0
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
            "Property failed after \(iterations) iterations. Original: positiveNumber=\(counterexample) | Shrunk: positiveNumber=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )

    case .gaveUp:
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
