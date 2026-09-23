/// Expansion of `@StateMachine` for state fields, ignored members and larger command sets.
///
/// Split from `StateMachineMacroTests` so neither class carries a body over the budget.
import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class StateMachineMacroStateTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "StateMachine": StateMachineMacro.self,
    "Command": CommandMacro.self,
  ]

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
