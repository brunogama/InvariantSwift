// MARK: - Ghostwriter CLI
// Command-line interface for accurate source analysis and test generation.

import Foundation
import SwiftParser
import SwiftSyntax

@main
struct GhostwriterCLI {

  static func main() async throws {
    let arguments = CommandLine.arguments

    // Parse arguments
    let config = parseArguments(arguments)

    if config.showHelp {
      printHelp()
      return
    }

    print("✨ Ghostwriter CLI - SwiftSyntax-Powered Test Generation")
    print(String(repeating: "=", count: 60))

    if config.verbose {
      print("📋 Configuration:")
      print("   • Sources: \(config.sources.joined(separator: ", "))")
      print("   • Output: \(config.outputDirectory)")
      print("   • Dry Run: \(config.dryRun)")
      print()
    }

    // Run analysis
    let result = try await run(config: config)

    // Print summary
    print()
    print(String(repeating: "=", count: 60))
    print("📊 Summary:")
    print("   • Files Analyzed: \(result.filesAnalyzed)")
    print("   • Types Found: \(result.typesFound)")
    print("   • Testable Types: \(result.testableTypes)")
    print("   • Tests Generated: \(result.testsGenerated)")

    if result.skippedCompile > 0 {
      print("\n⚠️  Skipped \(result.skippedCompile) file(s) due to compilation errors")
      print("   Run with --verbose to see details or --skip-compile-test to write anyway")
    }

    if config.dryRun {
      print("\n📝 Dry run complete. No files were written.")
    } else if result.testsGenerated > 0 {
      print("\n✅ Tests generated successfully!")
      print("   Output: \(config.outputDirectory)")
    } else {
      print("\n⚠️  No tests generated.")
      print("   Ensure types conform to Codable, Equatable, Hashable, or Comparable.")
    }
  }

  // MARK: - Argument Parsing

  struct Config {
    var sources: [String] = []
    var outputDirectory: String = "Tests/Generated/"
    var dryRun: Bool = false
    var verbose: Bool = false
    var showHelp: Bool = false
    var includeInternal: Bool = false
    var skipCompileTest: Bool = false
  }

  static func parseArguments(_ arguments: [String]) -> Config {
    var config = Config()
    var i = 1  // Skip program name

    while i < arguments.count {
      let arg = arguments[i]

      switch arg {
      case "--source", "-s":
        if i + 1 < arguments.count {
          config.sources.append(arguments[i + 1])
          i += 1
        }
      case "--output", "-o":
        if i + 1 < arguments.count {
          config.outputDirectory = arguments[i + 1]
          i += 1
        }
      case "--dry-run":
        config.dryRun = true
      case "--verbose", "-v":
        config.verbose = true
      case "--help", "-h":
        config.showHelp = true
      case "--include-internal":
        config.includeInternal = true
      case "--skip-compile-test":
        config.skipCompileTest = true
      default:
        if !arg.hasPrefix("-") {
          config.sources.append(arg)
        }
      }

      i += 1
    }

    // Default to current directory if no sources
    if config.sources.isEmpty {
      config.sources = ["Sources/"]
    }

    return config
  }

  static func printHelp() {
    print(
      """
      Ghostwriter CLI - SwiftSyntax-Powered Test Generation

      USAGE:
          GhostwriterCLI [options] [sources...]

      OPTIONS:
          --source, -s <path>     Source file or directory to analyze
          --output, -o <path>     Output directory (default: Tests/Generated/)
          --dry-run               Preview without writing files
          --verbose, -v           Enable verbose output
          --include-internal      Include internal types (default: only public/open)
          --skip-compile-test     Skip compile verification (faster but may generate invalid code)
          --help, -h              Show this help

      EXAMPLES:
          GhostwriterCLI Sources/Models/
          GhostwriterCLI --source Sources/User.swift --verbose
          GhostwriterCLI --dry-run Sources/
      """
    )
  }

  // MARK: - Main Execution

