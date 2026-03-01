import Foundation

// swiftlint:disable:next orphaned_doc_comment
/// Outcome of executing a property-based test.
///
/// `PropertyResult<T>` represents the three possible outcomes when running a property test:
/// success, failure with a minimal counterexample, or giving up due to too many discarded cases.
///
/// **Success**: The property held for all generated test cases. Confidence in the property
/// increases with more iterations.
///
/// **Failure**: The property failed on some generated input. The result includes:
/// - `counterexample`: The original failing input (as generated)
/// - `shrunk`: The minimal counterexample (simplified to make debugging easier)
/// - `iterations`: How many test cases were executed before failure
/// - `reason`: Classification of failure type (predicate failed, threw, timed out)
/// - `seed`: The seed used for deterministic reproduction
///
/// **GaveUp**: The property testing framework discarded too many generated values
/// (e.g., all generated inputs violated preconditions). This indicates the property
/// cannot be adequately tested with the current generator and assumptions.
///
/// - Cases:
///   - `success(iterations:)`: Property held for all iterations
///   - `failure(counterexample:iterations:shrunk:reason:seed:)`: Property failed on this input
///   - `gaveUp(discarded:iterations:)`: Too many inputs discarded due to assumptions
///
/// - Example:
///   ```swift
///   let gen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
///   let property = Property(generator: gen) { n in n >= 0 }
///
///   let result = /* run property */
///
///   switch result {
///   case .success(let iterations):
// swiftlint:disable:next no_print
///       print("Passed \(iterations) tests")
///   case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
// swiftlint:disable:next no_print
///       print("Failed after \(iterations) tests (\(reason))")
// swiftlint:disable:next no_print
///       print("Original: \(counterexample), Minimal: \(shrunk)")
// swiftlint:disable:next no_print
///       print("Reproduce with seed: \(seed.rawValue)")
///   case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///       print("Gave up after discarding \(discarded) cases in \(iterations) attempts")
///   }
///   ```
///
/// - See Also: ``Property``, ``PropertyRunner``, ``FailureReason``
public enum PropertyResult<T>: Sendable where T: Sendable {
  /// Property held for all generated test cases.
  ///
  /// - Parameters:
  ///   - iterations: Number of test cases successfully checked
  case success(iterations: Int)

  // swiftlint:disable:next orphaned_doc_comment
  /// Property failed on a generated input.
  ///
  /// - Parameters:
  ///   - counterexample: The original failing input as generated
  ///   - iterations: Number of iterations before failure
  ///   - shrunk: The minimized failing input (typically simpler than counterexample)
  ///   - reason: Classification of how the property failed
  ///   - seed: The seed used for this test run (for reproduction)
  // swiftlint:disable:next enum_case_associated_values_count
  case failure(counterexample: T, iterations: Int, shrunk: T, reason: FailureReason, seed: Seed)

  /// Property testing gave up due to too many discarded cases.
  ///
  /// - Parameters:
  ///   - discarded: Number of generated inputs rejected by the property's assumption
  ///   - iterations: Total number of generation attempts
  case gaveUp(discarded: Int, iterations: Int)
}

// MARK: - PropertyResult Computed Properties

extension PropertyResult {
  /// Check if the property result represents a failure
  public var isFailure: Bool {
    switch self {
    case .failure:
      return true

    case .success, .gaveUp:
      return false
    }
  }

  /// Check if the property result represents success
  public var isSuccess: Bool {
    switch self {
    case .success:
      return true

    case .failure, .gaveUp:
      return false
    }
  }

  /// Check if the property result represents giving up due to too many discards
  public var isGaveUp: Bool {
    switch self {
    case .gaveUp:
      return true

    case .success, .failure:
      return false
    }
  }

  /// Extract the iteration count from any result case.
  ///
  /// - Returns: Number of iterations that were executed
  public var iterationCount: Int {
    switch self {
    case .success(let iterations):
      return iterations

    case .failure(_, let iterations, _, _, _):
      return iterations

    case .gaveUp(_, let iterations):
      return iterations
    }
  }

  /// Convert result to CLI exit code.
  ///
  /// - Returns: 0 for success, 1 for failure, 2 for gave up
  public func toExitCode() -> Int32 {
    switch self {
    case .success:
      return 0

    case .failure:
      return 1

    case .gaveUp:
      return 2
    }
  }

  /// Short one-line description suitable for logs.
  public var shortDescription: String {
    switch self {
    case .success(let iterations):
      return "PASS (\(iterations) iterations)"

    case .failure:
      return "FAIL"

    case .gaveUp(let discarded, _):
      return "GAVE_UP (\(discarded) discarded)"
    }
  }

  /// Generates a deterministic reproduction string for failures.
  ///
  /// Returns nil for success or gaveUp results. For failures, returns a
  /// `ReproString` that can be used to reproduce the exact failure.
  public var reproString: ReproString? {
    switch self {
    case .success, .gaveUp:
      return nil

    case .failure(_, let iterations, let shrunk, let reason, let seed):
      return ReproString(
        seed: seed.rawValue,
        iteration: iterations,
        shrunkDescription: "\(shrunk)",
        reason: reason
      )
    }
  }
}

