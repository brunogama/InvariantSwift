// GeneratorRegistry.swift
// InvariantSwift
//
// Actor-based thread-safe registry for custom generator registration.
// Implements Task 1.7 from the roadmap.

import Foundation
import InvariantSwiftCore

// MARK: - Generator Registration Types

/// A type-erased generator wrapper for storage in the registry.
///
/// This allows storing generators for different types in a single collection
/// while maintaining type safety at lookup time.
public struct AnyGenerator: Sendable {
  private let _generate: @Sendable (inout any RandomNumberGenerator, Size) -> Any
  private let _shrink: @Sendable (Any) -> [Any]

  /// The metatype of the generated value.
  public let valueType: Any.Type

  /// Creates a type-erased generator from a typed generator.
  ///
  /// - Parameter generator: The typed generator to wrap.
  public init<T>(_ generator: Gen<T>) {
    self.valueType = T.self
    self._generate = { rng, size in
      generator.generate(&rng, size)
    }
    self._shrink = { value in
      guard let typed = value as? T else { return [] }
      return generator.shrink.shrink(typed).map { $0 as Any }
    }
  }

  /// Attempts to cast back to a typed generator.
  ///
  /// - Returns: The typed generator if the type matches, otherwise nil.
  public func typed<T>() -> Gen<T>? {
    guard valueType == T.self else { return nil }
    return Gen<T>(
      generate: { rng, size in
        self._generate(&rng, size) as! T  // swiftlint:disable:this force_cast
      },
      shrink: Shrink<T> { value in
        self._shrink(value).compactMap { $0 as? T }
      }
    )
  }
}

// MARK: - Registry Scope

/// Defines the scope of a generator registration.
///
/// Scopes allow for layered generator registrations where test-local
/// registrations can override global defaults.
public enum RegistryScope: Sendable, Hashable {
  /// Global scope - available throughout the application.
  case global

  /// Test-local scope - only available within current test context.
  case testLocal(id: String)

  /// Creates a test-local scope with a unique identifier.
  public static func testLocal() -> Self {
    .testLocal(id: UUID().uuidString)
  }
}

// MARK: - Generator Registry

