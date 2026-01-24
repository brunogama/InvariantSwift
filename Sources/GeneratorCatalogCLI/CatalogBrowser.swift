// swiftlint:disable no_print file_length function_body_length type_body_length
import Foundation
import InvariantSwift

// MARK: - Generator Category

/// Categories for organizing generators in the catalog.
public enum GeneratorCategory: String, CaseIterable, Sendable {
  case primitive = "Primitive"
  case numeric = "Numeric"
  case string = "String"
  case collection = "Collection"
  case composite = "Composite"
  case domainData = "Domain Data"
  case custom = "Custom"
}

// MARK: - Generator Info

/// Information about a generator for catalog display.
public struct GeneratorInfo: Sendable, Identifiable {
  public let id: String
  public let name: String
  public let type: String
  public let category: GeneratorCategory
  public let description: String
  public let example: String
  public let sampleGenerator: @Sendable () -> String

  public init(
    id: String,
    name: String,
    type: String,
    category: GeneratorCategory,
    description: String,
    example: String,
    sampleGenerator: @escaping @Sendable () -> String
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.category = category
    self.description = description
    self.example = example
    self.sampleGenerator = sampleGenerator
  }
}

// MARK: - Generator Catalog

/// Catalog of all built-in generators.
public struct GeneratorCatalog: Sendable {
  public static let shared = Self()

  public let generators: [GeneratorInfo]

