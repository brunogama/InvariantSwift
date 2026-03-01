import Foundation

// MARK: - Subprocess IPC Protocol

/// Request sent from parent to child process for property evaluation.
///
/// Serialised as length-prefixed JSON on the child's stdin pipe.
/// Both sides must agree on `protocolVersion` — the helper exits with
/// code 3 if the version does not match.
public struct PropertyEvaluationRequest: Codable, Sendable {

  /// Unique identifier for this evaluation request.
  public let testId: UUID

  /// Seed for deterministic test generation.
  public let seed: UInt64

  /// Size parameter for generation.
  public let size: Int

  /// Serialized test input (JSON encoded).
  public let testInput: Data

  /// Generator type name for reconstruction.
  public let generatorType: String

  /// IPC protocol version — checked by the helper binary to detect mismatches.
  public let protocolVersion: Int

  public init(
    testId: UUID,
    seed: UInt64,
    size: Int,
    testInput: Data,
    generatorType: String,
    protocolVersion: Int = 1
  ) {
    self.testId = testId
    self.seed = seed
    self.size = size
    self.testInput = testInput
    self.generatorType = generatorType
    self.protocolVersion = protocolVersion
  }
}

/// Response sent from child to parent after property evaluation.
///
/// Serialised as length-prefixed JSON on the child's stdout pipe.
public struct PropertyEvaluationResponse: Codable, Sendable {

  /// Unique identifier matching the request.
  public let testId: UUID

  /// Whether the property predicate passed.
  public let passed: Bool

  /// Optional failure reason if `passed == false`.
  public let failureReason: String?

  /// Execution time in seconds.
  public let duration: TimeInterval

  /// IPC protocol version echoed back from the helper.
  public let protocolVersion: Int

  public init(
    testId: UUID,
    passed: Bool,
    failureReason: String? = nil,
    duration: TimeInterval,
    protocolVersion: Int = 1
  ) {
    self.testId = testId
    self.passed = passed
    self.failureReason = failureReason
    self.duration = duration
    self.protocolVersion = protocolVersion
  }
}
