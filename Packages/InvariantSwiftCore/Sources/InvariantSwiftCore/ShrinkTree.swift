/// ShrinkTree - Lazy tree structure for deterministic shrinking
///
/// Represents shrink candidates as a lazy tree, enabling BFS search
/// for minimal counterexamples instead of greedy-first shrinking.

import Foundation

// MARK: - ShrinkTree

/// A value with its shrink candidates organized as a lazy tree.
///
/// `ShrinkTree<T>` represents a value and its potential simplifications
/// (shrinks) as children. This tree structure enables:
/// - **BFS shrinking**: Find truly minimal counterexamples
/// - **Lazy evaluation**: Children computed only when needed
/// - **Deterministic order**: Reproducible shrink sequences
///
/// The tree is constructed lazily, so only explored branches are computed.
/// This is crucial for performance when shrinking complex values.
///
/// - Example:
///   ```swift
///   // Integer 100 with shrinks toward 0
///   let tree = ShrinkTree(value: 100) {
///     [ShrinkTree(value: 0), ShrinkTree(value: 50), ShrinkTree(value: 99)]
///   }
///
///   // Find minimal value > 10
///   let minimal = tree.findMinimal(budget: 100) { $0 > 10 }
///   // Returns 11 (the smallest value > 10 reachable in tree)
///   ```
///
/// - See Also: ``Shrink``, ``PropertyRunner``
public final class ShrinkTree<T: Sendable>: @unchecked Sendable {
  /// The current value at this node.
  public let value: T

  /// Lazy computation of child shrink trees.
  /// Each child represents a simpler version of the value.
  private let _children: @Sendable () -> [ShrinkTree<T>]

  /// The immediate shrink candidates for this value.
  public var children: [ShrinkTree<T>] {
    _children()
  }

  /// Creates a shrink tree with a value and lazy children.
  ///
  /// - Parameters:
  ///   - value: The value at this node
  ///   - children: Lazy computation returning child shrink trees
  public init(value: T, children: @escaping @Sendable () -> [ShrinkTree<T>] = { [] }) {
    self.value = value
    self._children = children
  }

  /// Creates a leaf node with no shrink candidates.
  ///
  /// Use for values that cannot be simplified further (e.g., 0, empty string).
  public static func leaf(_ value: T) -> ShrinkTree<T> {
    ShrinkTree(value: value, children: { [] })
  }
}

// MARK: - Bridge from Shrink<T>

extension ShrinkTree {
  /// Creates a shrink tree from a value and its `Shrink<T>` strategy.
  ///
  /// This bridges the existing `Shrink<T>` API to the tree-based model,
  /// enabling BFS search on existing generators.
  ///
  /// - Parameters:
  ///   - value: The root value
  ///   - shrink: The shrink strategy to generate candidates
  ///
  /// - Returns: A lazily-constructed shrink tree
  public static func from(_ value: T, shrink: Shrink<T>) -> ShrinkTree<T> {
    ShrinkTree(value: value) {
      shrink.shrink(value).map { child in
        ShrinkTree.from(child, shrink: shrink)
      }
    }
  }
}

// MARK: - Functor

extension ShrinkTree {
  /// Transforms the values in the tree while preserving structure.
  ///
  /// - Parameter transform: Function to apply to each value
  /// - Returns: A new tree with transformed values
  public func map<U: Sendable>(_ transform: @escaping @Sendable (T) -> U) -> ShrinkTree<U> {
    ShrinkTree<U>(
      value: transform(value),
      children: {
        self.children.map { child in
          child.map(transform)
        }
      }
    )
  }
}

// MARK: - Monad

extension ShrinkTree {
  /// Monadic bind for dependent shrink trees.
  ///
  /// Creates a tree where shrinking can depend on the current value.
  /// Essential for shrinking dependent generators correctly.
  ///
  /// - Parameter transform: Function producing a shrink tree for each value
  /// - Returns: Flattened shrink tree
  public func flatMap<U: Sendable>(
    _ transform: @escaping @Sendable (T) -> ShrinkTree<U>
  )
    -> ShrinkTree<U>
  {
    let transformed = transform(value)
    return ShrinkTree<U>(
      value: transformed.value,
      children: {
        // Include shrinks from the transformed tree
        var result = transformed.children

        // Include shrinks from the original tree, transformed
        let indirectShrinks = self.children.map { child in
          child.flatMap(transform)
        }
        result.append(contentsOf: indirectShrinks)

        return result
      }
    )
  }
}

// MARK: - Filtering

extension ShrinkTree {
  /// Filters the tree to only include values satisfying a predicate.
  ///
  /// Useful for respecting property assumptions during shrinking.
  ///
  /// - Parameter predicate: Function returning true for values to keep
  /// - Returns: Filtered tree (may have fewer children)
  public func filter(_ predicate: @escaping @Sendable (T) -> Bool) -> ShrinkTree<T> {
    ShrinkTree(
      value: value,
      children: {
        self.children.compactMap { child in
          predicate(child.value) ? child.filter(predicate) : nil
        }
      }
    )
  }
}

// MARK: - Search

