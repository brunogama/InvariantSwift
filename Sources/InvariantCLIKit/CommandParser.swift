import Foundation

enum InvariantCommandParser {
  static func parse(_ arguments: [String]) -> ParseResult {
    guard let command = arguments.first else { return ParseResult(command: .help) }
    let values = Array(arguments.dropFirst())
    if ["help", "--help", "-h"].contains(command) { return ParseResult(command: .help) }
    if ["version", "--version"].contains(command) { return ParseResult(command: .version) }
    guard let parser = commandParsers[command] else {
      return failure("unknown command '\(command)'")
    }
    return parser(values)
  }

  private typealias CommandParser = @Sendable ([String]) -> ParseResult

  private static let commandParsers: [String: CommandParser] = [
    "run": ExecutionCommandParser.parseRun,
    "report": ExecutionCommandParser.parseReport,
    "corpus": parseCorpus,
    "benchmark": ExecutionCommandParser.parseBenchmark,
    "characterize": parseCharacterize,
    "ghostwrite": parseGhostwrite,
    "generators": parseGenerators,
    "interactive": parseInteractive,
  ]

  private static func parseInteractive(_ arguments: [String]) -> ParseResult {
    arguments.isEmpty ? ParseResult(command: .interactive) : unknown(arguments[0])
  }

  private static func parseCorpus(_ arguments: [String]) -> ParseResult {
    guard let action = arguments.first else { return ParseResult(command: .corpus(.init())) }
    let extras = Array(arguments.dropFirst())
    switch action {
    case "list":
      return noExtras(extras, command: .corpus(.init(action: .list)))

    case "clear":
      return noExtras(extras, command: .corpus(.init(action: .clear)))

    case "stats":
      return noExtras(extras, command: .corpus(.init(action: .stats)))

    case "export":
      return optionalPath(extras, action: CorpusAction.export, defaultPath: "corpus.json")

    case "import":
      return optionalPath(extras, action: CorpusAction.import, defaultPath: "corpus.json")

    case "--help", "-h":
      return ParseResult(command: .corpus(.init()))

    default:
      return failure("unknown corpus command '\(action)'")
    }
  }

  private static func parseCharacterize(_ arguments: [String]) -> ParseResult {
    var options = CharacterizeOptions()
    var selectedModes: Set<CharacterizationMode> = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      switch argument {
      case "--record":
        selectedModes.insert(.record)
        index += 1

      case "--verify":
        selectedModes.insert(.verify)
        index += 1

      case "--target":
        guard let target = value(after: index, in: arguments) else { return missingValue(argument) }
        options.target = target
        index += 2

      case "--help", "-h":
        return ParseResult(command: .help)

      default:
        options.forwardedArguments.append(argument)
        index += 1
      }
    }
    guard selectedModes.count <= 1 else { return failure("use only one of --record or --verify") }
    options.mode = selectedModes.first ?? .verify
    return ParseResult(command: .characterize(options))
  }

  private static func parseGhostwrite(_ arguments: [String]) -> ParseResult {
    var sources: [String] = []
    var options = GhostwriteOptions(sources: [])
    var warnings: [String] = []
    var index = 0
    while index < arguments.count {
      let argument = arguments[index]
      if applyGhostwriteBoolFlag(argument, to: &options) {
        index += 1
        continue
      }
      switch argument {
      case "--source", "-s":
        guard let path = value(after: index, in: arguments) else { return missingValue(argument) }
        sources.append(path)
        index += 2

      case "--output", "-o":
        guard let path = value(after: index, in: arguments) else { return missingValue(argument) }
        options.outputDirectory = path
        index += 2

      case "--help", "-h":
        return ParseResult(command: .help)

      default:
        if argument.hasPrefix("-") {
          warnings.append(compatibilityWarning(argument))
        } else {
          sources.append(argument)
        }
        index += 1
      }
    }
    options.sources = sources.isEmpty ? ["Sources/"] : sources
    return ParseResult(command: .ghostwrite(options), warnings: warnings)
  }

  private static func parseGenerators(_ arguments: [String]) -> ParseResult {
    guard let first = arguments.first else {
      return ParseResult(command: .generators(.interactive))
    }
    switch first {
    case "--interactive", "-i":
      return noExtras(Array(arguments.dropFirst()), command: .generators(.interactive))

    case "--list":
      return noExtras(Array(arguments.dropFirst()), command: .generators(.list))

    case "--search":
      return requiredGeneratorValue(arguments, action: GeneratorAction.search)

    case "--category":
      return requiredGeneratorValue(arguments, action: GeneratorAction.category)

    case "--sample":
      return requiredGeneratorValue(arguments, action: GeneratorAction.sample)

    case "--help", "-h":
      return ParseResult(command: .generators(.help))

    default:
      return unknown(first)
    }
  }

  private static func applyGhostwriteBoolFlag(
    _ argument: String,
    to options: inout GhostwriteOptions
  ) -> Bool {
    switch argument {
    case "--dry-run": options.dryRun = true
    case "--verbose", "-v": options.verbose = true
    case "--include-internal": options.includeInternal = true
    case "--skip-compile-test": options.skipCompileTest = true
    default: return false
    }
    return true
  }

  private static func optionalPath(
    _ arguments: [String],
    action: (String) -> CorpusAction,
    defaultPath: String
  ) -> ParseResult {
    guard arguments.count <= 1 else { return failure("too many corpus arguments") }
    return ParseResult(command: .corpus(.init(action: action(arguments.first ?? defaultPath))))
  }

  private static func requiredGeneratorValue(
    _ arguments: [String],
    action: (String) -> GeneratorAction
  ) -> ParseResult {
    guard arguments.count >= 2 else { return missingValue(arguments[0]) }
    guard arguments.count == 2 else { return failure("too many generator arguments") }
    return ParseResult(command: .generators(action(arguments[1])))
  }

  private static func noExtras(_ extras: [String], command: InvariantCommand) -> ParseResult {
    extras.isEmpty ? ParseResult(command: command) : failure("unexpected argument '\(extras[0])'")
  }

  private static func value(after index: Int, in arguments: [String]) -> String? {
    let valueIndex = index + 1
    guard valueIndex < arguments.count, !arguments[valueIndex].hasPrefix("-") else { return nil }
    return arguments[valueIndex]
  }

  private static func unknown(_ value: String) -> ParseResult {
    failure("unknown option '\(value)'")
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
