func testUserValidation(
  @Label("User's Age") age: Int,
  @Label("Account Balance") balance: Double
) {
  age >= 0 && balance >= 0.0
}

private enum testUserValidation_PropertyTest {
  @Test(
    "testUserValidation",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testUserValidation",
      labels: ["User's Age", "Account Balance"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
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
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testUserValidation",
      labels: ["User's Age", "Account Balance"],
      persistFailures: false
    )
  }
}
