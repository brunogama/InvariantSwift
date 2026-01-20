func testComplex(
  @Gen(.int(in: 0...10)) count: Int,
  @Label("User name") name: String
) {
  count >= 0
}

private enum testComplex_PropertyTest {
  @Test("testComplex") static func run() throws {
    let generator: Gen<(Int, String)> = Gen<Int>.int(in: 0...10).flatMap { count in
      Gen<String>.string.map { name in
        (count, name)
      }
    }
    let property = Property(generator: generator) { (count: Int, name: String) in
      count >= 0
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
            "Property failed after \(iterations) iterations. Original: count=\(counterexample), User name=\(counterexample) | Shrunk: count=\(shrunk), User name=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )
    case .gaveUp(discarded: _, iterations: _):
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
