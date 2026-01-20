import Foundation

/// A type-erased Codable wrapper that supports common primitive types.
/// Uses @unchecked Sendable because the wrapped value is always a Sendable primitive.
struct AnyCodable: Codable, @unchecked Sendable {
  let value: Any

  init<T>(_ value: T) {
    self.value = value
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let string = try? container.decode(String.self) {
      value = string
    } else if let int = try? container.decode(Int.self) {
      value = int
    } else if let double = try? container.decode(Double.self) {
      value = double
    } else if let bool = try? container.decode(Bool.self) {
      value = bool
    } else if let array = try? container.decode([Self].self) {
      value = array.map { $0.value }
    } else if let dict = try? container.decode([String: Self].self) {
      value = dict.mapValues { $0.value }
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported type"
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let string as String:
      try container.encode(string)

    case let int as Int:
      try container.encode(int)

    case let double as Double:
      try container.encode(double)

    case let bool as Bool:
      try container.encode(bool)

    case let array as [Any]:
      try container.encode(array.map { Self($0) })

    case let dict as [String: Any]:
      try container.encode(dict.mapValues { Self($0) })

    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: container.codingPath,
          debugDescription: "Unsupported type"
        )
      )
    }
  }
}
