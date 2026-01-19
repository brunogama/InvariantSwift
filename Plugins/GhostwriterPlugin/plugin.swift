import Foundation
import PackagePlugin

// MARK: - Ghostwriter Plugin

/// **Ghostwriter Plugin for Automatic Property Test Generation**
///
/// This plugin analyzes Swift source files and generates property tests
/// based on detected patterns (Codable, Equatable, Hashable, Comparable).
///
/// **Usage:**
/// ```bash
/// swift package ghostwrite Sources/Models/
/// swift package ghostwrite --source Sources/User.swift --verbose
/// swift package ghostwrite --dry-run
/// ```
///
/// **Features:**
/// - Analyzes Swift source code for testable patterns
/// - Generates @PropertyTest functions automatically
/// - Supports Codable roundtrip, Equatable laws, Hashable consistency
/// - Dry-run mode for previewing without writing

@main
struct GhostwriterPlugin: CommandPlugin {

  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let packageDirectoryURL = context.package.directoryURL

    // Parse arguments
    let config = parseConfig(from: arguments, packageDirectory: packageDirectoryURL.path)

    print("✨ Ghostwriter: Automatic Property Test Generation")
    print("=" * 60)

    if config.verbose {
      print("📋 Configuration:")
      print("   • Sources: \(config.sources.joined(separator: ", "))")
      print("   • Output: \(config.outputDirectory)")
      print("   • Dry Run: \(config.dryRun)")
      print()
    }

    // Run the ghostwriter
    let result = try await runGhostwriter(config: config, verbose: config.verbose)

    // Print summary
    print("\n" + "=" * 60)
    print("📊 Ghostwriter Summary:")
    print("   • Files Analyzed: \(result.analyzedCount)")
    print("   • Types Discovered: \(result.typeCount)")
    print("   • Tests Generated: \(result.testCount)")

