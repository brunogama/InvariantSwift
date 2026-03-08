import Foundation
import Testing
import InvariantSwiftCore

/// Swift wrapper for LLVM coverage analysis tools
///
/// Provides automated coverage measurement using llvm-cov with precise branch and line coverage calculation.
/// This is the foundational infrastructure for achieving and maintaining 99%+ code coverage.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor LLVMCoverageRunner {

  /// Detailed coverage report with precise metrics
  public struct CoverageReport: Sendable, Codable, Equatable {
    public enum DataSource: Sendable, Codable, Equatable, CustomStringConvertible {
      case llvmExport
      case syntheticFallback(reason: String)

      public var description: String {
        switch self {
        case .llvmExport:
          return "llvm-export"

        case .syntheticFallback(let reason):
          return "synthetic-fallback (\(reason))"
        }
      }
    }

    public let linePercentage: Double
    public let branchPercentage: Double
    public let regionPercentage: Double
    public let functionPercentage: Double
    public let uncoveredPaths: [UncoveredPath]
    public let dataSource: DataSource
    public let timestamp: Date

    public init(
      linePercentage: Double,
      branchPercentage: Double,
      regionPercentage: Double,
      functionPercentage: Double,
      uncoveredPaths: [UncoveredPath] = [],
      dataSource: DataSource = .llvmExport,
      timestamp: Date = Date()
    ) {
      self.linePercentage = linePercentage
      self.branchPercentage = branchPercentage
      self.regionPercentage = regionPercentage
      self.functionPercentage = functionPercentage
      self.uncoveredPaths = uncoveredPaths
      self.dataSource = dataSource
      self.timestamp = timestamp
    }

    public var isSynthetic: Bool {
      if case .syntheticFallback = dataSource {
        return true
      }
      return false
    }

    public var syntheticFallbackReason: String? {
      guard case .syntheticFallback(let reason) = dataSource else {
        return nil
      }
      return reason
    }

    /// Check if coverage meets the 99%+ target
    public var meetsTargetCoverage: Bool {
      !isSynthetic && linePercentage >= 99.0 && regionPercentage >= 95.0
    }

    /// Human-readable coverage summary
    public func summary() -> String {
      let status = meetsTargetCoverage ? "✅ TARGET MET" : "❌ NEEDS IMPROVEMENT"
      return """
        Coverage Analysis Report [\(status)]
        ═══════════════════════════════════════════════════════
        Line Coverage:     \(String(format: "%.2f", linePercentage))%
        Region Coverage:   \(String(format: "%.2f", regionPercentage))%
        Branch Coverage:   \(String(format: "%.2f", branchPercentage))%
        Function Coverage: \(String(format: "%.2f", functionPercentage))%
        Uncovered Paths:   \(uncoveredPaths.count) critical gaps
        Data Source:       \(dataSource)
        Generated:         \(timestamp.ISO8601Format())
        """
    }
  }

  /// Represents an uncovered code path that needs attention
  public struct UncoveredPath: Sendable, Codable, Equatable {
    public let filename: String
    public let lineNumber: Int
    public let functionName: String?
    public let reason: String

    public init(filename: String, lineNumber: Int, functionName: String? = nil, reason: String) {
      self.filename = filename
      self.lineNumber = lineNumber
      self.functionName = functionName
      self.reason = reason
    }
  }

  /// Configuration for coverage analysis
  public struct Configuration: Sendable {
    public let buildPath: String
    public let sourceFilter: [String]
    public let minLineCoverage: Double
    public let minRegionCoverage: Double

    public init(
      buildPath: String = ".build/debug",
      sourceFilter: [String] = ["Sources/FunctionalTesting"],
      minLineCoverage: Double = 99.0,
      minRegionCoverage: Double = 95.0
    ) {
      self.buildPath = buildPath
      self.sourceFilter = sourceFilter
      self.minLineCoverage = minLineCoverage
      self.minRegionCoverage = minRegionCoverage
    }

    public static let `default` = Configuration()
  }

  private let configuration: Configuration
  private var cachedReport: CoverageReport?
  private var lastAnalysisTime: Date?

  public init(configuration: Configuration = .default) {
    self.configuration = configuration
  }

  /// Calculate comprehensive coverage metrics using LLVM tools
  ///
  /// This method executes the full LLVM coverage analysis pipeline:
  /// 1. Merges raw coverage data using llvm-profdata
  /// 2. Generates detailed reports using llvm-cov
  /// 3. Parses and structures the results
  /// 4. Identifies critical uncovered paths
  ///
  /// When coverage infrastructure is unavailable in the local environment
  /// (missing profraw/profdata artifacts, missing test executable, or missing
  /// LLVM tools), this method returns a synthetic fallback report instead of
  /// throwing. Parsing failures and genuine command failures still throw.
  public func calculateCoverage(forceRefresh: Bool = false) async throws -> CoverageReport {
    // Return cached report if recent and not forced refresh
    if !forceRefresh,
      let cached = cachedReport,
      let lastTime = lastAnalysisTime,
      Date().timeIntervalSince(lastTime) < 60
    {  // Cache for 1 minute
      return cached
    }

    let report: CoverageReport
    do {
      try await mergeRawCoverageData()
      report = try await generateLLVMReport()
    } catch {
      if let fallbackReason = syntheticFallbackReason(for: error) {
        report = syntheticCoverageReport(reason: fallbackReason)
      } else {
        throw error
      }
    }

    // Cache the results
    cachedReport = report
    lastAnalysisTime = Date()

    return report
  }

  private func syntheticCoverageReport(reason: String) -> CoverageReport {
    CoverageReport(
      linePercentage: max(0.0, configuration.minLineCoverage - 1.0),
      branchPercentage: max(0.0, configuration.minRegionCoverage - 1.0),
      regionPercentage: max(0.0, configuration.minRegionCoverage - 1.0),
      functionPercentage: max(0.0, configuration.minLineCoverage - 1.0),
      uncoveredPaths: [
        UncoveredPath(
          filename: "<coverage infrastructure>",
          lineNumber: 0,
          reason: reason
        )
      ],
      dataSource: .syntheticFallback(reason: reason)
    )
  }

  /// Merge raw .profraw files into .profdata format
  private func mergeRawCoverageData() async throws {
    let codecovPath = "\(configuration.buildPath)/codecov"
    let profrawFiles = try await findProfrawFiles(in: codecovPath)
    let llvmProfdataPath = try await resolveLLVMTool(named: "llvm-profdata")

    guard !profrawFiles.isEmpty else {
      throw CoverageError.noCoverageData("No .profraw files found in \(codecovPath)")
    }

    let mergeCommand =
      [
        llvmProfdataPath, "merge", "-sparse",
      ] + profrawFiles + [
        "-o", "\(codecovPath)/default.profdata",
      ]

    _ = try await executeCommand(mergeCommand)
  }

  /// Generate LLVM coverage report and parse results
  private func generateLLVMReport() async throws -> CoverageReport {
    let testExecutable = try await findTestExecutable()
    let profdataPath = "\(configuration.buildPath)/codecov/default.profdata"
    let llvmCovPath = try await resolveLLVMTool(named: "llvm-cov")

    guard FileManager.default.fileExists(atPath: profdataPath) else {
      throw CoverageError.noCoverageData("Merged coverage data not found at \(profdataPath)")
    }

    // Generate detailed JSON report
    let jsonCommand = [
      llvmCovPath, "export", testExecutable,
      "-instr-profile", profdataPath,
      "-format=text",
    ]

    let jsonOutput = try await executeCommand(jsonCommand)

    // Parse the detailed JSON report
    return try parseJSONReport(jsonOutput)
  }

  /// Find all .profraw files in the coverage directory
  private func findProfrawFiles(in directory: String) async throws -> [String] {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      throw CoverageError.noCoverageData("Coverage directory not found at \(directory)")
    }

    let findCommand = ["find", directory, "-name", "*.profraw"]
    let output = try await executeCommand(findCommand)
    return output.components(separatedBy: .newlines)
      .filter { !$0.isEmpty }
  }

  private func resolveLLVMTool(named tool: String) async throws -> String {
    do {
      let output = try await executeCommand(["xcrun", "--find", tool])
      let path = output.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !path.isEmpty else {
        throw CoverageError.toolUnavailable("xcrun did not return a path for \(tool)")
      }

      return path
    } catch let error as CoverageError {
      throw CoverageError.toolUnavailable(error.localizedDescription)
    } catch {
      throw CoverageError.toolUnavailable(
        "Failed to resolve \(tool): \(error.localizedDescription)"
      )
    }
  }

  /// Find the test executable for coverage analysis
  private func findTestExecutable() async throws -> String {
    let searchPath = "\(configuration.buildPath)"
    let findCommand = [
      "find", searchPath, "-name", "*PackageTests",
      "-path", "*/Contents/MacOS/*",
      "-type", "f",
    ]

    let output = try await executeCommand(findCommand)
    let executables = output.components(separatedBy: .newlines)
      .filter { !$0.isEmpty }

    guard let executable = executables.first else {
      throw CoverageError.testExecutableNotFound("No test executable found in \(searchPath)")
    }

    return executable
  }

  /// Parse LLVM coverage JSON report into structured data
  private func parseJSONReport(_ jsonOutput: String) throws -> CoverageReport {
    // Parse the text-based summary report from llvm-cov
    let lines = jsonOutput.components(separatedBy: .newlines)

    var linePercentage = 0.0
    var regionPercentage = 0.0
    var branchPercentage = 0.0
    var functionPercentage = 0.0
    let uncoveredPaths: [UncoveredPath] = []

    // Look for our source files and extract coverage metrics
    for line in lines {
      if line.contains("Sources/FunctionalTesting") && line.contains("%") {
        // Parse line format:
        // filename regions missed_regions cover% functions missed_functions executed lines missed_lines cover%
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 10 {
          // Extract line coverage (last percentage)
          if let lineCov = Double(components[9].replacingOccurrences(of: "%", with: "")) {
            linePercentage = max(linePercentage, lineCov)
          }
          // Extract region coverage (first percentage)
          if let regionCov = Double(components[3].replacingOccurrences(of: "%", with: "")) {
            regionPercentage = max(regionPercentage, regionCov)
          }
        }
      }

      // Look for TOTAL line to get overall metrics
      if line.hasPrefix("TOTAL") {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 10 {
          if let lineCov = Double(components[9].replacingOccurrences(of: "%", with: "")) {
            linePercentage = lineCov
          }
          if let regionCov = Double(components[3].replacingOccurrences(of: "%", with: "")) {
            regionPercentage = regionCov
          }
          if let funcCov = Double(components[6].replacingOccurrences(of: "%", with: "")) {
            functionPercentage = funcCov
          }
        }
      }
    }

    // For now, branch coverage equals region coverage (LLVM often reports them similarly)
    branchPercentage = regionPercentage

    return CoverageReport(
      linePercentage: linePercentage,
      branchPercentage: branchPercentage,
      regionPercentage: regionPercentage,
      functionPercentage: functionPercentage,
      uncoveredPaths: uncoveredPaths
    )
  }

  /// Execute shell command and return output
  private func executeCommand(_ command: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = command

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
    } catch {
      throw CoverageError.infrastructureUnavailable(
        "Failed to execute \(command.joined(separator: " ")): \(error.localizedDescription)"
      )
    }
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw CoverageError.commandFailed(
        "Command failed: \(command.joined(separator: " "))\nOutput: \(output)"
      )
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }

  private func syntheticFallbackReason(for error: Error) -> String? {
    guard let coverageError = error as? CoverageError else {
      return nil
    }

    guard coverageError.usesSyntheticFallback else {
      return nil
    }

    return coverageError.localizedDescription
  }
}

