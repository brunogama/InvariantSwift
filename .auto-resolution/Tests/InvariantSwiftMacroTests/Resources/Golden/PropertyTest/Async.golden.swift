func testAsync(value: Int) async -> Bool {
  await someAsyncCheck(value)
}

private enum testAsync_PropertyTest {
  @Test("testAsync") static func run() async throws {
    let generator: Gen<Int> = Gen<Int>.int
    let property = Property(generator: generator) { (value: Int) in
      await someAsyncCheck(value)
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    let result = await runPropertyAsync(property, config: config)
    switch result {
    case .success:
      break
    case .failure(let counterexample, let iterations, let shrunk, reason: _, let seed):
      Issue.record(
        Comment(
          rawValue:
            "Property failed after \(iterations) iterations. Original: value=\(counterexample) | Shrunk: value=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )
    case .gaveUp(discarded: _, iterations: _):
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