  struct RunResult {
    var filesAnalyzed: Int = 0
    var typesFound: Int = 0
    var testableTypes: Int = 0
    var testsGenerated: Int = 0
    var generatedFiles: [String] = []
    var skippedCompile: Int = 0
  }

  static func run(config: Config) async throws -> RunResult {
    var result = RunResult()

    let extractor = SwiftSyntaxTypeExtractor()
    let generator = TestCodeGenerator()

    // Find all Swift files
    let files = try findSwiftFiles(in: config.sources)
    result.filesAnalyzed = files.count

    if config.verbose {
      print("📂 Found \(files.count) Swift file(s) to analyze")
    }

    // Analyze all files
    var allTypes: [ExtractedTypeInfo] = []
    var allExtensions: [String: [String]] = [:]

    for file in files {
      do {
        let analysis = try extractor.analyze(filePath: file)

        allTypes.append(contentsOf: analysis.types)
        for (typeName, conformances) in analysis.extensionConformances {
          allExtensions[typeName, default: []].append(contentsOf: conformances)
        }

        if config.verbose && !analysis.types.isEmpty {
          print("  📄 \(file): \(analysis.types.count) type(s)")
        }
      } catch {
        print("  ⚠️ Error analyzing \(file): \(error)")
      }
    }

    // Merge extension conformances into types
    let mergedTypes = SwiftSyntaxTypeExtractor.mergeConformances(
      types: allTypes,
      extensions: allExtensions
    )

    result.typesFound = mergedTypes.count

    // Filter to testable types:
    // 1. Must have appropriate access level (public/open by default, or internal if --include-internal), AND
    // 2. Has @Arbitrary attribute, OR is a known primitive type, OR has generatable properties
    let testableTypes = mergedTypes.filter { type in
      let patterns = generator.detectPatterns(for: type)
      guard !patterns.isEmpty else { return false }

      // Filter by access level
      let accessOK = config.includeInternal || type.accessLevel.isPubliclyAccessible
      guard accessOK else { return false }

      return type.hasArbitraryAttribute
        || isKnownGeneratableType(type.name)
        || canAutoGenerateArbitrary(for: type)
    }

    result.testableTypes = testableTypes.count

    if config.verbose {
      print("🔍 Found \(result.typesFound) type(s), \(result.testableTypes) testable")

      let skipped = mergedTypes.count - testableTypes.count
      if skipped > 0 {
        print("⚠️  Skipped \(skipped) type(s) without @Arbitrary or known generators")
      }

      // Show skipped types due to access level
      let skippedAccess = mergedTypes.filter {
        !config.includeInternal && !$0.accessLevel.isPubliclyAccessible
      }
      if !skippedAccess.isEmpty {
        print("  Skipped \(skippedAccess.count) non-public type(s)")
        for type in skippedAccess.prefix(5) {
          print("    - \(type.name) (\(type.accessLevel.rawValue))")
        }
        if skippedAccess.count > 5 {
          print("    ... and \(skippedAccess.count - 5) more")
        }
      }

      // Show partial generation info
      var fullyGenerated = 0
      var partiallyGenerated = 0
      for type in testableTypes
      where !type.hasArbitraryAttribute
        && !isKnownGeneratableType(type.name)
      {
        if generator.canFullyGenerateArbitrary(for: type) {
          fullyGenerated += 1
        } else if generator.canAutoGenerateArbitrary(for: type) {
          partiallyGenerated += 1
        }
      }

      if fullyGenerated > 0 {
        print("✅ \(fullyGenerated) type(s) can be fully auto-generated")
      }
      if partiallyGenerated > 0 {
        print(
          "⚠️  \(partiallyGenerated) type(s) partially generated (some properties need manual generators)"
        )
      }
    }

    // Group by source file
    var typesByFile: [String: [ExtractedTypeInfo]] = [:]
    for type in testableTypes {
      typesByFile[type.sourceFile, default: []].append(type)
    }

    // Generate tests
    let verifier = CompileVerifier(verbose: config.verbose)

    for (sourceFile, types) in typesByFile {
      let testCode = generator.generateTestFile(types: types, sourceFile: sourceFile)
      let testsInFile = types.reduce(0) { $0 + generator.detectPatterns(for: $1).count }

      // Verify compilation before writing (unless skipped)
      if !config.skipCompileTest && !config.dryRun {
        let fileName = URL(fileURLWithPath: sourceFile)
          .deletingPathExtension()
          .lastPathComponent
        let testFileName = "\(fileName)PropertyTests.swift"

        let verifyResult = verifier.verify(code: testCode, fileName: testFileName)

        if !verifyResult.success {
          print("⚠️  Compilation errors in generated test for \(sourceFile):")
          for error in verifyResult.errors {
            if let line = error.line, let col = error.column {
              print("  Line \(line):\(col): \(error.message)")
            } else {
              print("  \(error.message)")
            }
          }
          if config.verbose {
            print("\nFull output:")
            print(verifyResult.output)
          }
          print("  Skipping \(sourceFile) (use --skip-compile-test to write anyway)")
          result.skippedCompile += 1
          continue  // Skip this file
        }
      }

      result.testsGenerated += testsInFile

      if config.dryRun {
        if config.verbose {
          print("\n📝 Would generate for \(sourceFile):")
          print(String(testCode.prefix(800)))
          if testCode.count > 800 {
            print("... (truncated)")
          }
        }
      } else {
        let outputFile = try writeTestFile(
          testCode,
          sourceFile: sourceFile,
          outputDirectory: config.outputDirectory
        )
        result.generatedFiles.append(outputFile)

        if config.verbose {
          print("  💾 Wrote \(outputFile)")
        }
      }
    }

    return result
  }

