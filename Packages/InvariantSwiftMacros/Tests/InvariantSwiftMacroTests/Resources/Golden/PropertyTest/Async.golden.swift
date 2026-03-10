func testAsync(value: Int) async -> Bool {
  await someAsyncCheck(value)
}

private enum testAsync_PropertyTest {
  @Test(
    "testAsync",
    InvariantSwiftPropertyExecutionTrait(
      testName: "testAsync",
      labels: ["value"],
      configuredSeed: nil
    ),
    .tags(.invariantSwiftPropertyBased)
  ) static func run() async throws {
    let generator = Gen<Int>.int
    let property = Property(generator: generator) { (value: Int) in
      await someAsyncCheck(value)
      return true
    }
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
    try await executeGeneratedPropertyTestAsync(
      property,
      config: config,
      testName: "testAsync",
      labels: ["value"],
      timeoutSeconds: nil,
      persistFailures: false
    )
  }
}
