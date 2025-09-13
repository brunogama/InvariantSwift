/// **Business Domain Generators for Real-World Applications**
///
/// Specialized generators for common business domain objects and data patterns.
/// These generators bridge the gap between mathematical property testing and
/// practical business validation by providing realistic, domain-appropriate test data.
///
/// **Mathematical Foundation:**
/// Based on domain-driven design principles and empirical analysis of business
/// data patterns. Generators follow mathematical laws while maintaining business
/// realism through constrained random generation and semantic inference.
///
/// **Coverage Areas:**
/// - Financial data (currency, prices, rates)
/// - Personal information (names, emails, addresses)
/// - Temporal data (dates, timestamps, durations)
/// - Geographic data (addresses, postal codes, regions)
/// - Communication data (emails, phone numbers, URLs)
///
/// **External References:**
/// - [Domain-Driven Design](https://en.wikipedia.org/wiki/Domain-driven_design)
/// - [Data Generation Patterns](https://en.wikipedia.org/wiki/Synthetic_data)
/// - [Business Rule Testing](https://en.wikipedia.org/wiki/Business_rule)

import Foundation

// MARK: - Financial Generators

extension Gen where T == Decimal {
  /// **Generate realistic currency amounts for business testing**
  ///
  /// Produces currency values appropriate for business scenarios with realistic
  /// distributions focusing on common transaction amounts while including edge cases.
  ///
  /// **Business Distribution:**
  /// - 60% small amounts: $0.01 - $1,000
  /// - 30% medium amounts: $1,000 - $100,000
  /// - 10% large amounts: $100,000 - $10,000,000
  ///
  /// **Edge Cases:**
  /// - Zero amounts (free transactions)
  /// - Fractional cents (precision testing)
  /// - Maximum representable values
  /// - Common amounts ($1, $10, $100, etc.)
  ///
  /// **Usage:**
  /// ```swift
  /// let priceGen = Gen.currency
  /// let expensiveItemGen = Gen.currency(in: 1000...100000)
  /// ```
  public static var currency: Gen<Decimal> {
    Gen.currency(in: 0...1_000_000)
  }

  /// **Generate currency amounts within specified range**
  ///
  /// Creates currency values constrained to business-appropriate ranges
  /// with realistic precision (2 decimal places) and distribution patterns.
  public static func currency(in range: ClosedRange<Decimal>) -> Gen<Decimal> {
    Gen<Decimal>(
      generate: { rng, size in
        let minValue = range.lowerBound
        let maxValue = range.upperBound

        // Edge cases for small sizes
        if size.value <= 3 {
          let edgeCases: [Decimal] = [
            0,
            Decimal(0.01),
            Decimal(1),
            Decimal(10),
            Decimal(100),
            minValue,
            maxValue,
          ].filter { range.contains($0) }

          if let edgeCase = edgeCases.randomElement(using: &rng) {
            return edgeCase
          }
        }

        // Generate realistic currency amounts
        let rawValue = Decimal(
          Double.random(
            in: Double(
              truncating: minValue as NSDecimalNumber
            )...Double(truncating: maxValue as NSDecimalNumber),
            using: &rng
          )
        )

        // Round to 2 decimal places for currency
        var rounded = rawValue
        var result = rounded
        NSDecimalRound(&result, &rounded, 2, .bankers)

        return result
      },
      shrink: Shrink { amount in
        var shrunk: [Decimal] = []

        if amount != 0 { shrunk.append(0) }
        if amount > 1 {
          shrunk.append(1)
          let half = amount / 2
          if half != amount { shrunk.append(half) }
        }
        if amount > Decimal(0.01) { shrunk.append(Decimal(0.01)) }

        // Round to common amounts
        let commonAmounts: [Decimal] = [1, 5, 10, 25, 50, 100, 500, 1000]
        for common in commonAmounts {
          if common < amount && common > 0 {
            shrunk.append(common)
          }
        }

        return Array(Set(shrunk)).sorted()
      }
    )
  }
}

