import Foundation

/// Configuration for SMT solver execution.
public struct SMTSolverConfig: Sendable {
  public let solverPath: String
  public let timeout: Duration

  /// Peak memory the solver may use, in megabytes.
  ///
  /// Honoured by `z3` only. Other solvers have no portable equivalent and
  /// ignore this value.
  public let memoryLimit: Int?

  /// Seed for the solver's internal randomness, for reproducible models.
  ///
  /// Honoured by `z3` and the `cvc` family.
  public let randomSeed: UInt32?

  public init(
    solverPath: String = "z3",
    timeout: Duration = .seconds(30),
    memoryLimit: Int? = nil,
    randomSeed: UInt32? = nil
  ) {
    self.solverPath = solverPath
    self.timeout = timeout
    self.memoryLimit = memoryLimit
    self.randomSeed = randomSeed
  }

  public static let zThree = Self(solverPath: "z3")
  public static let cvc4 = Self(solverPath: "cvc4")
}

/// Actor that manages SMT solver interactions.
public actor SMTSolver {
  private let config: SMTSolverConfig
  private var solveCount = 0

  public init(config: SMTSolverConfig = .zThree) {
    self.config = config
  }

  /// Solves a constraint using the configured SMT solver.
  public func solve(_ constraint: SMTConstraint) async -> SMTResult {
    solveCount += 1
    do {
      let output = try await executeSolver(
        input: constraint.toSMTLIB2(),
        config: config
      )
      return parse(output)
    } catch SMTSolverError.timeout {
      return .timeout
    } catch {
      return .error("Solver execution failed: \(error)")
    }
  }

  /// Checks satisfiability without retrieving a model.
  ///
  /// Returns `false` for an unsatisfiable constraint *and* for a solver
  /// failure. Use ``solve(_:)`` when those outcomes must be distinguished.
  public func checkSat(_ constraint: SMTConstraint) async -> Bool {
    guard case .satisfiable = await solve(constraint) else { return false }
    return true
  }

  /// Generates distinct solutions for a constraint.
  public func generateSolutions(
    _ constraint: SMTConstraint,
    maxSolutions: Int = 10
  ) async -> [SMTResult] {
    guard maxSolutions > 0 else { return [] }
    var solutions: [SMTResult] = []
    var current = constraint
    for _ in 0..<maxSolutions {
      let result = await solve(current)
      switch result {
      case .satisfiable(let model) where !model.isEmpty:
        solutions.append(result)
        current = current.blocking(model)

      case .satisfiable:
        // An empty model cannot be blocked, so continuing would return the
        // same solution for every remaining iteration.
        solutions.append(result)
        return solutions

      case .unsatisfiable:
        return solutions

      default:
        solutions.append(result)
        return solutions
      }
    }
    return solutions
  }

  /// Returns solver statistics.
  public func getStatistics() -> SMTSolverStatistics {
    SMTSolverStatistics(
      solveCount: solveCount,
      solverPath: config.solverPath,
      timeout: config.timeout
    )
  }

  private func parse(_ output: String) -> SMTResult {
    let lines = output.components(separatedBy: .newlines)
    guard let status = lines.first?.trimmingCharacters(in: .whitespaces) else {
      return .error("Empty output")
    }
    switch status {
    case "sat":
      return .satisfiable(
        SMTModelParser.parseModel(lines.dropFirst().joined(separator: "\n"))
      )

    case "unsat":
      return .unsatisfiable

    case "unknown":
      return .unknown

    case "timeout":
      return .timeout

    default:
      return .error("Unexpected output: \(status)")
    }
  }
}

/// Statistics for SMT solver usage.
public struct SMTSolverStatistics: Sendable {
  public let solveCount: Int
  public let solverPath: String
  public let timeout: Duration

  public init(solveCount: Int, solverPath: String, timeout: Duration) {
    self.solveCount = solveCount
    self.solverPath = solverPath
    self.timeout = timeout
  }
}

/// Errors that can occur during SMT solving.
public enum SMTSolverError: Error, Sendable {
  case timeout
  case solverError(String)
  case invalidInput(String)
  case unsupportedOperation(String)
}

extension SMTConstraint {
  func blocking(_ model: [String: SMTValue]) -> SMTConstraint {
    let equalities = model.map { name, value in
      SMTExpression.unary(
        .not,
        .binary(.equals, .variable(name), .constant(value))
      )
    }
    let clause = equalities.dropFirst().reduce(
      equalities.first ?? .constant(.bool(true))
    ) { partial, expression in
      .binary(.or, partial, expression)
    }
    return SMTConstraint(
      expression: .binary(.and, expression, clause),
      variables: variables,
      assertions: assertions
    )
  }
}
