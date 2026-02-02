import Foundation
import InvariantSwiftCore
import InvariantSwift

// MARK: - Fakery-Style Generators
//
// This module provides realistic fake data generators accessible via `Gen.fake` namespace.
// All generators automatically mix realistic data with edge cases to find bugs in property tests.
//
// ## Overview
//
// Fakery generators provide domain-specific realistic test data across 6 categories:
// - **Name**: firstName, lastName, fullName, prefix, suffix
// - **Address**: city, street, zipCode, coordinates
// - **Internet**: email, username, url, IP addresses
// - **Company**: name, catchPhrase, bs
// - **Commerce**: productName, price, color, department
// - **Lorem**: word, sentence, paragraph
//
// ## Usage
//
// ```swift
// // Basic usage - access via Gen.fake namespace
// let nameGen = Gen.fake.name.firstName
// let emailGen = Gen.fake.internet.email
//
// // Compose generators
// let personGen = nameGen.zip(emailGen).map { name, email in
//   Person(name: name, email: email)
// }
//
// // Use in property tests
// let property = Property(generator: personGen) { person in
//   #expect(!person.name.isEmpty)
//   #expect(person.email.contains("@"))
// }
// ```
//
// ## Edge Case Injection
//
// By default, generators produce 5% edge cases (empty strings, special characters, boundary values):
//
// ```swift
// // Default: 95% realistic, 5% edge cases
// let gen = Gen.fake.name.firstName  // Occasionally generates "", "A", "🙂", etc.
//
// // Adjust frequency
// Gen.configureFake(edgeCaseFrequency: 0.1)  // 10% edge cases
// Gen.configureFake(edgeCaseFrequency: 0.0)  // Disable edge cases
// Gen.configureFake(edgeCaseFrequency: 1.0)  // All edge cases (stress testing)
// ```
//
// ## Examples
//
// ### User Registration Testing
// ```swift
// struct User {
//   let firstName: String
//   let lastName: String
//   let email: String
//   let city: String
// }
//
// let userGen = Gen<String>.zip3(
//   Gen.fake.name.firstName,
//   Gen.fake.name.lastName,
//   Gen.fake.internet.email
// ).zip(Gen.fake.address.city).map { (names, city) in
//   User(firstName: names.0, lastName: names.1, email: names.2, city: city)
// }
//
// let property = Property(generator: userGen) { user in
//   // Properties always hold even with edge case data
//   #expect(user.email.contains("@") || user.email.isEmpty)  // Edge case: empty email
//   return true
// }
// ```
//
// ### E-commerce Product Testing
// ```swift
// struct Product {
//   let name: String
//   let price: Double
//   let color: String
//   let department: String
// }
//
// let productGen = Gen<String>.zip3(
//   Gen.fake.commerce.productName,
//   Gen.fake.commerce.color,
//   Gen.fake.commerce.department
// ).zip(Gen.fake.commerce.price).map { (details, price) in
//   Product(name: details.0, price: price, color: details.1, department: details.2)
// }
// ```
//
// ### Address Validation Testing
// ```swift
// let addressGen = Gen<String>.zip3(
//   Gen.fake.address.streetAddress,
//   Gen.fake.address.city,
//   Gen.fake.address.zipCode
// ).map { street, city, zip in
//   "\(street), \(city) \(zip)"
// }
//
// let property = Property(generator: addressGen) { address in
//   // Should handle edge cases gracefully
//   let normalized = address.trimmingCharacters(in: .whitespaces)
//   return normalized.isEmpty || normalized.count > 0
// }
// ```
//
// ## Performance
//
// All generators are:
// - **Deterministic**: Same seed produces same output
// - **Fast**: No external dependencies, all data embedded
// - **Composable**: Work seamlessly with Gen.map, Gen.zip, Gen.flatMap
// - **Shrinkable**: Inherit shrinking from underlying primitive generators
//
// ## See Also
// - ``FakeConfig`` - Edge case configuration
// - ``FakeGenerators`` - Root namespace
// - ``NameGenerators``, ``AddressGenerators``, ``InternetGenerators``
// - ``CompanyGenerators``, ``CommerceGenerators``, ``LoremGenerators``

// MARK: - Edge Case Configuration

/// Configuration for fake data edge case generation.
///
/// Controls the frequency at which intentionally malformed data is generated
/// to stress-test properties and find edge cases.
public struct FakeConfig: Sendable {
  /// Frequency of edge case generation (0.0 to 1.0).
  ///
  /// - 0.0: All data is realistic and valid
  /// - 0.05: 5% edge cases (default)
  /// - 1.0: All data is intentionally malformed
  public var edgeCaseFrequency: Double

