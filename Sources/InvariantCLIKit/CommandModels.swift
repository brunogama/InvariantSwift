import Foundation

enum InvariantCommand: Equatable, Sendable {
  case run(RunOptions)
  case report(ReportOptions)
  case corpus(CorpusOptions)
  case benchmark(BenchmarkOptions)
  case characterize(CharacterizeOptions)
  case ghostwrite(GhostwriteOptions)
  case generators(GeneratorAction)
  case interactive
  case version
  case help

  var name: String {
    switch self {
    case .run: "run"
    case .report: "report"
    case .corpus: "corpus"
    case .benchmark: "benchmark"
    case .characterize: "characterize"
    case .ghostwrite: "ghostwrite"
    case .generators: "generators"
    case .interactive: "interactive"
    case .version: "version"
    case .help: "help"
    }
  }
}

struct RunOptions: Equatable, Sendable {
  var iterations: Int
  var maxShrinks: Int
  var timeout: TimeInterval
  var reportPath: String?
  var verbose: Bool

  init(
    iterations: Int = 100,
    maxShrinks: Int = 1_000,
    timeout: TimeInterval = 30,
    reportPath: String? = nil,
    verbose: Bool = false
  ) {
    self.iterations = iterations
    self.maxShrinks = maxShrinks
    self.timeout = timeout
    self.reportPath = reportPath
    self.verbose = verbose
  }
}

enum ReportFormat: String, CaseIterable, Equatable, Sendable {
  case json, html, markdown, csv
}

struct ReportOptions: Equatable, Sendable {
  var outputPath: String
  var format: ReportFormat
  var includeCorpus: Bool
  var includeStats: Bool

  init(
    outputPath: String = "functest-report",
    format: ReportFormat = .html,
    includeCorpus: Bool = false,
    includeStats: Bool = true
  ) {
    self.outputPath = outputPath
    self.format = format
    self.includeCorpus = includeCorpus
    self.includeStats = includeStats
  }
}

enum CorpusAction: Equatable, Sendable {
  case list
  case clear
  case stats
  case export(String)
  case `import`(String)
  case help
}

struct CorpusOptions: Equatable, Sendable {
  var action: CorpusAction

  init(action: CorpusAction = .help) {
    self.action = action
  }
}

struct BenchmarkOptions: Equatable, Sendable {
  var iterations: [Int]
  var sizes: [Int]
  var outputPath: String?
  var compareBaseline: String?

  init(
    iterations: [Int] = [10, 50, 100, 500, 1_000],
    sizes: [Int] = [1, 5, 10, 50, 100],
    outputPath: String? = nil,
    compareBaseline: String? = nil
  ) {
    self.iterations = iterations
    self.sizes = sizes
    self.outputPath = outputPath
    self.compareBaseline = compareBaseline
  }
}

enum CharacterizationMode: String, Equatable, Sendable {
  case record, verify
}

struct CharacterizeOptions: Equatable, Sendable {
  var mode: CharacterizationMode
  var target: String?
  var forwardedArguments: [String]

  init(
    mode: CharacterizationMode = .verify,
    target: String? = nil,
    forwardedArguments: [String] = []
  ) {
    self.mode = mode
    self.target = target
    self.forwardedArguments = forwardedArguments
  }
}

struct GhostwriteOptions: Equatable, Sendable {
  var sources: [String]
  var outputDirectory: String
  var dryRun: Bool
  var verbose: Bool
  var includeInternal: Bool
  var skipCompileTest: Bool

  init(
    sources: [String] = ["Sources/"],
    outputDirectory: String = "Tests/Generated/",
    dryRun: Bool = false,
    verbose: Bool = false,
    includeInternal: Bool = false,
    skipCompileTest: Bool = false
  ) {
    self.sources = sources
    self.outputDirectory = outputDirectory
    self.dryRun = dryRun
    self.verbose = verbose
    self.includeInternal = includeInternal
    self.skipCompileTest = skipCompileTest
  }
}

enum GeneratorAction: Equatable, Sendable {
  case interactive
  case list
  case search(String)
  case category(String)
  case sample(String)
  case help
}

struct ParseResult: Equatable, Sendable {
  let command: InvariantCommand?
  let warnings: [String]
  let error: String?

  init(command: InvariantCommand?, warnings: [String] = [], error: String? = nil) {
    self.command = command
    self.warnings = warnings
    self.error = error
  }
}
