import Foundation
import SnapshotTesting

protocol CharacterizationFixtures: Sendable {
  func load<Input, Observation>()
    throws -> [CharacterizationCase<Input, Observation>]
  func prepareForRecording() throws
  func verify<Input, Observation>(
    _ cases: [CharacterizationCase<Input, Observation>],
    mode: CharacterizationMode
  ) -> [CharacterizationDifference]
  where Input: Codable & Sendable, Observation: Codable & Sendable
}

struct FileSystemSnapshotTestingFixtures: CharacterizationFixtures {
  let directory: URL
  let testName: String

  init<Input>(configuration: CharacterizationConfiguration<Input>)
  where Input: Codable & Sendable {
    directory = resolveSnapshotDirectory(
      configuration.fixture,
      sourceFile: configuration.sourceFile
    )
    testName = configuration.name
  }

  func load<Input, Observation>() throws
    -> [CharacterizationCase<Input, Observation>]
  where Input: Codable & Sendable, Observation: Codable & Sendable {
    try loadSnapshots(from: directory, testName: testName)
  }

  func prepareForRecording() throws {
    try prepareSnapshotDirectory(directory, testName: testName)
  }

  func verify<Input, Observation>(
    _ cases: [CharacterizationCase<Input, Observation>],
    mode: CharacterizationMode
  ) -> [CharacterizationDifference]
  where Input: Codable & Sendable, Observation: Codable & Sendable {
    let hasReference = FileManager.default.fileExists(atPath: directory.path)
    guard hasReference else {
      return cases.map { missingReferenceDifference(for: $0.id) }
    }
    return verifySnapshots(
      SnapshotVerificationPlan(
        cases: cases,
        testName: testName,
        snapshotDirectory: directory,
        mode: mode
      )
    )
  }
}

final class InMemoryCharacterizationFixtures: CharacterizationFixtures,
  @unchecked Sendable
{
  private var records: [Data]
  private let lock = NSLock()

  init(records: [Data] = []) {
    self.records = records
  }

  func load<Input, Observation>() throws
    -> [CharacterizationCase<Input, Observation>]
  where Input: Codable & Sendable, Observation: Codable & Sendable {
    lock.lock()
    defer { lock.unlock() }
    return try records.map(decodeCase)
  }

  func prepareForRecording() throws {
    lock.lock()
    defer { lock.unlock() }
    records = []
  }

  func verify<Input, Observation>(
    _ cases: [CharacterizationCase<Input, Observation>],
    mode: CharacterizationMode
  ) -> [CharacterizationDifference]
  where Input: Codable & Sendable, Observation: Codable & Sendable {
    lock.lock()
    defer { lock.unlock() }
    let snapshots = SnapshotAdapter<Input, Observation>()
    if mode == .record {
      records = cases.map(snapshots.data)
      return []
    }
    let storedCases = try? records.map {
      try JSONDecoder().decode(
        CharacterizationCase<Input, Observation>.self,
        from: $0
      )
    }
    let expected = Dictionary(
      uniqueKeysWithValues: (storedCases ?? []).map { ($0.id, $0) }
    )
    return cases.compactMap {
      verifyCase($0, expected: expected, snapshots: snapshots)
    }
  }
}

private struct PointFreeJSONSnapshotAdapter<Value: Encodable> {
  private let strategy = Snapshotting<Value, String>.json

  func data(_ value: Value) -> Data {
    strategy.diffing.toData(snapshot(value))
  }

  func difference(expected: Value, actual: Value) -> String? {
    strategy.diffing.diffV2(snapshot(expected), snapshot(actual))?.0
  }

  private func snapshot(_ value: Value) -> String {
    var representation = ""
    strategy.snapshot(value).run { representation = $0 }
    return representation
  }
}

private typealias SnapshotAdapter<
  Input: Codable & Sendable,
  Observation: Codable & Sendable
> =
  PointFreeJSONSnapshotAdapter<CharacterizationCase<Input, Observation>>

private func missingReferenceDifference(
  for id: String
)
  -> CharacterizationDifference
{
  CharacterizationDifference(
    caseID: id,
    message: "No reference was found on disk. New snapshot was not "
      + "recorded because recording is disabled"
  )
}

func preflightEncoding<Input, Observation>(
  _ cases: [CharacterizationCase<Input, Observation>]
) throws where Input: Codable & Sendable, Observation: Codable & Sendable {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  _ = try cases.map(encoder.encode)
}

private struct SnapshotVerificationPlan<
  Input: Codable & Sendable,
  Observation: Codable & Sendable
> {
  let cases: [CharacterizationCase<Input, Observation>]
  let testName: String
  let snapshotDirectory: URL
  let mode: CharacterizationMode
}

private func verifySnapshots<Input, Observation>(
  _ plan: SnapshotVerificationPlan<Input, Observation>
) -> [CharacterizationDifference]
where Input: Codable & Sendable, Observation: Codable & Sendable {
  plan.cases.compactMap { testCase in
    let failure = verifySnapshot(
      of: testCase,
      as: Snapshotting<CharacterizationCase<Input, Observation>, String>.json,
      named: testCase.id,
      record: plan.mode == .record ? .all : .never,
      snapshotDirectory: plan.snapshotDirectory.path,
      testName: plan.testName
    )
    guard plan.mode == .verify, let failure else { return nil }
    return CharacterizationDifference(caseID: testCase.id, message: failure)
  }
}


private func decodeCase<Input, Observation>(
  _ data: Data
) throws -> CharacterizationCase<Input, Observation>
where Input: Codable & Sendable, Observation: Codable & Sendable {
  try JSONDecoder().decode(
    CharacterizationCase<Input, Observation>.self,
    from: data
  )
}

private func verifyCase<Input, Observation>(
  _ testCase: CharacterizationCase<Input, Observation>,
  expected: [String: CharacterizationCase<Input, Observation>],
  snapshots: SnapshotAdapter<Input, Observation>
) -> CharacterizationDifference?
where Input: Codable & Sendable, Observation: Codable & Sendable {
  guard let storedCase = expected[testCase.id] else {
    return missingReferenceDifference(for: testCase.id)
  }
  let message = snapshots.difference(expected: storedCase, actual: testCase)
  guard let message else { return nil }
  return CharacterizationDifference(caseID: testCase.id, message: message)
}