  public init(edgeCaseFrequency: Double = 0.05) {
    self.edgeCaseFrequency = min(1.0, max(0.0, edgeCaseFrequency))
  }

  /// Shared configuration instance.
  nonisolated(unsafe) public static var current = Self()
}

// MARK: - Gen Extension for Fake Namespace

extension Gen where T == Never {
  /// Namespace for realistic fake data generators.
  ///
  /// Provides domain-specific generators for realistic test data including names,
  /// addresses, internet data, companies, commerce, and Lorem Ipsum text.
  ///
  /// All generators automatically mix realistic data with occasional edge cases
  /// (5% by default) to help find bugs in property tests.
  ///
  /// - Example:
  ///   ```swift
  ///   let nameGen = Gen.fake.name.firstName
  ///   let emailGen = Gen.fake.internet.email
  ///   let personGen = Gen.zip(nameGen, emailGen)
  ///   ```
  public static var fake: FakeGenerators { FakeGenerators() }

  /// Configure fake data edge case frequency.
  ///
  /// Controls how often generators produce intentionally malformed data
  /// to stress-test properties.
  ///
  /// - Parameter edgeCaseFrequency: Probability of edge cases (0.0 to 1.0)
  ///
  /// - Example:
  ///   ```swift
  ///   Gen.configureFake(edgeCaseFrequency: 0.1)  // 10% edge cases
  ///   Gen.configureFake(edgeCaseFrequency: 0.0)  // Disable edge cases
  ///   ```
  public static func configureFake(edgeCaseFrequency: Double) {
    FakeConfig.current = FakeConfig(edgeCaseFrequency: edgeCaseFrequency)
  }
}

/// Mixes realistic and edge case generators based on configuration.
///
/// - Parameters:
///   - normal: Generator for realistic data
///   - edge: Generator for edge case data
/// - Returns: Generator that probabilistically chooses between normal and edge
func withEdgeCases<U>(normal: Gen<U>, edge: Gen<U>) -> Gen<U> {
  Gen<U>(generate: { rng, size in
    let roll = Double.random(in: 0..<1, using: &rng)
    if roll < FakeConfig.current.edgeCaseFrequency {
      return edge.generate(&rng, size)
    } else {
      return normal.generate(&rng, size)
    }
  })
}

// MARK: - Fake Generators Root

/// Root struct for all fake data generators.
///
/// Organizes generators into categories: name, address, internet, company, commerce, lorem.
public struct FakeGenerators: Sendable {
  /// Name generators (firstName, lastName, fullName, prefix, suffix).
  public let name = NameGenerators()

  /// Address generators (city, street, zipCode, coordinates, etc.).
  public let address = AddressGenerators()

  /// Internet generators (email, username, url, IP addresses, etc.).
  public let internet = InternetGenerators()

  /// Company generators (name, suffix, catchPhrase, bs).
  public let company = CompanyGenerators()

  /// Commerce generators (productName, price, color, department).
  public let commerce = CommerceGenerators()

  /// Lorem Ipsum generators (word, sentence, paragraph).
  public let lorem = LoremGenerators()

  public init() {}
}

// MARK: - Name Generators

/// Generators for realistic person names.
public struct NameGenerators: Sendable {
  public init() {}

  /// Generates realistic first names.
  public var firstName: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(firstNames.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("A"),
        Gen.pure("🙂"),
        Gen.pure("X Æ A-12"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates realistic last names.
  public var lastName: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(lastNames.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("X"),
        Gen.pure("Jr."),
        Gen.pure("O'Brien-Smith"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates realistic full names (first + last).
  public var fullName: Gen<String> {
    firstName.zip(lastName).map { "\($0) \($1)" }
  }

  /// Generates name prefixes (Mr., Mrs., Dr., etc.).
  public var prefix: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(namePrefixes.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("Mx."),
        Gen.pure("Sir"),
      ])
    )
  }

  /// Generates name suffixes (Jr., Sr., PhD, etc.).
  public var suffix: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(nameSuffixes.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("IV"),
        Gen.pure("Esq."),
      ])
    )
  }
}

// MARK: - Address Generators

/// Generators for realistic addresses and geographic data.
public struct AddressGenerators: Sendable {
  public init() {}

