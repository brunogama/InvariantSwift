// MARK: - ISP-0009: Source Code Analyzer
// Lightweight Swift source code analyzer using regex-based parsing.
// Note: For full accuracy, SwiftSyntax integration is recommended,
// but this regex-based approach works for common patterns.

import Foundation

// MARK: - Source Analyzer

/// Analyzes Swift source files to extract type information.
public actor SourceAnalyzer {

  /// Analyze a single source file.
  public func analyze(filePath: String) async throws -> SourceFileInfo {
    let url = URL(fileURLWithPath: filePath)
    let content = try String(contentsOf: url, encoding: .utf8)

    let hash = computeHash(content)
    let imports = extractImports(from: content)
    let types = extractTypes(from: content, filePath: filePath)

    return SourceFileInfo(
      path: filePath,
      types: types,
      imports: imports,
      hash: hash
    )
  }

  /// Analyze multiple source files.
  public func analyze(filePaths: [String]) async throws -> [SourceFileInfo] {
    var results: [SourceFileInfo] = []

    for path in filePaths {
      do {
        let info = try await analyze(filePath: path)
        results.append(info)
      } catch {
        // Log error but continue with other files
        // swiftlint:disable:next no_print
        print("Warning: Could not analyze \(path): \(error)")
      }
    }

    return results
  }

  // MARK: - Hash Computation

  private func computeHash(_ content: String) -> String {
    // Simple hash for change detection
    var hash = 0
    for char in content.utf8 {
      hash = hash &* 31 &+ Int(char)
    }
    return String(format: "%08x", abs(hash))
  }

  // MARK: - Import Extraction

  private func extractImports(from content: String) -> [String] {
    var imports: [String] = []

    let pattern = #"import\s+(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return imports
    }

    let range = NSRange(content.startIndex..., in: content)
    let matches = regex.matches(in: content, options: [], range: range)

    for match in matches {
      if let importRange = Range(match.range(at: 1), in: content) {
        imports.append(String(content[importRange]))
      }
    }

    return imports
  }

  // MARK: - Type Extraction

  private func extractTypes(from content: String, filePath: String) -> [TypeInfo] {
    var types: [TypeInfo] = []
    let lines = content.components(separatedBy: .newlines)

    // Pattern for type declarations with conformances
    // swiftlint:disable:next line_length
    let typePattern =
      #"(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(struct|class|enum|actor)\s+(\w+)(?:<[^>]+>)?(?:\s*:\s*([^{]+))?\s*\{"#

    guard let regex = try? NSRegularExpression(pattern: typePattern, options: []) else {
      return types
    }

    for (lineIndex, line) in lines.enumerated() {
      let range = NSRange(line.startIndex..., in: line)
      if let match = regex.firstMatch(in: line, options: [], range: range) {
        // Extract type kind
        var kindString = "struct"
        if let kindRange = Range(match.range(at: 2), in: line) {
          kindString = String(line[kindRange])
        }

        // Extract type name
        var typeName = ""
        if let nameRange = Range(match.range(at: 3), in: line) {
          typeName = String(line[nameRange])
        }

        // Extract conformances
        var conformances: [ProtocolConformance] = []
        if let conformanceRange = Range(match.range(at: 4), in: line) {
          let conformanceString = String(line[conformanceRange])
          conformances = parseConformances(conformanceString)
        }

        // Extract generic parameters
        let generics = extractGenericParameters(from: line)

        // Extract the type body to get properties and methods
        let bodyStartLine = lineIndex
        let (properties, methods) = extractMembersFromBody(
          lines: lines,
          startingAt: bodyStartLine
        )

        let typeInfo = TypeInfo(
          name: typeName,
          kind: TypeKind(rawValue: kindString) ?? .structType,
          sourceFile: filePath,
          line: lineIndex + 1,
          conformances: conformances,
          genericParameters: generics,
          properties: properties,
          methods: methods,
          hasFailableInit: checkForFailableInit(lines: lines, startingAt: bodyStartLine),
          hasPublicInit: true
        )

        types.append(typeInfo)
      }
    }

    return types
  }

  // MARK: - Conformance Parsing

  private func parseConformances(_ conformanceString: String) -> [ProtocolConformance] {
    var conformances: [ProtocolConformance] = []

    let protocols = conformanceString.split(separator: ",").map {
      $0.trimmingCharacters(in: .whitespaces)
    }

    for proto in protocols {
      // Handle protocols with generic parameters like Collection<Element>
      let cleanProto = proto.split(separator: "<").first.map(String.init) ?? proto

      if let conformance = ProtocolConformance(rawValue: cleanProto) {
        conformances.append(conformance)
      }
    }

    return conformances
  }

  // MARK: - Generic Parameter Extraction

  private func extractGenericParameters(from line: String) -> [String] {
    let pattern = #"<([^>]+)>"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return []
    }

    let range = NSRange(line.startIndex..., in: line)
    if let match = regex.firstMatch(in: line, options: [], range: range),
      let genericRange = Range(match.range(at: 1), in: line)
    {
      let genericsString = String(line[genericRange])
      return genericsString.split(separator: ",").map {
        $0.trimmingCharacters(in: .whitespaces)
          .split(separator: ":").first.map(String.init) ?? ""
      }.filter { !$0.isEmpty }
    }

    return []
  }

  // MARK: - Member Extraction

  private func extractMembersFromBody(
    lines: [String],
    startingAt startLine: Int
  ) -> (properties: [PropertyInfo], methods: [MethodInfo]) {
    var properties: [PropertyInfo] = []
    var methods: [MethodInfo] = []

    var braceCount = 0
    var foundOpeningBrace = false

    for lineIndex in startLine..<min(startLine + 100, lines.count) {
      let line = lines[lineIndex]

      // Track brace depth
      for char in line {
        if char == "{" {
          braceCount += 1
          foundOpeningBrace = true
        } else if char == "}" {
          braceCount -= 1
        }
      }

      // Stop if we've closed the type body
      if foundOpeningBrace && braceCount == 0 {
        break
      }

      // Only look at lines inside the type body
      guard foundOpeningBrace && braceCount > 0 else { continue }

      // Extract properties
      if let property = extractProperty(from: line) {
        properties.append(property)
      }

      // Extract methods
      if let method = extractMethod(from: line) {
        methods.append(method)
      }
    }

    return (properties, methods)
  }

  private func extractProperty(from line: String) -> PropertyInfo? {
    let pattern = #"(let|var)\s+(\w+)\s*:\s*(\S+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return nil
    }

    let range = NSRange(line.startIndex..., in: line)
    if let match = regex.firstMatch(in: line, options: [], range: range) {
      var isMutable = false
      if let mutRange = Range(match.range(at: 1), in: line) {
        isMutable = String(line[mutRange]) == "var"
      }

      var name = ""
      if let nameRange = Range(match.range(at: 2), in: line) {
        name = String(line[nameRange])
      }

      var typeName = ""
      if let typeRange = Range(match.range(at: 3), in: line) {
        typeName = String(line[typeRange])
      }

      let isOptional = typeName.hasSuffix("?") || typeName.hasPrefix("Optional<")
      let hasDefault = line.contains("=")

      return PropertyInfo(
        name: name,
        typeName: typeName,
        isOptional: isOptional,
        isMutable: isMutable,
        hasDefaultValue: hasDefault
      )
    }

    return nil
  }

  private func extractMethod(from line: String) -> MethodInfo? {
    let pattern = #"func\s+(\w+)\s*\([^)]*\)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return nil
    }

    let range = NSRange(line.startIndex..., in: line)
    if let match = regex.firstMatch(in: line, options: [], range: range) {
      var name = ""
      if let nameRange = Range(match.range(at: 1), in: line) {
        name = String(line[nameRange])
      }

      let isStatic = line.contains("static ") || line.contains("class ")
      let isMutating = line.contains("mutating ")
      let isThrowing = line.contains(" throws") || line.contains(" rethrows")
      let isAsync = line.contains(" async")

      // Extract return type
      var returnType: String?
      if let arrowIndex = line.range(of: "->") {
        let afterArrow = line[arrowIndex.upperBound...]
        let cleaned = afterArrow.trimmingCharacters(in: .whitespaces)
        if let braceIndex = cleaned.firstIndex(of: "{") {
          returnType = String(cleaned[..<braceIndex]).trimmingCharacters(in: .whitespaces)
        } else {
          returnType = String(cleaned)
        }
      }

      return MethodInfo(
        name: name,
        parameters: [],
        returnType: returnType,
        isStatic: isStatic,
        isMutating: isMutating,
        isThrowing: isThrowing,
        isAsync: isAsync
      )
    }

    return nil
  }

  private func checkForFailableInit(lines: [String], startingAt startLine: Int) -> Bool {
    for lineIndex in startLine..<min(startLine + 50, lines.count) {
      // swiftlint:disable:next for_where
      if lines[lineIndex].contains("init?") {
        return true
      }
    }
    return false
  }
}

