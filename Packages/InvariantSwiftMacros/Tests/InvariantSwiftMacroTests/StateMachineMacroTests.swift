/// Expansion of `@StateMachine` for counters, commands and command parameters.
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
}
