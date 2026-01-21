func testWithConfig(x: Int, y: String) {
  x >= Int.min && y.isEmpty
}

private enum testWithConfig_PropertyTest {
  @Test("testWithConfig") static func run() throws {
    let generator: Gen<(Int, String)> = Gen<Int>.int.flatMap { x in
      Gen<String>.string.map { y in
        (x, y)
      }
    }
    let property = Property(generator: generator) { (x: Int, y: String) in
      x >= Int.min && y.isEmpty
      return true
    }
    let config = PropertyConfig(iterations: 500, maxShrinks: 1000, seed: Seed(value: 42))
    let result = runPropertySynchronously(property, config: config)
    switch result {
    case .success:
      break

    case .failure(let counterexample, let iterations, let shrunk, reason: _, let seed):
      Issue.record(
        Comment(
          rawValue:
            "Property failed after \(iterations) iterations. Original: x=\(counterexample), y=\(counterexample) | Shrunk: x=\(shrunk), y=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )

    case .gaveUp:
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
