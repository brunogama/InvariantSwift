import Foundation

enum ExecutionCommandParser {
  private enum OptionResult {
    case handled
    case unrecognized
    case failure(ParseResult)
  }

  static func parseRun(_ arguments: [String]) -> ParseResult {
    var options = RunOptions()
    var warnings: [String] = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if ["--verbose", "-v"].contains(argument) {
        options.verbose = true
        index += 1
        continue
      }
      if ["--help", "-h"].contains(argument) { return ParseResult(command: .help) }
      switch consumeRunValue(argument, at: index, from: arguments, into: &options) {
      case .handled:
        index += 2

      case .failure(let result):
        return result

      case .unrecognized:
        guard argument.hasPrefix("-") else {
          return failure("unexpected argument '\(argument)'")
        }
        warnings.append(compatibilityWarning(argument))
        index += 1
      }
    }
    return ParseResult(command: .run(options), warnings: warnings)
  }

  static func parseReport(_ arguments: [String]) -> ParseResult {
    var options = ReportOptions()
    var warnings: [String] = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if argument == "--include-corpus" {
        options.includeCorpus = true
        index += 1
        continue
      }
      if argument == "--no-stats" {
        options.includeStats = false
        index += 1
        continue
      }
      if ["--help", "-h"].contains(argument) { return ParseResult(command: .help) }
      switch consumeReportValue(argument, at: index, from: arguments, into: &options) {
      case .handled:
        index += 2

      case .failure(let result):
        return result

      case .unrecognized:
        guard argument.hasPrefix("-") else {
          return failure("unexpected argument '\(argument)'")
        }
        warnings.append(compatibilityWarning(argument))
        index += 1
      }
    }
    return ParseResult(command: .report(options), warnings: warnings)
  }

  static func parseBenchmark(_ arguments: [String]) -> ParseResult {
    var options = BenchmarkOptions()
    var warnings: [String] = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if ["--help", "-h"].contains(argument) { return ParseResult(command: .help) }
      switch consumeBenchmarkValue(argument, at: index, from: arguments, into: &options) {
      case .handled:
        index += 2

      case .failure(let result):
        return result

      case .unrecognized:
        guard argument.hasPrefix("-") else {
          return failure("unexpected argument '\(argument)'")
        }
        warnings.append(compatibilityWarning(argument))
        index += 1
      }
    }
    return ParseResult(command: .benchmark(options), warnings: warnings)
  }

  private static func consumeRunValue(
    _ argument: String,
    at index: Int,
    from arguments: [String],
    into options: inout RunOptions
  ) -> OptionResult {
    guard let rawValue = value(after: index, in: arguments) else {
      return runValueOptions.contains(argument) ? .failure(missingValue(argument)) : .unrecognized
    }
    switch argument {
    case "--iterations", "-i":
      guard let parsed = Int(rawValue), parsed > 0 else { return .failure(invalidValue(argument)) }
      options.iterations = parsed

    case "--max-shrinks", "-s":
      guard let parsed = Int(rawValue), parsed >= 0 else { return .failure(invalidValue(argument)) }
      options.maxShrinks = parsed

    case "--timeout", "-t":
      guard let parsed = Double(rawValue), parsed > 0 else {
        return .failure(invalidValue(argument))
      }
      options.timeout = parsed

    case "--report", "-r":
      options.reportPath = rawValue

    default:
      return .unrecognized
    }
    return .handled
  }

  private static func consumeReportValue(
    _ argument: String,
    at index: Int,
    from arguments: [String],
    into options: inout ReportOptions
  ) -> OptionResult {
    guard let rawValue = value(after: index, in: arguments) else {
      return reportValueOptions.contains(argument)
        ? .failure(missingValue(argument)) : .unrecognized
    }
    switch argument {
    case "--output", "-o":
      options.outputPath = rawValue

    case "--format", "-f":
      guard let format = ReportFormat(rawValue: rawValue) else {
        return .failure(failure("invalid report format '\(rawValue)'"))
      }
      options.format = format

    default:
      return .unrecognized
    }
    return .handled
  }

  private static func consumeBenchmarkValue(
    _ argument: String,
    at index: Int,
    from arguments: [String],
    into options: inout BenchmarkOptions
  ) -> OptionResult {
    guard let rawValue = value(after: index, in: arguments) else {
      return benchmarkValueOptions.contains(argument)
        ? .failure(missingValue(argument)) : .unrecognized
    }
    switch argument {
    case "--iterations", "--sizes":
      let values = rawValue.split(separator: ",").compactMap { Int($0) }
      guard !values.isEmpty, values.allSatisfy({ $0 > 0 }) else {
        return .failure(invalidValue(argument))
      }
      if argument == "--iterations" { options.iterations = values } else { options.sizes = values }

    case "--output", "-o":
      options.outputPath = rawValue

    case "--compare":
      options.compareBaseline = rawValue

    default:
      return .unrecognized
    }
    return .handled
  }

  private static let runValueOptions = [
    "--iterations", "-i", "--max-shrinks", "-s", "--timeout", "-t", "--report", "-r",
  ]
  private static let reportValueOptions = ["--output", "-o", "--format", "-f"]
  private static let benchmarkValueOptions = [
    "--iterations", "--sizes", "--output", "-o", "--compare",
  ]

  private static func value(after index: Int, in arguments: [String]) -> String? {
    let valueIndex = index + 1
    guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("-") else { return nil }
    return arguments[valueIndex]
  }

  private static func missingValue(_ option: String) -> ParseResult {
    failure("missing value for '\(option)'")
  }

  private static func invalidValue(_ option: String) -> ParseResult {
    failure("invalid value for '\(option)'")
  }

  private static func compatibilityWarning(_ option: String) -> String {
    "ignoring deprecated unknown option '\(option)'"
  }

  private static func failure(_ message: String) -> ParseResult {
    ParseResult(command: nil, error: message)
  }
}
