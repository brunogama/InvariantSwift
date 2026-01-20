import InvariantSwift
import InvariantSwiftExperimental
import InvariantSwiftCore
import Foundation
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
