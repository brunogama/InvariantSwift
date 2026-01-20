import InvariantSwift
import InvariantSwiftExperimental
import InvariantSwiftCore
import Foundation

/// Automatically generates property-based tests for mathematical laws.
///
/// Supported laws:
/// - Functor: identity, composition
/// - Applicative: identity, composition, homomorphism, interchange
/// - Monad: left identity, right identity, associativity
/// - Semigroup: associativity
/// - Monoid: left identity, right identity
/// - Group: identity, inverse, associativity
/// - Ring: additive and multiplicative properties
/// - Field: division and multiplicative inverse
/// - Partial Order: reflexivity, antisymmetry, transitivity
/// - Total Order: totality in addition to partial order
/// - Lattice: join and meet properties
/// - Metric: symmetry, identity, triangle inequality
/// - Norm: absolute homogeneity, triangle inequality, positive definiteness
/// - Foldable: fold laws
/// - Traversable: identity, composition
/// - Bifunctor: identity, composition
/// - Profunctor: identity, composition
/// - Comonad: extract and extend laws
///
/// Example:
/// ```swift
/// @LawChecked(laws: [.functor, .monad])
/// struct MyBox<T>: Functor, Monad {
///     let value: T
///     func map<U>(_ f: (T) -> U) -> MyBox<U> { ... }
///     func flatMap<U>(_ f: (T) -> MyBox<U>) -> MyBox<U> { ... }
/// }
/// ```
///
/// Custom laws can be specified:
/// ```swift
/// @LawChecked(customLaws: ["commutativity": "a + b == b + a"])
/// struct Addition: Semigroup { ... }
/// ```
@attached(member, names: arbitrary)
public macro LawChecked(
  laws: [MathematicalLaw] = [],
  customLaws: [String: String] = [:],
  iterations: Int = 100,
  size: Int = 50,
  enableShrinking: Bool = true,
  timeout: Double = 30.0
) = #externalMacro(module: "InvariantSwiftMacros", type: "LawCheckedMacro")

/// Mathematical laws available for verification with @LawChecked.
public enum MathematicalLaw: String, CaseIterable, Sendable {
  // Category Theory
  case functor
  case applicative
  case monad
  case comonad

  // Abstract Algebra
  case semigroup
  case monoid
  case group
  case ring
  case field

  // Order Theory
  case partialOrder
  case totalOrder
  case lattice

  // Topology
  case metric
  case norm

  // Special Structures
  case foldable
  case traversable
  case bifunctor
  case profunctor
}