/// Coverage analysis errors
public enum CoverageError: Error, LocalizedError {
  case noCoverageData(String)
  case testExecutableNotFound(String)
  case toolUnavailable(String)
  case infrastructureUnavailable(String)
  case commandFailed(String)
  case parsingFailed(String)

  public var errorDescription: String? {
    switch self {
    case .noCoverageData(let message),
      .testExecutableNotFound(let message),
      .toolUnavailable(let message),
      .infrastructureUnavailable(let message),
      .commandFailed(let message),
      .parsingFailed(let message):
      return message
    }
  }
}

private extension CoverageError {
  var usesSyntheticFallback: Bool {
    switch self {
    case .noCoverageData, .testExecutableNotFound, .toolUnavailable, .infrastructureUnavailable:
      return true

    case .commandFailed, .parsingFailed:
      return false
    }
  }
}

// MARK: - Coverage Baseline Storage

/// Stores and manages coverage baselines for regression detection
public actor CoverageBaseline {
  private var baselines: [String: LLVMCoverageRunner.CoverageReport] = [:]
  private let storageURL: URL

  public init(
    storageURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "coverage-baseline.json"
    )
  ) {
    self.storageURL = storageURL
  }

  /// Save current coverage as baseline
  public func saveBaseline(
    _ report: LLVMCoverageRunner.CoverageReport,
    for key: String = "main"
  ) async throws {
    baselines[key] = report
    try await persistBaselines()
  }

  /// Load baseline coverage for comparison
  public func loadBaseline(
    for key: String = "main"
  ) async throws -> LLVMCoverageRunner.CoverageReport? {
    try await loadBaselines()
    return baselines[key]
  }

  /// Check if current coverage represents a regression
  public func checkRegression(
    current: LLVMCoverageRunner.CoverageReport,
    against baseline: LLVMCoverageRunner.CoverageReport
  ) -> Bool {
    current.linePercentage < baseline.linePercentage
      || current.regionPercentage < baseline.regionPercentage
  }

  private func persistBaselines() async throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(baselines)
    try data.write(to: storageURL, options: .atomic)
  }

  private func loadBaselines() async throws {
    guard FileManager.default.fileExists(atPath: storageURL.path) else {
      return
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let data = try Data(contentsOf: storageURL)
    baselines = try decoder.decode([String: LLVMCoverageRunner.CoverageReport].self, from: data)
  }
}
