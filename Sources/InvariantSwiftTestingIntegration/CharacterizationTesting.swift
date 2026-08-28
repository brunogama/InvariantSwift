import Foundation
import SnapshotTesting
import Testing

/// The mode used when executing characterization snapshots.
public enum CharacterizationMode: String, Codable, Sendable {
  case verify
  case record

  /// Reads the mode from `INVARIANT_CHARACTERIZATION_MODE`.
  public static var fromEnvironment: Self {
    let value = ProcessInfo.processInfo.environment["INVARIANT_CHARACTERIZATION_MODE"]
    return Self(rawValue: value ?? "verify") ?? .verify
  }
}

/// Configuration shared by characterization API and macro-generated tests.
public struct CharacterizationConfiguration<Input: Codable & Sendable>: Sendable {
  public let name: String
  public let fixture: String
  public let inputs: [CharacterizationInput<Input>]
  public let mode: CharacterizationMode?

  public init(
    name: String,
    fixture: String,
    inputs: [CharacterizationInput<Input>],
    mode: CharacterizationMode? = nil
  ) {
    self.name = name
    self.fixture = fixture
    self.inputs = inputs
    self.mode = mode
  }
}

/// An explicitly named input for a characterization case.
public struct CharacterizationInput<Value: Codable & Sendable>: Codable, Sendable, Identifiable {
  public let id: String
  public let value: Value

  public init(id: String, value: Value) {
    self.id = id
    self.value = value
  }
}

/// A stable projection of an error thrown by a system under test.
public struct CharacterizationError: Codable, Sendable, Equatable, Error {
  public let type: String
  public let code: String?
  public let message: String

  public init(type: String, code: String? = nil, message: String) {
    self.type = type
    self.code = code
    self.message = message
  }

  fileprivate init(error: any Error) {
    self.init(
      type: String(reflecting: Swift.type(of: error)),
      message: String(describing: error)
    )
  }
}

/// The recorded result for one characterization case.
public enum CharacterizationOutcome<Value: Codable & Sendable>: Codable, Sendable {
  case returned(Value)
  case threw(CharacterizationError)

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
    case error
  }

  private enum Kind: String, Codable {
    case returned
    case threw
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .returned:
      self = .returned(try container.decode(Value.self, forKey: .value))

    case .threw:
      self = .threw(try container.decode(CharacterizationError.self, forKey: .error))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .returned(let value):
      try container.encode(Kind.returned, forKey: .kind)
      try container.encode(value, forKey: .value)

    case .threw(let error):
      try container.encode(Kind.threw, forKey: .kind)
      try container.encode(error, forKey: .error)
    }
  }
}

/// One replayable characterization snapshot.
public struct CharacterizationCase<Input: Codable & Sendable, Value: Codable & Sendable>:
  Codable, Sendable
{
  public let id: String
  public let input: Input
  public let expected: CharacterizationOutcome<Value>

  public init(id: String, input: Input, expected: CharacterizationOutcome<Value>) {
    self.id = id
    self.input = input
    self.expected = expected
  }
}

/// One SnapshotTesting mismatch.
public struct CharacterizationDifference: Sendable, Equatable {
  public let caseID: String
  public let message: String

  public init(caseID: String, message: String) {
    self.caseID = caseID
    self.message = message
  }
}

/// The aggregate result of a characterization run.
public struct CharacterizationReport: Sendable {
  public let mode: CharacterizationMode
  public let caseCount: Int
  public let differences: [CharacterizationDifference]

  public init(
    mode: CharacterizationMode,
    caseCount: Int,
    differences: [CharacterizationDifference]
  ) {
    self.mode = mode
    self.caseCount = caseCount
    self.differences = differences
  }
}

/// Errors raised before characterization can compare snapshots.
public enum CharacterizationTestingError: Error, Sendable, CustomStringConvertible {
  case fixtureMissing(String)
  case invalidCaseID(String)
  case duplicateCaseID(String)
  case collidingSnapshotIDs(String, String)

  public var description: String {
    switch self {
    case .fixtureMissing(let path):
      return "No characterization snapshots exist in \(path). Record explicit inputs first."

    case .invalidCaseID(let id):
      return "Characterization case IDs must be non-empty: \(id.debugDescription)."

    case .duplicateCaseID(let id):
      return "Characterization case ID is duplicated: \(id.debugDescription)."

    case .collidingSnapshotIDs(let first, let second):
      return
        "Characterization case IDs map to one snapshot: \(first.debugDescription), \(second.debugDescription)."
    }
  }
}

/// Runs an explicit input corpus against a system under test.
public func characterize<Input, Output>(
  _ configuration: CharacterizationConfiguration<Input>,
  observeError: (@Sendable (any Error) throws -> CharacterizationError)? = nil,
  operation: @escaping @Sendable (Input) async throws -> Output
) async throws -> CharacterizationReport
where Input: Codable & Sendable, Output: Codable & Sendable {
  try await characterize(
    configuration,
    observe: { $0 },
    observeError: observeError,
    operation: operation
  )
}

/// Runs an explicit input corpus with a custom Codable observation projection.
public func characterize<Input, Output, Observation>(
  _ configuration: CharacterizationConfiguration<Input>,
  observe: @escaping @Sendable (Output) throws -> Observation,
  observeError: (@Sendable (any Error) throws -> CharacterizationError)? = nil,
  operation: @escaping @Sendable (Input) async throws -> Output
) async throws -> CharacterizationReport
where Input: Codable & Sendable, Output: Sendable, Observation: Codable & Sendable {
  let mode = configuration.mode ?? CharacterizationMode.fromEnvironment
  let snapshotDirectory = resolveSnapshotDirectory(configuration.fixture)
  let recordedCases: [CharacterizationCase<Input, Observation>] =
    mode == .verify ? try loadSnapshots(from: snapshotDirectory, testName: configuration.name) : []
  let inputs = try replayInputs(recordedCases, configuration: configuration, mode: mode)

  try validateCaseIDs(inputs)
  let cases = try await executeCases(
    inputs,
    observe: observe,
    observeError: observeError,
    operation: operation
  )

  if mode == .record {
    try preflightEncoding(cases)
    try prepareSnapshotDirectory(snapshotDirectory, testName: configuration.name)
  }

  let differences = verifySnapshots(
    cases,
    configuration: configuration,
    snapshotDirectory: snapshotDirectory,
    mode: mode
  )
  recordDifferencesIfNeeded(name: configuration.name, differences: differences)
  return CharacterizationReport(mode: mode, caseCount: cases.count, differences: differences)
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
  guard knownIDs.insert(id).inserted else {
    throw CharacterizationTestingError.duplicateCaseID(id)
  }

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
  configuration: CharacterizationConfiguration<Input>,
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
      testName: configuration.name
    )
    guard mode == .verify, let failure else { return nil }
    return CharacterizationDifference(caseID: testCase.id, message: failure)
  }
}

private func resolveSnapshotDirectory(_ path: String) -> URL {
  let url = URL(fileURLWithPath: path, isDirectory: true)
  guard !path.hasPrefix("/") else { return url }
  return URL(
    fileURLWithPath: path,
    isDirectory: true,
    relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  )
}

private func prepareSnapshotDirectory(_ directory: URL, testName: String) throws {
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
where Input: Codable & Sendable, Observation: Codable & Sendable {
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