extension PropertyResult: CustomStringConvertible {
  /// Human-readable description of the property result.
  public var description: String {
    switch self {
    case .success(let iterations):
      return "✓ Passed \(iterations) tests"

    case .failure(_, let iterations, let shrunk, let reason, let seed):
      return """
        ✗ Failed after \(iterations) tests: \(reason)
          Minimal counterexample: \(shrunk)
          Reproduce with seed: \(seed.rawValue)
        """

    case .gaveUp(let discarded, let iterations):
      return "? Gave up after \(iterations) tests (\(discarded) inputs discarded)"
    }
  }
}

// MARK: - Reproduction String

/// A deterministic reproduction string for property test failures.
///
/// `ReproString` encapsulates all information needed to reproduce a failing property test:
/// - The seed used for random generation
/// - The iteration count where failure occurred
/// - The configuration used (iterations, maxShrinks)
/// - The minimal counterexample (shrunk value)
/// - The failure reason
///
/// The string format is designed to be copy-pasteable from test output into code or CLI.
///
/// - Example:
///   ```swift
///   // From test output:
///   // REPRO:seed=12345678,iter=42,shrunk="[1, 2]",reason=predicateFailed
///
///   // Parse and re-run:
///   let repro = ReproString.parse("REPRO:seed=12345678,iter=42,shrunk=\"[1, 2]\",reason=predicateFailed")
///   ```
public struct ReproString: Sendable, Equatable, CustomStringConvertible {
  public let seed: UInt64
  public let iteration: Int
  public let shrunkDescription: String
  public let reason: FailureReason

  public init(seed: UInt64, iteration: Int, shrunkDescription: String, reason: FailureReason) {
    self.seed = seed
    self.iteration = iteration
    self.shrunkDescription = shrunkDescription
    self.reason = reason
  }

  public var description: String {
    let reasonStr: String
    switch reason {
    case .predicateFailed:
      reasonStr = "predicateFailed"

    case .threwError(let error):
      reasonStr = "threwError(\(error))"

    case .timedOut(let seconds):
      reasonStr = "timedOut(\(seconds)s)"
    }
    return
      "REPRO:seed=\(seed),iter=\(iteration),shrunk=\"\(shrunkDescription)\",reason=\(reasonStr)"
  }

  /// Parses a reproduction string back into its components.
  ///
  /// Format: `REPRO:seed=<uint64>,iter=<int>,shrunk="<description>",reason=<reason>`
  ///
  /// - Parameter string: The reproduction string to parse
  /// - Returns: A `ReproString` if parsing succeeds, nil otherwise
  public static func parse(_ string: String) -> Self? {
    guard string.hasPrefix("REPRO:") else { return nil }

    let content = String(string.dropFirst(6))
    let parts = splitQuoteAware(content)

    var seed: UInt64?
    var iteration: Int?
    var shrunk: String?
    var reason: FailureReason = .predicateFailed

    for part in parts {
      let trimmed = part.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("seed=") {
        seed = UInt64(String(trimmed.dropFirst(5)))
      } else if trimmed.hasPrefix("iter=") {
        iteration = Int(String(trimmed.dropFirst(5)))
      } else if trimmed.hasPrefix("shrunk=\"") {
        shrunk = parseShrunkValue(trimmed)
      } else if trimmed.hasPrefix("reason=") {
        reason = parseReason(String(trimmed.dropFirst(7)))
      }
    }

    guard let parsedSeed = seed, let parsedIteration = iteration, let parsedShrunk = shrunk else {
      return nil
    }

    return Self(
      seed: parsedSeed,
      iteration: parsedIteration,
      shrunkDescription: parsedShrunk,
      reason: reason
    )
  }

  private static func splitQuoteAware(_ content: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuotes = false

    for char in content {
      if char == "\"" {
        inQuotes.toggle()
        current.append(char)
      } else if char == "," && !inQuotes {
        parts.append(current)
        current = ""
      } else {
        current.append(char)
      }
    }
    if !current.isEmpty {
      parts.append(current)
    }
    return parts
  }

  private static func parseShrunkValue(_ trimmed: String) -> String? {
    if trimmed == "shrunk=\"\"" {
      return ""
    }
    let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 8)
    guard let endQuote = trimmed.lastIndex(of: "\""), endQuote > startIndex else {
      return nil
    }
    return String(trimmed[startIndex..<endQuote])
  }

  private static func parseReason(_ reasonStr: String) -> FailureReason {
    if reasonStr == "predicateFailed" {
      return .predicateFailed
    }
    if reasonStr.hasPrefix("threwError("), let errorEnd = reasonStr.lastIndex(of: ")") {
      let errorStart = reasonStr.index(reasonStr.startIndex, offsetBy: 11)
      return .threwError(String(reasonStr[errorStart..<errorEnd]))
    }
    if reasonStr.hasPrefix("timedOut("), let timeEnd = reasonStr.lastIndex(of: "s") {
      let timeStart = reasonStr.index(reasonStr.startIndex, offsetBy: 9)
      if let seconds = Double(String(reasonStr[timeStart..<timeEnd])) {
        return .timedOut(seconds: seconds)
      }
    }
    return .predicateFailed
  }
}