/// Thread-safe registry for custom generator registration and lookup.
///
/// `GeneratorRegistry` provides a centralized place to register generators for
/// custom types, enabling automatic generator selection in property-based tests.
///
/// The registry supports scoped registrations:
/// - **Global scope**: Generators available throughout the application
/// - **Test-local scope**: Generators available only within a specific test
///
/// Thread safety is guaranteed through actor isolation.
///
/// ## Example Usage
///
/// ```swift
/// // Register a generator for a custom type
/// struct User { let id: Int; let name: String }
///
/// let userGen = Gen<User> { rng, size in
///     User(
///         id: Int.random(in: 1...1000, using: &rng),
///         name: "User\(Int.random(in: 1...100, using: &rng))"
///     )
/// }
///
/// await GeneratorRegistry.shared.register(for: User.self, generator: userGen)
///
/// // Later, lookup the generator
/// if let gen: Gen<User> = await GeneratorRegistry.shared.lookup(for: User.self) {
///     let user = gen.sample()
/// }
/// ```
///
/// - See Also: ``Gen``, ``AnyGenerator``, ``RegistryScope``
public actor GeneratorRegistry {

  // MARK: - Singleton

  /// The shared global registry instance.
  public static let shared = GeneratorRegistry()

  // MARK: - Storage

  /// Storage for registered generators, keyed by type identifier and scope.
  private var registrations: [ObjectIdentifier: [RegistryScope: AnyGenerator]] = [:]

  /// Stack of active scopes for hierarchical lookup.
  private var activeScopes: [RegistryScope] = [.global]

  // MARK: - Initialization

  /// Creates a new generator registry.
  public init() {}

  // MARK: - Registration

  /// Registers a generator for a specific type.
  ///
  /// If a generator is already registered for this type in the given scope,
  /// it will be replaced.
  ///
  /// - Parameters:
  ///   - type: The type to register a generator for.
  ///   - generator: The generator to register.
  ///   - scope: The scope of the registration (default: global).
  ///
  /// - Example:
  ///   ```swift
  ///   await registry.register(for: User.self, generator: userGen)
  ///   await registry.register(for: Config.self, generator: configGen, scope: .testLocal())
  ///   ```
  public func register<T>(
    for type: T.Type,
    generator: Gen<T>,
    scope: RegistryScope = .global
  ) {
    let key = ObjectIdentifier(type)
    var scopedRegistrations = registrations[key] ?? [:]
    scopedRegistrations[scope] = AnyGenerator(generator)
    registrations[key] = scopedRegistrations
  }

  /// Looks up a registered generator for a type.
  ///
  /// Lookup proceeds from the most specific scope to the most general:
  /// 1. First, check active test-local scopes (most recent first)
  /// 2. Then, check global scope
  ///
  /// - Parameter type: The type to look up a generator for.
  /// - Returns: The registered generator, or nil if none is registered.
  ///
  /// - Example:
  ///   ```swift
  ///   if let gen: Gen<User> = await registry.lookup(for: User.self) {
  ///       let user = gen.sample()
  ///   }
  ///   ```
  public func lookup<T>(for type: T.Type) -> Gen<T>? {
    let key = ObjectIdentifier(type)
    guard let scopedRegistrations = registrations[key] else { return nil }

    // Search from most specific to most general scope
    for scope in activeScopes.reversed() {
      if let anyGen = scopedRegistrations[scope],
        let typedGen: Gen<T> = anyGen.typed()
      {
        return typedGen
      }
    }

    // Fall back to global if not in active scopes
    if let anyGen = scopedRegistrations[.global],
      let typedGen: Gen<T> = anyGen.typed()
    {
      return typedGen
    }

    return nil
  }

  /// Deregisters a generator for a type.
  ///
  /// - Parameters:
  ///   - type: The type to deregister.
  ///   - scope: The scope to deregister from (default: global).
  ///
  /// - Example:
  ///   ```swift
  ///   await registry.deregister(for: User.self)
  ///   await registry.deregister(for: Config.self, scope: testScope)
  ///   ```
  public func deregister<T>(for type: T.Type, scope: RegistryScope = .global) {
    let key = ObjectIdentifier(type)
    registrations[key]?[scope] = nil

    // Clean up empty dictionaries
    if registrations[key]?.isEmpty == true {
      registrations[key] = nil
    }
  }

  /// Checks if a generator is registered for a type.
  ///
  /// - Parameters:
  ///   - type: The type to check.
  ///   - scope: Optional scope to check. If nil, checks all scopes.
  /// - Returns: True if a generator is registered.
  public func isRegistered<T>(for type: T.Type, scope: RegistryScope? = nil) -> Bool {
    let key = ObjectIdentifier(type)
    guard let scopedRegistrations = registrations[key] else { return false }

    if let scope = scope {
      return scopedRegistrations[scope] != nil
    }
    return !scopedRegistrations.isEmpty
  }

  // MARK: - Scope Management

  /// Pushes a new scope onto the active scope stack.
  ///
  /// This is used to create layered registrations where test-local
  /// generators can override global ones.
  ///
  /// - Parameter scope: The scope to activate.
  public func pushScope(_ scope: RegistryScope) {
    activeScopes.append(scope)
  }

  /// Pops the most recent scope from the active scope stack.
  ///
  /// - Returns: The popped scope, or nil if only global scope remains.
  @discardableResult
  public func popScope() -> RegistryScope? {
    guard activeScopes.count > 1 else { return nil }
    return activeScopes.removeLast()
  }

  /// Executes a closure within a specific scope.
  ///
  /// The scope is automatically pushed before execution and popped after,
  /// even if the closure throws.
  ///
  /// - Parameters:
  ///   - scope: The scope to use during execution.
  ///   - operation: The closure to execute.
  /// - Returns: The result of the closure.
  /// - Throws: Rethrows any error from the closure.
  ///
  /// - Example:
  ///   ```swift
  ///   let result = await registry.withScope(.testLocal()) {
  ///       await registry.register(for: User.self, generator: testUserGen)
  ///       return runTest()
  ///   }
  ///   ```
  public func withScope<R>(
    _ scope: RegistryScope,
    operation: () async throws -> R
  ) async rethrows -> R {
    pushScope(scope)
    defer { popScope() }
    return try await operation()
  }

  // MARK: - Bulk Operations

  /// Clears all registrations.
  ///
  /// - Parameter scope: Optional scope to clear. If nil, clears all scopes.
  public func clearAll(scope: RegistryScope? = nil) {
    if let scope = scope {
      for key in registrations.keys {
        registrations[key]?[scope] = nil
        if registrations[key]?.isEmpty == true {
          registrations[key] = nil
        }
      }
    } else {
      registrations.removeAll()
    }
  }

  /// Returns all registered type names.
  ///
  /// Useful for debugging and introspection.
  public var registeredTypes: [String] {
    registrations.keys.map { String(describing: $0) }
  }

  /// Returns the count of registered generators.
  public var registrationCount: Int {
    registrations.values.reduce(0) { $0 + $1.count }
  }
}

// MARK: - Convenience Extensions

extension Gen {
  /// Registers this generator in the shared registry.
  ///
  /// - Parameter scope: The scope to register in (default: global).
  ///
  /// - Example:
  ///   ```swift
  ///   userGen.register(scope: .global)
  ///   ```
  public func register(scope: RegistryScope = .global) async {
    await GeneratorRegistry.shared.register(for: T.self, generator: self, scope: scope)
  }

  /// Looks up a generator for this type from the shared registry.
  ///
  /// - Returns: The registered generator, or nil if none exists.
  public static func fromRegistry() async -> Gen<T>? {
    await GeneratorRegistry.shared.lookup(for: T.self)
  }
}