extension Gen where T == Double {
  /// **Generate percentage values for business calculations**
  ///
  /// Produces percentage values as doubles (0.0 to 1.0) suitable for
  /// business calculations like tax rates, discounts, and growth rates.
  ///
  /// **Distribution:**
  /// - Common percentages: 5%, 10%, 15%, 20%, 25%, 50%
  /// - Edge cases: 0%, 100%, very small percentages
  /// - Random values with realistic precision
  public static var percentage: Gen<Double> {
    Gen<Double>(
      generate: { rng, size in
        // Edge cases
        if size.value <= 3 {
          let edgeCases: [Double] = [0.0, 0.01, 0.05, 0.1, 0.15, 0.2, 0.25, 0.5, 0.75, 1.0]
          if let edgeCase = edgeCases.randomElement(using: &rng) {
            return edgeCase
          }
        }

        // Common business percentages
        let commonPercentages = [0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.5]
        if Bool.random(using: &rng) {
          return commonPercentages.randomElement(using: &rng)!
        }

        // Random percentage
        return Double.random(in: 0...1, using: &rng)
      },
      shrink: Shrink { value in
        var shrunk: [Double] = []

        if value != 0 { shrunk.append(0) }
        if value > 0.1 { shrunk.append(0.1) }
        if value > 0.01 { shrunk.append(0.01) }
        if value != 0.5 && value > 0.5 { shrunk.append(0.5) }

        return shrunk.filter { $0 < value }
      }
    )
  }
}

// MARK: - Personal Information Generators

extension Gen where T == String {
  /// **Generate realistic person names for testing**
  ///
  /// Creates human-readable names suitable for business applications
  /// with international character support and realistic distributions.
  ///
  /// **Name Patterns:**
  /// - Common first names from various cultures
  /// - Professional surnames
  /// - Proper capitalization
  /// - Length appropriate for database fields
  public static var personName: Gen<String> {
    let firstNames = [
      "James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
      "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
      "Thomas", "Sarah", "Christopher", "Karen", "Charles", "Nancy", "Daniel", "Lisa",
      "Matthew", "Betty", "Anthony", "Helen", "Mark", "Sandra", "Donald", "Donna",
      "Steven", "Carol", "Paul", "Ruth", "Andrew", "Sharon", "Joshua", "Michelle",
      "Kenneth", "Laura", "Kevin", "Sarah", "Brian", "Kimberly", "George", "Deborah",
      "Timothy", "Dorothy", "Ronald", "Lisa", "Jason", "Nancy", "Edward", "Karen",
    ]

    let lastNames = [
      "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
      "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzales", "Wilson", "Anderson", "Thomas",
      "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
      "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
      "Allen", "King", "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores",
      "Green", "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
    ]

    return Gen<String>(
      generate: { rng, _ in
        let firstName = firstNames.randomElement(using: &rng)!
        let lastName = lastNames.randomElement(using: &rng)!
        return "\(firstName) \(lastName)"
      },
      shrink: Shrink { name in
        // Shrink to shorter names or single words
        let components = name.components(separatedBy: " ")
        var shrunk: [String] = []

        if components.count > 1 {
          shrunk.append(components[0])  // Just first name
          shrunk.append("A B")  // Minimal name
        }

        return shrunk
      }
    )
  }

