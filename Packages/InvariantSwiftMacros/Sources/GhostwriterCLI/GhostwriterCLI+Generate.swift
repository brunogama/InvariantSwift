// MARK: - GhostwriterCLI Generate Extension
// Test file generation and verification logic.

import Foundation
import GhostwriterLib

extension GhostwriterBuildContext {
  func typeCheckContext(for moduleName: String) -> CompileVerifier.TypeCheckContext? {
    let buildDirectory = packageDirectory.appendingPathComponent(".build")
    guard
      let module = findBuildArtifact(
        names: ["\(moduleName).swiftmodule"],
        under: buildDirectory,
        requiredSiblings: [
          "InvariantSwift.swiftmodule",
          "InvariantSwiftMacroAPI.swiftmodule",
          "InvariantSwiftTesting.swiftmodule",
        ]
      )
    else {
      return nil
    }

    let moduleDirectory = module.deletingLastPathComponent()
    guard let macroPlugin = findMacroPlugin(near: moduleDirectory, buildDirectory: buildDirectory)
    else {
      return nil
    }

    var compilerArguments =
      [
        "-parse-as-library",
        "-enable-testing",
        "-disable-sandbox",
        "-Xfrontend",
        "-load-plugin-executable",
        "-Xfrontend",
        "\(macroPlugin.path)#InvariantSwiftMacros",
      ] + swiftSyntaxCShimsArguments(in: buildDirectory)
    if let testingPluginPath = testingPluginPath() {
      compilerArguments += ["-plugin-path", testingPluginPath.path]
    }
    return CompileVerifier.TypeCheckContext(
      moduleSearchPaths: [moduleDirectory],
      frameworkSearchPaths: frameworkSearchPaths(),
      compilerArguments: compilerArguments
    )
  }

  private func swiftSyntaxCShimsArguments(in buildDirectory: URL) -> [String] {
    let includeDirectory = buildDirectory.appendingPathComponent(
      "checkouts/swift-syntax/Sources/_SwiftSyntaxCShims/include"
    )
    let moduleMap = includeDirectory.appendingPathComponent("module.modulemap")
    guard FileManager.default.fileExists(atPath: moduleMap.path) else { return [] }
    return [
      "-Xcc", "-fmodule-map-file=\(moduleMap.path)",
      "-Xcc", "-I\(includeDirectory.path)",
    ]
  }

