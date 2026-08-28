import Foundation
import SnapshotTesting
import Testing

struct CharacterizationExecutionRequest<Input, Output, Observation>: Sendable
where Input: Codable & Sendable, Output: Sendable, Observation: Codable & Sendable {
  let configuration: CharacterizationConfiguration<Input>
  let observe: @Sendable (Output) throws -> Observation
  let observeError: (@Sendable (any Error) throws -> CharacterizationError)?
  let operation: @Sendable (Input) async throws -> Output
}

struct CharacterizationExecution: Sendable {
  static func run<Input, Output, Observation>(
    _ request: CharacterizationExecutionRequest<Input, Output, Observation>
  ) async throws -> CharacterizationReport
  where Input: Codable & Sendable, Output: Sendable, Observation: Codable & Sendable {
    try await run(
      request,
      modeSelector: EnvironmentCharacterizationModeSelector(),
      fixtures: FileSystemSnapshotTestingFixtures(configuration: request.configuration),
      reporter: SwiftTestingDifferenceReporter()
    )
  }

  static func run<Input, Output, Observation>(
    _ request: CharacterizationExecutionRequest<Input, Output, Observation>,
    modeSelector: some CharacterizationModeSelecting,
    fixtures: some CharacterizationFixtures,
    reporter: some CharacterizationDifferenceReporting
  ) async throws -> CharacterizationReport
  where Input: Codable & Sendable, Output: Sendable, Observation: Codable & Sendable {
    let mode = modeSelector.select(explicitMode: request.configuration.mode)
    let recordedCases: [CharacterizationCase<Input, Observation>] =
      mode == .verify ? try fixtures.load() : []
    let inputs = try replayInputs(recordedCases, configuration: request.configuration, mode: mode)

    try validateCaseIDs(inputs)
    let cases = try await executeCases(
      inputs,
      observe: request.observe,
      observeError: request.observeError,
      operation: request.operation
    )

    if mode == .record {
      try preflightEncoding(cases)
      try fixtures.prepareForRecording()
    }

    let differences = fixtures.verify(cases, mode: mode)
    reporter.record(name: request.configuration.name, differences: differences)
    return CharacterizationReport(mode: mode, caseCount: cases.count, differences: differences)
  }
}

protocol CharacterizationModeSelecting: Sendable {
  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode
}

struct EnvironmentCharacterizationModeSelector: CharacterizationModeSelecting {
  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode {
    explicitMode ?? CharacterizationMode.fromEnvironment
  }
}

struct FixedCharacterizationModeSelector: CharacterizationModeSelecting {
  let mode: CharacterizationMode

  func select(explicitMode: CharacterizationMode?) -> CharacterizationMode {
    explicitMode ?? mode
  }
}

protocol CharacterizationFixtures: Sendable {
  func load<Input, Observation>() throws -> [CharacterizationCase<Input, Observation>]
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

  init<Input>(configuration: CharacterizationConfiguration<Input>) where Input: Codable & Sendable {
    directory = resolveSnapshotDirectory(configuration.fixture)
    testName = configuration.name
  }

  func load<Input, Observation>() throws -> [CharacterizationCase<Input, Observation>]
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
    guard mode == .record || FileManager.default.fileExists(atPath: directory.path) else {
      return cases.map { missingReferenceDifference(for: $0.id) }
    }
    return verifySnapshots(cases, testName: testName, snapshotDirectory: directory, mode: mode)
  }
}

final class InMemoryCharacterizationFixtures: CharacterizationFixtures, @unchecked Sendable {
  private var records: [Data]
  private let lock = NSLock()

  init(records: [Data] = []) {
    self.records = records
  }

