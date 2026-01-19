// MARK: - ISP-0009: Ghostwriter Main Entry Point
// Orchestrates source analysis and test generation.

import Foundation

// MARK: - Ghostwriter

/// Main Ghostwriter class that orchestrates automatic test generation.
public actor Ghostwriter {

  /// Configuration
  private let config: GhostwriterConfig

  /// Source analyzer
  private let analyzer: SourceAnalyzer

  /// Test generator
  private let generator: TestGenerator

  public init(config: GhostwriterConfig) {
    self.config = config
    self.analyzer = SourceAnalyzer()
    self.generator = TestGenerator(config: config)
  }

  // MARK: - Main Entry Point

  /// Run the Ghostwriter to analyze sources and generate tests.
  // swiftlint:disable:next cyclomatic_complexity
  public func run() async throws -> GhostwriterResult {
    // Step 1: Find source files
    let filePaths = try FileDiscovery.findFiles(for: config)

    if config.verbose {
      // swiftlint:disable:next no_print
      print("📂 Found \(filePaths.count) Swift file(s) to analyze")
    }

    guard !filePaths.isEmpty else {
      return GhostwriterResult(
        analyzedFiles: [],
        discoveredTypes: [],
        generatedTests: [],
        errors: [.noTypesFound(config.sources.joined(separator: ", "))]
      )
    }

    // Step 2: Analyze source files
    let sourceFiles = try await analyzer.analyze(filePaths: filePaths)

    if config.verbose {
      for file in sourceFiles {
        // swiftlint:disable:next no_print
        print("  📄 \(file.path): \(file.types.count) type(s)")
      }
    }

    // Step 3: Extract all types
    let allTypes = sourceFiles.flatMap { $0.types }
    let testableTypes = allTypes.filter { !$0.applicablePatterns.isEmpty }

    if config.verbose {
      // swiftlint:disable:next no_print
      print("🔍 Found \(allTypes.count) type(s), \(testableTypes.count) testable")
    }

    // Step 4: Generate tests
    var allGeneratedTests: [GeneratedTest] = []

    for file in sourceFiles where !file.testableTypes.isEmpty {
      if config.verbose {
        // swiftlint:disable:next no_print
        print("✨ Generating tests for \(file.path)")
      }

      let testCode = generator.generateTestFile(for: file)

      // Collect individual tests for the manifest
      for typeInfo in file.testableTypes {
        let tests = generator.generateTests(for: typeInfo)
        allGeneratedTests.append(contentsOf: tests)
      }

      // Write the test file (unless dry run)
      if !config.dryRun {
        try await writeTestFile(testCode, for: file)
      } else if config.verbose {
        // swiftlint:disable:next no_print
        print("📝 Would generate:")
        // swiftlint:disable:next no_print
        print(testCode)
      }
    }

    if config.verbose {
      // swiftlint:disable:next no_print
      print("✅ Generated \(allGeneratedTests.count) test(s)")
    }

    // Step 5: Write manifest
    if !config.dryRun && !allGeneratedTests.isEmpty {
      try await writeManifest(tests: allGeneratedTests, sourceFiles: sourceFiles)
    }

    return GhostwriterResult(
      analyzedFiles: filePaths,
      discoveredTypes: allTypes,
      generatedTests: allGeneratedTests,
      errors: []
    )
  }

  // MARK: - File Writing

  private func writeTestFile(_ content: String, for sourceFile: SourceFileInfo) async throws {
    let fileName = URL(fileURLWithPath: sourceFile.path)
      .deletingPathExtension()
      .lastPathComponent

    let outputFileName = "\(fileName)\(config.testSuffix).swift"
    let outputPath = (config.outputDirectory as NSString).appendingPathComponent(outputFileName)

    // Create output directory if needed
    let outputDir = URL(fileURLWithPath: config.outputDirectory)
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

    // Write the file
    let outputURL = URL(fileURLWithPath: outputPath)
    try content.write(to: outputURL, atomically: true, encoding: .utf8)

    if config.verbose {
      // swiftlint:disable:next no_print
      print("  💾 Wrote \(outputPath)")
    }
  }

  private func writeManifest(
    tests: [GeneratedTest],
    sourceFiles: [SourceFileInfo]
  ) async throws {
    let sourceHash = sourceFiles.map { $0.hash }.joined()

    let manifest = GhostwriterManifest(
      sourceHash: sourceHash,
      tests: tests
    )

    let manifestPath = (config.outputDirectory as NSString)
      .appendingPathComponent("_GhostwriteManifest.json")
    let manifestURL = URL(fileURLWithPath: manifestPath)

    try manifest.save(to: manifestURL)

    if config.verbose {
      // swiftlint:disable:next no_print
      print("  📋 Wrote manifest to \(manifestPath)")
    }
  }

  // MARK: - Incremental Check

  /// Check if regeneration is needed.
  public func needsRegeneration() async throws -> Bool {
    if config.force {
      return true
    }

    let manifestPath = (config.outputDirectory as NSString)
      .appendingPathComponent("_GhostwriteManifest.json")
    let manifestURL = URL(fileURLWithPath: manifestPath)

    guard FileManager.default.fileExists(atPath: manifestPath) else {
      return true  // No manifest = needs generation
    }

    let manifest = try GhostwriterManifest.load(from: manifestURL)

    // Check if source files have changed
    let filePaths = try FileDiscovery.findFiles(for: config)
    let sourceFiles = try await analyzer.analyze(filePaths: filePaths)
    let currentHash = sourceFiles.map { $0.hash }.joined()

    return currentHash != manifest.sourceHash
  }
}

// MARK: - Convenience Functions

/// Run Ghostwriter with default configuration for a source path.
public func ghostwrite(
  source: String,
  output: String = "Tests/Generated/",
  dryRun: Bool = false,
  verbose: Bool = false
) async throws -> GhostwriterResult {
  let config = GhostwriterConfig(
    sources: [source],
    outputDirectory: output,
    dryRun: dryRun,
    verbose: verbose
  )

  let ghostwriter = Ghostwriter(config: config)
  return try await ghostwriter.run()
}

/// Run Ghostwriter for multiple sources.
public func ghostwrite(
  sources: [String],
  output: String = "Tests/Generated/",
  patterns: [TestPattern] = [],
  excludePatterns: [String] = [],
  dryRun: Bool = false,
  verbose: Bool = false
) async throws -> GhostwriterResult {
  let config = GhostwriterConfig(
    sources: sources,
    outputDirectory: output,
    patterns: patterns,
    excludePatterns: excludePatterns,
    dryRun: dryRun,
    verbose: verbose
  )

  let ghostwriter = Ghostwriter(config: config)
  return try await ghostwriter.run()
}
