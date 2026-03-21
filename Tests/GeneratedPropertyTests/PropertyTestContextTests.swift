import InvariantSwiftTesting
import InvariantSwiftMacroAPI
import Testing

@Suite("PropertyTest Context Tests")
struct PropertyTestContextTests {
  @PropertyTest(iterations: 1, seed: 99)
  func exposesPropertyExecutionContext(value: Int) {
    let observedValue = value
    #expect(observedValue >= Int.min)

    let context = PropertyTestContext.current
    #expect(context != nil)

    if let context {
      #expect(context.testName == "exposesPropertyExecutionContext")
      #expect(context.seed == 99)
      #expect(context.labels == ["value"])
      #expect(context.isReplay == false)
      #expect(context.replayFailureID == nil)
      #expect(context.config?.seed?.rawValue == 99)
    }
  }
}
