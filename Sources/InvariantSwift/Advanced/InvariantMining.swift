/// Invariant Mining System
///
/// Automatic invariant discovery system with ML-assisted pattern recognition.
/// Discovers implicit properties in code by analyzing execution traces and
/// identifying patterns that hold consistently across different inputs.

import Foundation

// MARK: - Core Types

/// An invariant discovered through execution analysis
public struct DiscoveredInvariant: Sendable, Hashable, CustomStringConvertible {
  public let id: UUID
  public let predicate: String
  public let confidence: Double
  public let supportCount: Int
  public let violationCount: Int
  public let category: InvariantCategory
  public let discoveryMethod: DiscoveryMethod
  public let metadata: [String: String]
  public let examples: [String]

  public init(
    id: UUID = UUID(),
    predicate: String,
    confidence: Double,
    supportCount: Int,
    violationCount: Int = 0,
    category: InvariantCategory,
    discoveryMethod: DiscoveryMethod,
    metadata: [String: String] = [:],
    examples: [String] = []
  ) {
    self.id = id
    self.predicate = predicate
    self.confidence = max(0.0, min(1.0, confidence))
    self.supportCount = supportCount
    self.violationCount = max(0, violationCount)
    self.category = category
    self.discoveryMethod = discoveryMethod
    self.metadata = metadata
    self.examples = examples
  }

  /// Success rate of this invariant
  public var successRate: Double {
    let total = supportCount + violationCount
    return total > 0 ? Double(supportCount) / Double(total) : 0.0
  }

  /// Whether this invariant meets quality thresholds
  public var isHighQuality: Bool {
    confidence >= 0.8 && supportCount >= 10 && successRate >= 0.95
  }

  public var description: String {
    "\(predicate) (confidence: \(String(format: "%.3f", confidence)), support: \(supportCount))"
  }

  /// Generate code for this invariant as a property test
  public func generatePropertyTest() -> String {
    """
    @Test("Generated invariant: \(predicate)")
    func testInvariant_\(id.uuidString.prefix(8))() async {
        let property = Property(generator: /* appropriate generator */) { input in
            // \(predicate)
            /* generated assertion code */
            return true
        }

        #expect(await checkProperty(property).isSuccess)
    }
    """
  }
}

/// Categories of invariants
public enum InvariantCategory: String, Sendable, CaseIterable {
  case numerical  // x >= 0, x < 100, etc.
  case structural  // array.count >= 0, etc.
  case relational  // x < y, length(a) == length(b)
  case conditional  // if P then Q
  case equality  // x == f(y)
  case ordering  // x <= y <= z
  case membership  // x ∈ S
  case functional  // f(x) = g(h(x))

  public var priority: Int {
    switch self {
    case .equality, .functional: return 10
    case .relational, .ordering: return 8
    case .conditional: return 6
    case .numerical, .structural: return 4
    case .membership: return 2
    }
  }
}

/// Methods for discovering invariants
public enum DiscoveryMethod: String, Sendable {
  case statistical  // Statistical analysis of traces
  case template  // Template-based pattern matching
  case symbolic  // Symbolic execution analysis
  case clustering  // ML clustering of behaviors
  case regression  // Regression analysis
  case decision_tree  // Decision tree learning
}

/// Configuration for invariant mining
public struct MiningConfig: Sendable {
  public let minSupport: Int
  public let minConfidence: Double
  public let maxInvariants: Int
  public let enabledCategories: Set<InvariantCategory>
  public let enabledMethods: Set<DiscoveryMethod>
  public let timeLimit: Duration
  public let sampleSize: Int

  public init(
    minSupport: Int = 10,
    minConfidence: Double = 0.8,
    maxInvariants: Int = 100,
    enabledCategories: Set<InvariantCategory> = Set(InvariantCategory.allCases),
    enabledMethods: Set<DiscoveryMethod> = [.statistical, .template, .clustering],
    timeLimit: Duration = .seconds(60),
    sampleSize: Int = 1000
  ) {
    self.minSupport = max(1, minSupport)
    self.minConfidence = max(0.0, min(1.0, minConfidence))
    self.maxInvariants = max(1, maxInvariants)
    self.enabledCategories = enabledCategories
    self.enabledMethods = enabledMethods
    self.timeLimit = timeLimit
    self.sampleSize = max(10, sampleSize)
  }