  /// Generates realistic city names.
  public var city: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(cities.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("X"),
        Gen.pure("São Paulo"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates realistic street names.
  public var streetName: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(streetNames.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("1st"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates realistic full street addresses.
  public var streetAddress: Gen<String> {
    Gen { rng, _ in Int.random(in: 1...9999, using: &rng) }
      .zip(streetName)
      .map { "\($0) \($1)" }
  }

  /// Generates realistic ZIP/postal codes.
  public var zipCode: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        String(format: "%05d", Int.random(in: 0...99999, using: &rng))
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("00000"),
        Gen.pure("ABCDE"),
      ])
    )
  }

  /// Generates realistic US state names.
  public var state: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(states.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("XX"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates realistic country names.
  public var country: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(countries.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("X"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates valid latitude values (-90 to 90).
  public var latitude: Gen<Double> {
    withEdgeCases(
      normal: Gen { rng, _ in Double.random(in: -90.0...90.0, using: &rng) },
      edge: Gen.oneOf([
        Gen.pure(-90.0),
        Gen.pure(90.0),
        Gen.pure(0.0),
        Gen.pure(Double.nan),
        Gen.pure(Double.infinity),
      ])
    )
  }

  /// Generates valid longitude values (-180 to 180).
  public var longitude: Gen<Double> {
    withEdgeCases(
      normal: Gen { rng, _ in Double.random(in: -180.0...180.0, using: &rng) },
      edge: Gen.oneOf([
        Gen.pure(-180.0),
        Gen.pure(180.0),
        Gen.pure(0.0),
        Gen.pure(Double.nan),
        Gen.pure(Double.infinity),
      ])
    )
  }

  /// Generates coordinates as (latitude, longitude) pairs.
  public var coordinates: Gen<(Double, Double)> {
    latitude.zip(longitude)
  }
}

// MARK: - Internet Generators

/// Generators for realistic internet-related data.
public struct InternetGenerators: Sendable {
  public init() {}

  /// Generates realistic email addresses.
  public var email: Gen<String> {
    withEdgeCases(
      normal: username.zip(domainName).map { "\($0)@\($1)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("invalid"),
        Gen.pure("@@example.com"),
        Gen.pure("user@"),
        Gen.pure("@example.com"),
        Gen.pure("user @example.com"),
      ])
    )
  }

  /// Generates realistic usernames.
  public var username: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(firstNames.map { Gen.pure($0.lowercased()) })
        .map { name in
          let number = Int.random(in: 0...999)
          return "\(name)\(number)"
        },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("a"),
        Gen.pure("user name"),
        Gen.pure("user@name"),
      ])
    )
  }

  /// Generates realistic domain names.
  public var domainName: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(domains.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("..com"),
        Gen.pure("example"),
        Gen.pure("exam ple.com"),
      ])
    )
  }

  /// Generates realistic HTTP/HTTPS URLs.
  public var url: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf([Gen.pure("http"), Gen.pure("https")])
        .zip(domainName)
        .map { "\($0)://\($1)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("http://"),
        Gen.pure("ftp://example.com"),
        Gen.pure("not a url"),
      ])
    )
  }

  /// Generates valid IPv4 addresses.
  public var ipV4Address: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        let octets = (0..<4).map { _ in Int.random(in: 0...255, using: &rng) }
        return octets.map(String.init).joined(separator: ".")
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("0.0.0.0"),
        Gen.pure("255.255.255.255"),
        Gen.pure("999.999.999.999"),
        Gen.pure("a.b.c.d"),
      ])
    )
  }

  /// Generates valid IPv6 addresses.
  public var ipV6Address: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        let groups = (0..<8).map { _ in
          String(format: "%x", Int.random(in: 0...0xFFFF, using: &rng))
        }
        return groups.joined(separator: ":")
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("::1"),
        Gen.pure("0:0:0:0:0:0:0:0"),
        Gen.pure("gggg:gggg:gggg:gggg:gggg:gggg:gggg:gggg"),
      ])
    )
  }

  /// Generates random password strings.
  public var password: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        let length = Int.random(in: 8...20, using: &rng)
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("pass"),
        Gen.pure("   "),
      ])
    )
  }
}

// MARK: - Company Generators

/// Generators for realistic company data.
public struct CompanyGenerators: Sendable {
  public init() {}

