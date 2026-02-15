// MARK: - GhostwriterCLI File Utilities
// File discovery and writing utilities.

import Foundation

extension GhostwriterCLI {
  /// Find all Swift files in the given source paths.
  static func findSwiftFiles(in sources: [String]) throws -> [String] {
    var files: [String] = []
    let fileManager = FileManager.default

    for source in sources {
      var isDirectory: ObjCBool = false
      guard fileManager.fileExists(atPath: source, isDirectory: &isDirectory) else {
        continue
      }

      if isDirectory.boolValue {
        if let enumerator = fileManager.enumerator(atPath: source) {
          while let file = enumerator.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            files.append("\(source)/\(file)")
          }
        }
      } else if source.hasSuffix(".swift") {
        files.append(source)
      }
    }

    return files
  }

  /// Write generated test code to a file.
  static func writeTestFile(
    _ content: String,
    sourceFile: String,
    outputDirectory: String
  ) throws -> String {
    let fileName = URL(fileURLWithPath: sourceFile)
      .deletingPathExtension()
      .lastPathComponent
    let outputFileName = "\(fileName)PropertyTests.swift"
    let outputPath = "\(outputDirectory)/\(outputFileName)"

    try FileManager.default.createDirectory(
      atPath: outputDirectory,
      withIntermediateDirectories: true
    )

    try content.write(toFile: outputPath, atomically: true, encoding: .utf8)
    return outputPath
  }
}
