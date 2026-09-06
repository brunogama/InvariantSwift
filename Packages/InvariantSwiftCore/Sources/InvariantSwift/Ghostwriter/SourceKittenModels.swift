/// Maps SourceKitten protocol names to known conformances.
public enum ProtocolConformanceMapper {
  /// Maps one protocol name when supported.
  public static func map(
    _ protocolName: String
  ) -> ProtocolConformance? {
    mappings[protocolName]
  }

  /// Maps all supported protocol names.
  public static func mapAll(
    _ protocolNames: [String]
  ) -> [ProtocolConformance] {
    protocolNames.compactMap(map)
  }

  private static let mappings: [String: ProtocolConformance] = [
    "Equatable": .equatable,
    "Hashable": .hashable,
    "Comparable": .comparable,
    "Codable": .codable,
    "Encodable": .codable,
    "Decodable": .codable,
    "Sendable": .sendable,
    "Collection": .collection,
    "Sequence": .collection,
    "RandomAccessCollection": .collection,
    "Identifiable": .identifiable,
  ]
}