    if config.dryRun {
      print("\n📝 Dry run complete. No files were written.")
    } else if result.testCount > 0 {
      print("\n✅ Tests generated successfully!")
      print("   Output: \(config.outputDirectory)")
    } else {
      print("\n⚠️  No tests generated. Make sure types conform to testable protocols.")
    }
  }

  // MARK: - Configuration Parsing

  private func parseConfig(from arguments: [String], packageDirectory: String) -> GhostwriteConfig {
    var sources: [String] = []
    var outputDirectory = "\(packageDirectory)/Tests/Generated/"
    var dryRun = false
    var verbose = false
    var patterns: [String] = []
    var excludePatterns: [String] = []

    var i = 0
    while i < arguments.count {
      let arg = arguments[i]

      switch arg {
      case "--source", "-s":
        if i + 1 < arguments.count {
          let source = arguments[i + 1]
          // Make relative paths absolute
          if source.hasPrefix("/") {
            sources.append(source)
          } else {
            sources.append("\(packageDirectory)/\(source)")
          }
          i += 1
        }

      case "--output", "-o":
        if i + 1 < arguments.count {
          let output = arguments[i + 1]
          if output.hasPrefix("/") {
            outputDirectory = output
          } else {
            outputDirectory = "\(packageDirectory)/\(output)"
          }
          i += 1
        }

      case "--patterns", "-p":
        if i + 1 < arguments.count {
          patterns = arguments[i + 1].split(separator: ",").map(String.init)
          i += 1
        }

      case "--exclude", "-e":
        if i + 1 < arguments.count {
          excludePatterns.append(arguments[i + 1])
          i += 1
        }

      case "--dry-run":
        dryRun = true

      case "--verbose", "-v":
        verbose = true

      case "--help", "-h":
        printHelp()
        Foundation.exit(0)

      default:
        // Treat as source if it looks like a path
        if !arg.hasPrefix("-") {
          if arg.hasPrefix("/") {
            sources.append(arg)
          } else {
            sources.append("\(packageDirectory)/\(arg)")
          }
        }
      }

      i += 1
    }

    // Default to Sources/ if no sources specified
    if sources.isEmpty {
      sources = ["\(packageDirectory)/Sources/"]
    }

    return GhostwriteConfig(
      sources: sources,
      outputDirectory: outputDirectory,
      patterns: patterns,
      excludePatterns: excludePatterns,
      dryRun: dryRun,
      verbose: verbose,
      supportedArbitraryTypes: GhostwriteConfig.defaultArbitraryTypes
    )
  }

  private func printHelp() {
    print(
      """
      Ghostwriter - Automatic Property Test Generation

      USAGE:
          swift package ghostwrite [options] [sources...]

      OPTIONS:
          --source, -s <path>     Source file or directory to analyze
          --output, -o <path>     Output directory (default: Tests/Generated/)
          --patterns, -p <list>   Comma-separated patterns to generate
          --exclude, -e <pattern> Exclude files matching pattern
          --dry-run               Preview without writing files
          --verbose, -v           Enable verbose output
          --help, -h              Show this help

      PATTERNS:
          codable_roundtrip       Codable encode/decode roundtrip
          equatable_reflexive     Equatable: x == x
          equatable_symmetric     Equatable: x == y implies y == x
          equatable_transitive    Equatable: transitive equality
          hashable_consistency    Hashable: equal values have equal hashes
          comparable_*            Comparable ordering laws

      EXAMPLES:
          swift package ghostwrite Sources/Models/
          swift package ghostwrite --source Sources/User.swift --verbose
          swift package ghostwrite --dry-run
      """
    )
  }

  // MARK: - Ghostwriter Execution

  private func runGhostwriter(
    config: GhostwriteConfig,
    verbose: Bool
  ) async throws -> GhostwriteResult {
    var analyzedCount = 0
    var typeCount = 0
    var testCount = 0
    var generatedFiles: [String] = []

    // Find Swift files
    let files = try findSwiftFiles(in: config.sources, excluding: config.excludePatterns)
    analyzedCount = files.count

    if verbose {
      print("📂 Found \(files.count) Swift file(s) to analyze")
    }

    // Analyze each file
    var allTypes: [ExtractedType] = []

    for file in files {
      let types = try analyzeFile(at: file)
      allTypes.append(contentsOf: types)

      if verbose && !types.isEmpty {
        print("  📄 \(file): \(types.count) type(s)")
      }
    }

    typeCount = allTypes.count
    let testableTypes = allTypes.filter { !$0.applicablePatterns.isEmpty }

    if verbose {
      print("🔍 Found \(typeCount) type(s), \(testableTypes.count) testable")
    }

    // Group types by source file for generation
    // Filter to only types with known Arbitrary generators
    let supportedTypes = testableTypes.filter { type in
      config.supportedArbitraryTypes.contains(type.name)
    }

    if verbose && supportedTypes.count < testableTypes.count {
      let skipped = testableTypes.count - supportedTypes.count
      print("⚠️ Skipped \(skipped) type(s) without Arbitrary generators")
    }

    var typesByFile: [String: [ExtractedType]] = [:]
    for type in supportedTypes {
      typesByFile[type.sourceFile, default: []].append(type)
    }

    // Generate tests
    for (sourceFile, types) in typesByFile {
      let testCode = generateTestFile(for: types, sourceFile: sourceFile)
      let testsInFile = types.reduce(0) { $0 + $1.applicablePatterns.count }
      testCount += testsInFile

      if config.dryRun {
        if verbose {
          print("\n📝 Would generate for \(sourceFile):")
          print(testCode.prefix(500))
          if testCode.count > 500 {
            print("... (truncated)")
          }
        }
      } else {
        let outputFile = try writeTestFile(
          testCode,
          sourceFile: sourceFile,
          outputDirectory: config.outputDirectory
        )
        generatedFiles.append(outputFile)

        if verbose {
          print("  💾 Wrote \(outputFile)")
        }
      }
    }

    return GhostwriteResult(
      analyzedCount: analyzedCount,
      typeCount: typeCount,
      testCount: testCount,
      generatedFiles: generatedFiles
    )
  }

  // MARK: - File Discovery

  private func findSwiftFiles(
    in sources: [String],
    excluding patterns: [String]
  ) throws -> [String] {
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

            let fullPath = "\(source)/\(file)"

            // Check exclusions
            let shouldExclude = patterns.contains { pattern in
              fullPath.contains(pattern.replacingOccurrences(of: "**/", with: ""))
            }

            if !shouldExclude {
              files.append(fullPath)
            }
          }
        }
      } else if source.hasSuffix(".swift") {
        files.append(source)
      }
    }

    return files
  }

  // MARK: - Source Analysis

  private func analyzeFile(at path: String) throws -> [ExtractedType] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    return extractTypes(from: content, filePath: path)
  }

  private func extractTypes(from content: String, filePath: String) -> [ExtractedType] {
    var types: [ExtractedType] = []
    let lines = content.components(separatedBy: .newlines)

    // Pattern for type declarations with conformances
    // swiftlint:disable:next line_length
    let pattern =
      #"(public\s+|private\s+|internal\s+|fileprivate\s+|open\s+)?(struct|class|enum|actor)\s+(\w+)(?:<[^>]+>)?(?:\s*:\s*([^{]+))?\s*\{"#

    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return types
    }

    for (lineIndex, line) in lines.enumerated() {
      let range = NSRange(line.startIndex..., in: line)
      if let match = regex.firstMatch(in: line, options: [], range: range) {
        var typeName = ""
        if let nameRange = Range(match.range(at: 3), in: line) {
          typeName = String(line[nameRange])
        }

        var conformances: [String] = []
        if let conformanceRange = Range(match.range(at: 4), in: line) {
          let conformanceString = String(line[conformanceRange])
          conformances = conformanceString.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
              .split(separator: "<").first.map(String.init) ?? ""
          }
        }

        let patterns = detectPatterns(from: conformances)

        let typeInfo = ExtractedType(
          name: typeName,
          sourceFile: filePath,
          line: lineIndex + 1,
          conformances: conformances,
          applicablePatterns: patterns
        )

        types.append(typeInfo)
      }
    }

    return types
  }

  private func detectPatterns(from conformances: [String]) -> [TestPatternType] {
    var patterns: [TestPatternType] = []

    for conformance in conformances {
      switch conformance {
      case "Codable":
        // Codable roundtrip only - don't assume Equatable
        // The roundtrip test requires Equatable but we only generate it
        // if the type is also explicitly Equatable
        if conformances.contains("Equatable") || conformances.contains("Hashable") {
          patterns.append(.codableRoundtrip)
        }
      case "Equatable":
        patterns.append(contentsOf: TestPatternType.equatableLaws)
      case "Hashable":
        patterns.append(.hashableConsistency)
        patterns.append(contentsOf: TestPatternType.equatableLaws)
      case "Comparable":
        patterns.append(contentsOf: TestPatternType.comparableLaws)
      default:
        break
      }
    }

    return Array(Set(patterns))
  }

  // MARK: - Test Generation

  private func generateTestFile(for types: [ExtractedType], sourceFile: String) -> String {
    var lines: [String] = []

    let fileName =
      URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent

    lines.append("// Generated by InvariantSwift Ghostwriter Plugin")
    lines.append("// Source: \(sourceFile)")
    lines.append("// Generated: \(ISO8601DateFormatter().string(from: Date()))")
    lines.append("//")
    lines.append("// DO NOT EDIT - Regenerate with: swift package ghostwrite")
    lines.append("")
    lines.append("import Testing")
    lines.append("import Foundation")
    lines.append("@testable import InvariantSwift")
    lines.append("")
    lines.append("// MARK: - \(fileName) Property Tests")
    lines.append("")

    for type in types {
      lines.append("// MARK: - \(type.name)")
      lines.append("")

      for pattern in type.applicablePatterns {
        let testCode = generateTest(for: type, pattern: pattern)
        lines.append(testCode)
        lines.append("")
      }
    }

    return lines.joined(separator: "\n")
  }

  private func generateTest(for type: ExtractedType, pattern: TestPatternType) -> String {
    let typeName = type.name

    switch pattern {
    case .codableRoundtrip:
      return """
        /// Codable roundtrip: encoding and decoding preserves value.
        @PropertyTest
        func test\(typeName)_codableRoundtrip(value: \(typeName)) throws {
          let encoded = try JSONEncoder().encode(value)
          let decoded = try JSONDecoder().decode(\(typeName).self, from: encoded)
          #expect(decoded == value, "Codable roundtrip should preserve value")
        }
        """

    case .equatableReflexive:
      return """
        /// Equatable reflexivity: x == x for all x.
        @PropertyTest
        func test\(typeName)_equatableReflexive(value: \(typeName)) {
          #expect(value == value, "Reflexivity: x == x")
        }
        """

    case .equatableSymmetric:
      return """
        /// Equatable symmetry: x == y implies y == x.
        @PropertyTest
        func test\(typeName)_equatableSymmetric(a: \(typeName), b: \(typeName)) {
          if a == b {
            #expect(b == a, "Symmetry: a == b implies b == a")
          }
        }
        """

    case .equatableTransitive:
      return """
        /// Equatable transitivity: x == y && y == z implies x == z.
        @PropertyTest
        func test\(typeName)_equatableTransitive(a: \(typeName), b: \(typeName), c: \(typeName)) {
          if a == b && b == c {
            #expect(a == c, "Transitivity: a == b && b == c implies a == c")
          }
        }
        """

    case .hashableConsistency:
      return """
        /// Hashable consistency: equal values must have equal hash values.
        @PropertyTest
        func test\(typeName)_hashableConsistency(a: \(typeName), b: \(typeName)) {
          if a == b {
            #expect(a.hashValue == b.hashValue, "Equal values must have equal hash values")
          }
        }
        """

    case .comparableIrreflexive:
      return """
        /// Comparable irreflexivity: !(x < x) for all x.
        @PropertyTest
        func test\(typeName)_comparableIrreflexive(value: \(typeName)) {
          #expect(!(value < value), "Irreflexivity: !(x < x)")
        }
        """

    case .comparableAsymmetric:
      return """
        /// Comparable asymmetry: x < y implies !(y < x).
        @PropertyTest
        func test\(typeName)_comparableAsymmetric(a: \(typeName), b: \(typeName)) {
          if a < b {
            #expect(!(b < a), "Asymmetry: a < b implies !(b < a)")
          }
        }
        """

    case .comparableTransitive:
      return """
        /// Comparable transitivity: x < y && y < z implies x < z.
        @PropertyTest
        func test\(typeName)_comparableTransitive(a: \(typeName), b: \(typeName), c: \(typeName)) {
          if a < b && b < c {
            #expect(a < c, "Transitivity: a < b && b < c implies a < c")
          }
        }
        """

    case .comparableTrichotomy:
      return """
        /// Comparable trichotomy: exactly one of <, ==, > holds.
        @PropertyTest
        func test\(typeName)_comparableTrichotomy(a: \(typeName), b: \(typeName)) {
          let isLess = a < b
          let isEqual = a == b
          let isGreater = b < a
          let exactlyOne = [isLess, isEqual, isGreater].filter { $0 }.count == 1
          #expect(exactlyOne, "Trichotomy: exactly one of <, ==, > holds")
        }
        """
    }
  }

  // MARK: - File Writing

  private func writeTestFile(
    _ content: String,
    sourceFile: String,
    outputDirectory: String
  ) throws -> String {
    let fileName =
      URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
    let outputFileName = "\(fileName)PropertyTests.swift"
    let outputPath = "\(outputDirectory)/\(outputFileName)"

    // Create directory if needed
    try FileManager.default.createDirectory(
      atPath: outputDirectory,
      withIntermediateDirectories: true
    )

    try content.write(toFile: outputPath, atomically: true, encoding: .utf8)

    return outputPath
  }
}

