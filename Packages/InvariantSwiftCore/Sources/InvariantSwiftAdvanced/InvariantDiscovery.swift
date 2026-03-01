/// Invariant discovery implementations and memory-efficient utilities.
///
/// Mining strategies (statistical, template, clustering, regression) and
/// memory-efficient data structures for streaming invariant discovery.
/// Extracted from InvariantMining.swift to keep the engine file under budget.

import Foundation
import InvariantSwiftCore

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


// Note: Memory optimization types (StreamingStats, StreamingCorrelation, InvariantStream,
// BoundedPriorityQueue, ScoredInvariant) and Gen.withTracing extension are defined
// in InvariantStreaming.swift.
