// MARK: - GhostwriterCLI Generate Extension
// Test file generation and verification logic.

import Foundation

/// Context for test generation containing all necessary dependencies.
struct GenerationContext {
  let generator: TestCodeGenerator
  let verifier: CompileVerifier
  let config: GhostwriterCLI.Config
  let output: CLIOutput
}

extension GhostwriterCLI {
  static func generateTests(
    for testableTypes: [ExtractedTypeInfo],
    using context: GenerationContext,
    result: RunResult
  ) throws -> RunResult {
    var result = result
    var typesByFile: [String: [ExtractedTypeInfo]] = [:]
    for type in testableTypes {
      typesByFile[type.sourceFile, default: []].append(type)
    }

    for (sourceFile, types) in typesByFile {
      let genResult = try generateTestFile(
        for: types,
        sourceFile: sourceFile,
        context: context
      )

      switch genResult {
      case .generated(let testsCount, let outputFile):
        result.testsGenerated += testsCount
        if let file = outputFile {
          result.generatedFiles.append(file)
        }

      case .skipped:
        result.skippedCompile += 1
      }
    }

    return result
  }

  private enum GenerationResult {
    case generated(testsCount: Int, outputFile: String?)
    case skipped
  }

  private static func generateTestFile(
    for types: [ExtractedTypeInfo],
    sourceFile: String,
    context: GenerationContext
  ) throws -> GenerationResult {
    let testCode = context.generator.generateTestFile(types: types, sourceFile: sourceFile)
    let testsCount = types.reduce(0) {
      $0 + context.generator.detectPatterns(for: $1).count
    }

    if !context.config.skipCompileTest && !context.config.dryRun {
      let fileName = URL(fileURLWithPath: sourceFile)
        .deletingPathExtension()
        .lastPathComponent
      let testFileName = "\(fileName)PropertyTests.swift"

      let verifyResult = context.verifier.verify(code: testCode, fileName: testFileName)

      if !verifyResult.success {
        reportCompilationErrors(verifyResult, sourceFile, context)
        return .skipped
      }
    }

    if context.config.dryRun {
      if context.config.verbose {
        context.output.write("\nWould generate for \(sourceFile):")
        context.output.write(String(testCode.prefix(800)))
        if testCode.count > 800 {
          context.output.write("... (truncated)")
        }
      }
      return .generated(testsCount: testsCount, outputFile: nil)
    }

    let outputFile = try writeTestFile(
      testCode,
      sourceFile: sourceFile,
      outputDirectory: context.config.outputDirectory
    )

    if context.config.verbose {
      context.output.write("  Wrote \(outputFile)")
    }

    return .generated(testsCount: testsCount, outputFile: outputFile)
  }

  private static func reportCompilationErrors(
    _ result: CompileVerificationResult,
    _ sourceFile: String,
    _ context: GenerationContext
  ) {
    context.output.write("Compilation errors in generated test for \(sourceFile):")
    for error in result.errors {
      if let line = error.line, let col = error.column {
        context.output.write("  Line \(line):\(col): \(error.message)")
      } else {
        context.output.write("  \(error.message)")
      }
    }
    if context.config.verbose {
      context.output.write("\nFull output:")
      context.output.write(result.output)
    }
    context.output.write("  Skipping \(sourceFile) (use --skip-compile-test to write anyway)")
  }
}
