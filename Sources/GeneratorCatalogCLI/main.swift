import Foundation

struct GeneratorCatalogCLI {
  static func main() {
    let arguments = CommandLine.arguments

    // Check for flags
    if arguments.contains("--help") || arguments.contains("-h") {
      printHelp()
      return
    }

    if arguments.contains("--list") {
      listGenerators()
      return
    }

    if let searchIndex = arguments.firstIndex(of: "--search") {
      let query = arguments.dropFirst(searchIndex + 1).first ?? ""
      searchGenerators(query: query)
      return
    }

    if let categoryIndex = arguments.firstIndex(of: "--category") {
      let categoryName = arguments.dropFirst(categoryIndex + 1).first ?? ""
      listByCategory(categoryName: categoryName)
      return
    }

    if let sampleIndex = arguments.firstIndex(of: "--sample") {
      let generatorID = arguments.dropFirst(sampleIndex + 1).first ?? ""
      generateSample(generatorID: generatorID)
      return
    }

    if arguments.contains("--interactive") || arguments.count == 1 {
      // Default to interactive mode
      let browser = CatalogBrowser()
      browser.run()
      return
    }

    // Unknown arguments
    print("Unknown arguments. Use --help for usage information.")
  }

  static func printHelp() {
    print(
      """
      Generator Catalog Browser

      USAGE:
          swift package browse-generators [OPTIONS]

      OPTIONS:
          --interactive, -i    Launch interactive browser (default)
          --list               List all available generators
          --search <query>     Search generators by name or description
          --category <name>    List generators in a category
          --sample <id>        Generate sample value for a generator
          --help, -h           Show this help

      CATEGORIES:
          Primitive, Numeric, String, Collection, Composite, DomainData, Custom

      EXAMPLES:
          swift package browse-generators
          swift package browse-generators --list
          swift package browse-generators --search email
          swift package browse-generators --category Numeric
          swift package browse-generators --sample int-range
      """
    )
  }

  static func listGenerators() {
    let catalog = GeneratorCatalog.shared

    print("Generator Catalog (\(catalog.generators.count) generators)")
    print(String(repeating: "=", count: 50))

    for gen in catalog.generators {
      print("\n[\(gen.id)]")
      print("  Name: \(gen.name)")
      print("  Type: \(gen.type)")
      print("  Category: \(gen.category.rawValue)")
      print("  Description: \(gen.description)")
    }
  }

  static func searchGenerators(query: String) {
    let catalog = GeneratorCatalog.shared
    let results = catalog.search(query)

    if results.isEmpty {
      print("No generators found matching '\(query)'")
      return
    }

    print("Search Results for '\(query)' (\(results.count) found)")
    print(String(repeating: "=", count: 50))

    for gen in results {
      print("\n[\(gen.id)] \(gen.name)")
      print("  Type: \(gen.type) | Category: \(gen.category.rawValue)")
      print("  Description: \(gen.description)")
      print("  Example: \(gen.example)")
    }
  }

  static func listByCategory(categoryName: String) {
    guard
      let category = GeneratorCategory.allCases.first(where: {
        $0.rawValue.lowercased() == categoryName.lowercased()
      })
    else {
      print("Unknown category: \(categoryName)")
      print(
        "Available categories: \(GeneratorCategory.allCases.map { $0.rawValue }.joined(separator: ", "))"
      )
      return
    }

    let catalog = GeneratorCatalog.shared
    let generators = catalog.filter(category: category)

    print("\(category.rawValue) Generators (\(generators.count) total)")
    print(String(repeating: "=", count: 50))

    for gen in generators {
      print("\n[\(gen.id)] \(gen.name)")
      print("  Type: \(gen.type)")
      print("  Description: \(gen.description)")
      print("  Example: \(gen.example)")
    }
  }

  static func generateSample(generatorID: String) {
    let catalog = GeneratorCatalog.shared

    guard let generator = catalog.generators.first(where: { $0.id == generatorID }) else {
      print("Generator '\(generatorID)' not found.")
      print("Use --list to see all available generator IDs.")
      return
    }

    print("Generator: \(generator.name)")
    print("Type: \(generator.type)")
    print("Description: \(generator.description)")
    print("")
    print("Sample values:")
    print(String(repeating: "-", count: 50))

    for i in 1...5 {
      let sample = generator.sampleGenerator()
      print("\(i). \(sample)")
    }

    print("")
    print("Code example:")
    print(generator.example)
  }
}

// Entry point
GeneratorCatalogCLI.main()
