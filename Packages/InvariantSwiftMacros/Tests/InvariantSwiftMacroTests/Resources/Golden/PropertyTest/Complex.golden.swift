func testComplex(
  @Gen(.int(in: 0...10)) count: Int,
  @Label("User name") name: String
) {
  count >= 0
}

private enum testComplex_PropertyTest {
  @Test(
    "testComplex",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testComplex",
      labels: ["count", "User name"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
    let generator: Gen<(Int, String)> = Gen<Int>.int(in: 0...10).flatMap { count in
      Gen<String>.string.map { name in
        (count, name)
      }
    }
    let property = Property(generator: generator) { (count: Int, _: String) in
      count >= 0
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testComplex",
      labels: ["count", "User name"],
      persistFailures: false
    )
  }
}
