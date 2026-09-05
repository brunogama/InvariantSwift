import Foundation

/// Resolves a fixture path against the directory of the declaring source
/// file when relative, or uses the absolute path unchanged.
func resolveSnapshotDirectory(
  _ path: String,
  sourceFile: String
) -> URL {
  guard !path.hasPrefix("/") else {
    return URL(fileURLWithPath: path, isDirectory: true)
  }
  return URL(
    fileURLWithPath: path,
    isDirectory: true,
    relativeTo: URL(fileURLWithPath: sourceFile).deletingLastPathComponent()
  )
}

/// Prepares a snapshot directory for recording by removing stale snapshots
/// that share the test's identifier prefix.
func prepareSnapshotDirectory(
  _ directory: URL,
  testName: String
) throws {
  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
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

/// Loads the checked-in snapshots for a characterization test, if any.
func loadSnapshots<Input, Observation>(
  from directory: URL,
  testName: String
) throws -> [CharacterizationCase<Input, Observation>]
where
  Input: Codable & Sendable,
  Observation: Codable & Sendable
{
  guard FileManager.default.fileExists(atPath: directory.path) else {
    return []
  }
  let prefix = "\(snapshotIdentifier(testName))."
  let contents = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil
  )
  let urls =
    contents
    .filter {
      $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "json"
    }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
  return try urls.map { try loadCase(from: $0) }
}

/// Decodes one checked-in characterization case from disk.
func loadCase<Input, Observation>(
  from url: URL
) throws -> CharacterizationCase<Input, Observation>
where Input: Codable & Sendable, Observation: Codable & Sendable {
  try JSONDecoder().decode(
    CharacterizationCase<Input, Observation>.self,
    from: Data(contentsOf: url)
  )
}

/// Turns a test name into the stable file-name prefix snapshots share.
func snapshotIdentifier(_ value: String) -> String {
  value
    .replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
    .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
}
