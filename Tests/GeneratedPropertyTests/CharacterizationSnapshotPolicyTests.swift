import Foundation
import InvariantSwiftMacroAPI
@testable import InvariantSwiftTesting
import Testing

@Suite("Characterization Snapshot Policy")
struct CharacterizationSnapshotPolicyTests {
  @Test("verification does not create a missing snapshot beside an existing fixture")
  func verificationDoesNotCreatePartiallyMissingSnapshot() throws {
    let snapshotDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("characterization-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: snapshotDirectory) }

    let cases = [
      CharacterizationCase(id: "one", input: 1, expected: .returned(1)),
      CharacterizationCase(id: "two", input: 2, expected: .returned(2)),
    ]
    let fixtures = FileSystemSnapshotTestingFixtures(
      configuration: CharacterizationConfiguration<Int>(
        name: "identity",
        fixture: snapshotDirectory.path,
        inputs: []
      )
    )
    try fixtures.prepareForRecording()
    #expect(fixtures.verify(cases, mode: .record).isEmpty)

    let missingSnapshot = snapshotDirectory.appendingPathComponent("identity.two.json")
    try FileManager.default.removeItem(at: missingSnapshot)

    let differences = fixtures.verify(cases, mode: .verify)

    #expect(differences.map(\.caseID) == ["two"])
    #expect(!FileManager.default.fileExists(atPath: missingSnapshot.path))
  }
}
