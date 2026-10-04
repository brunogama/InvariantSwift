import Foundation
import InvariantSwiftMacroAPI
import InvariantSwiftTesting
import Testing

@PropertyTest(iterations: 100, seed: 42)
func stringsSurviveJSONRoundTrip(value: String) throws {
  let encoded = try JSONEncoder().encode(value)
  let decoded = try JSONDecoder().decode(String.self, from: encoded)
  #expect(decoded == value)
}

private enum ThrowingPropertyFixtureError: Error {
  case expected
}

@PropertyTest(
  iterations: 1,
  seed: 42,
  maxShrinks: 0,
  disabledReason: "Invoked explicitly to inspect recorded issues"
)
private func propertyThrowsForGeneratedInput(value: Int) throws {
  throw ThrowingPropertyFixtureError.expected
}


@Test
func throwingPropertyRecordsOriginalError() async throws {
  try await confirmation("Original thrown error", expectedCount: 1...) { errorRecorded in
    try withKnownIssue("The fixture deliberately throws") {
      try propertyThrowsForGeneratedInput_PropertyTest.run()
    } matching: { issue in
      if issue.error is ThrowingPropertyFixtureError {
        errorRecorded()
      }
      return true
    }
  }
}
