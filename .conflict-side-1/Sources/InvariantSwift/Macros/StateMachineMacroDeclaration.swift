import Foundation
import InvariantCore
/// Automatically derives StateMachine conformance for model-based testing.
///
/// `@StateMachine` enables automatic generation of command enums and state machine
/// protocol conformance from annotated structs. Methods marked with `@Command`
/// become cases in the generated command enum.
///
/// **Basic Usage:**
/// ```swift
/// @StateMachine
/// struct CounterModel {
///     var count: Int = 0
///
///     @Command
///     mutating func increment() { count += 1 }
///
///     @Command
///     mutating func decrement() { guard count > 0 else { return }; count -= 1 }
/// }
/// ```
///
/// **Generated Output:**
/// - `CounterModelCommand` enum with `increment` and `decrement` cases
/// - `StateMachine` protocol conformance with `initialState`, `generateCommand`, `invariant`
/// - `Command` protocol conformance on the generated enum
///
/// **With Preconditions:**
/// ```swift
/// @StateMachine
/// struct StackModel<T> {
///     var items: [T] = []
///
///     @Command
///     mutating func push(_ value: T) { items.append(value) }
///
///     @Command(precondition: !items.isEmpty)
///     mutating func pop() -> T? { items.popLast() }
/// }
/// ```
///
/// - See Also: ``Command``, ``StateMachine``, ``ModelTestRunner``
@attached(member, names: arbitrary, named(initialState), named(generateCommand), named(invariant))
@attached(extension, conformances: RuleBasedStateMachine)
public macro StateMachine() =
  #externalMacro(module: "InvariantSwiftMacros", type: "StateMachineMacro")

/// Marks a method as a command in a `@StateMachine` annotated type.
///
/// Methods marked with `@Command` will be included as cases in the generated
/// command enum. The macro extracts parameter information to generate
/// appropriate enum associated values.
///
/// **Basic Usage:**
/// ```swift
/// @Command
/// mutating func increment() { count += 1 }
/// ```
///
/// **With Precondition:**
/// ```swift
/// @Command(precondition: count > 0)
/// mutating func decrement() { count -= 1 }
/// ```
///
/// **With Parameters:**
/// ```swift
/// @Command
/// mutating func add(value: Int) { total += value }
/// // Generates: case add(value: Int)
/// ```
///
/// - Parameter precondition: Optional condition that must be true for the command
///   to be applicable in a given state (default: true)
///
/// - See Also: ``StateMachine``
@attached(peer)
public macro Command(
  precondition: @autoclosure () -> Bool = true
) = #externalMacro(module: "InvariantSwiftMacros", type: "CommandMacro")
