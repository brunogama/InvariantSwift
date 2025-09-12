import Foundation

// MARK: - Lens Extensions for FunctionalTesting Configuration Objects

/// **PropertyConfig Lens System**
///
/// Provides lenses for immutable updates to PropertyConfig instances,
/// enabling functional configuration management without verbose boilerplate.
///
/// **Example Usage:**
/// ```swift
/// let config = PropertyConfig.default
/// let updated = PropertyConfig.iterations.set(500, config)
/// let doubled = PropertyConfig.iterations.over({ $0 * 2 })(config)
/// let chained = config
///     |> PropertyConfig.iterations.over({ $0 + 50 })
///     |> PropertyConfig.maxShrinks.set(2000)
/// ```
extension PropertyConfig {

  /// **Lens for iterations property**
  /// Focus on the number of test iterations
  public static let iterations = Lens<PropertyConfig, Int>(
    get: { $0.iterations },
    set: { newIterations, config in
      PropertyConfig(
        iterations: newIterations,
        maxShrinks: config.maxShrinks,
        maxDiscarded: config.maxDiscarded,
        seed: config.seed
      )
    }
  )

  /// **Lens for maxShrinks property**
  /// Focus on the maximum shrinking attempts
  public static let maxShrinks = Lens<PropertyConfig, Int>(
    get: { $0.maxShrinks },
    set: { newMaxShrinks, config in
      PropertyConfig(
        iterations: config.iterations,
        maxShrinks: newMaxShrinks,
        maxDiscarded: config.maxDiscarded,
        seed: config.seed
      )
    }
  )

  /// **Lens for maxDiscarded property**
  /// Focus on the maximum number of discarded test cases
  public static let maxDiscarded = Lens<PropertyConfig, Int>(
    get: { $0.maxDiscarded },
    set: { newMaxDiscarded, config in
      PropertyConfig(
        iterations: config.iterations,
        maxShrinks: config.maxShrinks,
        maxDiscarded: newMaxDiscarded,
        seed: config.seed
      )
    }
  )

  /// **Lens for seed property**
  /// Focus on the random seed (optional)
  public static let seed = Lens<PropertyConfig, Seed?>(
    get: { $0.seed },
    set: { newSeed, config in
      PropertyConfig(
        iterations: config.iterations,
        maxShrinks: config.maxShrinks,
        maxDiscarded: config.maxDiscarded,
        seed: newSeed
      )
    }
  )
}

/// **Functional PropertyConfig Utilities**
/// Convenience functions for common PropertyConfig modifications
extension PropertyConfig {

  /// **Scale iterations by a factor**
  /// - Parameter factor: Multiplication factor for iterations
  /// - Returns: Function that scales iterations
  public static func scaleIterations(by factor: Double) -> (PropertyConfig) -> PropertyConfig {
    iterations.over { Int(Double($0) * factor) }
  }

  /// **Enable deterministic testing with seed**
  /// - Parameter seedValue: Seed value for deterministic testing
  /// - Returns: Function that sets the seed
  public static func withSeed(_ seedValue: UInt64) -> (PropertyConfig) -> PropertyConfig {
    { config in seed.set(Seed(value: seedValue), config) }
  }

  /// **Configure for performance testing**
  /// High iterations, minimal shrinking for performance tests
  /// - Returns: Function that configures for performance testing
  public static let performanceConfig: @Sendable (PropertyConfig) -> PropertyConfig = { config in
    let step1 = iterations.set(10000, config)
    let step2 = maxShrinks.set(10, step1)
    let step3 = maxDiscarded.set(100, step2)
    return step3
  }

  /// **Configure for quick feedback**
  /// Low iterations, fast shrinking for development
  /// - Returns: Function that configures for quick feedback
  public static let quickConfig: @Sendable (PropertyConfig) -> PropertyConfig = { config in
    let step1 = iterations.set(20, config)
    let step2 = maxShrinks.set(50, step1)
    let step3 = maxDiscarded.set(50, step2)
    return step3
  }

  /// **Configure for exhaustive testing**
  /// High iterations and shrinking for thorough testing
  /// - Returns: Function that configures for exhaustive testing
  public static let exhaustiveConfig: @Sendable (PropertyConfig) -> PropertyConfig = { config in
    let step1 = iterations.set(1000, config)
    let step2 = maxShrinks.set(10000, step1)
    let step3 = maxDiscarded.set(5000, step2)
    return step3
  }
}