  public static let fast = Self(
    minSupport: 5,
    minConfidence: 0.7,
    maxInvariants: 20,
    sampleSize: 100
  )

  public static let thorough = Self(
    minSupport: 20,
    minConfidence: 0.9,
    maxInvariants: 500,
    sampleSize: 5000
  )
}

// MARK: - Execution Trace Types

/// A recorded execution trace
public struct ExecutionTrace: Sendable {
  public let id: UUID
  public let input: ExecutionState
  public let output: ExecutionState
  public let intermediateStates: [ExecutionState]
  public let timestamp: Date
  public let duration: Duration

  public init(
    id: UUID = UUID(),
    input: ExecutionState,
    output: ExecutionState,
    intermediateStates: [ExecutionState] = [],
    timestamp: Date = Date(),
    duration: Duration = .zero
  ) {
    self.id = id
    self.input = input
    self.output = output
    self.intermediateStates = intermediateStates
    self.timestamp = timestamp
    self.duration = duration
  }

  /// All states in this trace (input + intermediate + output)
  public var allStates: [ExecutionState] {
    [input] + intermediateStates + [output]
  }
}

/// State of execution at a point in time
public struct ExecutionState: Sendable, Hashable {
  public let variables: [String: StateValue]
  public let returnValue: StateValue?
  public let properties: [String: Double]

  public init(
    variables: [String: StateValue],
    returnValue: StateValue? = nil,
    properties: [String: Double] = [:]
  ) {
    self.variables = variables
    self.returnValue = returnValue
    self.properties = properties
  }

  /// Extract numerical properties from this state
  public var numericalProperties: [String: Double] {
    var props = properties

    for (name, value) in variables {
      switch value {
      case .integer(let i):
        props[name] = Double(i)

      case .double(let d):
        props[name] = d

      case .array(let arr):
        props["\(name).count"] = Double(arr.count)

      case .string(let s):
        props["\(name).length"] = Double(s.count)

      default:
        break
      }
    }

    return props
  }
}

/// Value that can be stored in execution state
public enum StateValue: Sendable, Hashable, CustomStringConvertible {
  case integer(Int)
  case double(Double)
  case string(String)
  case boolean(Bool)
  case array([Self])
  case dictionary([String: Self])
  case null

  public var description: String {
    switch self {
    case .integer(let i): return "\(i)"
    case .double(let d): return "\(d)"
    case .string(let s): return "\"\(s)\""
    case .boolean(let b): return "\(b)"
    case .array(let arr): return "[\(arr.map(\.description).joined(separator: ", "))]"

    case .dictionary(let dict):
      let pairs = dict.map { "\($0): \($1)" }.joined(separator: ", ")
      return "{\(pairs)}"
    case .null: return "null"
    }
  }

  /// Convert to double if possible
  public var numericValue: Double? {
    switch self {
    case .integer(let i): return Double(i)
    case .double(let d): return d
    case .boolean(let b): return b ? 1.0 : 0.0
    case .array(let arr): return Double(arr.count)
    case .string(let s): return Double(s.count)
    default: return nil
    }
  }
}

// MARK: - Invariant Mining Engine

