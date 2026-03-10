func testWithCustomGen(@Gen(.int(in: 1...100)) positiveNumber: Int) {
  positiveNumber > 0
}

private enum testWithCustomGen_PropertyTest {
  @Test(
    "testWithCustomGen",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testWithCustomGen",
      labels: ["positiveNumber"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
    let generator = Gen<Int>.int(in: 1...100)
    let property = Property(generator: generator) { (positiveNumber: Int) in
      positiveNumber > 0
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testWithCustomGen",
      labels: ["positiveNumber"],
      persistFailures: false
    )
  }
}
