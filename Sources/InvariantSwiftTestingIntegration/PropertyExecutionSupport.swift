import Foundation
import InvariantSwift
import InvariantSwiftCore
import Testing

public extension Tag {
  static var invariantSwiftPropertyBased: Self {
    Self.__fromStaticMember(of: Self.self, "invariantSwiftPropertyBased")
  }

  static var invariantSwiftPropertyReplay: Self {
    Self.__fromStaticMember(of: Self.self, "invariantSwiftPropertyReplay")
  }
}

public enum InvariantSwiftTestingTags {
  public static var propertyBased: Tag {
    .invariantSwiftPropertyBased
  }

  public static var propertyReplay: Tag {
    .invariantSwiftPropertyReplay
  }
}

public struct PropertyTestContext: Sendable {
  @TaskLocal public static var current: Self?

  public let testName: String
  public let seed: UInt64?
  public let config: PropertyConfig?
  public let labels: [String]
  public let isReplay: Bool
  public let replayFailureID: UUID?

  public init(
    testName: String,
    seed: UInt64?,
    config: PropertyConfig?,
    labels: [String],
    isReplay: Bool,
    replayFailureID: UUID?
  ) {
    self.testName = testName
    self.seed = seed
    self.config = config
    self.labels = labels
    self.isReplay = isReplay
    self.replayFailureID = replayFailureID
  }
}

public struct InvariantSwiftPropertyExecutionTrait: TestTrait, TestScoping {
  public typealias TestScopeProvider = Self

  public let testName: String
  public let labels: [String]
  public let configuredSeed: UInt64?

  public init(testName: String, labels: [String] = [], configuredSeed: UInt64? = nil) {
    self.testName = testName
    self.labels = labels
    self.configuredSeed = configuredSeed
  }

  public var comments: [Comment] { [] }

  public func prepare(for test: Test) async throws {}

  public func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    let context = PropertyTestContext(
      testName: test.displayName ?? test.name,
      seed: configuredSeed,
      config: nil,
      labels: labels,
      isReplay: false,
      replayFailureID: nil
    )
    try await PropertyTestContext.$current.withValue(context) {
      try await function()
    }
  }
}

public func executeGeneratedPropertyTest<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig,
  testName: String,
  labels: [String],
  persistFailures: Bool = false,
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let actualSeed = config.seed ?? Seed.random
  let executionConfig = config.withExecutionSeed(actualSeed)
  let context = PropertyTestContext(
    testName: testName,
    seed: actualSeed.rawValue,
    config: executionConfig,
    labels: labels,
    isReplay: false,
    replayFailureID: nil
  )
  let result = PropertyTestContext.$current.withValue(context) {
    runPropertySynchronously(property, config: executionConfig)
  }

  handleGeneratedPropertyResult(
    result,
    testName: testName,
    persistFailures: persistFailures,
    context: PropertyIssueContext(labels: labels, file: file, line: line)
  )
}

public func executeGeneratedPropertyTestAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig,
  testName: String,
  labels: [String],
  timeoutSeconds: Double? = nil,
  persistFailures: Bool = false,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let actualSeed = config.seed ?? Seed.random
  let executionConfig = config.withExecutionSeed(actualSeed)
  let context = PropertyTestContext(
    testName: testName,
    seed: actualSeed.rawValue,
    config: executionConfig,
    labels: labels,
    isReplay: false,
    replayFailureID: nil
  )

  let result = try await PropertyTestContext.$current.withValue(context) {
    if let timeoutSeconds {
      return try await withPropertyTimeout(seconds: timeoutSeconds) {
        await runPropertyAsync(property, config: executionConfig)
      }
    }

    return await runPropertyAsync(property, config: executionConfig)
  }

  handleGeneratedPropertyResult(
    result,
    testName: testName,
    persistFailures: persistFailures,
    context: PropertyIssueContext(labels: labels, file: file, line: line)
  )
}

// swiftlint:disable:next function_parameter_count
public func executePersistedFailureReplay<T: Sendable>(
  _ property: Property<T>,
  baseConfig: PropertyConfig,
  persistedFailure: PersistedFailure,
  testName: String,
  labels: [String],
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let replayConfig = baseConfig.replayConfiguration(for: persistedFailure)
  let context = PropertyTestContext(
    testName: testName,
    seed: persistedFailure.seed,
    config: replayConfig,
    labels: labels,
    isReplay: true,
    replayFailureID: persistedFailure.id
  )
  let result = PropertyTestContext.$current.withValue(context) {
    runPropertySynchronously(property, config: replayConfig)
  }

  verifyPersistedReplay(
    result,
    expectedFailure: persistedFailure,
    testName: testName,
    context: PropertyIssueContext(
      labels: labels,
      file: file,
      line: line,
      replayFailureID: persistedFailure.id
    )
  )
}

// swiftlint:disable:next function_parameter_count
public func executePersistedFailureReplayAsync<T: Sendable>(
  _ property: Property<T>,
  baseConfig: PropertyConfig,
  persistedFailure: PersistedFailure,
  testName: String,
  labels: [String],
  timeoutSeconds: Double? = nil,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let replayConfig = baseConfig.replayConfiguration(for: persistedFailure)
  let context = PropertyTestContext(
    testName: testName,
    seed: persistedFailure.seed,
    config: replayConfig,
    labels: labels,
    isReplay: true,
    replayFailureID: persistedFailure.id
  )

  let result = try await PropertyTestContext.$current.withValue(context) {
    if let timeoutSeconds {
      return try await withPropertyTimeout(seconds: timeoutSeconds) {
        await runPropertyAsync(property, config: replayConfig)
      }
    }

    return await runPropertyAsync(property, config: replayConfig)
  }

  verifyPersistedReplay(
    result,
    expectedFailure: persistedFailure,
    testName: testName,
    context: PropertyIssueContext(
      labels: labels,
      file: file,
      line: line,
      replayFailureID: persistedFailure.id
    )
  )
}
