// MARK: - GhostwriterCLI Run Extension
// Main execution logic for test generation.

import Foundation
import SwiftParser
import SwiftSyntax

extension GhostwriterCLI {
  /// Main execution method for test generation.
  static func run(config: Config, output: CLIOutput) async throws -> RunResult {
    var result = RunResult()
    let extractor = SwiftSyntaxTypeExtractor()
    let generator = TestCodeGenerator()

    let files = try findSwiftFiles(in: config.sources)
    result.filesAnalyzed = files.count

    if config.verbose {
      output.write("Found \(files.count) Swift file(s) to analyze")
    }

    let (allTypes, allExtensions) = analyzeFiles(
      files,
      extractor: extractor,
      config: config,
      output: output
    )

    let mergedTypes = SwiftSyntaxTypeExtractor.mergeConformances(
      types: allTypes,
      extensions: allExtensions
    )
    result.typesFound = mergedTypes.count

    let testableTypes = filterTestableTypes(
      mergedTypes,
      generator: generator,
      config: config
    )
    result.testableTypes = testableTypes.count

    if config.verbose {
      let statsContext = VerboseStatsContext(
        generator: generator,
        config: config,
        output: output
      )
      printVerboseStats(mergedTypes, testableTypes, context: statsContext)
    }

    let context = GenerationContext(
      generator: generator,
      verifier: CompileVerifier(verbose: config.verbose),
      config: config,
      output: output
    )

    result = try generateTests(
      for: testableTypes,
      using: context,
      result: result
    )

    return result
  }

  private static func analyzeFiles(
    _ files: [String],
    extractor: SwiftSyntaxTypeExtractor,
    config: Config,
    output: CLIOutput
  ) -> ([ExtractedTypeInfo], [String: [String]]) {
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
          output.write("  \(file): \(analysis.types.count) type(s)")
        }
      } catch {
        output.write("  Error analyzing \(file): \(error)")
      }
    }

    return (allTypes, allExtensions)
  }

  private static func filterTestableTypes(
    _ types: [ExtractedTypeInfo],
    generator: TestCodeGenerator,
    config: Config
  ) -> [ExtractedTypeInfo] {
    types.filter { type in
      let patterns = generator.detectPatterns(for: type)
      guard !patterns.isEmpty else { return false }
      let accessOK = config.includeInternal || type.accessLevel.isPubliclyAccessible
      guard accessOK else { return false }
      return type.hasArbitraryAttribute
        || isKnownGeneratableType(type.name)
        || canAutoGenerateArbitrary(for: type)
    }
  }

  private static func printVerboseStats(
    _ allTypes: [ExtractedTypeInfo],
    _ testableTypes: [ExtractedTypeInfo],
    context: VerboseStatsContext
  ) {
    context.output.write("Found \(allTypes.count) type(s), \(testableTypes.count) testable")

    let skipped = allTypes.count - testableTypes.count
    if skipped > 0 {
      context.output.write("Skipped \(skipped) type(s) without @Arbitrary or known generators")
    }

    printSkippedAccessTypes(allTypes, context.config, context.output)
    printGenerationStats(testableTypes, context.generator, context.output)
  }
}

/// Context for verbose statistics printing.
struct VerboseStatsContext {
  let generator: TestCodeGenerator
  let config: GhostwriterCLI.Config
  let output: CLIOutput
}

extension GhostwriterCLI {

  private static func printSkippedAccessTypes(
    _ allTypes: [ExtractedTypeInfo],
    _ config: Config,
    _ output: CLIOutput
  ) {
    let skippedAccess = allTypes.filter {
      !config.includeInternal && !$0.accessLevel.isPubliclyAccessible
    }

    guard !skippedAccess.isEmpty else { return }

    output.write("  Skipped \(skippedAccess.count) non-public type(s)")
    for type in skippedAccess.prefix(5) {
      output.write("    - \(type.name) (\(type.accessLevel.rawValue))")
    }
    if skippedAccess.count > 5 {
      output.write("    ... and \(skippedAccess.count - 5) more")
    }
  }

  private static func printGenerationStats(
    _ testableTypes: [ExtractedTypeInfo],
    _ generator: TestCodeGenerator,
    _ output: CLIOutput
  ) {
    var fullyGenerated = 0
    var partiallyGenerated = 0

    for type in testableTypes
    where !type.hasArbitraryAttribute && !isKnownGeneratableType(type.name) {
      if generator.canFullyGenerateArbitrary(for: type) {
        fullyGenerated += 1
      } else if generator.canAutoGenerateArbitrary(for: type) {
        partiallyGenerated += 1
      }
    }

    if fullyGenerated > 0 {
      output.write("\(fullyGenerated) type(s) can be fully auto-generated")
    }
    if partiallyGenerated > 0 {
      output.write("\(partiallyGenerated) type(s) partially generated")
    }
  }
}
