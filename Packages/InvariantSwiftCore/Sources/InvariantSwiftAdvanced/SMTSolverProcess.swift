import Foundation

/// Configuration for SMT solver execution.
public struct SMTSolverConfig: Sendable {
  public let solverPath: String
  public let timeout: Duration
  public let memoryLimit: Int?
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
      let output = try await execute(
        input: constraint.toSMTLIB2(),
        config: config
      )
      return parse(output)
    } catch {
      return .error("Solver execution failed: \(error)")
    }
  }

  /// Checks satisfiability without retrieving a model.
  public func checkSat(_ constraint: SMTConstraint) async -> Bool {
    guard case .satisfiable = await solve(constraint) else { return false }
    return true
  }

  /// Generates distinct solutions for a constraint.
  public func generateSolutions(
    _ constraint: SMTConstraint,
    maxSolutions: Int = 10
  ) async -> [SMTResult] {
    var solutions: [SMTResult] = []
    var current = constraint
    for _ in 0..<maxSolutions {
      let result = await solve(current)
      switch result {
      case .satisfiable(let model):
        solutions.append(result)
        current = current.blocking(model)

      case .unsatisfiable:
        return solutions

      default:
        solutions.append(result)
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
      return parseModel(Array(lines.dropFirst()))

    case "unsat":
      return .unsatisfiable

    case "unknown":
      return .unknown

    default:
      return .error("Unexpected output: \(status)")
    }
  }

  private func parseModel(_ lines: [String]) -> SMTResult {
    var model: [String: SMTValue] = [:]
    for line in lines {
      let definition = line.trimmingCharacters(in: .whitespaces)
      guard definition.hasPrefix("(define-fun ") else { continue }
      guard let binding = parseDefinition(definition) else { continue }
      model[binding.name] = binding.value
    }
    return .satisfiable(model)
  }

  private func parseDefinition(_ line: String) -> SMTBinding? {
    let components = line.components(separatedBy: " ")
    guard components.count >= 5, components[0] == "(define-fun" else {
      return nil
    }
    let value = components[components.count - 1]
      .replacingOccurrences(of: ")", with: "")
    guard let parsedValue = parseValue(value) else { return nil }
    return SMTBinding(name: components[1], value: parsedValue)
  }

  private func parseValue(_ value: String) -> SMTValue? {
    if value == "true" { return .bool(true) }
    if value == "false" { return .bool(false) }
    if let integer = Int(value) { return .int(integer) }
    if let real = Double(value) { return .real(real) }
    return nil
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

private struct SMTBinding {
  let name: String
  let value: SMTValue
}

private extension SMTConstraint {
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

private func execute(
  input: String,
  config: SMTSolverConfig
) async throws -> String {
  #if os(macOS)
  let execution = makeExecution(config: config)
  try execution.process.run()
  try write(input, to: execution.input)
  let timeoutTask = timeout(execution.process, after: config.timeout)
  execution.process.waitUntilExit()
  timeoutTask.cancel()
  return try read(execution)
  #else
  throw SMTSolverError.unsupportedOperation(
    "SMT solver execution is unavailable on this platform"
  )
  #endif
}

#if os(macOS)
private struct SMTExecution {
  let process: Process
  let input: Pipe
  let output: Pipe
  let error: Pipe
}

private func makeExecution(config: SMTSolverConfig) -> SMTExecution {
  let execution = SMTExecution(
    process: Process(),
    input: Pipe(),
    output: Pipe(),
    error: Pipe()
  )
  execution.process.executableURL = URL(fileURLWithPath: config.solverPath)
  execution.process.arguments = ["-in"]
  execution.process.standardInput = execution.input
  execution.process.standardOutput = execution.output
  execution.process.standardError = execution.error
  return execution
}

private func write(_ input: String, to pipe: Pipe) throws {
  guard let data = input.data(using: .utf8) else {
    throw SMTSolverError.invalidInput("Input is not valid UTF-8")
  }
  pipe.fileHandleForWriting.write(data)
  pipe.fileHandleForWriting.closeFile()
}

private func timeout(
  _ process: Process,
  after duration: Duration
) -> Task<Void, Error> {
  Task {
    try await Task.sleep(for: duration)
    guard process.isRunning else { return }
    process.terminate()
  }
}

private func read(_ execution: SMTExecution) throws -> String {
  guard execution.process.terminationReason != .uncaughtSignal else {
    throw SMTSolverError.timeout
  }
  let output = execution.output.fileHandleForReading.readDataToEndOfFile()
  guard execution.process.terminationStatus != 0 else {
    return String(data: output, encoding: .utf8) ?? ""
  }
  let error = execution.error.fileHandleForReading.readDataToEndOfFile()
  let message = String(data: error, encoding: .utf8) ?? "Unknown error"
  throw SMTSolverError.solverError(message)
}
#endif
