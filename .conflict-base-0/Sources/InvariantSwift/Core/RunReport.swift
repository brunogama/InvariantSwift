import Foundation

// MARK: - JSON Report Schema v1

/// Versioned JSON report for property test runs.
///
/// `RunReport` provides a stable, machine-readable format for CI/CD integration.
/// It includes all information needed to understand test outcomes, replay failures,
/// and track distributions.
///
/// The report format is versioned to enable backward-compatible schema evolution.
///
/// - Example:
///   ```swift
///   let report = RunReport(
///     version: 1,
///     propertyName: "Array Reverse Involution",
///     outcome: .success,
///     statistics: .init(
///       totalIterations: 100,
///       successfulIterations: 100,
///       failedIterations: 0,
///       discardedCases: 0,
///       durationMs: 123
///     ),
///     failure: nil,
///     classification: nil
///   )
///
///   let encoder = JSONEncoder()
///   encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
///   let jsonData = try encoder.encode(report)
///   let jsonString = String(data: jsonData, encoding: .utf8)!
///   ```
///
/// - See Also: ``FailureDetails``, ``RunStatistics``
public struct RunReport: Sendable, Codable, Equatable {
  /// Schema version for backward compatibility.
  ///
  /// Current version: 1
  public let version: Int

  /// Name or identifier of the property being tested.
  public let propertyName: String?

  /// Overall outcome of the test run.
  public let outcome: TestOutcome

  /// Execution statistics for the run.
  public let statistics: RunStatistics

  /// Detailed failure information if test failed.
  ///
  /// Present only when `outcome` is `.failed` or `.gaveUp`.
  public let failure: FailureDetails?

  /// Classification distribution if using ClassifyingProperty.
  ///
  /// Present only when the test used classification.
  public let classification: ClassificationReport?

  /// Creates a run report.
  public init(
    version: Int = 1,
    propertyName: String? = nil,
    outcome: TestOutcome,
    statistics: RunStatistics,
    failure: FailureDetails? = nil,
    classification: ClassificationReport? = nil
  ) {
    self.version = version
    self.propertyName = propertyName
    self.outcome = outcome
    self.statistics = statistics
    self.failure = failure
    self.classification = classification
  }
}

// MARK: - Test Outcome

extension RunReport {
  /// Overall outcome of a property test run.
  public enum TestOutcome: String, Sendable, Codable, Equatable {
    /// Property held for all test cases.
    case success

    /// Property failed on at least one test case.
    case failed

    /// Test gave up due to too many discarded cases.
    case gaveUp
  }
}

// MARK: - Run Statistics

extension RunReport {
  /// Execution statistics for a property test run.
  public struct RunStatistics: Sendable, Codable, Equatable {
    /// Total iterations attempted (including discarded).
    public let totalIterations: Int

    /// Number of successful property checks.
    public let successfulIterations: Int

    /// Number of failed property checks.
    public let failedIterations: Int

    /// Number of test cases discarded due to assumption violations.
    public let discardedCases: Int

    /// Total execution time in milliseconds.
    public let durationMs: Int

    /// Number of shrinking steps performed (if applicable).
    public let shrinkSteps: Int?

    /// Creates run statistics.
    public init(
      totalIterations: Int,
      successfulIterations: Int,
      failedIterations: Int,
      discardedCases: Int,
      durationMs: Int,
      shrinkSteps: Int? = nil
    ) {
      self.totalIterations = totalIterations
      self.successfulIterations = successfulIterations
      self.failedIterations = failedIterations
      self.discardedCases = discardedCases
      self.durationMs = durationMs
      self.shrinkSteps = shrinkSteps
    }
  }
}

// MARK: - Failure Details

extension RunReport {
  /// Detailed information about a test failure.
  public struct FailureDetails: Sendable, Codable, Equatable {
    /// The iteration number where failure occurred.
    public let failedAtIteration: Int

    /// Classification of why the property failed.
    public let reason: String

    /// String representation of the original failing counterexample.
    public let originalCounterexample: String

