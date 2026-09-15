import Foundation

/// Maps `SMTSolverConfig` options onto the command line of the selected solver.
///
/// Options have no portable spelling, so each supported solver family gets its
/// own mapping. An unrecognised solver receives only the stdin flag: silently
/// passing a z3 flag to another binary would make it fail to launch.
enum SMTSolverArguments {
  enum Family {
    case zThree
    case cvc
    case unknown

    init(solverPath: String) {
      let name = (solverPath as NSString).lastPathComponent.lowercased()
      if name.contains("z3") {
        self = .zThree
      } else if name.contains("cvc") {
        self = .cvc
      } else {
        self = .unknown
      }
    }
  }

  static func arguments(for config: SMTSolverConfig) -> [String] {
    let family = Family(solverPath: config.solverPath)
    return ["-in"] + options(for: config, family: family)
  }

  private static func options(for config: SMTSolverConfig, family: Family) -> [String] {
    switch family {
    case .zThree:
      return zThreeOptions(for: config)

    case .cvc:
      return cvcOptions(for: config)

    case .unknown:
      return []
    }
  }

  private static func zThreeOptions(for config: SMTSolverConfig) -> [String] {
    var options: [String] = []
    if let memoryLimit = config.memoryLimit, memoryLimit > 0 {
      options.append("-memory:\(memoryLimit)")
    }
    if let seed = config.randomSeed {
      options.append("smt.random_seed=\(seed)")
      options.append("sat.random_seed=\(seed)")
    }
    return options
  }

  private static func cvcOptions(for config: SMTSolverConfig) -> [String] {
    guard let seed = config.randomSeed else { return [] }
    return ["--seed=\(seed)"]
  }
}
