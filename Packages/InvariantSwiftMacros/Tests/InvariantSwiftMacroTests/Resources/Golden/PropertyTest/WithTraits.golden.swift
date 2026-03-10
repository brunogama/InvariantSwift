func testTraits(value: Int) {
  value >= 0
}

private enum testTraits_PropertyTest {
  @Test(
    "testTraits",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testTraits",
      labels: ["value"],
      configuredSeed: nil
    ),
    .enabled(if: true),
    .serialized,
    .timeLimit(.minutes(1)),
    .tags(.invariantSwiftPropertyBased, .invariantSwiftPropertyReplay),
    Bug.bug(id: "PBT-123")
  ) static func run() throws {
    let generator = Gen<Int>.int
    let property = Property(generator: generator) { (value: Int) in
      value >= 0
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try executeGeneratedPropertyTest(
      property,
      config: config,
      testName: "testTraits",
      labels: ["value"],
      persistFailures: false
    )
  }
}
