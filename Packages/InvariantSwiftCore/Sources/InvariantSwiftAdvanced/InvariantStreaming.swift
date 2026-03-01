/// Memory-efficient streaming types for invariant discovery.
///
/// Implements O(1) streaming statistics (Welford's algorithm), streaming correlation,
/// lazy invariant streams, and bounded priority queues for top-K selection.
/// Extracted from InvariantDiscovery.swift to keep that file under the line budget.

import Foundation
import InvariantSwiftCore

// MARK: - Streaming Statistics

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
  // swiftlint:disable:next empty_count
  public var isEmpty: Bool { count == 0 }

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

// MARK: - Streaming Correlation

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

// MARK: - Invariant Stream

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

// MARK: - Bounded Priority Queue

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

// MARK: - Scored Invariant

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
}
