func testWithMultipleGen(
  @Gen(.int(in: 0...10)) small: Int,
  @Gen(.string(length: 5...10)) mediumString: String
) {
  small >= 0 && mediumString.count >= 5
}

private enum testWithMultipleGen_PropertyTest {
  @Test(
    "testWithMultipleGen",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testWithMultipleGen",
      labels: ["small", "mediumString"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() throws {
    let generator: Gen<(Int, String)> = Gen<Int>.int(in: 0...10).flatMap { small in
      Gen<String>.string(length: 5...10).map { mediumString in
        (small, mediumString)
      }
    }
    let property = Property(generator: generator) { (small: Int, mediumString: String) in
      small >= 0 && mediumString.count >= 5
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testWithMultipleGen",
      labels: ["small", "mediumString"],
      persistFailures: false
    )
  }
}
