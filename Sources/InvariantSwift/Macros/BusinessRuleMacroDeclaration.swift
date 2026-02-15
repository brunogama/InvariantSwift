import InvariantSwift
import InvariantSwiftAdvanced
import InvariantSwiftCore
import Foundation
@attached(peer, names: suffixed(_PropertyTest))
public macro BusinessRule(
  _ description: String,
  iterations: Int = .smart,
  timeout: TimeInterval = 30.0
) = #externalMacro(module: "InvariantSwiftMacros", type: "BusinessRuleMacro")

// MARK: - Smart Iteration Configuration

extension Int {
  /// **Smart iteration count that automatically adapts to complexity**
  ///
  /// Provides intelligent test coverage based on:
  /// - Parameter count and complexity
  /// - Type complexity (custom types vs primitives)
  /// - Historical failure patterns
  /// - Performance constraints
  ///
  /// **Theory Behind Smart Iterations:**
  /// Based on statistical testing theory and coverage probability:
  /// - Simple rules: 100-200 iterations provide 99%+ confidence
  /// - Complex rules: 300-500 iterations for comprehensive coverage
  /// - Critical rules: 1000+ iterations for maximum confidence
  ///
  /// The smart algorithm analyzes the function signature and automatically
  /// selects appropriate iteration counts for optimal coverage/performance balance.
  public static let smart: Int = -1  // Special marker for smart calculation
}