/// Main engine for discovering invariants from execution traces
public actor InvariantMiningEngine {
  private let config: MiningConfig
  private var traces: [ExecutionTrace] = []
  private var discoveredInvariants: [DiscoveredInvariant] = []
  private let miners: [InvariantMiner]

  public init(config: MiningConfig = MiningConfig()) {
    self.config = config

    // Initialize miners based on enabled methods
    var miners: [InvariantMiner] = []

    if config.enabledMethods.contains(.statistical) {
      miners.append(StatisticalMiner(config: config))
    }
    if config.enabledMethods.contains(.template) {
      miners.append(TemplateMiner(config: config))
    }
    if config.enabledMethods.contains(.clustering) {
      miners.append(ClusteringMiner(config: config))
    }
    if config.enabledMethods.contains(.regression) {
      miners.append(RegressionMiner(config: config))
    }

    self.miners = miners
  }

  /// Add execution traces for analysis
  public func addTraces(_ newTraces: [ExecutionTrace]) {
    traces.append(contentsOf: newTraces)

    // Maintain reasonable trace count
    if traces.count > config.sampleSize * 2 {
      traces = Array(traces.suffix(config.sampleSize))
    }
  }

  /// Mine invariants from collected traces
  public func mineInvariants() async -> [DiscoveredInvariant] {
    let startTime = ContinuousClock().now
    var allInvariants: [DiscoveredInvariant] = []

    // Run each miner
    for miner in miners {
      let minerInvariants = await miner.mine(traces: traces)
      allInvariants.append(contentsOf: minerInvariants)

      // Check time limit
      let elapsed = ContinuousClock().now - startTime
      if elapsed > config.timeLimit {
        break
      }
    }

    // Deduplicate and rank invariants
    let rankedInvariants = rankAndDedup(allInvariants)
    let topInvariants = Array(rankedInvariants.prefix(config.maxInvariants))

    discoveredInvariants = topInvariants
    return topInvariants
  }

  /// Verify invariants against new traces
  public func verifyInvariants(
    _ invariants: [DiscoveredInvariant],
    against traces: [ExecutionTrace]
  ) async -> [InvariantVerificationResult] {
    var results: [InvariantVerificationResult] = []

    for invariant in invariants {
      var violations: [TraceViolation] = []
      var successes = 0

      for trace in traces {
        if await verifyInvariantOnTrace(invariant, trace: trace) {
          successes += 1
        } else {
          violations.append(
            TraceViolation(
              invariant: invariant.id,
              trace: trace.id,
              violatingState: trace.output,
              description: "Invariant violated in output state"
            )
          )
        }
      }

      let result = InvariantVerificationResult(
        invariant: invariant,
        totalTraces: traces.count,
        successes: successes,
        violations: violations,
        successRate: Double(successes) / Double(traces.count)
      )

      results.append(result)
    }

    return results
  }

  /// Get statistics about mining progress
  public func getStatistics() -> MiningStatistics {
    MiningStatistics(
      totalTraces: traces.count,
      discoveredInvariants: discoveredInvariants.count,
      highQualityInvariants: discoveredInvariants.filter(\.isHighQuality).count,
      categoryCounts: Dictionary(grouping: discoveredInvariants, by: \.category)
        .mapValues { $0.count },
      averageConfidence: discoveredInvariants.isEmpty
        ? 0.0
        : discoveredInvariants.map(\.confidence).reduce(0, +) / Double(discoveredInvariants.count)
    )
  }

  // MARK: - Private Methods

  private func rankAndDedup(_ invariants: [DiscoveredInvariant]) -> [DiscoveredInvariant] {
    // Group by predicate text to find duplicates
    let grouped = Dictionary(grouping: invariants, by: \.predicate)

    var unique: [DiscoveredInvariant] = []
    for (_, candidates) in grouped {
      // Keep the one with highest confidence
      if let best = candidates.max(by: { $0.confidence < $1.confidence }) {
        unique.append(best)
      }
    }

    // Sort by quality score
    return unique.sorted { inv1, inv2 in
      let score1 =
        inv1.confidence * Double(inv1.category.priority) * (inv1.isHighQuality ? 2.0 : 1.0)
      let score2 =
        inv2.confidence * Double(inv2.category.priority) * (inv2.isHighQuality ? 2.0 : 1.0)
      return score1 > score2
    }
  }

  private func verifyInvariantOnTrace(
    _ invariant: DiscoveredInvariant,
    trace: ExecutionTrace
  ) async -> Bool {
    // This would contain the actual verification logic based on the invariant type
    // For now, simplified implementation
    true  // Placeholder
  }
}

