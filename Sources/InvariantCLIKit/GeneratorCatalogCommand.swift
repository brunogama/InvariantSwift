import Foundation

struct GeneratorCatalogCommand {
  let output: any CLIOutput

  func run(_ action: GeneratorAction) {
    switch action {
    case .interactive:
      interactive()

    case .list:
      output.writeStandardOutput(list())

    case .search(let query):
      output.writeStandardOutput(search(query))

    case .category(let category):
      output.writeStandardOutput(categoryList(category))

    case .sample(let identifier):
      output.writeStandardOutput(sample(identifier))

    case .help:
      output.writeStandardOutput(Self.help)
    }
  }

  private func interactive() {
    output.writeStandardOutput(Self.interactiveIntroduction)
    while let line = readLine() {
      let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
      guard let command = parts.first else { continue }
      let value = parts.count == 2 ? parts[1] : ""
      switch command.lowercased() {
      case "list":
        output.writeStandardOutput(list())

      case "search":
        output.writeStandardOutput(search(value))

      case "category":
        output.writeStandardOutput(categoryList(value))

      case "sample":
        output.writeStandardOutput(sample(value))

      case "help":
        output.writeStandardOutput(Self.help)

      case "quit", "exit", "q":
        output.writeStandardOutput("Goodbye!\n")
        return

      default:
        output.writeStandardOutput("Unknown command. Type 'help' for options.\n")
      }
    }
  }