  func load<Input, Observation>() throws -> [CharacterizationCase<Input, Observation>]
  where Input: Codable & Sendable, Observation: Codable & Sendable {
    lock.lock()
    defer { lock.unlock() }
    return try records.map {
      try JSONDecoder().decode(CharacterizationCase<Input, Observation>.self, from: $0)
    }
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
    let snapshots = PointFreeJSONSnapshotAdapter<CharacterizationCase<Input, Observation>>()
    if mode == .record {
      records = cases.map(snapshots.data)
      return []
    }
    let storedCases = try? records.map {
      try JSONDecoder().decode(CharacterizationCase<Input, Observation>.self, from: $0)
    }
    let expected = Dictionary(uniqueKeysWithValues: (storedCases ?? []).map { ($0.id, $0) })
    return cases.compactMap { testCase in
      guard let storedCase = expected[testCase.id] else {
        return missingReferenceDifference(for: testCase.id)
      }
      guard let message = snapshots.difference(expected: storedCase, actual: testCase) else {
        return nil
      }
      return CharacterizationDifference(caseID: testCase.id, message: message)
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

protocol CharacterizationDifferenceReporting: Sendable {
  func record(name: String, differences: [CharacterizationDifference])
}

struct SwiftTestingDifferenceReporter: CharacterizationDifferenceReporting {
  func record(name: String, differences: [CharacterizationDifference]) {
    recordDifferencesIfNeeded(name: name, differences: differences)
  }
}

final class CapturingDifferenceReporter: CharacterizationDifferenceReporting,
  @unchecked Sendable
{
  private(set) var reports: [(name: String, differences: [CharacterizationDifference])] = []

  func record(name: String, differences: [CharacterizationDifference]) {
    guard !differences.isEmpty else { return }
    reports.append((name: name, differences: differences))
  }
}

private func missingReferenceDifference(for id: String) -> CharacterizationDifference {
  CharacterizationDifference(
    caseID: id,
    message:
      "No reference was found on disk. New snapshot was not recorded because recording is disabled"
  )
}

private func replayInputs<Input, Observation>(
  _ recordedCases: [CharacterizationCase<Input, Observation>],
  configuration: CharacterizationConfiguration<Input>,
  mode: CharacterizationMode
) throws -> [CharacterizationInput<Input>]
where Input: Codable & Sendable, Observation: Codable & Sendable {
  if mode == .record || recordedCases.isEmpty && !configuration.inputs.isEmpty {
    return configuration.inputs
  }
  guard !recordedCases.isEmpty else {
    throw CharacterizationTestingError.fixtureMissing(configuration.fixture)
  }
  return recordedCases.map { CharacterizationInput(id: $0.id, value: $0.input) }
}

private func validateCaseIDs<Input>(_ inputs: [CharacterizationInput<Input>]) throws
where Input: Codable & Sendable {
  var knownIDs = Set<String>()
  var knownSnapshotIDs: [String: String] = [:]

  for input in inputs {
    try validateCaseID(input.id, knownIDs: &knownIDs, knownSnapshotIDs: &knownSnapshotIDs)
  }
}

private func validateCaseID(
  _ id: String,
  knownIDs: inout Set<String>,
  knownSnapshotIDs: inout [String: String]
) throws {
  guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    throw CharacterizationTestingError.invalidCaseID(id)
  }
  guard knownIDs.insert(id).inserted else { throw CharacterizationTestingError.duplicateCaseID(id) }

  let snapshotID = snapshotIdentifier(id)
  if let existingID = knownSnapshotIDs[snapshotID] {
    throw CharacterizationTestingError.collidingSnapshotIDs(existingID, id)
  }
  knownSnapshotIDs[snapshotID] = id
}

private func executeCases<Input, Output, Observation>(
  _ inputs: [CharacterizationInput<Input>],
  observe: @escaping @Sendable (Output) throws -> Observation,
  observeError: (@Sendable (any Error) throws -> CharacterizationError)?,
  operation: @escaping @Sendable (Input) async throws -> Output
) async throws -> [CharacterizationCase<Input, Observation>]
where Input: Codable & Sendable, Output: Sendable, Observation: Codable & Sendable {
  var cases: [CharacterizationCase<Input, Observation>] = []
  cases.reserveCapacity(inputs.count)
  for input in inputs {
    let outcome = try await runOperation(
      input.value,
      observe: observe,
      observeError: observeError,
      operation: operation
    )
    cases.append(CharacterizationCase(id: input.id, input: input.value, expected: outcome))
  }
  return cases
}

private func runOperation<Input, Output, Observation>(
  _ input: Input,
  observe: @escaping @Sendable (Output) throws -> Observation,
  observeError: (@Sendable (any Error) throws -> CharacterizationError)?,
  operation: @escaping @Sendable (Input) async throws -> Output
) async throws -> CharacterizationOutcome<Observation>
where Input: Sendable, Output: Sendable, Observation: Codable & Sendable {
  let output: Output
  do {
    output = try await operation(input)
  } catch {
    let projectedError = try observeError?(error) ?? CharacterizationError(error: error)
    return .threw(projectedError)
  }
  return .returned(try observe(output))
}

private func preflightEncoding<Input, Observation>(
  _ cases: [CharacterizationCase<Input, Observation>]
) throws where Input: Codable & Sendable, Observation: Codable & Sendable {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  _ = try cases.map(encoder.encode)
}

private func verifySnapshots<Input, Observation>(
  _ cases: [CharacterizationCase<Input, Observation>],
  testName: String,
  snapshotDirectory: URL,
  mode: CharacterizationMode
) -> [CharacterizationDifference]
where Input: Codable & Sendable, Observation: Codable & Sendable {
  cases.compactMap { testCase in
    let failure = verifySnapshot(
      of: testCase,
      as: Snapshotting<CharacterizationCase<Input, Observation>, String>.json,
      named: testCase.id,
      record: mode == .record ? .all : .never,
      snapshotDirectory: snapshotDirectory.path,
      testName: testName
    )
    guard mode == .verify, let failure else { return nil }
    return CharacterizationDifference(caseID: testCase.id, message: failure)
  }
}

private func resolveSnapshotDirectory(_ path: String) -> URL {
  guard !path.hasPrefix("/") else { return URL(fileURLWithPath: path, isDirectory: true) }
  return URL(
    fileURLWithPath: path,
    isDirectory: true,
    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  )
}

private func prepareSnapshotDirectory(
  _ directory: URL,
  testName: String
) throws {
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  let prefix = "\(snapshotIdentifier(testName))."
  let urls = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil
  )
  for url in urls
  where url.lastPathComponent.hasPrefix(prefix) && url.pathExtension == "json" {
    try FileManager.default.removeItem(at: url)
  }
}

private func loadSnapshots<Input, Observation>(
  from directory: URL,
  testName: String
) throws -> [CharacterizationCase<Input, Observation>]
where
  Input: Codable & Sendable,
  Observation: Codable & Sendable
{
  guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
  let prefix = "\(snapshotIdentifier(testName))."
  let contents = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil
  )
  let urls =
    contents
    .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
  return try urls.map { url in
    try JSONDecoder().decode(
      CharacterizationCase<Input, Observation>.self,
      from: Data(contentsOf: url)
    )
  }
}

private func snapshotIdentifier(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}

private func recordDifferencesIfNeeded(
  name: String,
  differences: [CharacterizationDifference]
) {
  guard !differences.isEmpty else { return }
  let details =
    differences
    .map { "[\($0.caseID)] \($0.message)" }
    .joined(separator: "\n")
  Issue.record(Comment(rawValue: "Characterization '\(name)' found differences:\n\(details)"))
}