extension ShrinkTree {
  /// Finds the minimal value satisfying a predicate using BFS.
  ///
  /// Searches the shrink tree breadth-first, looking for the smallest
  /// (most shrunk) value that still satisfies the predicate. This finds
  /// better counterexamples than greedy-first shrinking.
  ///
  /// - Parameters:
  ///   - budget: Maximum number of nodes to visit
  ///   - predicate: Function returning true for values to consider
  ///
  /// - Returns: The minimal satisfying value, or nil if none found within budget
  ///
  /// - Complexity: O(budget) time, O(width) space for the BFS queue
  public func findMinimal(budget: Int, satisfying predicate: (T) -> Bool) -> T? {
    // Start with root if it satisfies predicate
    guard predicate(value) else { return nil }

    var best: T = value
    var queue: [ShrinkTree<T>] = children
    var visited = 0

    while !queue.isEmpty && visited < budget {
      let current = queue.removeFirst()
      visited += 1

      if predicate(current.value) {
        // Found a smaller value that still satisfies
        best = current.value
        // Continue searching this branch for even smaller values
        queue.append(contentsOf: current.children)
      }
    }

    return best
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public func findMinimalAsync(
    budget: Int,
    satisfying predicate: @escaping @Sendable (T) async -> Bool
  ) async -> T? {
    guard await predicate(value) else { return nil }

    var best: T = value
    var queue: [ShrinkTree<T>] = children
    var visited = 0

    while !queue.isEmpty && visited < budget {
      let current = queue.removeFirst()
      visited += 1

      if await predicate(current.value) {
        best = current.value
        queue.append(contentsOf: current.children)
      }
    }

    return best
  }

  /// Breadth-first traversal of all values in the tree.
  ///
  /// - Returns: Array of values in BFS order
  public func breadthFirst() -> [T] {
    var result: [T] = []
    var queue: [ShrinkTree<T>] = [self]

    while !queue.isEmpty {
      let current = queue.removeFirst()
      result.append(current.value)
      queue.append(contentsOf: current.children)
    }

    return result
  }

  /// Depth-first traversal of all values in the tree.
  ///
  /// - Returns: Array of values in DFS order
  public func depthFirst() -> [T] {
    var result: [T] = [value]
    for child in children {
      result.append(contentsOf: child.depthFirst())
    }
    return result
  }
}

// MARK: - Utilities

extension ShrinkTree {
  /// Limits the tree to a maximum depth for performance.
  ///
  /// - Parameter maxDepth: Maximum levels to keep (0 = leaf only)
  /// - Returns: Pruned tree
  public func prune(maxDepth: Int) -> ShrinkTree<T> {
    guard maxDepth > 0 else {
      return .leaf(value)
    }

    return ShrinkTree(
      value: value,
      children: {
        self.children.map { child in
          child.prune(maxDepth: maxDepth - 1)
        }
      }
    )
  }

  /// Takes only the first n children for performance.
  ///
  /// - Parameter n: Maximum number of children to keep
  /// - Returns: Tree with limited branching
  public func take(_ n: Int) -> ShrinkTree<T> {
    ShrinkTree(value: value) {
      Array(self.children.prefix(n))
    }
  }

  /// Limits the tree to a maximum number of children per node (breadth limit).
  ///
  /// Keeps only the first `maxChildren` children at each node, preventing
  /// exponential breadth explosion. This is useful for shrink trees generated
  /// from greedy strategies that can produce many candidates.
  ///
  /// - Parameter maxChildren: Maximum number of children per node (0 = leaf only)
  /// - Returns: Tree with breadth limited to `maxChildren`
  ///
  /// - Example:
  ///   ```swift
  ///   let tree = ShrinkTree(value: 100) {
  ///     [ShrinkTree.leaf(0), ShrinkTree.leaf(50), ShrinkTree.leaf(75), ShrinkTree.leaf(99)]
  ///   }
  ///   let limited = tree.limitBreadth(2)  // Only [0, 50]
  ///   ```
  public func limitBreadth(_ maxChildren: Int) -> ShrinkTree<T> {
    guard maxChildren > 0 else {
      return .leaf(value)
    }

    return ShrinkTree(
      value: value,
      children: {
        self.children.prefix(maxChildren).map { child in
          child.limitBreadth(maxChildren)
        }
      }
    )
  }

  /// Limits the tree to a maximum total number of nodes using BFS pruning.
  ///
  /// Keeps the first `maxNodes` nodes encountered in breadth-first order,
  /// ensuring the total tree size never exceeds the budget. This is essential
  /// for preventing memory explosion with deep or wide shrink trees.
  ///
  /// - Parameter maxNodes: Maximum total nodes to retain
  /// - Returns: Pruned tree with at most `maxNodes` nodes
  ///
  /// - Complexity: O(maxNodes) time and space
  ///
  /// - Example:
  ///   ```swift
  ///   let largTree = ... // Very deep/wide tree
  ///   let bounded = largeTree.limitTotal(1000)  // Keep first 1000 nodes in BFS order
  ///   ```
  public func limitTotal(_ maxNodes: Int) -> ShrinkTree<T> {
    guard maxNodes > 0 else {
      return .leaf(value)
    }

    // BFS traversal to mark which nodes to keep
    var queue: [ShrinkTree<T>] = [self]
    var nodesVisited = 0
    var nodesToKeep: Set<ObjectIdentifier> = []

    while !queue.isEmpty && nodesVisited < maxNodes {
      let current = queue.removeFirst()
      nodesVisited += 1
      nodesToKeep.insert(ObjectIdentifier(current))

      for child in current.children where nodesVisited < maxNodes {
        queue.append(child)
      }
    }

    let keptIDs = nodesToKeep

    // Prune tree to only include kept nodes
    // swiftlint:disable:next attributes
    @Sendable func pruneToKeep(_ node: ShrinkTree<T>) -> ShrinkTree<T> {
      let nodeID = ObjectIdentifier(node)
      guard keptIDs.contains(nodeID) else {
        return .leaf(node.value)
      }

      return ShrinkTree(
        value: node.value,
        children: {
          node.children.compactMap { child in
            let childID = ObjectIdentifier(child)
            if keptIDs.contains(childID) {
              return pruneToKeep(child)
            }
            return nil
          }
        }
      )
    }

    return pruneToKeep(self)
  }
}