    /// String representation of the minimal (shrunk) counterexample.
    public let minimalCounterexample: String

    /// Replay token for reproducing this failure.
    public let replayToken: ReplayToken

    /// Shrink trace showing the path to the minimal counterexample.
    public let shrinkTrace: [ShrinkStep]?

    /// Creates failure details.
    public init(
      failedAtIteration: Int,
      reason: String,
      originalCounterexample: String,
      minimalCounterexample: String,
      replayToken: ReplayToken,
      shrinkTrace: [ShrinkStep]? = nil
    ) {
      self.failedAtIteration = failedAtIteration
      self.reason = reason
      self.originalCounterexample = originalCounterexample
      self.minimalCounterexample = minimalCounterexample
      self.replayToken = replayToken
      self.shrinkTrace = shrinkTrace
    }
  }

  /// A single step in the shrink trace.
  public struct ShrinkStep: Sendable, Codable, Equatable {
    /// The candidate value at this shrink step.
    public let candidate: String

    /// Whether this candidate still failed the property.
    public let stillFails: Bool

    /// Creates a shrink step.
    public init(candidate: String, stillFails: Bool) {
      self.candidate = candidate
      self.stillFails = stillFails
    }
  }
}

// MARK: - Factory Methods

extension RunReport {
  /// Creates a run report from a PropertyResult.
  ///
  /// - Parameters:
  ///   - result: The property test result
  ///   - propertyName: Optional name for the property
  ///   - durationMs: Execution time in milliseconds
  ///   - config: The configuration that was used
  ///   - shrinkTrace: Optional shrink trace for failures
  /// - Returns: A RunReport encoding all test information
  public static func from<T>(
    _ result: PropertyResult<T>,
    propertyName: String? = nil,
    durationMs: Int,
    config: PropertyConfig,
    shrinkTrace: [ShrinkStep]? = nil
  ) -> RunReport {
    buildReport(
      from: result,
      propertyName: propertyName,
      durationMs: durationMs,
      config: config,
      shrinkTrace: shrinkTrace
    )
  }

  // swiftlint:disable function_body_length function_parameter_count
  // Complexity: Each case builds different report structure; extraction would obscure logic flow
  private static func buildReport<T>(
    from result: PropertyResult<T>,
    propertyName: String?,
    durationMs: Int,
    config: PropertyConfig,
    shrinkTrace: [ShrinkStep]?
  ) -> RunReport {
    switch result {
    case .success(let iterations):
      return RunReport(
        propertyName: propertyName,
        outcome: .success,
        statistics: RunStatistics(
          totalIterations: iterations,
          successfulIterations: iterations,
          failedIterations: 0,
          discardedCases: 0,
          durationMs: durationMs,
          shrinkSteps: nil
        ),
        failure: nil,
        classification: nil
      )

    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      let token = ReplayToken(seed: seed, config: config)
      let failureDetails = FailureDetails(
        failedAtIteration: iterations,
        reason: reason.description,
        originalCounterexample: String(describing: counterexample),
        minimalCounterexample: String(describing: shrunk),
        replayToken: token,
        shrinkTrace: shrinkTrace
      )

      return RunReport(
        propertyName: propertyName,
        outcome: .failed,
        statistics: RunStatistics(
          totalIterations: iterations,
          successfulIterations: iterations - 1,
          failedIterations: 1,
          discardedCases: 0,
          durationMs: durationMs,
          shrinkSteps: shrinkTrace?.count
        ),
        failure: failureDetails,
        classification: nil
      )

    case .gaveUp(let discarded, let iterations):
      let token = ReplayToken(
        seed: config.seed?.rawValue ?? 0,
        iterations: config.iterations,
        maxDiscarded: config.maxDiscarded
      )
      let failureDetails = FailureDetails(
        failedAtIteration: iterations,
        reason: "Too many discarded cases",
        originalCounterexample: "N/A",
        minimalCounterexample: "N/A",
        replayToken: token,
        shrinkTrace: nil
      )

      return RunReport(
        propertyName: propertyName,
        outcome: .gaveUp,
        statistics: RunStatistics(
          totalIterations: iterations,
          successfulIterations: 0,
          failedIterations: 0,
          discardedCases: discarded,
          durationMs: durationMs,
          shrinkSteps: nil
        ),
        failure: failureDetails,
        classification: nil
      )
    }
  }
  // swiftlint:enable function_body_length function_parameter_count