  private func list() -> String {
    var lines = [
      "Generator Catalog (\(Self.catalog.count) generators)", String(repeating: "=", count: 50),
    ]
    for generator in Self.catalog {
      lines += [
        "", "[\(generator.id)]", "  Name: \(generator.name)", "  Type: \(generator.type)",
        "  Category: \(generator.category)", "  Description: \(generator.description)",
      ]
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private func search(_ query: String) -> String {
    let lowercased = query.lowercased()
    let matches = Self.catalog.filter {
      $0.name.lowercased().contains(lowercased)
        || $0.type.lowercased().contains(lowercased)
        || $0.description.lowercased().contains(lowercased)
    }
    guard !matches.isEmpty else { return "No generators found matching '\(query)'\n" }
    var lines = [
      "Search Results for '\(query)' (\(matches.count) found)", String(repeating: "=", count: 50),
    ]
    for generator in matches {
      lines += [
        "", "[\(generator.id)] \(generator.name)",
        "  Type: \(generator.type) | Category: \(generator.category)",
        "  Description: \(generator.description)", "  Example: \(generator.example)",
      ]
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private func categoryList(_ category: String) -> String {
    let canonical = Self.categories.first { $0.caseInsensitiveCompare(category) == .orderedSame }
    guard let canonical else {
      let available = Self.categories.joined(separator: ", ")
      return "Unknown category: \(category)\nAvailable categories: \(available)\n"
    }
    let matches = Self.catalog.filter { $0.category == canonical }
    var lines = [
      "\(canonical) Generators (\(matches.count) total)", String(repeating: "=", count: 50),
    ]
    for generator in matches {
      lines += [
        "", "[\(generator.id)] \(generator.name)", "  Type: \(generator.type)",
        "  Description: \(generator.description)", "  Example: \(generator.example)",
      ]
    }
    return lines.joined(separator: "\n") + "\n"
  }

  private func sample(_ identifier: String) -> String {
    guard let generator = Self.catalog.first(where: { $0.id == identifier }) else {
      return
        "Generator '\(identifier)' not found.\nUse --list to see all available generator IDs.\n"
    }
    let values = (1...5).map { "\($0). \(sampleValue(for: generator.id))" }
    return """
      Generator: \(generator.name)
      Type: \(generator.type)
      Description: \(generator.description)

      Sample values:
      --------------------------------------------------
      \(values.joined(separator: "\n"))

      Code example:
      \(generator.example)
      """ + "\n"
  }

  private func sampleValue(for identifier: String) -> String {
    switch identifier {
    case "bool": Bool.random() ? "true" : "false"
    case "uuid": UUID().uuidString
    case "character", "letter": String(UnicodeScalar(Int.random(in: 65...90)) ?? "A")
    case "string-ascii": UUID().uuidString.prefix(8).description
    default: String(Int.random(in: 0...100))
    }
  }
}

private extension GeneratorCatalogCommand {
  struct Entry: Sendable {
    let id: String
    let name: String
    let type: String
    let category: String
    let description: String
    let example: String
  }

  static let categories = [
    "Primitive", "Numeric", "String", "Collection", "Composite", "Domain Data", "Custom",
  ]

  static let catalog: [Entry] = [
    .init(
      id: "int",
      name: "Gen<Int>.int",
      type: "Int",
      category: "Primitive",
      description: "Generates random integers across the full Int range.",
      example: "let gen = Gen<Int>.int"
    ),
    .init(
      id: "int-range",
      name: "Gen<Int>.int(in:)",
      type: "Int",
      category: "Primitive",
      description: "Generates integers within a specific range.",
      example: "let gen = Gen<Int>.int(in: 1...100)"
    ),
    .init(
      id: "bool",
      name: "Gen<Bool>.bool",
      type: "Bool",
      category: "Primitive",
      description: "Generates random boolean values.",
      example: "let gen = Gen<Bool>.bool"
    ),
    .init(
      id: "character",
      name: "Gen<Character>.letter",
      type: "Character",
      category: "Primitive",
      description: "Generates random alphabetic characters.",
      example: "let gen = Gen<Character>.letter"
    ),
    .init(
      id: "int8",
      name: "Gen<Int8>.int8",
      type: "Int8",
      category: "Numeric",
      description: "Generates Int8 values.",
      example: "let gen = Gen<Int8>.int8"
    ),
    .init(
      id: "int16",
      name: "Gen<Int16>.int16",
      type: "Int16",
      category: "Numeric",
      description: "Generates Int16 values.",
      example: "let gen = Gen<Int16>.int16"
    ),
    .init(
      id: "int32",
      name: "Gen<Int32>.int32",
      type: "Int32",
      category: "Numeric",
      description: "Generates Int32 values.",
      example: "let gen = Gen<Int32>.int32"
    ),
    .init(
      id: "int64",
      name: "Gen<Int64>.int64",
      type: "Int64",
      category: "Numeric",
      description: "Generates Int64 values.",
      example: "let gen = Gen<Int64>.int64"
    ),
    .init(
      id: "uint",
      name: "Gen<UInt>.uint",
      type: "UInt",
      category: "Numeric",
      description: "Generates unsigned integers.",
      example: "let gen = Gen<UInt>.uint"
    ),
    .init(
      id: "double",
      name: "Gen<Double>.double",
      type: "Double",
      category: "Numeric",
      description: "Generates Double values.",
      example: "let gen = Gen<Double>.double"
    ),
    .init(
      id: "float",
      name: "Gen<Float>.float",
      type: "Float",
      category: "Numeric",
      description: "Generates Float values.",
      example: "let gen = Gen<Float>.float"
    ),
    .init(
      id: "string-ascii",
      name: "Gen<String>.asciiString",
      type: "String",
      category: "String",
      description: "Generates printable ASCII strings.",
      example: "let gen = Gen<String>.asciiString"
    ),
    .init(
      id: "letter",
      name: "Gen<Character>.letter",
      type: "Character",
      category: "String",
      description: "Generates alphabetic characters.",
      example: "let gen = Gen<Character>.letter"
    ),
    .init(
      id: "digit",
      name: "Gen<Character>.digit",
      type: "Character",
      category: "String",
      description: "Generates numeric digit characters.",
      example: "let gen = Gen<Character>.digit"
    ),
    .init(
      id: "uuid",
      name: "Gen<UUID>.uuid",
      type: "UUID",
      category: "String",
      description: "Generates random UUIDs.",
      example: "let gen = Gen<UUID>.uuid"
    ),
    .init(
      id: "array",
      name: "Gen.array(_:)",
      type: "[T]",
      category: "Collection",
      description: "Generates arrays from an element generator.",
      example: "let gen = Gen<[Int]>.array(Gen<Int>.int)"
    ),
    .init(
      id: "set",
      name: "Gen.set(_:)",
      type: "Set<T>",
      category: "Collection",
      description: "Generates sets of hashable values.",
      example: "let gen = Gen<Set<Int>>.set(Gen<Int>.int)"
    ),
    .init(
      id: "dictionary",
      name: "Gen.dictionary(_:_:)",
      type: "[K: V]",
      category: "Collection",
      description: "Generates dictionaries with key-value pairs.",
      example: "let gen = Gen<[Int: Int]>.dictionary(Gen<Int>.int, Gen<Int>.int)"
    ),
    .init(
      id: "optional",
      name: "OptionalGen.optional(valueGen:)",
      type: "T?",
      category: "Collection",
      description: "Generates optional values.",
      example: "let gen = OptionalGen.optional(valueGen: Gen<Int>.int)"
    ),
    .init(
      id: "pure",
      name: "Gen.pure(_:)",
      type: "T",
      category: "Composite",
      description: "Generates a constant value.",
      example: "let gen = Gen.pure(42)"
    ),
    .init(
      id: "oneof",
      name: "Gen.oneOf(_:)",
      type: "T",
      category: "Composite",
      description: "Selects from multiple generators.",
      example: "let gen = Gen.oneOf([gen1, gen2])"
    ),
    .init(
      id: "frequency",
      name: "Gen.frequency(_:)",
      type: "T",
      category: "Composite",
      description: "Selects generators by weighted frequency.",
      example: "let gen = Gen.frequency([(1, gen)])"
    ),
    .init(
      id: "uint8",
      name: "Gen<UInt8>.uint8",
      type: "UInt8",
      category: "Numeric",
      description: "Generates UInt8 values.",
      example: "let gen = Gen<UInt8>.uint8"
    ),
    .init(
      id: "cgfloat",
      name: "Gen<CGFloat>.cgFloat",
      type: "CGFloat",
      category: "Numeric",
      description: "Generates CGFloat values.",
      example: "let gen = Gen<CGFloat>.cgFloat"
    ),
  ]

  static let interactiveIntroduction = """
    InvariantSwift Generator Catalog Browser
    Use list, category, search, sample, help, or quit.
    """ + "\n"

  static let help = """
    Generator Catalog Browser

    OPTIONS:
        --interactive, -i    Launch interactive browser (default)
        --list               List all available generators
        --search <query>     Search generators by name or description
        --category <name>    List generators in a category
        --sample <id>        Generate sample values
        --help, -h           Show this help
    """ + "\n"
}