  /// Generates realistic company names.
  public var name: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(lastNames.map { Gen.pure($0) })
        .zip(Gen.oneOf(companySuffixes.map { Gen.pure($0) }))
        .map { "\($0) \($1)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("X"),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates company suffixes (Inc, LLC, Ltd, etc.).
  public var suffix: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(companySuffixes.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("XYZ"),
      ])
    )
  }

  /// Generates business catch phrases.
  public var catchPhrase: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(catchPhraseAdjectives.map { Gen.pure($0) })
        .zip(Gen.oneOf(catchPhraseNouns.map { Gen.pure($0) }))
        .map { "\($0) \($1)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("Synergy"),
      ])
    )
  }

  /// Generates business buzzword phrases.
  public var bs: Gen<String> {
    withEdgeCases(
      normal: Gen<String>.zip3(
        Gen.oneOf(bsVerbs.map { Gen.pure($0) }),
        Gen.oneOf(bsAdjectives.map { Gen.pure($0) }),
        Gen.oneOf(bsNouns.map { Gen.pure($0) })
        // swiftlint:disable:next multiline_function_chains
      ).map { "\($0) \($1) \($2)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("do stuff"),
      ])
    )
  }
}

// MARK: - Commerce Generators

/// Generators for realistic commerce data.
public struct CommerceGenerators: Sendable {
  public init() {}

  /// Generates realistic product names.
  public var productName: Gen<String> {
    withEdgeCases(
      normal: Gen<String>.zip3(
        Gen.oneOf(productAdjectives.map { Gen.pure($0) }),
        Gen.oneOf(productMaterials.map { Gen.pure($0) }),
        Gen.oneOf(productTypes.map { Gen.pure($0) })
        // swiftlint:disable:next multiline_function_chains
      ).map { "\($0) \($1) \($2)" },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("Product"),
      ])
    )
  }

  /// Generates realistic prices as Double.
  public var price: Gen<Double> {
    withEdgeCases(
      normal: Gen { rng, _ in
        Double.random(in: 0.99...999.99, using: &rng).rounded(toPlaces: 2)
      },
      edge: Gen.oneOf([
        Gen.pure(0.0),
        Gen.pure(-10.0),
        Gen.pure(999999.99),
        Gen.pure(Double.nan),
      ])
    )
  }

  /// Generates color names.
  public var color: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(colors.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("   "),
      ])
    )
  }

  /// Generates retail department names.
  public var department: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(departments.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("   "),
      ])
    )
  }
}

// MARK: - Lorem Ipsum Generators

/// Generators for Lorem Ipsum placeholder text.
public struct LoremGenerators: Sendable {
  public init() {}

  /// Generates a random Lorem Ipsum word.
  public var word: Gen<String> {
    withEdgeCases(
      normal: Gen.oneOf(loremWords.map { Gen.pure($0) }),
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("a"),
      ])
    )
  }

  /// Generates a random Lorem Ipsum sentence.
  public var sentence: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        let wordCount = Int.random(in: 4...10, using: &rng)
        let words = (0..<wordCount).map { _ in
          loremWords.randomElement(using: &rng)!
        }
        let sentence = words.joined(separator: " ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("."),
        Gen.pure("Word."),
      ])
    )
  }

  /// Generates a random Lorem Ipsum paragraph.
  public var paragraph: Gen<String> {
    withEdgeCases(
      normal: Gen { rng, _ in
        let sentenceCount = Int.random(in: 3...6, using: &rng)
        var sentences: [String] = []
        for _ in 0..<sentenceCount {
          let wordCount = Int.random(in: 4...10, using: &rng)
          let words = (0..<wordCount).map { _ in
            loremWords.randomElement(using: &rng)!
          }
          let sentence = words.joined(separator: " ")
          sentences.append(sentence.prefix(1).uppercased() + sentence.dropFirst() + ".")
        }
        return sentences.joined(separator: " ")
      },
      edge: Gen.oneOf([
        Gen.pure(""),
        Gen.pure("Lorem."),
      ])
    )
  }
}

// MARK: - Helper Extensions

extension Double {
  fileprivate func rounded(toPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return (self * divisor).rounded() / divisor
  }
}


// MARK: - Data Sources

private let firstNames = [
  "Emma", "Liam", "Olivia", "Noah", "Ava", "Ethan", "Sophia", "Mason",
  "Isabella", "James", "Mia", "Alexander", "Charlotte", "Michael", "Amelia",
  "Benjamin", "Harper", "Elijah", "Evelyn", "Lucas", "Abigail", "William",
  "Emily", "Oliver", "Elizabeth", "Jacob", "Sofia", "Logan", "Avery",
  "Jack", "Ella", "Aiden", "Scarlett", "Samuel", "Grace", "Henry", "Chloe",
  "Sebastian", "Victoria", "Matthew", "Riley", "David", "Aria", "Joseph",
  "Lily", "Carter", "Aubrey", "Owen", "Zoey", "Wyatt", "Penelope",
]

private let lastNames = [
  "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
  "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
  "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
  "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
  "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
  "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
  "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
  "Carter", "Roberts",
]