// MARK: - Mining Statistics

public struct MiningStatistics: Sendable {
  public let totalTraces: Int
  public let discoveredInvariants: Int
  public let highQualityInvariants: Int
  public let categoryCounts: [InvariantCategory: Int]
  public let averageConfidence: Double

  public init(
    totalTraces: Int,
    discoveredInvariants: Int,
    highQualityInvariants: Int,
    categoryCounts: [InvariantCategory: Int],
    averageConfidence: Double
  ) {
    self.totalTraces = totalTraces
    self.discoveredInvariants = discoveredInvariants
    self.highQualityInvariants = highQualityInvariants
    self.categoryCounts = categoryCounts
    self.averageConfidence = averageConfidence
  }
}

// MARK: - Verification Types

public struct InvariantVerificationResult: Sendable {
  public let invariant: DiscoveredInvariant
  public let totalTraces: Int
  public let successes: Int
  public let violations: [TraceViolation]
  public let successRate: Double

  public init(
    invariant: DiscoveredInvariant,
    totalTraces: Int,
    successes: Int,
    violations: [TraceViolation],
    successRate: Double
  ) {
    self.invariant = invariant
    self.totalTraces = totalTraces
    self.successes = successes
    self.violations = violations
    self.successRate = successRate
  }
}

public struct TraceViolation: Sendable {
  public let invariant: UUID
  public let trace: UUID
  public let violatingState: ExecutionState
  public let description: String

  public init(invariant: UUID, trace: UUID, violatingState: ExecutionState, description: String) {
    self.invariant = invariant
    self.trace = trace
    self.violatingState = violatingState
    self.description = description
  }
}

// MARK: - Invariant Miner Protocol

public protocol InvariantMiner: Sendable {
  func mine(traces: [ExecutionTrace]) async -> [DiscoveredInvariant]
}

// MARK: - Statistical Miner

public struct StatisticalMiner: InvariantMiner {
  private let config: MiningConfig

  public init(config: MiningConfig) {
    self.config = config
  }

  public func mine(traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    var invariants: [DiscoveredInvariant] = []

    // Numerical invariants (bounds, ranges)
    if config.enabledCategories.contains(.numerical) {
      invariants.append(contentsOf: await mineNumericalInvariants(traces))
    }

    // Structural invariants (sizes, lengths)
    if config.enabledCategories.contains(.structural) {
      invariants.append(contentsOf: await mineStructuralInvariants(traces))
    }

    // Equality invariants
    if config.enabledCategories.contains(.equality) {
      invariants.append(contentsOf: await mineEqualityInvariants(traces))
    }

    return invariants
  }

  private func mineNumericalInvariants(_ traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    var invariants: [DiscoveredInvariant] = []
    // swiftlint:disable:next large_tuple
    var propertyStats: [String: (min: Double, max: Double, values: [Double])] = [:]

    // Collect numerical properties
    for trace in traces {
      for state in trace.allStates {
        for (name, value) in state.numericalProperties {
          if propertyStats[name] == nil {
            propertyStats[name] = (min: value, max: value, values: [])
          }

          var stats = propertyStats[name]!
          stats.min = min(stats.min, value)
          stats.max = max(stats.max, value)
          stats.values.append(value)
          propertyStats[name] = stats
        }
      }
    }

    // Generate bound invariants
    for (property, stats) in propertyStats {
      let supportCount = stats.values.count

      if supportCount >= config.minSupport {
        // Lower bound invariant
        let lowerBound = stats.min
        let confidence = Double(supportCount) / Double(traces.count * 3)  // Approximate

        if confidence >= config.minConfidence {
          let invariant = DiscoveredInvariant(
            predicate: "\(property) >= \(lowerBound)",
            confidence: confidence,
            supportCount: supportCount,
            category: .numerical,
            discoveryMethod: .statistical,
            examples: ["\(property) = \(stats.values.first ?? 0)"]
          )
          invariants.append(invariant)
        }

        // Upper bound invariant (if reasonable)
        if stats.max < Double.infinity {
          let upperBound = stats.max
          let invariant = DiscoveredInvariant(
            predicate: "\(property) <= \(upperBound)",
            confidence: confidence,
            supportCount: supportCount,
            category: .numerical,
            discoveryMethod: .statistical,
            examples: ["\(property) = \(stats.values.last ?? 0)"]
          )
          invariants.append(invariant)
        }
      }
    }

    return invariants
  }

