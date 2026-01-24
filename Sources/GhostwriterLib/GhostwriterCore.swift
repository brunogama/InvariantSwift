// MARK: - Ghostwriter Library
// Core types and functions for test generation, extracted for testability.

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Configuration

public struct GhostwriterConfig {
  public var sources: [String] = []
  public var outputDirectory: String = "Tests/Generated/"
  public var dryRun: Bool = false
  public var verbose: Bool = false
  public var showHelp: Bool = false
  public var includeInternal: Bool = false
  public var skipCompileTest: Bool = false

  public init(
    sources: [String] = [],
    outputDirectory: String = "Tests/Generated/",
    dryRun: Bool = false,
    verbose: Bool = false,
    showHelp: Bool = false,
    includeInternal: Bool = false,
    skipCompileTest: Bool = false
  ) {
    self.sources = sources
    self.outputDirectory = outputDirectory
    self.dryRun = dryRun
    self.verbose = verbose
    self.showHelp = showHelp
    self.includeInternal = includeInternal
    self.skipCompileTest = skipCompileTest
  }
}

// MARK: - Run Result

public struct GhostwriterRunResult {
  public var filesAnalyzed: Int = 0
  public var typesFound: Int = 0
  public var testableTypes: Int = 0
  public var testsGenerated: Int = 0
  public var generatedFiles: [String] = []
  public var skippedCompile: Int = 0

  public init() {}
}

// MARK: - Ghostwriter Core

public enum GhostwriterCore {

  // MARK: - Argument Parsing

  public static func parseArguments(_ arguments: [String]) -> GhostwriterConfig {
    var config = GhostwriterConfig()
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

  // MARK: - Main Execution

  public static func run(config: GhostwriterConfig) async throws -> GhostwriterRunResult {
    var result = GhostwriterRunResult()

    let extractor = SwiftSyntaxTypeExtractor()
    let generator = TestCodeGenerator()

    // Find all Swift files
    let files = try findSwiftFiles(in: config.sources)
    result.filesAnalyzed = files.count

    if config.verbose {
      // swiftlint:disable:next no_print
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
          // swiftlint:disable:next no_print
          print("  📄 \(file): \(analysis.types.count) type(s)")
        }
      } catch {
        // swiftlint:disable:next no_print
        print("  ⚠️ Error analyzing \(file): \(error)")
      }
    }

    // Merge extension conformances into types
    let mergedTypes = SwiftSyntaxTypeExtractor.mergeConformances(
      types: allTypes,
      extensions: allExtensions
    )

    result.typesFound = mergedTypes.count

    // Filter to testable types
    let testableTypes = mergedTypes.filter { type in
      let patterns = generator.detectPatterns(for: type)
      guard !patterns.isEmpty else { return false }

      let accessOK = config.includeInternal || type.accessLevel.isPubliclyAccessible
      guard accessOK else { return false }

      return type.hasArbitraryAttribute
        || isKnownGeneratableType(type.name)
        || canAutoGenerateArbitrary(for: type)
    }

    result.testableTypes = testableTypes.count

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
          // swiftlint:disable:next no_print
          print("⚠️  Compilation errors in generated test for \(sourceFile):")
          for error in verifyResult.errors {
            if let line = error.line, let col = error.column {
              // swiftlint:disable:next no_print
              print("  Line \(line):\(col): \(error.message)")
            } else {
              // swiftlint:disable:next no_print
              print("  \(error.message)")
            }
          }
          // swiftlint:disable:next no_print
          print("  Skipping \(sourceFile) (use --skip-compile-test to write anyway)")
          result.skippedCompile += 1
          continue  // Skip this file
        }
      }

      result.testsGenerated += testsInFile

      if config.dryRun {
        if config.verbose {
          // swiftlint:disable:next no_print
          print("\n📝 Would generate for \(sourceFile):")
          // swiftlint:disable:next no_print
          print(String(testCode.prefix(800)))
          if testCode.count > 800 {
            // swiftlint:disable:next no_print
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
          // swiftlint:disable:next no_print
          print("  💾 Wrote \(outputFile)")
        }
      }
    }

    return result
  }

  // MARK: - File Discovery

  public static func findSwiftFiles(in sources: [String]) throws -> [String] {
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

  public static let knownGeneratableTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    "Date", "UUID", "URL", "Data",
    "Seed", "Size",
  ]

  public static func isKnownGeneratableType(_ name: String) -> Bool {
    knownGeneratableTypes.contains(name)
  }

  public static func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.allSatisfy { prop in
      isPropertyTypeGeneratable(prop.typeName)
    }
  }

  public static func isPropertyTypeGeneratable(_ typeName: String) -> Bool {
    var cleanedType =
      typeName
      .replacingOccurrences(of: "?", with: "")
      .replacingOccurrences(of: "!", with: "")
      .trimmingCharacters(in: .whitespaces)

    if cleanedType.hasPrefix("Optional<") && cleanedType.hasSuffix(">") {
      cleanedType = String(cleanedType.dropFirst(9).dropLast())
    }

    if cleanedType.hasPrefix("Array<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(6).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    if cleanedType.hasPrefix("[") && cleanedType.hasSuffix("]") && !cleanedType.contains(":") {
      let inner = String(cleanedType.dropFirst().dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    if cleanedType.hasPrefix("Set<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(4).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    if cleanedType.hasPrefix("Dictionary<")
      || (cleanedType.hasPrefix("[") && cleanedType.contains(":"))
    {
      return true
    }

    return knownGeneratableTypes.contains(cleanedType)
  }

  // MARK: - File Writing

  public static func writeTestFile(
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

// For backward compatibility - type aliases
public typealias Config = GhostwriterConfig
public typealias RunResult = GhostwriterRunResult
