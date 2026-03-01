/// Diff types and implementations for comparing test values.
///
/// Provides structural diff representation and Diffable protocol conformances
/// for comparing before/after values in property test failures.
/// Extracted from PrettyPrint.swift to keep that file under the line budget.

import Foundation
import InvariantSwiftCore

// MARK: - Diff Result

/// **Diff representation for comparing values**
public enum DiffResult<T>: Sendable where T: Sendable {
  case identical(T)
  case different(old: T, new: T)
  case added(T)
  case removed(T)
}

// MARK: - Structured Diff

/// **Structured diff for complex types**
public indirect enum StructuredDiff: Sendable {
  case unchanged(String)
  case changed(old: String, new: String)
  case added(String)
  case removed(String)
  case nested(key: String, diff: Self)
  case collection([Self])
  case collapsed(unchangedCount: Int)

  /// Render the diff to a string with the given format
  public func render(format: DiffFormat = .default, indent: Int = 0) -> String {
    let indentStr = String(repeating: "  ", count: indent)

    switch self {
    case .unchanged(let value):
      return "\(indentStr)\(format.unchanged) \(value)"

    case .changed(let old, let new):
      return """
        \(indentStr)\(format.first) \(old)
        \(indentStr)\(format.second) \(new)
        """

    case .added(let value):
      return "\(indentStr)\(format.second) \(value)"

    case .removed(let value):
      return "\(indentStr)\(format.first) \(value)"

    case .nested(let key, let diff):
      return "\(indentStr)\(key):\n\(diff.render(format: format, indent: indent + 1))"

    case .collection(let diffs):
      return diffs.map { $0.render(format: format, indent: indent) }.joined(separator: "\n")

    case .collapsed(let count):
      return "\(indentStr)\(format.unchanged) ... (\(count) unchanged)"
    }
  }
}

// MARK: - Diffable Protocol

/// **Protocol for types that can be diffed**
public protocol Diffable {
  /// Create a structured diff between two values
  /// - Parameter other: The other value to compare against
  /// - Returns: Structured diff representation
  func diff(other: Self) -> StructuredDiff
}

// MARK: - Diff Conformances

extension String: Diffable {
  public func diff(other: String) -> StructuredDiff {
    if self == other {
      return .unchanged(self)
    } else {
      return .changed(old: self, new: other)
    }
  }
}

extension Array: Diffable where Element: Diffable & Equatable {
  public func diff(other: [Element]) -> StructuredDiff {
    diff(other: other, collapseUnchanged: true, collapseThreshold: 2)
  }

  public func diff(
    other: [Element],
    collapseUnchanged: Bool,
    collapseThreshold: Int = 2
  ) -> StructuredDiff {
    var diffs: [StructuredDiff] = []
    var unchangedRun: [StructuredDiff] = []

    func flushUnchanged() {
      guard !unchangedRun.isEmpty else { return }
      if collapseUnchanged && unchangedRun.count > collapseThreshold {
        diffs.append(.collapsed(unchangedCount: unchangedRun.count))
      } else {
        diffs.append(contentsOf: unchangedRun)
      }
      unchangedRun.removeAll()
    }

    let maxIndex = Swift.max(count, other.count)
    for i in 0..<maxIndex {
      let hasOld = i < count
      let hasNew = i < other.count

      switch (hasOld, hasNew) {
      case (true, true):
        let oldElem = self[i]
        let newElem = other[i]
        if oldElem == newElem {
          unchangedRun.append(.unchanged("\(oldElem)"))
        } else {
          flushUnchanged()
          diffs.append(oldElem.diff(other: newElem))
        }

      case (true, false):
        flushUnchanged()
        diffs.append(.removed("\(self[i])"))

      case (false, true):
        flushUnchanged()
        diffs.append(.added("\(other[i])"))

      case (false, false):
        break
      }
    }

    flushUnchanged()
    return .collection(diffs)
  }
}
