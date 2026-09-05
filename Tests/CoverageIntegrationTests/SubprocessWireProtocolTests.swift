import Foundation
@testable import InvariantSwiftCore
import Testing

@Suite("Subprocess Wire Protocol Tests")
struct SubprocessWireProtocolTests {
  @Test("request and response round trip with protocol version")
  func requestAndResponseRoundTripWithProtocolVersion() throws {
    let request = PropertyEvaluationRequest(
      testId: UUID(),
      seed: 42,
      size: 10,
      testInput: Data("input".utf8),
      generatorType: "Int"
    )
    let response = PropertyEvaluationResponse(
      testId: request.testId,
      passed: true,
      duration: 0.25
    )

    #expect(try roundTrip(request) == request)
    #expect(try roundTrip(response) == response)
    #expect(try protocolVersion(of: request) == 1)
    #expect(try protocolVersion(of: response) == 1)
  }

  @Test("failure response preserves the failure reason across the wire")
  func failureResponsePreservesFailureReasonAcrossTheWire() throws {
    let response = PropertyEvaluationResponse(
      testId: UUID(),
      passed: false,
      duration: 0.5,
      failureReason: "Property returned false"
    )

    let decoded = try roundTrip(response)
    #expect(decoded == response)
    #expect(decoded.failureReason == "Property returned false")
  }

  private func roundTrip<Model: Codable & Equatable>(
    _ value: Model
  ) throws -> Model {
    try JSONDecoder().decode(Model.self, from: JSONEncoder().encode(value))
  }

  private func protocolVersion<Model: Encodable>(
    of value: Model
  ) throws -> Int? {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let fields = object as? [String: Any] else {
      throw WireProtocolTestError.invalidJSON
    }
    return fields["protocolVersion"] as? Int
  }
}

private enum WireProtocolTestError: Error {
  case invalidJSON
}
