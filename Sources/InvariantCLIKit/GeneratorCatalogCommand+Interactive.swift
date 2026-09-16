import Foundation

extension GeneratorCatalogCommand {
  func interactive() -> Int32 {
    var status: Int32 = 0
    output.writeStandardOutput(Self.interactiveIntroduction)
    while let line = readLine() {
      let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
      guard let command = parts.first else { continue }
      let value = parts.count == 2 ? parts[1] : ""
      switch command.lowercased() {
      case "list":
        _ = run(.list)

      case "search":
        _ = run(.search(value))

      case "category":
        _ = run(.category(value))

      case "sample":
        _ = run(.sample(value))

      case "save-filter", "filters", "filter", "delete-filter":
        status = max(
          status,
          runInteractiveFilterCommand(command: command.lowercased(), value: value)
        )

      case "help":
        output.writeStandardOutput(Self.help)

      case "quit", "exit", "q":
        output.writeStandardOutput("Goodbye!\n")
        return status

      default:
        output.writeStandardOutput("Unknown command. Type 'help' for options.\n")
      }
    }
    return status
  }

  static let interactiveIntroduction = """
    InvariantSwift Generator Catalog Browser
    Use list, category, search, sample, save-filter, filters, filter, delete-filter, help, or quit.
    """ + "\n"

  static let help = """
    Generator Catalog Browser

    OPTIONS:
        --interactive, -i             Launch interactive browser (default)
        --list                        List all available generators
        --search <query>              Search generator names, types, and descriptions
        --category <name>             List generators in a category
        --sample <id>                 Generate sample values
        --save-filter <name> <query>   Save or replace a named search
        --filters                     List saved searches
        --filter <name>               Run a saved search
        --delete-filter <name>        Delete a saved search
        --help, -h                    Show this help
    """ + "\n"
}