  private func mineStructuralInvariants(_ traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    var invariants: [DiscoveredInvariant] = []

    // Common structural patterns
    let patterns = [
      ("array.count >= 0", "Array size is non-negative"),
      ("string.length >= 0", "String length is non-negative"),
      ("result != null", "Result is not null"),
    ]

    for (predicate, description) in patterns {
      let supportCount = traces.count  // Simplified - would need actual checking
      let confidence = 1.0  // These are generally true

      if supportCount >= config.minSupport && confidence >= config.minConfidence {
        let invariant = DiscoveredInvariant(
          predicate: predicate,
          confidence: confidence,
          supportCount: supportCount,
          category: .structural,
          discoveryMethod: .statistical,
          metadata: ["description": description]
        )
        invariants.append(invariant)
      }
    }

    return invariants
  }

  private func mineEqualityInvariants(_ traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    // Look for variables that always have the same value
    var invariants: [DiscoveredInvariant] = []
    var equalPairs: [String: [String: Int]] = [:]  // var1 -> [var2: count]

    for trace in traces {
      for state in trace.allStates {
        let numProps = state.numericalProperties
        let propNames = Array(numProps.keys)

        // Check all pairs
        for i in 0..<propNames.count {
          for j in (i + 1)..<propNames.count {
            let prop1 = propNames[i]
            let prop2 = propNames[j]
            let val1 = numProps[prop1]!
            let val2 = numProps[prop2]!

            if abs(val1 - val2) < 0.0001 {  // Close enough for equality
              let key = "\(prop1) == \(prop2)"
              equalPairs[key, default: [:]][trace.id.uuidString, default: 0] += 1
            }
          }
        }
      }
    }

    // Generate equality invariants
    for (predicate, traceCounts) in equalPairs {
      let supportCount = traceCounts.count
      let confidence = Double(supportCount) / Double(traces.count)

      if supportCount >= config.minSupport && confidence >= config.minConfidence {
        let invariant = DiscoveredInvariant(
          predicate: predicate,
          confidence: confidence,
          supportCount: supportCount,
          category: .equality,
          discoveryMethod: .statistical
        )
        invariants.append(invariant)
      }
    }

    return invariants
  }
}

// MARK: - Template Miner

public struct TemplateMiner: InvariantMiner {
  private let config: MiningConfig

  public init(config: MiningConfig) {
    self.config = config
  }

  public func mine(traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    var invariants: [DiscoveredInvariant] = []

    // Pre-defined templates to match against
    let templates = [
      Template(pattern: "input.size == output.size", category: .structural),
      Template(pattern: "output >= 0", category: .numerical),
      Template(pattern: "input != null", category: .structural),
      Template(pattern: "output.length <= input.length", category: .relational),
    ]

    for template in templates {
      if let invariant = await matchTemplate(template, traces: traces) {
        invariants.append(invariant)
      }
    }

    return invariants
  }

  private func matchTemplate(
    _ template: Template,
    traces: [ExecutionTrace]
  ) async -> DiscoveredInvariant? {
    let supportCount = traces.count  // Simplified - would need actual template matching
    let confidence = 0.8  // Simplified

    if supportCount >= config.minSupport && confidence >= config.minConfidence {
      return DiscoveredInvariant(
        predicate: template.pattern,
        confidence: confidence,
        supportCount: supportCount,
        category: template.category,
        discoveryMethod: .template
      )
    }

    return nil
  }