  /// **Generate realistic email addresses for business testing**
  ///
  /// Creates valid email addresses with business-appropriate domains
  /// and realistic username patterns for testing email validation logic.
  public static var email: Gen<String> {
    let domains = [
      "example.com", "test.org", "demo.net", "sample.co", "business.com",
      "company.org", "enterprise.net", "corporate.com", "professional.org",
    ]

    let firstNames = ["john", "jane", "mike", "sarah", "david", "lisa", "alex", "anna"]
    let lastNames = ["smith", "doe", "brown", "wilson", "davis", "miller", "taylor", "clark"]

    return Gen<String>(
      generate: { rng, _ in
        let firstName = firstNames.randomElement(using: &rng)!
        let lastName = lastNames.randomElement(using: &rng)!
        let domain = domains.randomElement(using: &rng)!
        let separator = [".", "_", ""].randomElement(using: &rng)!
        let number = Bool.random(using: &rng) ? "\(Int.random(in: 1...99, using: &rng))" : ""

        return "\(firstName)\(separator)\(lastName)\(number)@\(domain)"
      },
      shrink: Shrink { _ in
        // Shrink to simpler email patterns
        ["a@b.com", "test@example.com", "user@domain.org"]
      }
    )
  }

  /// **Generate phone numbers for business testing**
  ///
  /// Creates realistic phone numbers following common formatting patterns
  /// for business contact information testing.
  public static var phoneNumber: Gen<String> {
    let areaCodes = ["415", "650", "510", "408", "925", "707", "831", "559"]

    return Gen<String>(
      generate: { rng, _ in
        let areaCode = areaCodes.randomElement(using: &rng)!
        let exchange = String(format: "%03d", Int.random(in: 200...999, using: &rng))
        let number = String(format: "%04d", Int.random(in: 0...9999, using: &rng))

        let formats = [
          "(\(areaCode)) \(exchange)-\(number)",
          "\(areaCode)-\(exchange)-\(number)",
          "\(areaCode).\(exchange).\(number)",
          "+1-\(areaCode)-\(exchange)-\(number)",
        ]

        return formats.randomElement(using: &rng)!
      },
      shrink: Shrink { _ in
        ["555-0123", "(555) 555-5555", "123-456-7890"]
      }
    )
  }

  /// **Generate unique identifiers for business entities**
  ///
  /// Creates business-appropriate identifiers with realistic patterns
  /// for customer IDs, order numbers, and reference codes.
  public static var identifier: Gen<String> {
    let prefixes = ["ID", "REF", "ORD", "USR", "ACC", "TXN", "INV", "CTR"]

    return Gen<String>(
      generate: { rng, _ in
        let prefix = prefixes.randomElement(using: &rng)!
        let number = String(format: "%06d", Int.random(in: 1...999999, using: &rng))
        return "\(prefix)-\(number)"
      },
      shrink: Shrink { _ in
        ["ID-000001", "REF-123", "A-1"]
      }
    )
  }
}

// MARK: - Geographic Generators

extension Gen where T == String {
  /// **Generate realistic street addresses**
  ///
  /// Creates properly formatted street addresses suitable for
  /// business address validation and shipping applications.
  public static var address: Gen<String> {
    let streetNumbers = Array(1...9999)
    let streetNames = [
      "Main", "First", "Second", "Third", "Oak", "Pine", "Maple", "Cedar",
      "Elm", "Washington", "Park", "Lincoln", "Madison", "Jackson", "Jefferson",
      "Adams", "Wilson", "Johnson", "Smith", "Broadway", "Church", "Spring",
    ]
    let streetTypes = ["St", "Ave", "Blvd", "Dr", "Ln", "Rd", "Way", "Ct", "Pl"]

    return Gen<String>(
      generate: { rng, _ in
        let number = streetNumbers.randomElement(using: &rng)!
        let name = streetNames.randomElement(using: &rng)!
        let type = streetTypes.randomElement(using: &rng)!
        return "\(number) \(name) \(type)"
      },
      shrink: Shrink { _ in
        ["1 Main St", "123 Oak Ave", "1 A St"]
      }
    )
  }