// MARK: - Size Lens System

/// **Size Lens System**
///
/// Lenses for the Size type used in generation control
extension Size {

  /// **Lens for size value**
  /// Focus on the integer value within Size
  public static let value = Lens<Size, Int>(
    get: { $0.value },
    set: { newValue, _ in Size(value: newValue) }
  )
}

/// **Functional Size Utilities**
extension Size {

  /// **Scale size by a factor**
  /// - Parameter factor: Multiplication factor
  /// - Returns: Function that scales the size
  public static func scale(by factor: Double) -> (Size) -> Size {
    value.over { Int(Double($0) * factor) }
  }

  /// **Clamp size to a range**
  /// - Parameter range: Allowed size range
  /// - Returns: Function that clamps size to range
  public static func clamp(to range: ClosedRange<Int>) -> (Size) -> Size {
    value.over { Swift.max(range.lowerBound, Swift.min(range.upperBound, $0)) }
  }

  /// **Add offset to size**
  /// - Parameter offset: Value to add
  /// - Returns: Function that adds offset to size
  public static func offset(by amount: Int) -> (Size) -> Size {
    value.over { $0 + amount }
  }
}

// MARK: - Seed Lens System

/// **Seed Lens System**
///
/// Lenses for the Seed type used for deterministic generation
extension Seed {

  /// **Lens for seedValue property**
  /// Focus on the UInt64 value within Seed
  public static let seedValue = Lens<Seed, UInt64>(
    get: { $0.value },
    set: { newValue, _ in Seed(value: newValue) }
  )
}

/// **Functional Seed Utilities**
extension Seed {

  /// **Increment seed value**
  /// - Parameter increment: Amount to add to seed
  /// - Returns: Function that increments seed
  public static func increment(by amount: UInt64) -> (Seed) -> Seed {
    seedValue.over { $0.addingReportingOverflow(amount).partialValue }
  }

  /// **Create seed from current timestamp**
  /// - Returns: Seed based on current time
  public static func fromCurrentTime() -> Seed {
    Seed(value: UInt64(Date().timeIntervalSince1970 * 1000))
  }

  /// **Create predictable seed sequence**
  /// - Parameter base: Base seed value
  /// - Returns: Function that creates nth seed in sequence
  public static func sequence(from base: UInt64) -> (Int) -> Seed {
    { index in
      Seed(value: base.addingReportingOverflow(UInt64(index)).partialValue)
    }
  }
}

// MARK: - Generic Configuration Patterns

/// **Configuration Builder Pattern**
/// Functional approach to building complex configurations
public struct ConfigBuilder<T> {
  private let base: T
  private let transforms: [(T) -> T]

  private init(base: T, transforms: [(T) -> T] = []) {
    self.base = base
    self.transforms = transforms
  }

  /// **Start building from a base value**
  /// - Parameter base: Initial configuration
  /// - Returns: Configuration builder
  public static func from(_ base: T) -> ConfigBuilder<T> {
    Self(base: base)
  }

  /// **Apply a transformation**
  /// - Parameter transform: Function to apply
  /// - Returns: Builder with transformation added
  public func with(_ transform: @escaping (T) -> T) -> ConfigBuilder<T> {
    Self(base: base, transforms: transforms + [transform])
  }

  /// **Build the final configuration**
  /// - Returns: Configuration with all transforms applied
  public func build() -> T {
    transforms.reduce(base) { result, transform in
      transform(result)
    }
  }
}

/// **Configuration builder convenience**
extension ConfigBuilder {

  /// **Apply lens-based update**
  /// - Parameters:
  ///   - lens: Lens to focus on property
  ///   - value: New value to set
  /// - Returns: Builder with lens update added
  public func set<Value>(_ lens: Lens<T, Value>, to value: Value) -> ConfigBuilder<T> {
    with { lens.set(value, $0) }
  }

  /// **Apply lens-based transformation**
  /// - Parameters:
  ///   - lens: Lens to focus on property
  ///   - transform: Transformation to apply
  /// - Returns: Builder with lens transformation added
  public func update<Value>(
    _ lens: Lens<T, Value>,
    _ transform: @escaping (Value) -> Value
  ) -> ConfigBuilder<T> {
    with(lens.over(transform))
  }
}

// MARK: - Common Configuration Patterns

/// **Configuration Template System**
/// Pre-defined configuration patterns for common scenarios
public enum ConfigTemplate {