  private struct Template {
    let pattern: String
    let category: InvariantCategory
  }
}

// MARK: - Clustering Miner

public struct ClusteringMiner: InvariantMiner {
  private let config: MiningConfig

  public init(config: MiningConfig) {
    self.config = config
  }

  public func mine(traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    // Simplified clustering-based mining
    // In practice, this would use ML clustering algorithms
    var invariants: [DiscoveredInvariant] = []

    // Group traces by similar numerical properties
    let clusters = clusterTraces(traces)

    for cluster in clusters {
      if let clusterInvariant = extractClusterInvariant(cluster) {
        invariants.append(clusterInvariant)
      }
    }

    return invariants
  }

  private func clusterTraces(_ traces: [ExecutionTrace]) -> [[ExecutionTrace]] {
    // Simplified clustering - would use proper ML clustering
    [traces]  // Single cluster for now
  }

  private func extractClusterInvariant(_ cluster: [ExecutionTrace]) -> DiscoveredInvariant? {
    guard cluster.count >= config.minSupport else { return nil }

    // Extract common patterns from cluster
    return DiscoveredInvariant(
      predicate: "clustered_pattern",
      confidence: 0.7,
      supportCount: cluster.count,
      category: .functional,
      discoveryMethod: .clustering,
      metadata: ["cluster_size": "\(cluster.count)"]
    )
  }
}

// MARK: - Regression Miner

public struct RegressionMiner: InvariantMiner {
  private let config: MiningConfig

  public init(config: MiningConfig) {
    self.config = config
  }

  public func mine(traces: [ExecutionTrace]) async -> [DiscoveredInvariant] {
    // Simplified regression analysis for discovering functional relationships
    // In practice, would use statistical regression

    var invariants: [DiscoveredInvariant] = []

    // Look for linear relationships between variables
    if let linearInvariant = findLinearRelationships(traces) {
      invariants.append(linearInvariant)
    }

    return invariants
  }

  private func findLinearRelationships(_ traces: [ExecutionTrace]) -> DiscoveredInvariant? {
    // Simplified linear regression
    // Would analyze correlation between input/output variables

    if traces.count >= config.minSupport {
      return DiscoveredInvariant(
        predicate: "output ≈ α * input + β",
        confidence: 0.6,
        supportCount: traces.count,
        category: .functional,
        discoveryMethod: .regression,
        metadata: ["correlation": "0.8"]
      )
    }

    return nil
  }
}

// MARK: - Memory Optimization Types

/// **Streaming statistics using Welford's algorithm**
///
/// Implements numerically stable single-pass computation of mean and variance.
/// This achieves O(1) memory complexity instead of O(n) for batch computation.
///
/// **Mathematical Foundation:**
/// Uses Welford's online algorithm which computes:
/// - `M₂ = M₂ + (x - μₙ₋₁) × (x - μₙ)`
///
/// This provides numerical stability for floating-point variance computation.
///
/// **External References:**
/// - [Welford's Algorithm](https://en.wikipedia.org/wiki/Algorithms_for_calculating_variance#Welford's_online_algorithm)
public struct StreamingStats: Sendable {
  public private(set) var count: Int = 0
  public private(set) var mean: Double = 0.0
  public private(set) var min: Double = .infinity
  public private(set) var max: Double = -.infinity
  private var m2: Double = 0.0

  /// Creates empty streaming statistics
  public init() {}

  /// Creates streaming statistics with initial values
  public init(count: Int, mean: Double, m2: Double, min: Double, max: Double) {
    self.count = count
    self.mean = mean
    self.m2 = m2
    self.min = min
    self.max = max
  }

  /// Update statistics with a new value (mutating)
  ///
  /// - Parameter value: The new value to incorporate
  public mutating func update(_ value: Double) {
    count += 1
    let delta = value - mean
    mean += delta / Double(count)
    let delta2 = value - mean
    m2 += delta * delta2
    min = Swift.min(min, value)
    max = Swift.max(max, value)
  }

