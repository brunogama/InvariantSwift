// MARK: - GhostwriterCLI Integration Tests
// Tests for the GhostwriterCLI SwiftSyntax-based type extraction.
// These tests use the pre-built CLI binary for performance.

import Foundation
import Testing

@testable import InvariantSwift

@Suite("GhostwriterCLI Integration Tests")
struct GhostwriterCLIIntegrationTests {

  // MARK: - Single CLI Test (Validates Full Pipeline)

  @Test("CLI analyzes source file and generates property tests")
  func cliFullPipelineTest() async throws {
    // Create temp file with multiple test cases
    let source = """
      // Test source with various types
      import Foundation

      struct SimpleEquatable: Equatable {
        let id: Int
        let name: String
      }

      struct HashableType: Hashable {
        let value: Int
      }

      extension HashableType: Codable {}

      struct GenericContainer<T> {
        let item: T
      }

      @Arbitrary
      struct MarkedArbitrary {
        let data: Int
      }
      """

    let tempDir = FileManager.default.temporaryDirectory
    let tempFile = tempDir.appendingPathComponent("IntegrationTest_\(UUID().uuidString).swift")

    try source.write(to: tempFile, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: tempFile) }

    // Find the pre-built CLI
    let cliPath = findCLIBinary()

    guard FileManager.default.fileExists(atPath: cliPath) else {
      // Skip test if CLI not built
      print("⚠️ GhostwriterCLI not found at \(cliPath). Run 'swift build' first.")
      return
    }

    // Run CLI
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliPath)
    process.arguments = ["--source", tempFile.path, "--dry-run", "--verbose"]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    // Validate output
    #expect(output.contains("type(s)"), "Should detect types")
    #expect(output.contains("Ghostwriter"), "Should show CLI banner")
    #expect(
      output.contains("testable") || output.contains("Testable"),
      "Should find testable types"
    )
    #expect(process.terminationStatus == 0, "CLI should exit successfully")
  }

  // MARK: - Library-Level Type Detection Tests

  @Test("Detects Equatable conformance patterns")
  func detectEquatablePatterns() {
    let conformance = ProtocolConformance.equatable
    let patterns = conformance.applicablePatterns

    #expect(patterns.contains(.equatableReflexive))
    #expect(patterns.contains(.equatableSymmetric))
    #expect(patterns.contains(.equatableTransitive))
  }

  @Test("Detects Hashable conformance patterns")
  func detectHashablePatterns() {
    let conformance = ProtocolConformance.hashable
    let patterns = conformance.applicablePatterns

    #expect(patterns.contains(.hashableConsistency))
    // Hashable also implies Equatable
    #expect(patterns.contains(.equatableReflexive))
  }

  @Test("Detects Codable conformance patterns")
  func detectCodablePatterns() {
    let conformance = ProtocolConformance.codable
    let patterns = conformance.applicablePatterns

    #expect(patterns.contains(.codableRoundtrip))
  }

  @Test("Detects Comparable conformance patterns")
  func detectComparablePatterns() {
    let conformance = ProtocolConformance.comparable
    let patterns = conformance.applicablePatterns

    #expect(patterns.contains(.comparableIrreflexive))
    #expect(patterns.contains(.comparableAsymmetric))
    #expect(patterns.contains(.comparableTransitive))
    #expect(patterns.contains(.comparableTrichotomy))
  }

  // MARK: - TypeInfo Pattern Detection Tests

  @Test("TypeInfo computes applicable patterns from conformances")
  func typeInfoApplicablePatterns() {
    let typeInfo = TypeInfo(
      name: "TestType",
      kind: .structType,
      sourceFile: "test.swift",
      line: 1,
      conformances: [.equatable, .codable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let patterns = typeInfo.applicablePatterns

    #expect(patterns.contains(.equatableReflexive))
    #expect(patterns.contains(.codableRoundtrip))
  }

  @Test("TypeInfo handles multiple conformances")
  func typeInfoMultipleConformances() {
    let typeInfo = TypeInfo(
      name: "FullType",
      kind: .structType,
      sourceFile: "test.swift",
      line: 1,
      conformances: [.hashable, .comparable, .codable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let patterns = typeInfo.applicablePatterns

    // Should have patterns from all conformances
    #expect(patterns.contains(.hashableConsistency))
    #expect(patterns.contains(.comparableTrichotomy))
    #expect(patterns.contains(.codableRoundtrip))
    // At least 7 patterns (3 equatable + 1 hashable + 4 comparable + 1 codable = 9, minus duplicates)
    #expect(patterns.count >= 7)
  }

  // MARK: - Helper

  private func findCLIBinary() -> String {
    // Look for pre-built binary in .build/debug
    var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path)
    {
      let parent = dir.deletingLastPathComponent()
      if parent.path == dir.path { break }
      dir = parent
    }
    return dir.appendingPathComponent(".build/debug/GhostwriterCLI").path
  }
}
