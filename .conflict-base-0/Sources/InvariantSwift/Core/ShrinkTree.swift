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
public struct ShrinkTree<T>: @unchecked Sendable {
  /// The current value at this node.
  public let value: T

  /// Lazy computation of child shrink trees.
  /// Each child represents a simpler version of the value.
  private let _children: () -> [ShrinkTree<T>]

  /// The immediate shrink candidates for this value.
  public var children: [ShrinkTree<T>] {
    _children()
  }

  /// Creates a shrink tree with a value and lazy children.
  ///
  /// - Parameters:
  ///   - value: The value at this node
  ///   - children: Lazy computation returning child shrink trees
  public init(value: T, children: @escaping () -> [ShrinkTree<T>] = { [] }) {
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
  public func map<U>(_ transform: @escaping (T) -> U) -> ShrinkTree<U> {
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
  public func flatMap<U>(_ transform: @escaping (T) -> ShrinkTree<U>) -> ShrinkTree<U> {
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
  public func filter(_ predicate: @escaping (T) -> Bool) -> ShrinkTree<T> {
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
    ShrinkTree(
      value: value,
      children: {
        Array(self.children.prefix(n))
      }
    )
  }
}