  private func findMacroPlugin(near moduleDirectory: URL, buildDirectory: URL) -> URL? {
    let names = ["InvariantSwiftMacros", "InvariantSwiftMacros-tool"]
    let nearbyDirectories = [moduleDirectory, moduleDirectory.deletingLastPathComponent()]
    for directory in nearbyDirectories {
      for name in names {
        let candidate = directory.appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
          return candidate
        }
      }
    }
    return findBuildArtifact(names: names, under: buildDirectory)
  }

  private func findBuildArtifact(
    names: [String],
    under directory: URL,
    requiredSiblings: [String] = []
  ) -> URL? {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey]
      )
    else {
      return nil
    }

    var matches: [URL] = []
    while let url = enumerator.nextObject() as? URL {
      if ["artifacts", "checkouts", "repositories"].contains(url.lastPathComponent) {
        enumerator.skipDescendants()
        continue
      }
      let siblingDirectory = url.deletingLastPathComponent()
      let hasRequiredSiblings = requiredSiblings.allSatisfy {
        FileManager.default.fileExists(atPath: siblingDirectory.appendingPathComponent($0).path)
      }
      if names.contains(url.lastPathComponent) && hasRequiredSiblings {
        matches.append(url)
        enumerator.skipDescendants()
      }
    }
    return matches.max { modificationDate(for: $0) < modificationDate(for: $1) }
  }

  private func modificationDate(for url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
      ?? .distantPast
  }

  private func testingPluginPath() -> URL? {
    guard let output = commandOutput(["swiftc", "-print-target-info"]),
      let data = output.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let paths = json["paths"] as? [String: Any],
      let runtimePath = paths["runtimeResourcePath"] as? String
    else {
      return nil
    }

    let resourceDirectory = URL(fileURLWithPath: runtimePath)
    let candidates = [resourceDirectory, resourceDirectory.deletingLastPathComponent()]
      .map { $0.appendingPathComponent("host/plugins/testing") }
    return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private func frameworkSearchPaths() -> [URL] {
    #if os(macOS)
    guard let sdkPath = commandOutput(["/usr/bin/xcrun", "--show-sdk-path"]) else { return [] }
    let developerDirectory = URL(fileURLWithPath: sdkPath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let frameworks = developerDirectory.appendingPathComponent("Library/Frameworks")
    return FileManager.default.fileExists(atPath: frameworks.path) ? [frameworks] : []
    #else
    return []
    #endif
  }

  private func commandOutput(_ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    return String(data: data, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

/// Context for test generation containing all necessary dependencies.
struct GenerationContext {
  let generator: TestCodeGenerator
  let verifier: CompileVerifier
  let buildContext: GhostwriterBuildContext
  let typeCheckContexts: [String: CompileVerifier.TypeCheckContext]
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
    let batchVerified = batchVerifiedFiles(typesByFile, context: context)

    for (sourceFile, types) in typesByFile {
      let genResult = try generateTestFile(
        for: types,
        sourceFile: sourceFile,
        verifiedInBatch: batchVerified.contains(sourceFile),
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

  private static func batchVerifiedFiles(
    _ typesByFile: [String: [ExtractedTypeInfo]],
    context: GenerationContext
  ) -> Set<String> {
    guard !context.config.skipCompileTest && !context.config.dryRun else { return [] }

    let filesByModule = Dictionary(grouping: typesByFile.keys) {
      context.buildContext.moduleName(for: $0) ?? ""
    }
    var verified: Set<String> = []
    for (module, sourceFiles) in filesByModule where sourceFiles.count > 1 {
      guard let typeCheckContext = context.typeCheckContexts[module] else { continue }
      let files = sourceFiles.sorted().compactMap { sourceFile -> CompileVerifier.SourceFile? in
        guard let types = typesByFile[sourceFile] else { return nil }
        let name = URL(fileURLWithPath: sourceFile).deletingPathExtension().lastPathComponent
        let suffix = context.config.discoverLaws ? "LawForgeTests" : "PropertyTests"
        let code = context.generator.generateTestFile(
          types: types,
          sourceFile: sourceFile,
          consumerModule: module,
          discoverLaws: context.config.discoverLaws
        )
        return CompileVerifier.SourceFile(fileName: "\(name)\(suffix).swift", code: code)
      }
      let verifier = CompileVerifier(typeCheckContext: typeCheckContext)
      if verifier.verifyBatch(files).success {
        verified.formUnion(sourceFiles)
        if context.config.verbose {
          context.output.write("  Type-checked \(sourceFiles.count) generated files for \(module)")
        }
      }
    }
    return verified
  }

  private enum GenerationResult {
    case generated(testsCount: Int, outputFile: String?)
    case skipped
  }

  private static func generateTestFile(
    for types: [ExtractedTypeInfo],
    sourceFile: String,
    verifiedInBatch: Bool,
    context: GenerationContext
  ) throws -> GenerationResult {
    let consumerModule = context.buildContext.moduleName(for: sourceFile)
    let testCode = context.generator.generateTestFile(
      types: types,
      sourceFile: sourceFile,
      consumerModule: consumerModule,
      discoverLaws: context.config.discoverLaws
    )
    let testsCount = types.reduce(0) {
      $0
        + context.generator.generatedTestCount(
          for: $1,
          discoverLaws: context.config.discoverLaws
        )
    }

    if !context.config.skipCompileTest && !context.config.dryRun && !verifiedInBatch {
      let fileName = URL(fileURLWithPath: sourceFile)
        .deletingPathExtension()
        .lastPathComponent
      let suffix = context.config.discoverLaws ? "LawForgeTests" : "PropertyTests"
      let testFileName = "\(fileName)\(suffix).swift"

      let verifyResult = verifyGeneratedTest(
        testCode,
        fileName: testFileName,
        consumerModule: consumerModule,
        context: context
      )

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
      outputDirectory: context.config.outputDirectory,
      suffix: context.config.discoverLaws ? "LawForgeTests" : "PropertyTests"
    )

    if context.config.verbose {
      context.output.write("  Wrote \(outputFile)")
    }

    return .generated(testsCount: testsCount, outputFile: outputFile)
  }

  private static func verifyGeneratedTest(
    _ testCode: String,
    fileName: String,
    consumerModule: String?,
    context: GenerationContext
  ) -> CompileVerificationResult {
    let syntaxResult = context.verifier.verifySyntax(code: testCode, fileName: fileName)
    guard syntaxResult.success else { return syntaxResult }

    guard let consumerModule else {
      context.output.write(
        "  Syntax verified for \(fileName); type-check unavailable because the source module "
          + "could not be identified"
      )
      return syntaxResult
    }
    guard let typeCheckContext = context.typeCheckContexts[consumerModule] else {
      context.output.write(
        "  Syntax verified for \(fileName); type-check unavailable because no built SwiftPM "
          + "context was found for \(consumerModule)"
      )
      return syntaxResult
    }

    let verifier = CompileVerifier(
      verbose: context.config.verbose,
      typeCheckContext: typeCheckContext
    )
    let result = verifier.verify(code: testCode, fileName: fileName)
    if result.success && context.config.verbose {
      context.output.write("  Type-checked \(fileName) against \(consumerModule)")
    }
    return result
  }

  private static func reportCompilationErrors(
    _ result: CompileVerificationResult,
    _ sourceFile: String,
    _ context: GenerationContext
  ) {
    let failure = result.level == .syntax ? "Syntax errors" : "Compilation errors"
    context.output.write("\(failure) in generated test for \(sourceFile):")
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
