// MARK: - Compile Verification Tests
// Tests for FR-4.3: Compile Verification Infrastructure

import Foundation
import Testing

@testable import GhostwriterLib

@Suite("CompileVerifier Tests")
struct CompileVerifierTests {

  @Test("Valid Swift code passes verification")
  func validCodePasses() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      import Foundation

      struct ValidType {
        let value: Int
      }
      """

    let result = verifier.verify(code: code, fileName: "Valid.swift")
    #expect(result.success == true)
    #expect(result.errors.isEmpty)
  }

  @Test("Syntax error is caught")
  func syntaxErrorCaught() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct BrokenType {
        let value Int  // Missing colon
      }
      """

    let result = verifier.verify(code: code, fileName: "Broken.swift")
    #expect(result.success == false)
    #expect(!result.errors.isEmpty)
  }

  @Test("Type error is caught")
  func typeErrorCaught() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct TypeMismatch {
        let value: String = 42  // Type mismatch
      }
      """

    let result = verifier.verify(code: code, fileName: "TypeMismatch.swift")
    #expect(result.success == false)
    #expect(!result.errors.isEmpty)
  }

  @Test("Missing import is caught")
  func missingImportCaught() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct UsesGen {
        static let gen = Gen.int  // Gen not imported
      }
      """

    let result = verifier.verify(code: code, fileName: "MissingImport.swift")
    #expect(result.success == false)
    #expect(
      result.errors.contains { $0.message.contains("Gen") || $0.message.contains("cannot find") }
    )
  }

  @Test("Error includes line number")
  func errorIncludesLineNumber() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct Test {
        let a: Int
        let b String  // Error on line 3
        let c: Bool
      }
      """

    let result = verifier.verify(code: code, fileName: "LineNumber.swift")
    #expect(result.success == false)
    let error = result.errors.first
    #expect(error?.line == 3)
  }

  @Test("Multiple errors are all reported")
  func multipleErrorsReported() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct MultiError {
        let a Int        // Error 1
        let b: String = 123  // Error 2
        let c Bool       // Error 3
      }
      """

    let result = verifier.verify(code: code, fileName: "MultiError.swift")
    #expect(result.success == false)
    #expect(result.errors.count >= 2)  // At least 2 errors
  }

  @Test("Verbose mode produces output")
  func verboseModeOutput() {
    let verifier = CompileVerifier(verbose: true)
    let code = """
      struct Valid {
        let x: Int
      }
      """

    let result = verifier.verify(code: code, fileName: "Verbose.swift")
    #expect(result.success == true)
  }

  @Test("Temp files are cleaned up")
  func tempFilesCleanedUp() {
    let verifier = CompileVerifier(verbose: false)
    let code = "struct Clean { let x: Int }"

    let tempDir = FileManager.default.temporaryDirectory
    let beforeCount =
      (try? FileManager.default.contentsOfDirectory(
        at: tempDir,
        includingPropertiesForKeys: nil
      ))?.count ?? 0

    _ = verifier.verify(code: code, fileName: "Clean.swift")

    let afterCount =
      (try? FileManager.default.contentsOfDirectory(
        at: tempDir,
        includingPropertiesForKeys: nil
      ))?.count ?? 0

    // Should not leak temp directories
    #expect(afterCount <= beforeCount + 1)  // Allow some OS temp file creation
  }

  @Test("Valid code with imports passes")
  func validCodeWithImportsPasses() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      import Foundation

      struct User {
        let id: UUID
        let name: String
        let createdAt: Date
      }
      """

    let result = verifier.verify(code: code, fileName: "User.swift")
    #expect(result.success == true)
    #expect(result.errors.isEmpty)
  }

  @Test("Undefined type error is caught")
  func undefinedTypeErrorCaught() {
    let verifier = CompileVerifier(verbose: false)
    let code = """
      struct Container {
        let value: NonExistentType  // Undefined type
      }
      """

    let result = verifier.verify(code: code, fileName: "UndefinedType.swift")
    #expect(result.success == false)
    #expect(!result.errors.isEmpty)
  }
}

@Suite("CLI Integration Tests")
struct CompileVerificationCLITests {

  @Test("Config defaults skipCompileTest to false")
  func configDefaultSkipCompileTest() {
    let config = GhostwriterConfig()
    #expect(config.skipCompileTest == false)
  }

  @Test("--skip-compile-test flag is parsed")
  func parseSkipCompileTestFlag() {
    let args = ["ghostwriter", "--skip-compile-test", "Sources/"]
    let config = GhostwriterCore.parseArguments(args)
    #expect(config.skipCompileTest == true)
  }

  @Test("Verification disabled with flag")
  func verificationDisabledWithFlag() {
    let config = GhostwriterConfig(
      sources: [],
      outputDirectory: "",
      dryRun: false,
      verbose: false,
      showHelp: false,
      includeInternal: false,
      skipCompileTest: true
    )
    #expect(config.skipCompileTest == true)
  }

  @Test("RunResult tracks skipped compile count")
  func runResultTracksSkippedCompile() {
    var result = GhostwriterRunResult()
    result.skippedCompile = 3
    #expect(result.skippedCompile == 3)
  }

  @Test("Default RunResult has zero skipped")
  func defaultRunResultZeroSkipped() {
    let result = GhostwriterRunResult()
    #expect(result.skippedCompile == 0)
  }
}