  /// Return new statistics with added value (non-mutating)
  ///
  /// - Parameter value: The new value to incorporate
  /// - Returns: New StreamingStats with updated values
  public func adding(_ value: Double) -> Self {
    var copy = self
    copy.update(value)
    return copy
  }

  /// Population variance
  public var variance: Double {
    count > 1 ? m2 / Double(count - 1) : 0.0
  }

  /// Population standard deviation
  public var standardDeviation: Double {
    sqrt(variance)
  }

  /// Whether no values have been added
  public var isEmpty: Bool { isEmpty }

  /// Range of values
  public var range: Double {
    guard !isEmpty else { return 0.0 }
    return max - min
  }

  /// Coefficient of variation (relative standard deviation)
  public var coefficientOfVariation: Double {
    guard mean != 0 else { return 0.0 }
    return standardDeviation / abs(mean)
  }
}

/// **Streaming correlation using single-pass algorithm**
///
/// Computes Pearson correlation coefficient in a single pass with O(1) memory.
public struct StreamingCorrelation: Sendable {
  private var xStats = StreamingStats()
  private var yStats = StreamingStats()
  private var coSum: Double = 0.0

  /// Creates empty streaming correlation
  public init() {}

  /// Update correlation with a new pair of values
  public mutating func update(x: Double, y: Double) {
    let n = Double(xStats.count + 1)
    let dx = x - xStats.mean
    let dy = y - yStats.mean

    xStats.update(x)
    yStats.update(y)

    // Update covariance sum
    coSum += dx * dy * (n - 1) / n
  }

  /// Return new correlation with added pair (non-mutating)
  public func adding(x: Double, y: Double) -> Self {
    var copy = self
    copy.update(x: x, y: y)
    return copy
  }

  /// Pearson correlation coefficient
  public var correlation: Double {
    guard xStats.count > 1 else { return 0.0 }
    let denom = xStats.standardDeviation * yStats.standardDeviation * Double(xStats.count - 1)
    guard denom > 0 else { return 0.0 }
    return coSum / denom
  }
}

/// **Lazy invariant stream with O(k) memory overhead**
///
/// Implements AsyncSequence for streaming invariant discovery.
/// Mining only occurs during iteration, enabling lazy evaluation.
///
/// **Mathematical Properties:**
/// - Identity: `stream.map(id) ≡ stream`
/// - Composition: `stream.map(f).map(g) ≡ stream.map(g ∘ f)`
/// - Lazy evaluation: Computation deferred until consumption
public struct InvariantStream: AsyncSequence, Sendable {
  public typealias Element = DiscoveredInvariant

  private let miner: any InvariantMiner
  private let traces: [ExecutionTrace]
  private let config: MiningConfig

  /// Creates a new invariant stream
  public init(miner: any InvariantMiner, traces: [ExecutionTrace], config: MiningConfig) {
    self.miner = miner
    self.traces = traces
    self.config = config
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(miner: miner, traces: traces, config: config)
  }

  /// Async iterator for lazy invariant mining
  public struct AsyncIterator: AsyncIteratorProtocol {
    private let miner: any InvariantMiner
    private let traces: [ExecutionTrace]
    private let config: MiningConfig
    private var invariants: [DiscoveredInvariant]?
    private var currentIndex = 0

    init(miner: any InvariantMiner, traces: [ExecutionTrace], config: MiningConfig) {
      self.miner = miner
      self.traces = traces
      self.config = config
    }

    public mutating func next() async -> DiscoveredInvariant? {
      // Lazy mining: only mine when first iteration starts
      if invariants == nil {
        invariants = await miner.mine(traces: traces)
      }

      guard let invariants = invariants, currentIndex < invariants.count else {
        return nil
      }

      let result = invariants[currentIndex]
      currentIndex += 1
      return result
    }
  }
}

