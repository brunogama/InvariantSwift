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

    // Filter to testable types (have @Arbitrary or standard conformances)
    let testableTypes = mergedTypes.filter { type in
      let patterns = generator.detectPatterns(for: type)
      return !patterns.isEmpty && (type.hasArbitraryAttribute || isKnownGeneratableType(type.name))
    }

    result.testableTypes = testableTypes.count

    if config.verbose {
      print("🔍 Found \(result.typesFound) type(s), \(result.testableTypes) testable")

      let skipped = mergedTypes.count - testableTypes.count
      if skipped > 0 {
        print("⚠️  Skipped \(skipped) type(s) without @Arbitrary or known generators")
      }
    }

    // Group by source file
    var typesByFile: [String: [ExtractedTypeInfo]] = [:]
    for type in testableTypes {
      typesByFile[type.sourceFile, default: []].append(type)
    }

    // Generate tests
    for (sourceFile, types) in typesByFile {
      let testCode = generator.generateTestFile(types: types, sourceFile: sourceFile)
      let testsInFile = types.reduce(0) { $0 + generator.detectPatterns(for: $1).count }
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

  static func isKnownGeneratableType(_ name: String) -> Bool {
    let knownTypes: Set<String> = [
      // Primitives
      "Int", "Int8", "Int16", "Int32", "Int64",
      "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
      "Double", "Float", "Bool", "String", "Character",
      // Core types
      "Seed", "Size",
    ]
    return knownTypes.contains(name)
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
