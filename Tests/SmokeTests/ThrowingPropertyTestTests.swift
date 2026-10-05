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
@PropertyTest(
  iterations: 1,
  seed: 42,
  maxShrinks: 0,
  disabledReason: "Invoked explicitly to inspect recorded issues"
)
private func boolPropertyThrowsForGeneratedInput(value: Int) throws -> Bool {
  throw ThrowingPropertyFixtureError.expected
}


@Test(arguments: [false, true])
func throwingPropertyRecordsOriginalError(returningBool: Bool) async throws {
  try await confirmation("Original thrown error", expectedCount: 1...) { errorRecorded in
    try withKnownIssue("The fixture deliberately throws") {
      if returningBool {
        try boolPropertyThrowsForGeneratedInput_PropertyTest.run()
      } else {
        try propertyThrowsForGeneratedInput_PropertyTest.run()
      }
    } matching: { issue in
      if issue.error is ThrowingPropertyFixtureError {
        errorRecorded()
      }
      return true
    }
  }
}

@PropertyTest(iterations: 10, seed: 42, serialized: true)
@Regression(replayFirst: false, maxExamples: 2, exposeCasesAsTests: true)
func throwingBoolPropertyPasses(value: Int) throws -> Bool {
  true
}

@PropertyTest(
  iterations: 1,
  seed: 42,
  maxShrinks: 0,
  disabledReason: "Invoked explicitly to inspect a false predicate"
)
private func throwingBoolPropertyRejects(value: Int) throws -> Bool {
  false
}

@Test
func throwingBoolPropertyPreservesFalseResult() {
  withKnownIssue("The Bool predicate deliberately rejects its input") {
    try throwingBoolPropertyRejects_PropertyTest.run()
  }
}
