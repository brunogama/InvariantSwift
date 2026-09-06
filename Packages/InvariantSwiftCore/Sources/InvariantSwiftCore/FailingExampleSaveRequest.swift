import Foundation

/// Optional values used when saving a failing input.
public struct FailingExampleSaveOptions: Sendable {
  public let shrinkPath: [Int]
  public let input: (any Codable & Sendable)?
  public let inputDescription: String?

  public init(
    shrinkPath: [Int] = [],
    input: (any Codable & Sendable)? = nil,
    inputDescription: String? = nil
  ) {
    self.shrinkPath = shrinkPath
    self.input = input
    self.inputDescription = inputDescription
  }
}

/// Request to persist a property-test failure.
public struct FailingExampleSaveRequest: Sendable {
  public let testID: TestIdentifier
  public let failure: FailingExampleFailure
  public let options: FailingExampleSaveOptions

  public init(
    testID: TestIdentifier,
    failure: FailingExampleFailure,
    options: FailingExampleSaveOptions = .init()
  ) {
    self.testID = testID
    self.failure = failure
    self.options = options
  }
}

extension FailingExampleDatabase {
  /// Saves a failure and its reproduction metadata.
  public func saveFailure(_ request: FailingExampleSaveRequest) async {
    let context = FailingExampleContext(
      shrinkPath: request.options.shrinkPath,
      serializedInput: serialize(request.options.input),
      inputDescription: request.options.inputDescription
    )
    let example = FailingExample(failure: request.failure, context: context)
    await save(testID: request.testID, example: example)
  }

  private func serialize(_ input: (any Codable & Sendable)?) -> Data? {
    guard let input else { return nil }
    return try? JSONEncoder().encode(AnyEncodable(input))
  }
}

private struct AnyEncodable: Encodable {
  private let encodeValue: (Encoder) throws -> Void

  init<Value: Encodable>(_ value: Value) {
    encodeValue = value.encode(to:)
  }

  func encode(to encoder: Encoder) throws {
    try encodeValue(encoder)
  }
}