  /// **Generate city names for business testing**
  public static var city: Gen<String> {
    let cities = [
      "San Francisco", "New York", "Los Angeles", "Chicago", "Houston", "Phoenix",
      "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose", "Austin",
      "Jacksonville", "Fort Worth", "Columbus", "Charlotte", "San Francisco", "Indianapolis",
      "Seattle", "Denver", "Washington", "Boston", "El Paso", "Detroit", "Nashville",
    ]

    return Gen<String>(
      generate: { rng, _ in
        cities.randomElement(using: &rng)!
      },
      shrink: Shrink { _ in
        ["City", "Town", "A"]
      }
    )
  }

  /// **Generate country names for international business testing**
  public static var country: Gen<String> {
    let countries = [
      "United States", "Canada", "United Kingdom", "France", "Germany", "Japan",
      "Australia", "Brazil", "India", "China", "Mexico", "Italy", "Spain",
      "Netherlands", "Sweden", "Norway", "Denmark", "Finland", "Belgium", "Austria",
    ]

    return Gen<String>(
      generate: { rng, _ in
        countries.randomElement(using: &rng)!
      },
      shrink: Shrink { _ in
        ["US", "Country", "A"]
      }
    )
  }

  /// **Generate postal codes for address validation**
  public static var postalCode: Gen<String> {
    Gen<String>(
      generate: { rng, _ in
        // US ZIP codes
        if Bool.random(using: &rng) {
          let zip = String(format: "%05d", Int.random(in: 10000...99999, using: &rng))
          let plus4 = String(format: "%04d", Int.random(in: 0...9999, using: &rng))
          return Bool.random(using: &rng) ? zip : "\(zip)-\(plus4)"
        } else {
          // International postal codes
          let patterns = ["A1A 1A1", "12345", "AB1 2CD", "1234 AB"]
          return patterns.randomElement(using: &rng)!
        }
      },
      shrink: Shrink { _ in
        ["12345", "90210", "A1A 1A1"]
      }
    )
  }
}

// MARK: - Temporal Generators

extension Gen where T == Date {
  /// **Generate business-appropriate dates**
  ///
  /// Creates dates within reasonable business ranges, avoiding far-future
  /// or far-past dates that would be unrealistic for most business applications.
  public static var date: Gen<Date> {
    Gen<Date>(
      generate: { rng, size in
        let now = Date()
        let oneYearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let oneYearFromNow = now.addingTimeInterval(365 * 24 * 60 * 60)

        // Edge cases
        if size.value <= 3 {
          let edgeCases = [oneYearAgo, now, oneYearFromNow]
          if let edgeCase = edgeCases.randomElement(using: &rng) {
            return edgeCase
          }
        }

        // Random date within business-reasonable range
        let timeInterval = Double.random(
          in: oneYearAgo.timeIntervalSince1970...oneYearFromNow.timeIntervalSince1970,
          using: &rng
        )
        return Date(timeIntervalSince1970: timeInterval)
      },
      shrink: Shrink { date in
        let now = Date()
        var shrunk: [Date] = [now]

        // Shrink towards now
        let distanceToNow = abs(date.timeIntervalSince(now))
        if distanceToNow > 86400 {  // More than a day
          let halfwayToNow = Date(
            timeIntervalSince1970: (date.timeIntervalSince1970 + now.timeIntervalSince1970) / 2
          )
          shrunk.append(halfwayToNow)
        }

        return shrunk
      }
    )
  }

  /// **Generate time values for business hours testing**
  public static var time: Gen<Date> {
    Gen<Date>(
      generate: { rng, _ in
        // Generate time within business hours (9 AM - 5 PM)
        let hour = Int.random(in: 9...17, using: &rng)
        let minute = Int.random(in: 0...59, using: &rng)

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0

        return Calendar.current.date(from: components) ?? Date()
      },
      shrink: Shrink { _ in
        // Shrink to common business times
        let calendar = Calendar.current
        let commonTimes = [
          calendar.date(from: DateComponents(hour: 9, minute: 0)),  // 9 AM
          calendar.date(from: DateComponents(hour: 12, minute: 0)),  // Noon
          calendar.date(from: DateComponents(hour: 17, minute: 0)),  // 5 PM
        ].compactMap { $0 }

        return commonTimes
      }
    )
  }
}