  private init() {
    generators = [
      // MARK: - Primitive Types

      GeneratorInfo(
        id: "int",
        name: "Gen<Int>.int",
        type: "Int",
        category: .primitive,
        description: "Generates random integers across the full Int range with edge case handling.",
        example: "let gen = Gen<Int>.int",
        sampleGenerator: { String(Gen<Int>.int.sample(size: Size(value: 50), seed: Seed.random)) }
      ),

      GeneratorInfo(
        id: "int-range",
        name: "Gen<Int>.int(in:)",
        type: "Int",
        category: .primitive,
        description: "Generates integers within a specific range.",
        example: "let gen = Gen<Int>.int(in: 1...100)",
        sampleGenerator: {
          String(Gen<Int>.int(in: 1...100).sample(size: Size(value: 50), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "bool",
        name: "Gen<Bool>.bool",
        type: "Bool",
        category: .primitive,
        description: "Generates random boolean values.",
        example: "let gen = Gen<Bool>.bool",
        sampleGenerator: {
          String(Gen<Bool>.bool.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "character",
        name: "Gen<Character>.letter",
        type: "Character",
        category: .primitive,
        description: "Generates random alphabetic characters (a-z, A-Z).",
        example: "let gen = Gen<Character>.letter",
        sampleGenerator: {
          String(Gen<Character>.letter.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      // MARK: - Numeric Types

      GeneratorInfo(
        id: "int8",
        name: "Gen<Int8>.int8",
        type: "Int8",
        category: .numeric,
        description: "Generates Int8 values with comprehensive edge cases.",
        example: "let gen = Gen<Int8>.int8",
        sampleGenerator: {
          String(Gen<Int8>.int8.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "int16",
        name: "Gen<Int16>.int16",
        type: "Int16",
        category: .numeric,
        description: "Generates Int16 values with comprehensive edge cases.",
        example: "let gen = Gen<Int16>.int16",
        sampleGenerator: {
          String(Gen<Int16>.int16.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "int32",
        name: "Gen<Int32>.int32",
        type: "Int32",
        category: .numeric,
        description: "Generates Int32 values with comprehensive edge cases.",
        example: "let gen = Gen<Int32>.int32",
        sampleGenerator: {
          String(Gen<Int32>.int32.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "int64",
        name: "Gen<Int64>.int64",
        type: "Int64",
        category: .numeric,
        description: "Generates Int64 values with comprehensive edge cases.",
        example: "let gen = Gen<Int64>.int64",
        sampleGenerator: {
          String(Gen<Int64>.int64.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "uint",
        name: "Gen<UInt>.uint",
        type: "UInt",
        category: .numeric,
        description: "Generates unsigned integers.",
        example: "let gen = Gen<UInt>.uint",
        sampleGenerator: {
          String(Gen<UInt>.uint.sample(size: Size(value: 50), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "double",
        name: "Gen<Double>.double",
        type: "Double",
        category: .numeric,
        description: "Generates Double values with NaN and infinity handling.",
        example: "let gen = Gen<Double>.double",
        sampleGenerator: {
          String(Gen<Double>.double.sample(size: Size(value: 50), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "float",
        name: "Gen<Float>.float",
        type: "Float",
        category: .numeric,
        description: "Generates Float values with NaN and infinity handling.",
        example: "let gen = Gen<Float>.float",
        sampleGenerator: {
          String(Gen<Float>.float.sample(size: Size(value: 50), seed: Seed.random))
        }
      ),

      // MARK: - String Generators

      GeneratorInfo(
        id: "string-ascii",
        name: "Gen<String>.asciiString",
        type: "String",
        category: .string,
        description: "Generates strings containing printable ASCII characters.",
        example: "let gen = Gen<String>.asciiString",
        sampleGenerator: {
          Gen<String>.asciiString.sample(size: Size(value: 15), seed: Seed.random)
        }
      ),

      GeneratorInfo(
        id: "letter",
        name: "Gen<Character>.letter",
        type: "Character",
        category: .string,
        description: "Generates alphabetic characters (a-z, A-Z).",
        example: "let gen = Gen<Character>.letter",
        sampleGenerator: {
          String(Gen<Character>.letter.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "digit",
        name: "Gen<Character>.digit",
        type: "Character",
        category: .string,
        description: "Generates numeric digit characters (0-9).",
        example: "let gen = Gen<Character>.digit",
        sampleGenerator: {
          String(Gen<Character>.digit.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "uuid",
        name: "Gen<UUID>.uuid",
        type: "UUID",
        category: .string,
        description: "Generates random UUIDs.",
        example: "let gen = Gen<UUID>.uuid",
        sampleGenerator: {
          Gen<UUID>.uuid.sample(size: Size(value: 10), seed: Seed.random).uuidString
        }
      ),

      // MARK: - Collection Generators

      GeneratorInfo(
        id: "array",
        name: "Gen.array(_:)",
        type: "[T]",
        category: .collection,
        description: "Generates arrays of values from an element generator.",
        example: "let gen = Gen<[Int]>.array(Gen<Int>.int)",
        sampleGenerator: {
          let arr = Gen<[Int]>.array(Gen<Int>.int(in: 1...100))
            .sample(size: Size(value: 10), seed: Seed.random)
          return "[\(arr.map { String($0) }.joined(separator: ", "))]"
        }
      ),

      GeneratorInfo(
        id: "set",
        name: "Gen.set(_:)",
        type: "Set<T>",
        category: .collection,
        description: "Generates sets of hashable values.",
        example: "let gen = Gen<Set<Int>>.set(Gen<Int>.int)",
        sampleGenerator: {
          let set = Gen<Set<Int>>.set(Gen<Int>.int(in: 1...100))
            .sample(size: Size(value: 10), seed: Seed.random)
          return "Set([\(set.sorted().map { String($0) }.joined(separator: ", "))])"
        }
      ),

      GeneratorInfo(
        id: "dictionary",
        name: "Gen.dictionary(_:_:)",
        type: "[K: V]",
        category: .collection,
        description: "Generates dictionaries with key-value pairs.",
        example: "let gen = Gen<[Int: Int]>.dictionary(Gen<Int>.int, Gen<Int>.int)",
        sampleGenerator: {
          let dict = Gen<[Int: Int]>.dictionary(
            Gen<Int>.int(in: 1...10),
            Gen<Int>.int(in: 100...200)
          )
          .sample(size: Size(value: 5), seed: Seed.random)
          let pairs = dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
          return "[\(pairs)]"
        }
      ),

      GeneratorInfo(
        id: "optional",
        name: "OptionalGen.optional(valueGen:)",
        type: "T?",
        category: .collection,
        description: "Generates optional values (nil or wrapped value).",
        example: "let gen = OptionalGen.optional(valueGen: Gen<Int>.int)",
        sampleGenerator: {
          let opt = OptionalGen.optional(valueGen: Gen<Int>.int(in: 1...100))
            .sample(size: Size(value: 10), seed: Seed.random)
          return opt.map { String($0) } ?? "nil"
        }
      ),

      // MARK: - Composite Generators

      GeneratorInfo(
        id: "pure",
        name: "Gen.pure(_:)",
        type: "T",
        category: .composite,
        description: "Generates a constant value (always the same).",
        example: "let gen = Gen.pure(42)",
        sampleGenerator: {
          String(Gen.pure(42).sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "oneof",
        name: "Gen.oneOf(_:)",
        type: "T",
        category: .composite,
        description: "Randomly selects from multiple generators with equal probability.",
        example: "let gen = Gen.oneOf([gen1, gen2, gen3])",
        sampleGenerator: {
          let gen = Gen.oneOf([
            Gen.pure(0),
            Gen<Int>.int(in: 1...10),
            Gen<Int>.int(in: 100...1000),
          ])
          return String(gen.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "frequency",
        name: "Gen.frequency(_:)",
        type: "T",
        category: .composite,
        description: "Selects generators based on frequency weights.",
        example: "let gen = Gen.frequency([(7, validGen), (2, edgeGen), (1, invalidGen)])",
        sampleGenerator: {
          let gen = Gen.frequency([
            (7, Gen<Int>.int(in: 1...100)),
            (2, Gen.pure(0)),
            (1, Gen.pure(-1)),
          ])
          return String(gen.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      // MARK: - Additional Numeric Generators

      GeneratorInfo(
        id: "uint8",
        name: "Gen<UInt8>.uint8",
        type: "UInt8",
        category: .numeric,
        description: "Generates UInt8 values with comprehensive edge cases.",
        example: "let gen = Gen<UInt8>.uint8",
        sampleGenerator: {
          String(Gen<UInt8>.uint8.sample(size: Size(value: 10), seed: Seed.random))
        }
      ),

      GeneratorInfo(
        id: "cgfloat",
        name: "Gen<CGFloat>.cgFloat",
        type: "CGFloat",
        category: .numeric,
        description: "Generates CGFloat values for graphics calculations.",
        example: "let gen = Gen<CGFloat>.cgFloat",
        sampleGenerator: {
          "\(Gen<CGFloat>.cgFloat.sample(size: Size(value: 50), seed: Seed.random))"
        }
      ),
    ]
  }

  /// Filter generators by category
  public func filter(category: GeneratorCategory) -> [GeneratorInfo] {
    generators.filter { $0.category == category }
  }

  /// Search generators by name, type, or description
  public func search(_ query: String) -> [GeneratorInfo] {
    guard !query.isEmpty else { return generators }

    let lowercased = query.lowercased()
    return generators.filter {
      $0.name.lowercased().contains(lowercased)
        || $0.description.lowercased().contains(lowercased)
        || $0.type.lowercased().contains(lowercased)
    }
  }
}

// MARK: - Catalog Browser

/// Interactive CLI browser for generator catalog.
public struct CatalogBrowser {
  private let catalog = GeneratorCatalog.shared

  public init() {}

  public func run() {
    printWelcome()

    var running = true
    while running {
      printMainMenu()
      guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
        continue
      }

      switch input.lowercased() {
      case "1", "list":
        listAllGenerators()

      case "2", "category":
        browseByCategory()

      case "3", "search":
        searchGenerators()

      case "4", "sample":
        generateSample()

      case "5", "help":
        printHelp()

      case "q", "quit", "exit":
        running = false
        print("\nGoodbye!")

      default:
        print("Unknown command. Type 'help' for options.")
      }
    }
  }

  private func printWelcome() {
    print(
      """

      ╔══════════════════════════════════════════════════════════════╗
      ║          InvariantSwift Generator Catalog Browser            ║
      ║         Explore 20+ built-in property test generators        ║
      ╚══════════════════════════════════════════════════════════════╝

      """
    )
  }

  private func printMainMenu() {
    print(
      """

      Generator Catalog
      ================
      1. List all generators
      2. Browse by category
      3. Search generators
      4. Generate sample values
      5. Help
      q. Quit

      Enter command:\u{0020}
      """,
      terminator: ""
    )
  }

  private func listAllGenerators() {
    print(
      """

      All Generators (\(catalog.generators.count) total)
      ═══════════════════════════════════
      """
    )

    for (index, gen) in catalog.generators.enumerated() {
      print("\n\(index + 1). \(gen.name)")
      print("   Type: \(gen.type)")
      print("   Category: \(gen.category.rawValue)")
      print("   Description: \(gen.description)")
    }

    print("\nPress Enter to continue...")
    _ = readLine()
  }

  private func browseByCategory() {
    print(
      """

      Browse by Category
      ══════════════════
      """
    )

    for (index, category) in GeneratorCategory.allCases.enumerated() {
      let count = catalog.filter(category: category).count
      print("\(index + 1). \(category.rawValue) (\(count) generators)")
    }

    print("\nEnter category number (or 'b' for back): ", terminator: "")
    guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
      return
    }

    if input.lowercased() == "b" {
      return
    }

    guard let index = Int(input), index > 0, index <= GeneratorCategory.allCases.count else {
      print("Invalid category number.")
      return
    }

    let category = GeneratorCategory.allCases[index - 1]
    let generators = catalog.filter(category: category)

    print(
      """

      \(category.rawValue) Generators
      \(String(repeating: "═", count: category.rawValue.count + 11))
      """
    )

    for gen in generators {
      print("\n• \(gen.name)")
      print("  \(gen.description)")
      print("  Example: \(gen.example)")
    }

    print("\nPress Enter to continue...")
    _ = readLine()
  }

  private func searchGenerators() {
    print("\nEnter search query: ", terminator: "")
    guard let query = readLine()?.trimmingCharacters(in: .whitespaces) else {
      return
    }

    let results = catalog.search(query)

    if results.isEmpty {
      print("\nNo generators found matching '\(query)'")
    } else {
      print(
        """

        Search Results (\(results.count) found)
        ═══════════════════════════════════
        """
      )

      for gen in results {
        print("\n• \(gen.name)")
        print("  Type: \(gen.type) | Category: \(gen.category.rawValue)")
        print("  \(gen.description)")
        print("  Example: \(gen.example)")
      }
    }

    print("\nPress Enter to continue...")
    _ = readLine()
  }

  private func generateSample() {
    print(
      """

      Generate Sample Values
      ═══════════════════════

      Enter generator ID (e.g., 'int', 'string', 'array'):
      (or 'list' to see all IDs, 'b' for back):\u{0020}
      """,
      terminator: ""
    )

    guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
      return
    }

    if input.lowercased() == "b" {
      return
    }

    if input.lowercased() == "list" {
      print("\nAvailable generator IDs:")
      for gen in catalog.generators {
        print("  • \(gen.id) - \(gen.name)")
      }
      print("\nPress Enter to continue...")
      _ = readLine()
      return
    }

    guard let generator = catalog.generators.first(where: { $0.id == input }) else {
      print("\nGenerator '\(input)' not found.")
      print("\nPress Enter to continue...")
      _ = readLine()
      return
    }

    print(
      """

      Generator: \(generator.name)
      Type: \(generator.type)
      Description: \(generator.description)

      Sample values (5 random samples):
      ═══════════════════════════════════
      """
    )

    for i in 1...5 {
      let sample = generator.sampleGenerator()
      print("\(i). \(sample)")
    }

    print(
      """

      Code example:
      \(generator.example)

      Press Enter to continue...
      """,
      terminator: ""
    )
    _ = readLine()
  }

  private func printHelp() {
    print(
      """

      Generator Catalog Help
      ═══════════════════════

      COMMANDS:
        1 or list       - List all available generators
        2 or category   - Browse generators by category
        3 or search     - Search for generators
        4 or sample     - Generate sample values
        5 or help       - Show this help
        q or quit       - Exit the browser

      CATEGORIES:
        Primitive   - Basic types (Int, Bool, Character)
        Numeric     - Numeric types (Int8, UInt, Double, Float)
        String      - String generators (ASCII, alphanumeric, UUID)
        Collection  - Collections (Array, Set, Dictionary, Optional)
        Composite   - Combinators (pure, oneOf, frequency)
        Domain Data - Domain-specific (Date, URL)

      USAGE:
        Browse the catalog to discover generators for property testing.
        Use the 'sample' command to see example values.
        Copy code examples to use generators in your tests.

      Press Enter to continue...
      """,
      terminator: ""
    )
    _ = readLine()
  }
}
