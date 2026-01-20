func testUserValidation(
  @Label("User's Age") age: Int,
  @Label("Account Balance") balance: Double
) {
  age >= 0 && balance >= 0.0
}

private enum testUserValidation_PropertyTest {
  @Test("testUserValidation") static func run() throws {
    let generator: Gen<(Int, Double)> = Gen<Int>.int.flatMap { age in
      Gen<Double>.double.map { balance in
        (age, balance)
      }
    }
    let property = Property(generator: generator) { (age: Int, balance: Double) in
      age >= 0 && balance >= 0.0
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
            "Property failed after \(iterations) iterations. Original: User's Age=\(counterexample), Account Balance=\(counterexample) | Shrunk: User's Age=\(shrunk), Account Balance=\(shrunk) | Seed: \(seed.rawValue)"
        )
      )
    case .gaveUp(discarded: _, iterations: _):
      Issue.record(Comment(stringLiteral: "Property test gaveUp"))
    }
  }
}
