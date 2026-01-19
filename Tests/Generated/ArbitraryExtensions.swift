// MARK: - Arbitrary Extensions for Generated Tests
// Provides Gen<T>.arbitrary implementations for types tested in generated property tests.

import Foundation
@testable import InvariantSwift

// MARK: - Core Types

extension Seed {
  /// Generator for Seed values
  public static var arbitrary: Gen<Seed> {
    Gen<UInt64>.uint64.map { Seed(value: $0) }
  }
}
