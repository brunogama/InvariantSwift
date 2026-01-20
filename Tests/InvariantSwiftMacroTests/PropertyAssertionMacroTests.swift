import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InvariantSwiftMacros

@Suite("Property Assertion Macros")
struct PropertyAssertionMacroTests {

  let testMacros: [String: Macro.Type] = [
    "Idempotent": IdempotentMacro.self,
    "Deterministic": DeterministicMacro.self,
    "Pure": PureMacro.self,
  ]

  // MARK: - @Idempotent Tests

  @Test("@Idempotent generates idempotency test for single parameter")
  func testIdempotentBasic() {
    assertMacroExpansion(
      """
      @Idempotent
      func normalize(_ value: Int) -> Int {
        abs(value)
      }
      """,
      expandedSource: """
        func normalize(_ value: Int) -> Int {
          abs(value)
        }

        private enum normalize_IdempotentTest {
          @Test("normalize")
          static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              var current = normalize(value)
              for _ in 1..<2 {
                current = normalize(current)
              }
              let next = normalize(current)
              return current == next
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Idempotency property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Idempotent generates flatMap chain for multiple parameters")
  func testIdempotentMultipleParameters() {
    assertMacroExpansion(
      """
      @Idempotent
      func combine(_ a: Int, _ b: String) -> String {
        "\\(a)-\\(b)"
      }
      """,
      expandedSource: """
        func combine(_ a: Int, _ b: String) -> String {
          "\\(a)-\\(b)"
        }

        private enum combine_IdempotentTest {
          @Test("combine")
          static func run() throws {
            let generator: Gen<(Int, String)> = Gen<Int>.int.flatMap { a in
              Gen<String>.string.map { b in (a, b) }
            }
            let property = Property(generator: generator) { (a: Int, b: String) in
              let (a, b) = (a, b)
              var current = combine(a, b)
              for _ in 1..<2 {
                current = combine(current)
              }
              let next = combine(current)
              return current == next
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Idempotency property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Idempotent generates await for async functions")
  func testIdempotentAsync() {
    assertMacroExpansion(
      """
      @Idempotent
      func normalize(_ value: Int) async -> Int {
        abs(value)
      }
      """,
      expandedSource: """
        func normalize(_ value: Int) async -> Int {
          abs(value)
        }

        private enum normalize_IdempotentTest {
          @Test("normalize")
          static func run() async throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              var current = await normalize(value)
              for _ in 1..<2 {
                current = await normalize(current)
              }
              let next = await normalize(current)
              return current == next
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = await runPropertyAsync(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Idempotency property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Idempotent respects custom applicationCount parameter")
  func testIdempotentCustomApplicationCount() {
    assertMacroExpansion(
      """
      @Idempotent(applicationCount: 5)
      func normalize(_ value: Int) -> Int {
        abs(value)
      }
      """,
      expandedSource: """
        func normalize(_ value: Int) -> Int {
          abs(value)
        }

        private enum normalize_IdempotentTest {
          @Test("normalize")
          static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              var current = normalize(value)
              for _ in 1..<5 {
                current = normalize(current)
              }
              let next = normalize(current)
              return current == next
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Idempotency property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Idempotent diagnostic: applied to non-function")
  func testIdempotentDiagnosticNonFunction() {
    assertMacroExpansion(
      """
      @Idempotent
      struct MyStruct {
        let value: Int
      }
      """,
      expandedSource: """
        struct MyStruct {
          let value: Int
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Property assertion macros can only be applied to functions",
          line: 1,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - @Deterministic Tests

  @Test("@Deterministic generates determinism test for single parameter")
  func testDeterministicBasic() {
    assertMacroExpansion(
      """
      @Deterministic
      func hash(_ value: String) -> Int {
        value.hashValue
      }
      """,
      expandedSource: """
        func hash(_ value: String) -> Int {
          value.hashValue
        }

        private enum hash_DeterministicTest {
          @Test("hash")
          static func run() throws {
            let generator: Gen<String> = Gen<String>.string
            let property = Property(generator: generator) { value in
              let call1 = hash(value)
              let call2 = hash(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Determinism property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Deterministic generates flatMap chain for multiple parameters")
  func testDeterministicMultipleParameters() {
    assertMacroExpansion(
      """
      @Deterministic
      func concat(_ a: String, _ b: String) -> String {
        a + b
      }
      """,
      expandedSource: """
        func concat(_ a: String, _ b: String) -> String {
          a + b
        }

        private enum concat_DeterministicTest {
          @Test("concat")
          static func run() throws {
            let generator: Gen<(String, String)> = Gen<String>.string.flatMap { a in
              Gen<String>.string.map { b in (a, b) }
            }
            let property = Property(generator: generator) { (a: String, b: String) in
              let call1 = concat(a, b)
              let call2 = concat(a, b)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Determinism property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Deterministic generates await for async functions")
  func testDeterministicAsync() {
    assertMacroExpansion(
      """
      @Deterministic
      func hash(_ value: String) async -> Int {
        value.hashValue
      }
      """,
      expandedSource: """
        func hash(_ value: String) async -> Int {
          value.hashValue
        }

        private enum hash_DeterministicTest {
          @Test("hash")
          static func run() async throws {
            let generator: Gen<String> = Gen<String>.string
            let property = Property(generator: generator) { value in
              let call1 = await hash(value)
              let call2 = await hash(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = await runPropertyAsync(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Determinism property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Deterministic respects custom callCount parameter")
  func testDeterministicCustomCallCount() {
    assertMacroExpansion(
      """
      @Deterministic(callCount: 3)
      func hash(_ value: String) -> Int {
        value.hashValue
      }
      """,
      expandedSource: """
        func hash(_ value: String) -> Int {
          value.hashValue
        }

        private enum hash_DeterministicTest {
          @Test("hash")
          static func run() throws {
            let generator: Gen<String> = Gen<String>.string
            let property = Property(generator: generator) { value in
              let call1 = hash(value)
              let call2 = hash(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Determinism property violated"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Deterministic diagnostic: no parameters")
  func testDeterministicDiagnosticNoParameters() {
    assertMacroExpansion(
      """
      @Deterministic
      func noParams() -> Int {
        42
      }
      """,
      expandedSource: """
        func noParams() -> Int {
          42
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function must have at least one parameter for property testing",
          line: 2,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - @Pure Tests

  @Test("@Pure generates determinism test for single parameter")
  func testPureBasic() {
    assertMacroExpansion(
      """
      @Pure
      func double(_ value: Int) -> Int {
        value * 2
      }
      """,
      expandedSource: """
        func double(_ value: Int) -> Int {
          value * 2
        }

        private enum double_PureTest {
          @Test("double")
          static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              let call1 = double(value)
              let call2 = double(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Purity property violated (non-deterministic)"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Pure generates flatMap chain for multiple parameters")
  func testPureMultipleParameters() {
    assertMacroExpansion(
      """
      @Pure
      func add(_ a: Int, _ b: Int) -> Int {
        a + b
      }
      """,
      expandedSource: """
        func add(_ a: Int, _ b: Int) -> Int {
          a + b
        }

        private enum add_PureTest {
          @Test("add")
          static func run() throws {
            let generator: Gen<(Int, Int)> = Gen<Int>.int.flatMap { a in
              Gen<Int>.int.map { b in (a, b) }
            }
            let property = Property(generator: generator) { (a: Int, b: Int) in
              let call1 = add(a, b)
              let call2 = add(a, b)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Purity property violated (non-deterministic)"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Pure generates await for async functions")
  func testPureAsync() {
    assertMacroExpansion(
      """
      @Pure
      func double(_ value: Int) async -> Int {
        value * 2
      }
      """,
      expandedSource: """
        func double(_ value: Int) async -> Int {
          value * 2
        }

        private enum double_PureTest {
          @Test("double")
          static func run() async throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              let call1 = await double(value)
              let call2 = await double(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
            let result = await runPropertyAsync(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Purity property violated (non-deterministic)"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Pure respects custom iterations parameter")
  func testPureCustomIterations() {
    assertMacroExpansion(
      """
      @Pure(iterations: 200)
      func double(_ value: Int) -> Int {
        value * 2
      }
      """,
      expandedSource: """
        func double(_ value: Int) -> Int {
          value * 2
        }

        private enum double_PureTest {
          @Test("double")
          static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { value in
              let call1 = double(value)
              let call2 = double(value)
              return call1 == call2
            }
            let config = PropertyConfig(iterations: 200, maxShrinks: 1000)
            let result = runPropertySynchronously(property, config: config)
            switch result {
            case .success:
              break

            case .failure(counterexample: _, iterations: _, shrunk: _, reason: _, seed: _):
              Issue.record(Comment(stringLiteral: "Purity property violated (non-deterministic)"))

            case .gaveUp(discarded: _, iterations: _):
              Issue.record(Comment(stringLiteral: "Property test gave up"))
            }
          }
        }
        """,
      macros: testMacros
    )
  }

  @Test("@Pure diagnostic: Void return type (allowed but generates useless test)")
  func testPureDiagnosticVoidReturn() {
    assertMacroExpansion(
      """
      @Pure
      func doNothing(_ value: Int) -> Void {
        print("side effect")
      }
      """,
      expandedSource: """
        func doNothing(_ value: Int) -> Void {
          print("side effect")
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "Function must return a value (Void return type not allowed)",
          line: 2,
          column: 1,
          severity: .error
        )
      ],
      macros: testMacros
    )
  }
}
