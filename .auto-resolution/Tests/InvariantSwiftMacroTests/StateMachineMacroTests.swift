// swiftlint:disable file_length
// Justification: Comprehensive state machine macro expansion tests require complete golden outputs
import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class StateMachineMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "StateMachine": StateMachineMacro.self,
    "Command": CommandMacro.self,
  ]

  // MARK: - Basic Expansion Tests

  func testBasicCounterExpansion() {
    assertMacroExpansion(
      """
      @StateMachine
      struct CounterModel {
          var count: Int = 0

          @Command
          mutating func increment() { count += 1 }

          @Command
          mutating func decrement() { count -= 1 }
      }
      """,
      expandedSource: """
        struct CounterModel {
            var count: Int = 0
            mutating func increment() { count += 1 }
            mutating func decrement() { count -= 1 }

            public enum CounterModelCommand {
                case increment
                case decrement
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<CounterModelCommand> {
                Gen.oneOf([Gen.pure(CounterModelCommand.increment), Gen.pure(CounterModelCommand.decrement)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension CounterModel: StateMachine {
        }

        extension CounterModel.CounterModelCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .increment:
                    return true

                case .decrement:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .increment:
                    let newState = state
                    return newState

                case .decrement:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testCommandWithParameters() {
    assertMacroExpansion(
      """
      @StateMachine
      struct CalculatorModel {
          var total: Int = 0

          @Command
          mutating func add(value: Int) { total += value }
      }
      """,
      expandedSource: """
        struct CalculatorModel {
            var total: Int = 0
            mutating func add(value: Int) { total += value }

            public enum CalculatorModelCommand {
                case add(value: Int)
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<CalculatorModelCommand> {
                Gen.oneOf([Gen<Int>.int.map {
                            CalculatorModelCommand.add(value: $0)
                        }])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension CalculatorModel: StateMachine {
        }

        extension CalculatorModel.CalculatorModelCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .add(value: _):
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .add(value: _):
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMultipleStateFields() {
    assertMacroExpansion(
      """
      @StateMachine
      struct BankAccount {
          var balance: Int = 0
          var transactionCount: Int = 0

          @Command
          mutating func deposit(amount: Int) {
              balance += amount
              transactionCount += 1
          }
      }
      """,
      expandedSource: """
        struct BankAccount {
            var balance: Int = 0
            var transactionCount: Int = 0
            mutating func deposit(amount: Int) {
                balance += amount
                transactionCount += 1
            }

            public enum BankAccountCommand {
                case deposit(amount: Int)
            }

            public var initialState: (balance: Int , transactionCount: Int ) {
                (balance: 0, transactionCount: 0)
            }

            public func generateCommand(state: State) -> Gen<BankAccountCommand> {
                Gen.oneOf([Gen<Int>.int.map {
                            BankAccountCommand.deposit(amount: $0)
                        }])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension BankAccount: StateMachine {
        }

        extension BankAccount.BankAccountCommand: Command {
            public typealias State = (balance: Int , transactionCount: Int )
            public func precondition(state: State) -> Bool {
                switch self {
                case .deposit(amount: _):
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .deposit(amount: _):
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Diagnostic Tests

  func testMustBeAppliedToStruct() {
    assertMacroExpansion(
      """
      @StateMachine
      class NotAStruct {
          var value: Int = 0
      }
      """,
      expandedSource: """
        class NotAStruct {
            var value: Int = 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StateMachine can only be applied to structs",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testRequiresAtLeastOneCommand() {
    assertMacroExpansion(
      """
      @StateMachine
      struct NoCommands {
          var value: Int = 0
      }
      """,
      expandedSource: """
        struct NoCommands {
            var value: Int = 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StateMachine requires at least one @Command method",
          line: 2,
          column: 8
        )
      ],
      macros: testMacros
    )
  }

  func testCannotApplyToEnum() {
    assertMacroExpansion(
      """
      @StateMachine
      enum InvalidEnum {
          case a
          case b
      }
      """,
      expandedSource: """
        enum InvalidEnum {
            case a
            case b
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StateMachine can only be applied to structs",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testCannotApplyToActor() {
    assertMacroExpansion(
      """
      @StateMachine
      actor InvalidActor {
          var value: Int = 0
      }
      """,
      expandedSource: """
        actor InvalidActor {
            var value: Int = 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StateMachine can only be applied to structs",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testCannotApplyToProtocol() {
    assertMacroExpansion(
      """
      @StateMachine
      protocol InvalidProtocol {
          var value: Int { get }
      }
      """,
      expandedSource: """
        protocol InvalidProtocol {
            var value: Int { get }
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@StateMachine can only be applied to structs",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  // MARK: - Edge Case Tests

  func testSingleCommand() {
    assertMacroExpansion(
      """
      @StateMachine
      struct SingleCommand {
          var value: Int = 0

          @Command
          mutating func update() { value += 1 }
      }
      """,
      expandedSource: """
        struct SingleCommand {
            var value: Int = 0
            mutating func update() { value += 1 }

            public enum SingleCommandCommand {
                case update
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<SingleCommandCommand> {
                Gen.oneOf([Gen.pure(SingleCommandCommand.update)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension SingleCommand: StateMachine {
        }

        extension SingleCommand.SingleCommandCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .update:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .update:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testCommandWithMultipleParameters() {
    assertMacroExpansion(
      """
      @StateMachine
      struct MultiParamModel {
          var x: Int = 0

          @Command
          mutating func move(dx: Int, dy: Int) { x += dx }
      }
      """,
      expandedSource: """
        struct MultiParamModel {
            var x: Int = 0
            mutating func move(dx: Int, dy: Int) { x += dx }

            public enum MultiParamModelCommand {
                case move(dx: Int, dy: Int)
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<MultiParamModelCommand> {
                Gen.oneOf([Gen<Int>.int.map {
                            MultiParamModelCommand.move(dx: $0)
                        }])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension MultiParamModel: StateMachine {
        }

        extension MultiParamModel.MultiParamModelCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .move(dx: _, dy: _):
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .move(dx: _, dy: _):
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMixedCommandsWithAndWithoutParameters() {
    assertMacroExpansion(
      """
      @StateMachine
      struct MixedCommands {
          var count: Int = 0

          @Command
          mutating func reset() { count = 0 }

          @Command
          mutating func set(to value: Int) { count = value }

          @Command
          mutating func increment() { count += 1 }
      }
      """,
      expandedSource: """
        struct MixedCommands {
            var count: Int = 0
            mutating func reset() { count = 0 }
            mutating func set(to value: Int) { count = value }
            mutating func increment() { count += 1 }

            public enum MixedCommandsCommand {
                case reset
                case set(value: Int)
                case increment
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<MixedCommandsCommand> {
                Gen.oneOf([Gen.pure(MixedCommandsCommand.reset), Gen<Int>.int.map {
                            MixedCommandsCommand.set(value: $0)
                        }, Gen.pure(MixedCommandsCommand.increment)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension MixedCommands: StateMachine {
        }

        extension MixedCommands.MixedCommandsCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .reset:
                    return true

                case .set(value: _):
                    return true

                case .increment:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .reset:
                    let newState = state
                    return newState

                case .set(value: _):
                    let newState = state
                    return newState

                case .increment:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testStateFieldWithoutDefaultValue() {
    assertMacroExpansion(
      """
      @StateMachine
      struct NoDefaultModel {
          var value: String = ""

          @Command
          mutating func clear() { value = "" }
      }
      """,
      expandedSource: """
        struct NoDefaultModel {
            var value: String = ""
            mutating func clear() { value = "" }

            public enum NoDefaultModelCommand {
                case clear
            }

            public var initialState: String {
                ""
            }

            public func generateCommand(state: State) -> Gen<NoDefaultModelCommand> {
                Gen.oneOf([Gen.pure(NoDefaultModelCommand.clear)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension NoDefaultModel: StateMachine {
        }

        extension NoDefaultModel.NoDefaultModelCommand: Command {
            public typealias State = String
            public func precondition(state: State) -> Bool {
                switch self {
                case .clear:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .clear:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testBoolStateField() {
    assertMacroExpansion(
      """
      @StateMachine
      struct ToggleModel {
          var isOn: Bool = false

          @Command
          mutating func toggle() { isOn.toggle() }
      }
      """,
      expandedSource: """
        struct ToggleModel {
            var isOn: Bool = false
            mutating func toggle() { isOn.toggle() }

            public enum ToggleModelCommand {
                case toggle
            }

            public var initialState: Bool {
                false
            }

            public func generateCommand(state: State) -> Gen<ToggleModelCommand> {
                Gen.oneOf([Gen.pure(ToggleModelCommand.toggle)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension ToggleModel: StateMachine {
        }

        extension ToggleModel.ToggleModelCommand: Command {
            public typealias State = Bool
            public func precondition(state: State) -> Bool {
                switch self {
                case .toggle:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .toggle:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testDoubleStateField() {
    assertMacroExpansion(
      """
      @StateMachine
      struct DoubleModel {
          var value: Double = 0.0

          @Command
          mutating func add(amount: Double) { value += amount }
      }
      """,
      expandedSource: """
        struct DoubleModel {
            var value: Double = 0.0
            mutating func add(amount: Double) { value += amount }

            public enum DoubleModelCommand {
                case add(amount: Double)
            }

            public var initialState: Double {
                0.0
            }

            public func generateCommand(state: State) -> Gen<DoubleModelCommand> {
                Gen.oneOf([Gen<Double>.double.map {
                            DoubleModelCommand.add(amount: $0)
                        }])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension DoubleModel: StateMachine {
        }

        extension DoubleModel.DoubleModelCommand: Command {
            public typealias State = Double
            public func precondition(state: State) -> Bool {
                switch self {
                case .add(amount: _):
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .add(amount: _):
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMethodsWithoutCommandAttributeAreIgnored() {
    assertMacroExpansion(
      """
      @StateMachine
      struct HelperMethodModel {
          var value: Int = 0

          @Command
          mutating func increment() { value += 1 }

          func helperMethod() -> Int { value * 2 }

          private func privateHelper() { }
      }
      """,
      expandedSource: """
        struct HelperMethodModel {
            var value: Int = 0
            mutating func increment() { value += 1 }

            func helperMethod() -> Int { value * 2 }

            private func privateHelper() { }

            public enum HelperMethodModelCommand {
                case increment
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<HelperMethodModelCommand> {
                Gen.oneOf([Gen.pure(HelperMethodModelCommand.increment)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension HelperMethodModel: StateMachine {
        }

        extension HelperMethodModel.HelperMethodModelCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .increment:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .increment:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  func testLetPropertiesAreIgnored() {
    assertMacroExpansion(
      """
      @StateMachine
      struct ConstantModel {
          let constant: Int = 42
          var mutableValue: Int = 0

          @Command
          mutating func update() { mutableValue += constant }
      }
      """,
      expandedSource: """
        struct ConstantModel {
            let constant: Int = 42
            var mutableValue: Int = 0
            mutating func update() { mutableValue += constant }

            public enum ConstantModelCommand {
                case update
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<ConstantModelCommand> {
                Gen.oneOf([Gen.pure(ConstantModelCommand.update)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension ConstantModel: StateMachine {
        }

        extension ConstantModel.ConstantModelCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .update:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .update:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Command Macro Standalone Tests

  func testCommandMacroProducesNoPeers() {
    assertMacroExpansion(
      """
      @Command
      mutating func standalone() { }
      """,
      expandedSource: """
        mutating func standalone() { }
        """,
      macros: testMacros
    )
  }

  // MARK: - Many Commands Test

  func testManyCommands() {
    assertMacroExpansion(
      """
      @StateMachine
      struct ManyCommands {
          var a: Int = 0

          @Command
          mutating func cmd1() { a += 1 }

          @Command
          mutating func cmd2() { a += 2 }

          @Command
          mutating func cmd3() { a += 3 }

          @Command
          mutating func cmd4() { a += 4 }

          @Command
          mutating func cmd5() { a += 5 }
      }
      """,
      expandedSource: """
        struct ManyCommands {
            var a: Int = 0
            mutating func cmd1() { a += 1 }
            mutating func cmd2() { a += 2 }
            mutating func cmd3() { a += 3 }
            mutating func cmd4() { a += 4 }
            mutating func cmd5() { a += 5 }

            public enum ManyCommandsCommand {
                case cmd1
                case cmd2
                case cmd3
                case cmd4
                case cmd5
            }

            public var initialState: Int {
                0
            }

            public func generateCommand(state: State) -> Gen<ManyCommandsCommand> {
                Gen.oneOf([Gen.pure(ManyCommandsCommand.cmd1), Gen.pure(ManyCommandsCommand.cmd2), Gen.pure(ManyCommandsCommand.cmd3), Gen.pure(ManyCommandsCommand.cmd4), Gen.pure(ManyCommandsCommand.cmd5)])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension ManyCommands: StateMachine {
        }

        extension ManyCommands.ManyCommandsCommand: Command {
            public typealias State = Int
            public func precondition(state: State) -> Bool {
                switch self {
                case .cmd1:
                    return true

                case .cmd2:
                    return true

                case .cmd3:
                    return true

                case .cmd4:
                    return true

                case .cmd5:
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .cmd1:
                    let newState = state
                    return newState

                case .cmd2:
                    let newState = state
                    return newState

                case .cmd3:
                    let newState = state
                    return newState

                case .cmd4:
                    let newState = state
                    return newState

                case .cmd5:
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - String Parameter Tests

  func testStringParameter() {
    assertMacroExpansion(
      """
      @StateMachine
      struct StringModel {
          var text: String = ""

          @Command
          mutating func append(s: String) { text += s }
      }
      """,
      expandedSource: """
        struct StringModel {
            var text: String = ""
            mutating func append(s: String) { text += s }

            public enum StringModelCommand {
                case append(s: String)
            }

            public var initialState: String {
                ""
            }

            public func generateCommand(state: State) -> Gen<StringModelCommand> {
                Gen.oneOf([Gen<String>.string.map {
                            StringModelCommand.append(s: $0)
                        }])
            }

            public func invariant(state: State) -> Bool {
                true
            }
        }

        extension StringModel: StateMachine {
        }

        extension StringModel.StringModelCommand: Command {
            public typealias State = String
            public func precondition(state: State) -> Bool {
                switch self {
                case .append(s: _):
                    return true
                }
            }
            public func execute() async throws -> Void {
            }
            public func apply(state: State) -> State {
                switch self {
                case .append(s: _):
                    let newState = state
                    return newState
                }
            }
            public func postcondition(state: State, result: Void) -> Bool {
                true
            }
        }
        """,
      macros: testMacros
    )
  }
}