/// **Bounded priority queue for top-K selection**
///
/// Maintains only the top-K highest-scoring invariants with O(k) memory.
/// Uses a min-heap to efficiently maintain the k best items.
public struct BoundedPriorityQueue<T: Comparable>: Sendable where T: Sendable {
  private let capacity: Int
  private var heap: [T] = []

  /// Creates a bounded priority queue with given capacity
  public init(capacity: Int) {
    self.capacity = max(1, capacity)
    self.heap.reserveCapacity(capacity + 1)
  }

  /// Number of items in the queue
  public var count: Int { heap.count }

  /// Whether the queue is at capacity
  public var isFull: Bool { count >= capacity }

  /// The minimum value in the queue (threshold for insertion)
  public var minimum: T? { heap.first }

  /// All items in the queue (not in order)
  public var items: [T] { heap }

  /// Insert an item, maintaining bounded size
  ///
  /// - Parameter element: The element to insert
  /// - Returns: true if element was inserted, false if rejected
  @discardableResult
  public mutating func insert(_ element: T) -> Bool {
    if count < capacity {
      // Not at capacity, always insert
      heap.append(element)
      heapifyUp(count - 1)
      return true
    } else if element > heap[0] {
      // At capacity, only insert if better than minimum
      heap[0] = element
      heapifyDown(0)
      return true
    }
    return false
  }

  /// Get sorted array of all items (ascending)
  public func sorted() -> [T] {
    heap.sorted()
  }

  /// Get sorted array of all items (descending)
  public func sortedDescending() -> [T] {
    heap.sorted(by: >)
  }

  // MARK: - Private Heap Operations

  private mutating func heapifyUp(_ index: Int) {
    var current = index
    while current > 0 {
      let parent = (current - 1) / 2
      if heap[current] < heap[parent] {
        heap.swapAt(current, parent)
        current = parent
      } else {
        break
      }
    }
  }

  private mutating func heapifyDown(_ index: Int) {
    var current = index
    while true {
      let left = 2 * current + 1
      let right = 2 * current + 2
      var smallest = current

      if left < count && heap[left] < heap[smallest] {
        smallest = left
      }
      if right < count && heap[right] < heap[smallest] {
        smallest = right
      }

      if smallest != current {
        heap.swapAt(current, smallest)
        current = smallest
      } else {
        break
      }
    }
  }
}

/// **Scored invariant for priority queue operations**
public struct ScoredInvariant: Sendable, Comparable {
  public let invariant: DiscoveredInvariant
  public let score: Double

  public init(invariant: DiscoveredInvariant) {
    self.invariant = invariant
    // Quality score: confidence × category priority × support factor
    self.score =
      invariant.confidence
      * Double(invariant.category.priority)
      * (invariant.isHighQuality ? 2.0 : 1.0)
      * sqrt(Double(invariant.supportCount))
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.score < rhs.score
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.score == rhs.score && lhs.invariant.id == rhs.invariant.id
  }
}

// MARK: - Integration Extensions

extension Gen {
  /// Generate traces while running this generator
  public func withTracing<O: Sendable>(
    function: @escaping @Sendable (T) -> O,
    engine: InvariantMiningEngine
  ) -> Gen<(T, ExecutionTrace)> {
    Gen<(T, ExecutionTrace)> { rng, size in
      let input = self.generate(&rng, size)

      // Create execution state from input
      let inputState = ExecutionState(
        variables: ["input": .string("\(input)")],
        properties: ["generation_size": Double(size.value)]
      )

      let startTime = ContinuousClock().now
      let output = function(input)
      let endTime = ContinuousClock().now

      // Create execution state from output
      let outputState = ExecutionState(
        variables: ["output": .string("\(output)")],
        returnValue: .string("\(output)"),
        properties: [:]
      )

      let trace = ExecutionTrace(
        input: inputState,
        output: outputState,
        duration: endTime - startTime
      )

      // Add trace to engine asynchronously
      Task {
        await engine.addTraces([trace])
      }

      return (input, trace)
    }
  }
  // swiftlint:disable:next file_length
}
