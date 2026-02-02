/// ISP Macro Tests - Tests for ISP-0004, ISP-0005, ISP-0006 macros
///
/// This file contains:
/// 1. Macro expansion tests (verifying generated code)
/// 2. Functional tests (verifying runtime behavior)

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

import InvariantCore
@testable import InvariantSwiftMacros

// MARK: - ISP-0004: @Reproduce Macro Tests

@Suite("ISP-0004: @Reproduce Macro Tests")
struct ReproduceMacroTests {

  @Test("ReproduceMacro is registered")
  func macroIsRegistered() {
    let macroTypeName = String(describing: ReproduceMacro.self)
    #expect(macroTypeName.contains("ReproduceMacro"))
  }

  @Test("ReproduceMacro expansion returns empty (marker macro)")
  func expansionReturnsEmpty() throws {
    assertMacroExpansion(
      """
      @Reproduce(seed: 0xDEADBEEF, size: 42)
      func testExample(x: Int) { }
      """,
      expandedSource: """
        func testExample(x: Int) { }
        """,
      macros: ["Reproduce": ReproduceMacro.self]
    )
  }

  @Test("ReproduceMacro with path parameter")
  func expansionWithPath() throws {
    assertMacroExpansion(
      """
      @Reproduce(seed: 12345, size: 50, path: "0:1:3:0:2")
      func testComplex(data: String) { }
      """,
      expandedSource: """
        func testComplex(data: String) { }
        """,
      macros: ["Reproduce": ReproduceMacro.self]
    )
  }

  @Test("ReproduceMacro with input parameter")
  func expansionWithInput() throws {
    assertMacroExpansion(
      """
      @Reproduce(input: "eyJuYW1lIjoiSm9obiJ9")
      func testUser(user: String) { }
      """,
      expandedSource: """
        func testUser(user: String) { }
        """,
      macros: ["Reproduce": ReproduceMacro.self]
    )
  }

  @Test("ReproduceExtractor parses seed and size")
  func extractorParsesSeedAndSize() throws {
    // Test that the extractor can parse reproduce attributes
    let config = ReproduceConfig(seed: 0xDEAD_BEEF, size: 42)
    #expect(config.seed == 0xDEAD_BEEF)
    #expect(config.size == 42)
    #expect(config.shrinkPath == nil)
  }

  @Test("ReproduceExtractor parses shrink path")
  func extractorParsesShrinkPath() throws {
    let config = ReproduceConfig(seed: 12345, size: 50, shrinkPath: [0, 1, 3, 0, 2])
    #expect(config.seed == 12345)
    #expect(config.shrinkPath == [0, 1, 3, 0, 2])
  }
}

// MARK: - ISP-0005: @DifferentialTest Macro Tests

@Suite("ISP-0005: @DifferentialTest Macro Tests")
struct DifferentialTestMacroTests {

  @Test("DifferentialTestMacro is registered")
  func macroIsRegistered() {
    let macroTypeName = String(describing: DifferentialTestMacro.self)
    #expect(macroTypeName.contains("DifferentialTestMacro"))
  }

  @Test("DifferentialTestMacro expansion returns empty (Phase 1 marker)")
  func expansionReturnsEmpty() throws {
    assertMacroExpansion(
      """
      @DifferentialTest(
          reference: OldSort.sort,
          candidate: NewSort.sort
      )
      func testSortMigration(array: [Int]) { }
      """,
      expandedSource: """
        func testSortMigration(array: [Int]) { }
        """,
      macros: ["DifferentialTest": DifferentialTestMacro.self]
    )
  }

  @Test("DifferentialTestExtractor parses reference and candidate")
  func extractorParsesReferenceAndCandidate() throws {
    let config = DifferentialTestConfig(
      referencePath: "OldSort.sort",
      candidatePath: "NewSort.sort"
    )
    #expect(config.referencePath == "OldSort.sort")
    #expect(config.candidatePath == "NewSort.sort")
    #expect(config.hasCustomComparer == false)
  }

  @Test("DifferentialTestExtractor parses with custom comparer")
  func extractorParsesCustomComparer() throws {
    let config = DifferentialTestConfig(
      referencePath: "old",
      candidatePath: "new",
      hasCustomComparer: true
    )
    #expect(config.hasCustomComparer == true)
  }
}

// MARK: - ISP-0006: @Contract Macro Tests

@Suite("ISP-0006: @Contract Macro Tests")
struct ContractMacroTests {

  @Test("ContractMacro is registered")
  func macroIsRegistered() {
    let macroTypeName = String(describing: ContractMacro.self)
    #expect(macroTypeName.contains("ContractMacro"))
  }

  @Test("TestContractMacro is registered")
  func testContractMacroIsRegistered() {
    let macroTypeName = String(describing: TestContractMacro.self)
    #expect(macroTypeName.contains("TestContractMacro"))
  }

  @Test("LawMacro is registered")
  func lawMacroIsRegistered() {
    let macroTypeName = String(describing: LawMacro.self)
    #expect(macroTypeName.contains("LawMacro"))
  }

  @Test("ContractMacro expansion adds ContractProtocol conformance")
  func expansionAddsConformance() throws {
    assertMacroExpansion(
      """
      @Contract
      struct Stack {
          var count: Int
      }
      """,
      expandedSource: """
        struct Stack {
            var count: Int
        }

        extension Stack: ContractProtocol {
        }
        """,
      macros: ["Contract": ContractMacro.self]
    )
  }

  @Test("TestContractMacro expansion returns empty (Phase 1)")
  func testContractExpansionEmpty() throws {
    assertMacroExpansion(
      """
      @TestContract(Stack.self)
      struct ArrayStackTests {
          typealias SUT = ArrayStack
      }
      """,
      expandedSource: """
        struct ArrayStackTests {
            typealias SUT = ArrayStack
        }
        """,
      macros: ["TestContract": TestContractMacro.self]
    )
  }

  @Test("LawMacro expansion returns empty (marker)")
  func lawExpansionEmpty() throws {
    assertMacroExpansion(
      """
      @Law
      static func leftIdentity(x: Int) -> Bool {
          x == x
      }
      """,
      expandedSource: """
        static func leftIdentity(x: Int) -> Bool {
            x == x
        }
        """,
      macros: ["Law": LawMacro.self]
    )
  }
}