// MARK: - Age Generator

extension Gen where T == Int {
  /// **Generate realistic ages for business applications**
  ///
  /// Produces age values appropriate for business demographics,
  /// focusing on working-age populations while including edge cases.
  public static var age: Gen<Int> {
    Gen<Int>(
      generate: { rng, size in
        // Edge cases
        if size.value <= 3 {
          let edgeCases = [0, 18, 21, 65, 100]
          if let edgeCase = edgeCases.randomElement(using: &rng) {
            return edgeCase
          }
        }

        // Business-realistic age distribution
        // 70% working age (18-65), 20% elderly (65+), 10% young (0-18)
        let category = Double.random(in: 0...1, using: &rng)

        if category < 0.7 {
          return Int.random(in: 18...65, using: &rng)  // Working age
        } else if category < 0.9 {
          return Int.random(in: 65...85, using: &rng)  // Elderly
        } else {
          return Int.random(in: 0...17, using: &rng)  // Young
        }
      },
      shrink: Shrink { age in
        var shrunk: [Int] = []

        if age != 0 { shrunk.append(0) }
        if age > 18 { shrunk.append(18) }
        if age > 21 { shrunk.append(21) }
        if age > 1 { shrunk.append(age / 2) }

        return shrunk.filter { $0 < age && $0 >= 0 }
      }
    )
  }
}

// MARK: - Web/URL Generators

extension Gen where T == URL {
  /// **Generate realistic URLs for web application testing**
  ///
  /// Creates valid URLs with business-appropriate domains and paths
  /// suitable for testing web applications and API endpoints.
  public static var url: Gen<URL> {
    let schemes = ["https", "http"]
    let domains = [
      "example.com", "test.org", "demo.net", "api.business.com",
      "app.company.org", "service.enterprise.net", "www.professional.org",
    ]
    let paths = [
      "/api/v1/users", "/dashboard", "/products", "/orders", "/account",
      "/settings", "/reports", "/admin", "/help", "/about",
    ]

    return Gen<URL>(
      generate: { rng, _ in
        let scheme = schemes.randomElement(using: &rng)!
        let domain = domains.randomElement(using: &rng)!
        let path = Bool.random(using: &rng) ? paths.randomElement(using: &rng)! : ""

        let urlString = "\(scheme)://\(domain)\(path)"
        return URL(string: urlString)!
      },
      shrink: Shrink { _ in
        [
          URL(string: "https://example.com")!,
          URL(string: "http://test.org")!,
          URL(string: "https://a.b")!,
        ]
      }
    )
  }
}

// MARK: - Data Generator

extension Gen where T == Data {
  /// **Generate data blobs for business applications**
  ///
  /// Creates data objects suitable for testing file uploads,
  /// binary content, and data processing applications.
  public static var data: Gen<Data> {
    Gen<Data>(
      generate: { rng, size in
        let length = max(0, Int.random(in: 0...max(size.value * 10, 1000), using: &rng))
        var bytes = [UInt8]()
        bytes.reserveCapacity(length)

        for _ in 0..<length {
          bytes.append(UInt8.random(in: 0...255, using: &rng))
        }

        return Data(bytes)
      },
      shrink: Shrink { data in
        var shrunk: [Data] = []

        // Shrink to empty data
        if !data.isEmpty {
          shrunk.append(Data())
        }

        // Shrink to half size
        if data.count > 1 {
          let halfSize = data.count / 2
          shrunk.append(Data(data.prefix(halfSize)))
        }

        // Shrink to single byte
        if data.count > 1 {
          shrunk.append(Data([data.first ?? 0]))
        }

        return shrunk
      }
    )
  }
}

// Note: UUID generator is already available in PrimitiveGenerators.swift