  // MARK: - File Discovery

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

  // MARK: - Known Types

  /// Known types that have built-in Arbitrary generators.
  static let knownGeneratableTypes: Set<String> = [
    // Primitives
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    // Foundation types
    "Date", "UUID", "URL", "Data",
    // Core types
    "Seed", "Size",
  ]

  static func isKnownGeneratableType(_ name: String) -> Bool {
    knownGeneratableTypes.contains(name)
  }

  /// Check if a type can have Arbitrary auto-generated because all its properties are generatable.
  static func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    // Must have at least one property
    guard !type.properties.isEmpty else { return false }

    // All properties must have known generatable types
    return type.properties.allSatisfy { prop in
      isPropertyTypeGeneratable(prop.typeName)
    }
  }

  /// Check if a property type can be generated.
  static func isPropertyTypeGeneratable(_ typeName: String) -> Bool {
    var cleanedType =
      typeName
      .replacingOccurrences(of: "?", with: "")  // Optional<T> -> T
      .replacingOccurrences(of: "!", with: "")  // ImplicitlyUnwrapped
      .trimmingCharacters(in: .whitespaces)

    // Handle Optional<T>
    if cleanedType.hasPrefix("Optional<") && cleanedType.hasSuffix(">") {
      cleanedType = String(cleanedType.dropFirst(9).dropLast())
    }

    // Handle Array<T>
    if cleanedType.hasPrefix("Array<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(6).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle [T] syntax
    if cleanedType.hasPrefix("[") && cleanedType.hasSuffix("]") && !cleanedType.contains(":") {
      let inner = String(cleanedType.dropFirst().dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle Set<T>
    if cleanedType.hasPrefix("Set<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(4).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle Dictionary<K,V> / [K:V]
    if cleanedType.hasPrefix("Dictionary<")
      || (cleanedType.hasPrefix("[") && cleanedType.contains(":"))
    {
      // Simplified: assume dictionaries with primitive keys/values are OK
      return true
    }

    return knownGeneratableTypes.contains(cleanedType)
  }

  // MARK: - File Writing

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

    // Create directory
    try FileManager.default.createDirectory(
      atPath: outputDirectory,
      withIntermediateDirectories: true
    )

    try content.write(toFile: outputPath, atomically: true, encoding: .utf8)
    return outputPath
  }
}
