import Foundation
import Testing

@testable import InvariantSwiftCore

@Suite("Failing Example Save Request Tests")
struct FailingExampleSaveRequestTests {
  @Test("Memory database persists a failure request")
  func memoryDatabasePersistsFailureRequest() async {
    let database = FailingExampleDatabase(backend: .memory)
    let testID = TestIdentifier(
      module: "RequestTests",
      file: "PersistenceTests.swift",
      function: "persistsRequest()",
      signature: "[Int]"
    )
    let request = makeSaveFailureRequest(testID: testID)

    await database.saveFailure(request)
    let retrieved = await database.examples(for: testID)

    guard let example = retrieved.first else {
      Issue.record("Expected a persisted failing example")
      return
    }
    #expect(retrieved.count == 1)
    #expect(example.shrinkPath == [1, 4, 2])
    #expect(example.inputDescription == "[3, 1, 4]")
    #expect(example.serializedInput == Data("[3,1,4]".utf8))
  }

  private func makeSaveFailureRequest(
    testID: TestIdentifier
  ) -> FailingExampleSaveRequest {
    FailingExampleSaveRequest(
      testID: testID,
      failure: FailingExampleFailure(
        seed: 9876,
        size: 12,
        message: "Request failure"
      ),
      options: FailingExampleSaveOptions(
        shrinkPath: [1, 4, 2],
        input: [3, 1, 4],
        inputDescription: "[3, 1, 4]"
      )
    )
  }
}
