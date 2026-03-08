func testWithMultipleGen(
  @Gen(.int(in: 0...10)) small: Int,
  @Gen(.string(length: 5...10)) mediumString: String
) {
  small >= 0 && mediumString.count >= 5
}

private enum testWithMultipleGen_PropertyTest {
    @Test("testWithMultipleGen") static func run() throws {
        let generator: Gen<(Int, String)> = Gen<Int>.int(in: 0 ... 10).flatMap { small in
            Gen<String>.string(length: 5 ... 10).map { mediumString in
                (small, mediumString)
            }
        }
        let property = Property(generator: generator) { (small: Int, mediumString: String) in
          small >= 0 && mediumString.count >= 5
          return true
        }
        let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
        let result = runPropertySynchronously(property, config: config)
        switch result {
        case .success:
            break
        case .failure(counterexample: let counterexample, iterations: let iterations, shrunk: let shrunk, reason: _, seed: let seed):
            Issue.record(Comment(rawValue: "Property failed after \(iterations) iterations. Original: small=\(counterexample), mediumString=\(counterexample) | Shrunk: small=\(shrunk), mediumString=\(shrunk) | Seed: \(seed.rawValue)"))
        case .gaveUp(discarded: _, iterations: _):
            Issue.record(Comment(stringLiteral: "Property test gaveUp"))
        }
    }
}