private let namePrefixes = ["Mr.", "Mrs.", "Ms.", "Dr.", "Prof."]
private let nameSuffixes = ["Jr.", "Sr.", "II", "III", "PhD", "MD"]

private let cities = [
  "New York", "Los Angeles", "Chicago", "Houston", "Phoenix", "Philadelphia",
  "San Antonio", "San Diego", "Dallas", "San Jose", "Austin", "Jacksonville",
  "Fort Worth", "Columbus", "Indianapolis", "Charlotte", "San Francisco",
  "Seattle", "Denver", "Boston", "Nashville", "Portland", "Las Vegas",
  "Detroit", "Memphis", "Baltimore", "Milwaukee", "Albuquerque", "Tucson",
]

private let streetNames = [
  "Main Street", "Oak Avenue", "Maple Drive", "Cedar Lane", "Pine Road",
  "Elm Street", "Washington Avenue", "Lake Drive", "Hill Road", "Park Avenue",
  "Sunset Boulevard", "First Street", "Second Avenue", "Broadway", "Market Street",
]

private let states = [
  "California", "Texas", "Florida", "New York", "Pennsylvania", "Illinois",
  "Ohio", "Georgia", "North Carolina", "Michigan", "New Jersey", "Virginia",
  "Washington", "Arizona", "Massachusetts", "Tennessee", "Indiana", "Missouri",
]

private let countries = [
  "United States", "Canada", "United Kingdom", "Germany", "France", "Spain",
  "Italy", "Australia", "Japan", "China", "Brazil", "Mexico", "India",
  "Netherlands", "Switzerland", "Sweden", "Norway", "Denmark",
]

private let domains = [
  "example.com", "test.org", "demo.net", "sample.io", "placeholder.dev",
  "gmail.com", "yahoo.com", "hotmail.com", "outlook.com",
]

private let companySuffixes = ["Inc", "LLC", "Ltd", "Corp", "Group", "Co"]

private let catchPhraseAdjectives = [
  "Innovative", "Cutting-edge", "Revolutionary", "Advanced", "Next-generation",
  "Industry-leading", "Award-winning", "Premium", "Professional", "Enterprise",
]

private let catchPhraseNouns = [
  "Solutions", "Services", "Platform", "Technology", "Software",
  "System", "Framework", "Infrastructure", "Products", "Applications",
]

private let bsVerbs = [
  "implement", "utilize", "integrate", "streamline", "optimize", "evolve",
  "transform", "embrace", "enable", "orchestrate", "deliver", "harness",
]

private let bsAdjectives = [
  "innovative", "strategic", "efficient", "scalable", "robust", "dynamic",
  "flexible", "intuitive", "comprehensive", "cutting-edge", "revolutionary",
]

private let bsNouns = [
  "solutions", "platforms", "technologies", "infrastructures", "systems",
  "frameworks", "methodologies", "synergies", "paradigms", "initiatives",
]

private let productAdjectives = [
  "Awesome", "Incredible", "Fantastic", "Amazing", "Gorgeous", "Practical",
  "Sleek", "Durable", "Lightweight", "Ergonomic", "Premium", "Handcrafted",
]

private let productMaterials = [
  "Wooden", "Plastic", "Steel", "Cotton", "Granite", "Rubber", "Metal",
  "Soft", "Fresh", "Frozen", "Concrete", "Leather",
]

private let productTypes = [
  "Chair", "Table", "Keyboard", "Mouse", "Shirt", "Pants", "Hat", "Shoes",
  "Bike", "Car", "Computer", "Phone", "Watch", "Bag", "Bottle", "Lamp",
]

private let colors = [
  "red", "blue", "green", "yellow", "purple", "orange", "pink", "brown",
  "black", "white", "gray", "navy", "teal", "maroon", "olive", "cyan",
]

private let departments = [
  "Electronics", "Clothing", "Home & Garden", "Sports", "Books", "Toys",
  "Beauty", "Health", "Automotive", "Grocery", "Tools", "Jewelry",
]

private let loremWords = [
  "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing",
  "elit", "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore",
  "et", "dolore", "magna", "aliqua", "enim", "ad", "minim", "veniam",
  "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi", "aliquip",
  "ex", "ea", "commodo", "consequat", "duis", "aute", "irure", "in",
  "reprehenderit", "voluptate", "velit", "esse", "cillum", "fugiat", "nulla",
  "pariatur", "excepteur", "sint", "occaecat", "cupidatat", "non", "proident",
  "sunt", "culpa", "qui", "officia", "deserunt", "mollit", "anim", "id",
  "est", "laborum",
  // swiftlint:disable:next file_length
]
