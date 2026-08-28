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

  init(error: any Error) {
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
  let request = CharacterizationExecutionRequest(
    configuration: configuration,
    observe: observe,
    observeError: observeError,
    operation: operation
  )
  return try await CharacterizationExecution.run(request)
}