  /// **Development configuration**
  /// Fast feedback, minimal resource usage
  public static let development = ConfigBuilder<PropertyConfig>
    .from(.default)
    .set(PropertyConfig.iterations, to: 25)
    .set(PropertyConfig.maxShrinks, to: 100)
    .set(PropertyConfig.maxDiscarded, to: 100)
    .build()

  /// **CI/CD configuration**
  /// Balanced testing for continuous integration
  public static let ci = ConfigBuilder<PropertyConfig>
    .from(.default)
    .set(PropertyConfig.iterations, to: 200)
    .set(PropertyConfig.maxShrinks, to: 500)
    .set(PropertyConfig.maxDiscarded, to: 500)
    .build()

  /// **Release configuration**
  /// Exhaustive testing for releases
  public static let release = ConfigBuilder<PropertyConfig>
    .from(.default)
    .set(PropertyConfig.iterations, to: 2000)
    .set(PropertyConfig.maxShrinks, to: 5000)
    .set(PropertyConfig.maxDiscarded, to: 2000)
    .build()

  /// **Performance testing configuration**
  /// High volume, minimal shrinking
  public static let performance = ConfigBuilder<PropertyConfig>
    .from(.default)
    .set(PropertyConfig.iterations, to: 10000)
    .set(PropertyConfig.maxShrinks, to: 10)
    .set(PropertyConfig.maxDiscarded, to: 100)
    .build()

  /// **Debugging configuration**
  /// Deterministic, limited iterations for debugging
  /// - Parameter seed: Seed for deterministic behavior
  /// - Returns: Debug configuration with specified seed
  public static func debug(seed: UInt64) -> PropertyConfig {
    ConfigBuilder<PropertyConfig>
      .from(.default)
      .set(PropertyConfig.iterations, to: 10)
      .set(PropertyConfig.maxShrinks, to: 20)
      .set(PropertyConfig.maxDiscarded, to: 20)
      .set(PropertyConfig.seed, to: Seed(value: seed))
      .build()
  }
}

// MARK: - Advanced Lens Patterns for Complex Configurations

/// **Lens for nested optional configurations**
/// When dealing with optional nested structures
public func optionalLens<Root, Value>(
  _ lens: Lens<Root, Value?>
) -> Lens<Root, Value?> {
  lens
}

/// **Lens for array element access**
/// Safe array element focusing with bounds checking
public func arrayElementLens<Element>(
  at index: Int
) -> Lens<[Element], Element?> {
  Lens<[Element], Element?>(
    get: { array in
      array.indices.contains(index) ? array[index] : nil
    },
    set: { newElement, array in
      var mutableArray = array
      if let element = newElement, array.indices.contains(index) {
        mutableArray[index] = element
      }
      return mutableArray
    }
  )
}

/// **Lens for dictionary value access**
/// Safe dictionary value focusing
public func dictionaryValueLens<Key: Hashable, Value>(
  for key: Key
) -> Lens<[Key: Value], Value?> {
  Lens<[Key: Value], Value?>(
    get: { dict in dict[key] },
    set: { newValue, dict in
      var mutableDict = dict
      mutableDict[key] = newValue
      return mutableDict
    }
  )
}

// MARK: - Functional Update Patterns

/// **Copy with functional updates**
/// Ergonomic way to apply multiple updates
///
/// **Example:**
/// ```swift
/// let newConfig = functionalUpdate(PropertyConfig.default) {
///     PropertyConfig.iterations.set(500, $0)
/// } then: {
///     PropertyConfig.maxShrinks.set(1000, $0)
/// } then: {
///     PropertyConfig.seed.set(Seed(value: 42), $0)
/// }
/// ```
public func functionalUpdate<T>(_ value: T, _ update: (T) -> T) -> T {
  update(value)
}

/// **Chain updates fluently**
public func then<T>(_ value: T, _ update: (T) -> T) -> T {
  update(value)
}

/// **Conditional updates**
/// Apply update only if condition is true
public func conditionally<T>(
  _ condition: Bool,
  _ update: @escaping (T) -> T
) -> (T) -> T {
  condition ? update : identity
}

/// **Multiple conditional updates**
/// Apply different updates based on conditions
public func when<T>(
  _ conditions: [(Bool, (T) -> T)]
) -> (T) -> T {
  { value in
    conditions
      .first { $0.0 }?
      .1(value) ?? value
  }
}
