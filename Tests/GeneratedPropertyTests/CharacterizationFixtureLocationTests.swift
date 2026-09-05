import Foundation
@testable import InvariantSwiftTesting
import Testing

@Suite("Characterization Fixture Location", .serialized)
struct CharacterizationFixtureLocationTests {
  @Test("recording is source relative and verification never rewrites")
  func recordingIsSourceRelativeAndVerificationDoesNotWrite() async throws {
    let fixture = temporaryFixtureName()
    defer { removeFixtures(named: fixture) }

    let sourceDirectory = sourceFixtureDirectory(named: fixture)
    #expect(FileManager.default.currentDirectoryPath != sourceDirectory.path)

    try await recordFixture(named: fixture)
    let snapshotURL = snapshotURL(in: sourceDirectory)
    let recordedData = try Data(contentsOf: snapshotURL)

    try await verifyFixture(named: fixture)

    let workingDirectory = workingFixtureDirectory(named: fixture)
    #expect(try Data(contentsOf: snapshotURL) == recordedData)
    #expect(!FileManager.default.fileExists(atPath: workingDirectory.path))
  }

  @Test("explicit source context overrides the working directory")
  func explicitSourceContextOverridesWorkingDirectory() async throws {
    let sourceDirectory = temporarySourceDirectory()
    try FileManager.default.createDirectory(
      at: sourceDirectory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: sourceDirectory) }
    let workingCopy = workingFixtureDirectory(named: "Fixtures")
      .appendingPathComponent("explicit-source.three.json")
    defer { try? FileManager.default.removeItem(at: workingCopy) }

    try await recordExplicitSourceFixture(in: sourceDirectory)

    let snapshot =
      sourceDirectory
      .appendingPathComponent("Fixtures", isDirectory: true)
      .appendingPathComponent("explicit-source.three.json")
    #expect(FileManager.default.fileExists(atPath: snapshot.path))
    #expect(!FileManager.default.fileExists(atPath: workingCopy.path))
  }

  private func recordFixture(named fixture: String) async throws {
    _ = try await characterize(
      CharacterizationConfiguration(
        name: "source relative recording",
        fixture: fixture,
        inputs: [CharacterizationInput(id: "two", value: 2)],
        mode: .record
      ),
      operation: { $0 * 2 }
    )
  }

  private func verifyFixture(named fixture: String) async throws {
    _ = try await characterize(
      CharacterizationConfiguration<Int>(
        name: "source relative recording",
        fixture: fixture,
        inputs: [],
        mode: .verify
      ),
      operation: { $0 * 2 }
    )
  }

  private func recordExplicitSourceFixture(
    in sourceDirectory: URL
  ) async throws {
    let declaringFile =
      sourceDirectory
      .appendingPathComponent("DeclaringTests.swift")
    _ = try await characterize(
      CharacterizationConfiguration(
        name: "explicit source",
        fixture: "Fixtures",
        inputs: [CharacterizationInput(id: "three", value: 3)],
        mode: .record,
        sourceFile: declaringFile.path
      ),
      operation: { $0 + 1 }
    )
  }

  private func temporaryFixtureName() -> String {
    "Fixtures/SourceRelativeFixtures-\(UUID().uuidString)"
  }

  private func temporarySourceDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "characterization-source-\(UUID().uuidString)",
        isDirectory: true
      )
  }

  private func sourceFixtureDirectory(named fixture: String) -> URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent(fixture, isDirectory: true)
  }

  private func workingFixtureDirectory(named fixture: String) -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent(fixture, isDirectory: true)
  }

  private func snapshotURL(in directory: URL) -> URL {
    directory.appendingPathComponent("source-relative-recording.two.json")
  }

  private func removeFixtures(named fixture: String) {
    let manager = FileManager.default
    try? manager.removeItem(at: sourceFixtureDirectory(named: fixture))
    try? manager.removeItem(at: workingFixtureDirectory(named: fixture))
  }
}
