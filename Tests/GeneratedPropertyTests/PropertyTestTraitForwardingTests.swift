import InvariantSwiftTesting
import InvariantSwiftMacroAPI
import Testing

private extension Tag {
  static var forwardedPropertyTrait: Self {
    Self.__fromStaticMember(of: Self.self, "forwardedPropertyTrait")
  }
}

@Suite("PropertyTest Trait Forwarding Tests")
struct PropertyTestTraitForwardingTests {
  @PropertyTest(
    iterations: 1,
    seed: 42,
    tags: [.forwardedPropertyTrait],
    bugs: [Bug.bug(id: "PBT-123")],
    serialized: true,
    timeLimit: .minutes(1),
    enabledIf: true
  )
  func forwardsNativeSwiftTestingTraits(value: Int) {
    let observedValue = value
    #expect(observedValue >= Int.min)

    let currentTest = Test.current
    #expect(currentTest != nil)

    if let currentTest {
      #expect(currentTest.tags.contains(InvariantSwiftTestingTags.propertyBased))
      #expect(currentTest.tags.contains(.forwardedPropertyTrait))
      #expect(currentTest.associatedBugs.contains(Bug.bug(id: "PBT-123")))
      #expect(currentTest.timeLimit != nil)
      #expect(currentTest.traits.contains { $0 is InvariantSwiftPropertyExecutionTrait })
      // `serialized:` is accepted but not forwarded: `.serialized` has no
      // effect on a non-parameterized test function, and emitting it warned
      // on every build. Suite-level ordering is the caller's to set.
      #expect(!currentTest.traits.contains { $0 is ParallelizationTrait })
    }
  }
}
