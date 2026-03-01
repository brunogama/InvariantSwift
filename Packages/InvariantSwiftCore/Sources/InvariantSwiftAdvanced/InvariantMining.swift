/// Invariant Mining System
///
/// Automatic invariant discovery system with ML-assisted pattern recognition.
/// Discovers implicit properties in code by analyzing execution traces and
/// identifying patterns that hold consistently across different inputs.

import Foundation
import InvariantSwiftCore

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
  // swiftlint:disable:next identifier_name
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

// Note: InvariantMiner protocol, miner implementations (StatisticalMiner, TemplateMiner,
// ClusteringMiner, RegressionMiner), memory optimization types (StreamingStats,
// StreamingCorrelation, InvariantStream, BoundedPriorityQueue, ScoredInvariant),
// and Gen integration extension are defined in InvariantDiscovery.swift.