  /// Creates a run report from a ClassifyingPropertyResult.
  ///
  /// Includes classification distribution in the report.
  ///
  /// - Parameters:
  ///   - result: The classifying property result
  ///   - propertyName: Optional name for the property
  ///   - durationMs: Execution time in milliseconds
  ///   - config: The configuration that was used
  ///   - shrinkTrace: Optional shrink trace for failures
  /// - Returns: A RunReport including classification data
  public static func from<T>(
    _ result: ClassifyingPropertyResult<T>,
    propertyName: String? = nil,
    durationMs: Int,
    config: PropertyConfig,
    shrinkTrace: [ShrinkStep]? = nil
  ) -> RunReport {
    var baseReport = RunReport.from(
      result.result,
      propertyName: propertyName,
      durationMs: durationMs,
      config: config,
      shrinkTrace: shrinkTrace
    )

    baseReport = RunReport(
      version: baseReport.version,
      propertyName: baseReport.propertyName,
      outcome: baseReport.outcome,
      statistics: baseReport.statistics,
      failure: baseReport.failure,
      classification: result.classification
    )

    return baseReport
  }
}

// MARK: - JSON Export

extension RunReport {
  /// Encodes the report to JSON data.
  ///
  /// - Parameter prettyPrinted: Whether to format the JSON for readability
  /// - Returns: JSON-encoded data
  /// - Throws: EncodingError if encoding fails
  public func toJSON(prettyPrinted: Bool = true) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    if prettyPrinted {
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
      encoder.outputFormatting = [.sortedKeys]
    }

    return try encoder.encode(self)
  }

  /// Encodes the report to a JSON string.
  ///
  /// - Parameter prettyPrinted: Whether to format the JSON for readability
  /// - Returns: JSON string
  /// - Throws: EncodingError if encoding fails
  public func toJSONString(prettyPrinted: Bool = true) throws -> String {
    let data = try toJSON(prettyPrinted: prettyPrinted)
    guard let string = String(data: data, encoding: .utf8) else {
      throw EncodingError.invalidValue(
        data,
        EncodingError.Context(
          codingPath: [],
          debugDescription: "Failed to convert JSON data to UTF-8 string"
        )
      )
    }
    return string
  }

  /// Writes the report to a JSON file.
  ///
  /// - Parameters:
  ///   - path: File path to write to
  ///   - prettyPrinted: Whether to format the JSON for readability
  /// - Throws: EncodingError or file I/O errors
  public func writeJSON(to path: String, prettyPrinted: Bool = true) throws {
    let data = try toJSON(prettyPrinted: prettyPrinted)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
  }
}

// MARK: - JSON Import

extension RunReport {
  /// Decodes a RunReport from JSON data.
  ///
  /// - Parameter data: JSON-encoded data
  /// - Returns: Decoded RunReport
  /// - Throws: DecodingError if decoding fails
  public static func fromJSON(_ data: Data) throws -> RunReport {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(RunReport.self, from: data)
  }

  /// Decodes a RunReport from a JSON string.
  ///
  /// - Parameter string: JSON string
  /// - Returns: Decoded RunReport
  /// - Throws: DecodingError if decoding fails
  public static func fromJSONString(_ string: String) throws -> RunReport {
    guard let data = string.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Invalid UTF-8 in JSON string"
        )
      )
    }
    return try fromJSON(data)
  }

  /// Reads a RunReport from a JSON file.
  ///
  /// - Parameter path: File path to read from
  /// - Returns: Decoded RunReport
  /// - Throws: DecodingError or file I/O errors
  public static func readJSON(from path: String) throws -> RunReport {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try fromJSON(data)
  }
}
