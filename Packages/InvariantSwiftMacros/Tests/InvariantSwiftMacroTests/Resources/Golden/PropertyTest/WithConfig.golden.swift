func testWithConfig(x: Int, y: String) {
  x >= Int.min && y.isEmpty
}

private enum testWithConfig_PropertyTest {
  @Test(
    "testWithConfig",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testWithConfig",
      labels: ["x", "y"],
      configuredSeed: 42
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
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
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testWithConfig",
      labels: ["x", "y"],
      persistFailures: false
    )
  }
}
