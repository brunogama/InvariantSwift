func testBasicProperty(x: Int) {
  x >= Int.min
}

private enum testBasicProperty_PropertyTest {
  @Test(
    "testBasicProperty",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testBasicProperty",
      labels: ["x"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
    let generator = Gen<Int>.int
    let property = Property(generator: generator) { (x: Int) in
      x >= Int.min
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testBasicProperty",
      labels: ["x"],
      persistFailures: false
    )
  }
}
