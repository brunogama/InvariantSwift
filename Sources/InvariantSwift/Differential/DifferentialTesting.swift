/// DifferentialTesting - Core types for differential testing
///
/// Part of ISP-0005: Differential Testing

import Foundation

// MARK: - Error Behavior

/// How to handle error cases in differential testing.
// swiftlint:disable cyclomatic_complexity
public enum ErrorBehavior: Sendable {
  /// Both implementations must throw the same error type
  case mustMatch

  /// Both must either succeed or throw (error types don't need to match)
  case bothThrowOrBothSucceed

  /// Candidate may succeed where reference throws (lenient migration)
  case candidateMaySucceedMore

  /// Ignore throwing behavior entirely
  case ignoreErrors
}

// MARK: - Differential Result

/// Result of comparing two implementations on the same input.
public struct DifferentialResult<Input: Sendable, Output: Sendable>: Sendable {
  /// The input that was tested
  public let input: Input

  /// Result from the reference implementation
  public let referenceOutput: Result<Output, any Error>

  /// Result from the candidate implementation
  public let candidateOutput: Result<Output, any Error>

  /// Custom comparison function (nil uses Equatable)
  private let comparer: (@Sendable (Output, Output) -> Bool)?

  public init(
    input: Input,
    referenceOutput: Result<Output, any Error>,
    candidateOutput: Result<Output, any Error>,
    comparer: (@Sendable (Output, Output) -> Bool)? = nil
  ) {
    self.input = input
    self.referenceOutput = referenceOutput
    self.candidateOutput = candidateOutput
    self.comparer = comparer
  }

  /// Whether the implementations produced different results
  public var diverges: Bool {
    diverges(errorBehavior: .bothThrowOrBothSucceed)
  }

  /// Check divergence with specific error behavior
  public func diverges(errorBehavior: ErrorBehavior) -> Bool {
    switch (referenceOutput, candidateOutput) {
    case (.success(let ref), .success(let cand)):
      if let comparer = comparer {
        return !comparer(ref, cand)
      }
      // Fall back to Equatable if Output conforms
      return !areEqual(ref, cand)

    case (.failure, .failure):
      switch errorBehavior {
      case .mustMatch:
        // TODO: Compare error types
        return false

      case .bothThrowOrBothSucceed, .candidateMaySucceedMore, .ignoreErrors:
        return false
      }

    case (.failure, .success):
      switch errorBehavior {
      case .candidateMaySucceedMore, .ignoreErrors:
        return false

      case .mustMatch, .bothThrowOrBothSucceed:
        return true
      }

    case (.success, .failure):
      switch errorBehavior {
      case .ignoreErrors:
        return false

      case .mustMatch, .bothThrowOrBothSucceed, .candidateMaySucceedMore:
        return true
      }
    }
  }

  /// Helper to check equality when Output is Equatable
  private func areEqual(_ lhs: Output, _ rhs: Output) -> Bool {
    if let lhsEq = lhs as? any Equatable, let rhsEq = rhs as? any Equatable {
      return isEqual(lhsEq, rhsEq)
    }
    // Non-Equatable types without custom comparer always diverge
    return false
  }

  private func isEqual<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool {
    guard let rhsT = rhs as? T else { return false }
    return lhs == rhsT
  }
}

// MARK: - Differential Test Error

/// Error thrown when differential test finds a divergence.
public struct DifferentialTestError<Input: Sendable, Output: Sendable>: Error,
  CustomStringConvertible, Sendable
{
  public let result: DifferentialResult<Input, Output>
  public let referenceName: String
  public let candidateName: String

  public init(
    result: DifferentialResult<Input, Output>,
    referenceName: String = "reference",
    candidateName: String = "candidate"
  ) {
    self.result = result
    self.referenceName = referenceName
    self.candidateName = candidateName
  }

  public var description: String {
    var lines: [String] = []
    lines.append("❌ Differential test failed!")
    lines.append("")
    lines.append("Input: \(result.input)")
    lines.append("")

    switch result.referenceOutput {
    case .success(let ref):
      lines.append("\(referenceName): \(ref)")

    case .failure(let err):
      lines.append("\(referenceName) threw: \(err)")
    }

    switch result.candidateOutput {
    case .success(let cand):
      lines.append("\(candidateName): \(cand)")

    case .failure(let err):
      lines.append("\(candidateName) threw: \(err)")
    }

    return lines.joined(separator: "\n")
  }
}

// MARK: - Differential Tester

/// Utility for running differential tests between two implementations.
public struct DifferentialTester<Input: Sendable, Output: Sendable>: Sendable {
  public let reference: @Sendable (Input) throws -> Output
  public let candidate: @Sendable (Input) throws -> Output
  public let comparer: (@Sendable (Output, Output) -> Bool)?
  public let errorBehavior: ErrorBehavior

  public init(
    reference: @escaping @Sendable (Input) throws -> Output,
    candidate: @escaping @Sendable (Input) throws -> Output,
    comparer: (@Sendable (Output, Output) -> Bool)? = nil,
    errorBehavior: ErrorBehavior = .bothThrowOrBothSucceed
  ) {
    self.reference = reference
    self.candidate = candidate
    self.comparer = comparer
    self.errorBehavior = errorBehavior
  }

  /// Test the two implementations on a given input
  public func test(_ input: Input) -> DifferentialResult<Input, Output> {
    let refResult: Result<Output, any Error>
    do {
      refResult = .success(try reference(input))
    } catch {
      refResult = .failure(error)
    }

    let candResult: Result<Output, any Error>
    do {
      candResult = .success(try candidate(input))
    } catch {
      candResult = .failure(error)
    }

    return DifferentialResult(
      input: input,
      referenceOutput: refResult,
      candidateOutput: candResult,
      comparer: comparer
    )
  }

  /// Test and throw if divergence is found
  public func testOrThrow(_ input: Input) throws {
    let result = test(input)
    if result.diverges(errorBehavior: errorBehavior) {
      throw DifferentialTestError(result: result)
    }
  }
}

// MARK: - Async Differential Tester

/// Async variant of DifferentialTester.
public struct AsyncDifferentialTester<Input: Sendable, Output: Sendable>: Sendable {
  public let reference: @Sendable (Input) async throws -> Output
  public let candidate: @Sendable (Input) async throws -> Output
  public let comparer: (@Sendable (Output, Output) -> Bool)?
  public let errorBehavior: ErrorBehavior

  public init(
    reference: @escaping @Sendable (Input) async throws -> Output,
    candidate: @escaping @Sendable (Input) async throws -> Output,
    comparer: (@Sendable (Output, Output) -> Bool)? = nil,
    errorBehavior: ErrorBehavior = .bothThrowOrBothSucceed
  ) {
    self.reference = reference
    self.candidate = candidate
    self.comparer = comparer
    self.errorBehavior = errorBehavior
  }

  /// Test the two implementations on a given input
  public func test(_ input: Input) async -> DifferentialResult<Input, Output> {
    let refResult: Result<Output, any Error>
    do {
      refResult = .success(try await reference(input))
    } catch {
      refResult = .failure(error)
    }

    let candResult: Result<Output, any Error>
    do {
      candResult = .success(try await candidate(input))
    } catch {
      candResult = .failure(error)
    }

    return DifferentialResult(
      input: input,
      referenceOutput: refResult,
      candidateOutput: candResult,
      comparer: comparer
    )
  }

  /// Test and throw if divergence is found
  public func testOrThrow(_ input: Input) async throws {
    let result = await test(input)
    if result.diverges(errorBehavior: errorBehavior) {
      throw DifferentialTestError(result: result)
    }
  }
}
