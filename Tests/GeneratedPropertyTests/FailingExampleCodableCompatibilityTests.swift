import Foundation
import InvariantSwiftCore
import Testing

@Suite("Failing Example Codable Compatibility Tests")
struct FailingExampleCodableCompatibilityTests {
  @Test("new examples use an empty shrink path by default")
  func defaultShrinkPathIsEmpty() {
    let failure = FailingExampleFailure(seed: 1, size: 2, message: "failed")
    let example = FailingExample(failure: failure)
    #expect(example.shrinkPath.isEmpty)
  }

  @Test("legacy examples with a missing shrink path decode an empty path")
  func missingShrinkPathDecodesAsEmpty() throws {
    let example = try decodeFailingExample(Self.missingShrinkPathPayload)
    #expect(example.shrinkPath.isEmpty)
  }

  @Test("legacy examples with a null shrink path decode an empty path")
  func nullShrinkPathDecodesAsEmpty() throws {
    let example = try decodeFailingExample(Self.nullShrinkPathPayload)
    #expect(example.shrinkPath.isEmpty)
  }

  private static let missingShrinkPathPayload = """
    {
      "id":"00000000-0000-0000-0000-000000000001",
      "seed":1,"size":2,"failureMessage":"failed","timestamp":0,
      "swiftVersion":"6.x","frameworkVersion":"1.0.0"
    }
    """

  private static let nullShrinkPathPayload = """
    {
      "id":"00000000-0000-0000-0000-000000000002",
      "seed":1,"size":2,"shrinkPath":null,"failureMessage":"failed",
      "timestamp":0,"swiftVersion":"6.x","frameworkVersion":"1.0.0"
    }
    """
}

private func decodeFailingExample(_ payload: String) throws -> FailingExample {
  try JSONDecoder().decode(FailingExample.self, from: Data(payload.utf8))
}