// MARK: - Configuration Types

private struct GhostwriteConfig {
  let sources: [String]
  let outputDirectory: String
  let patterns: [String]
  let excludePatterns: [String]
  let dryRun: Bool
  let verbose: Bool
  let supportedArbitraryTypes: Set<String>

  /// Default set of types with known Arbitrary generators
  static let defaultArbitraryTypes: Set<String> = [
    // Primitives
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    // Core InvariantSwift types
    "Seed", "Size",
    // Ghostwriter types
    "GeneratedTest", "GhostwriterManifest", "TestPattern",
    "ProtocolConformance", "TypeKind", "PropertyInfo",
    "MethodInfo", "TypeInfo", "SourceFileInfo",
  ]
}

private struct GhostwriteResult {
  let analyzedCount: Int
  let typeCount: Int
  let testCount: Int
  let generatedFiles: [String]
}

private struct ExtractedType: Hashable {
  let name: String
  let sourceFile: String
  let line: Int
  let conformances: [String]
  let applicablePatterns: [TestPatternType]

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(sourceFile)
    hasher.combine(line)
  }

  static func == (lhs: ExtractedType, rhs: ExtractedType) -> Bool {
    lhs.name == rhs.name && lhs.sourceFile == rhs.sourceFile && lhs.line == rhs.line
  }
}

private enum TestPatternType: String, Hashable {
  case codableRoundtrip
  case equatableReflexive
  case equatableSymmetric
  case equatableTransitive
  case hashableConsistency
  case comparableIrreflexive
  case comparableAsymmetric
  case comparableTransitive
  case comparableTrichotomy

  static var equatableLaws: [TestPatternType] {
    [.equatableReflexive, .equatableSymmetric, .equatableTransitive]
  }

  static var comparableLaws: [TestPatternType] {
    [.comparableIrreflexive, .comparableAsymmetric, .comparableTransitive, .comparableTrichotomy]
  }
}

// MARK: - String Extension

extension String {
  static func * (string: String, count: Int) -> String {
    String(repeating: string, count: count)
  }
}
