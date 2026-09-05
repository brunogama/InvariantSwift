import Foundation
import InvariantSwiftMacroAPI
@testable import InvariantSwiftTesting
import Testing

@Suite("Characterization Testing")
struct CharacterizationTestingTests {
  @Test("records explicit inputs and replays the checked-in snapshots")
  func recordsAndVerifiesSnapshots() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let inputs = [
      CharacterizationInput(id: "zero", value: 0),
      CharacterizationInput(id: "one", value: 1),
    ]

    let recorded = try await characterize(
      configuration(name: "double", fixture: snapshotDirectory, inputs: inputs, mode: .record),
      operation: { $0 * 2 }
    )
    #expect(recorded.caseCount == 2)
    #expect(recorded.differences.isEmpty)

    let verified = try await characterize(
      configuration(name: "double", fixture: snapshotDirectory, inputs: [], mode: .verify),
      operation: { (value: Int) in value * 2 }
    )
    #expect(verified.caseCount == 2)
    #expect(verified.differences.isEmpty)
  }

  @Test("missing verification snapshots report ordered differences without creating fixtures")
  func missingVerificationSnapshotsAreReportedWithoutWriting() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let inputs = [
      CharacterizationInput(id: "first", value: 1),
      CharacterizationInput(id: "second", value: 2),
    ]
    let configuration = CharacterizationConfiguration(
      name: "identity",
      fixture: snapshotDirectory.path,
      inputs: inputs
    )
    let request: CharacterizationExecutionRequest<Int, Int, Int> = CharacterizationExecutionRequest(
      configuration: configuration,
      observe: { $0 },
      observeError: nil,
      operation: { $0 }
    )
    let reporter = CapturingDifferenceReporter()
    let report = try await CharacterizationExecution.run(
      request,
      modeSelector: FixedCharacterizationModeSelector(mode: .verify),
      fixtures: FileSystemSnapshotTestingFixtures(configuration: configuration),
      reporter: reporter
    )

    #expect(report.caseCount == 2)
    #expect(report.differences.map(\.caseID) == ["first", "second"])
    #expect(reporter.reports.count == 1)
    #expect(!FileManager.default.fileExists(atPath: snapshotDirectory.path))
  }

  @Test("in-memory fixtures share the JSON snapshot contract")
  func inMemoryFixturesShareJSONSnapshotContract() throws {
    let fixtures = InMemoryCharacterizationFixtures()
    let original = characterizationCase(input: 1, output: 1)
    let changed = characterizationCase(input: 1, output: 2)

    let missing = fixtures.verify([original], mode: .verify)
    #expect(missing.map(\.caseID) == ["one"])

    try fixtures.prepareForRecording()
    #expect(fixtures.verify([original], mode: .record).isEmpty)
    let replayed: [CharacterizationCase<Int, Int>] = try fixtures.load()
    #expect(replayed.map(\.id) == ["one"])
    #expect(replayed.map(\.input) == [1])
    #expect(fixtures.verify([original], mode: .verify).isEmpty)

    let mismatch = fixtures.verify([changed], mode: .verify)
    #expect(mismatch.map(\.caseID) == ["one"])
    #expect(mismatch.first?.message.hasPrefix("@@ ") == true)
    #expect(mismatch.first?.message.contains("\"value\" : 2") == true)

    #expect(fixtures.verify([original], mode: .verify).isEmpty)
    let replayedAfterVerify: [CharacterizationCase<Int, Int>] = try fixtures.load()
    #expect(replayedAfterVerify.map(\.input) == [1])
  }

  @Test("verification does not rewrite a snapshot")
  func verificationDoesNotRewriteSnapshot() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let inputs = [CharacterizationInput(id: "one", value: 1)]
    _ = try await characterize(
      configuration(name: "identity", fixture: snapshotDirectory, inputs: inputs, mode: .record),
      operation: { $0 }
    )
    let snapshotURL = snapshotURL(for: "identity", id: "one", in: snapshotDirectory)
    let recordedBytes = try Data(contentsOf: snapshotURL)

    _ = try await characterize(
      configuration(name: "identity", fixture: snapshotDirectory, inputs: [], mode: .verify),
      operation: { (value: Int) in value }
    )

    #expect(try Data(contentsOf: snapshotURL) == recordedBytes)
  }

  @Test("invalid case IDs do not prune existing snapshots")
  func invalidCaseIDsDoNotPruneExistingSnapshots() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let originalInputs = [CharacterizationInput(id: "original", value: 1)]
    _ = try await characterize(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: originalInputs,
        mode: .record
      ),
      operation: { $0 }
    )
    let originalURL = snapshotURL(for: "identity", id: "original", in: snapshotDirectory)
    let originalBytes = try Data(contentsOf: originalURL)

    let invalidInputs = [
      CharacterizationInput(id: "duplicate", value: 2),
      CharacterizationInput(id: "duplicate", value: 3),
    ]
    await expectInvalidRecord(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: invalidInputs,
        mode: .record
      )
    )

    #expect(try Data(contentsOf: originalURL) == originalBytes)
  }

  @Test("empty and colliding snapshot IDs are rejected")
  func rejectsEmptyAndCollidingSnapshotIDs() async {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    await expectInvalidRecord(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: [CharacterizationInput(id: " ", value: 1)],
        mode: .record
      )
    )
    await expectInvalidRecord(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: [
          CharacterizationInput(id: "a b", value: 1),
          CharacterizationInput(id: "a-b", value: 2),
        ],
        mode: .record
      )
    )
  }

  @Test("record failures do not prune existing snapshots")
  func recordFailuresDoNotPruneExistingSnapshots() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let originalInputs = [CharacterizationInput(id: "original", value: 1)]
    _ = try await characterize(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: originalInputs,
        mode: .record
      ),
      operation: { $0 }
    )
    let originalURL = snapshotURL(for: "identity", id: "original", in: snapshotDirectory)
    let originalBytes = try Data(contentsOf: originalURL)

    do {
      _ = try await characterize(
        configuration(
          name: "identity",
          fixture: snapshotDirectory,
          inputs: [CharacterizationInput(id: "replacement", value: 2)],
          mode: .record
        ),
        observe: Self.failingObservation,
        operation: { $0 }
      )
      Issue.record("Expected observation failure to throw")
    } catch {
      #expect(error as? TestFailure == .observationFailed)
    }

    #expect(try Data(contentsOf: originalURL) == originalBytes)
  }

  @Test("supports a custom Codable observation")
  func customObservation() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let inputs = [CharacterizationInput(id: "value", value: 3)]
    let recorded = try await characterize(
      configuration(
        name: "wrapped double",
        fixture: snapshotDirectory,
        inputs: inputs,
        mode: .record
      ),
      observe: { output in ["result": output] },
      operation: { $0 * 2 }
    )

    #expect(recorded.caseCount == 1)
    #expect(recorded.differences.isEmpty)
  }

  @Test("captures a stable projected error")
  func projectedError() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let inputs = [CharacterizationInput(id: "bad", value: false)]
    let recorded = try await characterize(
      configuration(
        name: "throwing operation",
        fixture: snapshotDirectory,
        inputs: inputs,
        mode: .record
      ),
      observeError: { _ in
        CharacterizationError(type: "validation", code: "invalid", message: "invalid input")
      },
      operation: { value in
        guard value else { throw TestFailure.invalidInput }
        return 1
      }
    )

    #expect(recorded.caseCount == 1)
    #expect(recorded.differences.isEmpty)
  }

  @Test("stores the stable case identifier with its input and outcome")
  func snapshotContainsReplayableCase() async throws {
    let snapshotDirectory = temporarySnapshotDirectory()
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    _ = try await characterize(
      configuration(
        name: "identity",
        fixture: snapshotDirectory,
        inputs: [CharacterizationInput(id: "named-case", value: 7)],
        mode: .record
      ),
      operation: { $0 }
    )

    let data = try Data(
      contentsOf: snapshotURL(for: "identity", id: "named-case", in: snapshotDirectory)
    )
    let snapshot = try JSONDecoder().decode(
      CharacterizationCase<Int, Int>.self,
      from: data
    )
    #expect(snapshot.id == "named-case")
    #expect(snapshot.input == 7)
  }

  private func characterizationCase(
    input: Int,
    output: Int
  ) -> CharacterizationCase<Int, Int> {
    CharacterizationCase(id: "one", input: input, expected: .returned(output))
  }

  private static func failingObservation(_ value: Int) throws -> Int {
    _ = value
    throw TestFailure.observationFailed
  }

  private func expectInvalidRecord<Input>(
    _ configuration: CharacterizationConfiguration<Input>
  ) async
  where Input: Codable & Sendable {
    do {
      _ = try await characterize(configuration, operation: { $0 })
      Issue.record("Expected invalid characterization record to throw")
    } catch {
      #expect(error is CharacterizationTestingError)
    }
  }

  private func configuration<Input>(
    name: String,
    fixture: URL,
    inputs: [CharacterizationInput<Input>],
    mode: CharacterizationMode
  ) -> CharacterizationConfiguration<Input> where Input: Codable & Sendable {
    CharacterizationConfiguration(name: name, fixture: fixture.path, inputs: inputs, mode: mode)
  }

  private func snapshotURL(for testName: String, id: String, in directory: URL) -> URL {
    directory.appendingPathComponent(
      "\(snapshotIdentifier(testName)).\(snapshotIdentifier(id)).json"
    )
  }

  private func snapshotIdentifier(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
      .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
  }

  private func temporarySnapshotDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("characterization-\(UUID().uuidString)")
  }
}

private enum TestFailure: Error, Equatable {
  case invalidInput
  case observationFailed
}