// MARK: - File Discovery

/// Discovers Swift source files in directories.
public struct FileDiscovery: Sendable {

  /// Find all Swift files in a directory recursively.
  public static func findSwiftFiles(
    in directory: String,
    excluding patterns: [String] = []
  ) throws -> [String] {
    let url = URL(fileURLWithPath: directory)
    var files: [String] = []

    let fileManager = FileManager.default
    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      throw GhostwriterError.fileNotFound(directory)
    }

    while let fileURL = enumerator.nextObject() as? URL {
      guard fileURL.pathExtension == "swift" else { continue }

      let path = fileURL.path

      // Check exclusion patterns
      let shouldExclude = patterns.contains { pattern in
        path.contains(pattern.replacingOccurrences(of: "**/", with: ""))
      }

      if !shouldExclude {
        files.append(path)
      }
    }

    return files
  }

  /// Find all Swift files matching the sources configuration.
  public static func findFiles(for config: GhostwriterConfig) throws -> [String] {
    var allFiles: [String] = []

    for source in config.sources {
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: source, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
          let files = try findSwiftFiles(in: source, excluding: config.excludePatterns)
          allFiles.append(contentsOf: files)
        } else if source.hasSuffix(".swift") {
          allFiles.append(source)
        }
      }
    }

    return allFiles
  }
}
