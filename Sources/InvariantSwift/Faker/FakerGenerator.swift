// MARK: - ISP-0010: Faker Generator
// Fake data generators that integrate with Gen<T>.

import Foundation

// MARK: - Faker Generator Extension

extension Gen {

  /// Create a faker generator for the specified type.
  public static func faker(
    _ type: FakerType,
    locale: FakerLocale = .enUS
  ) -> Gen<String> {
    let data = FakerData.shared.data(for: locale)

    switch type {
    // MARK: - Names
    case .name, .fullName:
      return Gen<String> { rng, _ in
        let first = data.firstNames.randomElement(using: &rng) ?? "John"
        let last = data.lastNames.randomElement(using: &rng) ?? "Doe"
        return "\(first) \(last)"
      }

    case .firstName:
      return Gen<String> { rng, _ in
        data.firstNames.randomElement(using: &rng) ?? "John"
      }

    case .lastName:
      return Gen<String> { rng, _ in
        data.lastNames.randomElement(using: &rng) ?? "Doe"
      }

    case .prefix:
      return Gen<String> { rng, _ in
        data.prefixes.randomElement(using: &rng) ?? "Mr."
      }

    case .suffix:
      return Gen<String> { rng, _ in
        data.suffixes.randomElement(using: &rng) ?? "Jr."
      }

    // MARK: - Internet
    case .email:
      return Gen<String> { rng, _ in
        let first = data.firstNames.randomElement(using: &rng)?.lowercased() ?? "user"
        let last = data.lastNames.randomElement(using: &rng)?.lowercased() ?? "example"
        let domain = data.emailDomains.randomElement(using: &rng) ?? "example.com"
        let num = Int.random(in: 1...99, using: &rng)
        return "\(first).\(last)\(num)@\(domain)"
      }

    case .username:
      return Gen<String> { rng, _ in
        let first = data.firstNames.randomElement(using: &rng)?.lowercased() ?? "user"
        let last = data.lastNames.randomElement(using: &rng)?.lowercased() ?? ""
        let num = Int.random(in: 1...999, using: &rng)
        return "\(first)\(last)\(num)"
      }

    case .password(let strength):
      return Gen<String> { rng, _ in
        let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
        let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let numbers = Array("0123456789")
        let symbols = Array("!@#$%^&*()_+-=")

        let chars: [Character]
        switch strength {
        case .weak:
          chars = lowercase
        case .medium:
          chars = lowercase + uppercase + numbers
        case .strong, .veryStrong:
          chars = lowercase + uppercase + numbers + symbols
        }

        let length = Int.random(in: strength.minLength...strength.maxLength, using: &rng)
        return String((0..<length).map { _ in chars.randomElement(using: &rng)! })
      }

    case .url:
      return Gen<String> { rng, _ in
        let domain = data.emailDomains.randomElement(using: &rng) ?? "example.com"
        return "https://www.\(domain)"
      }

    case .domain:
      return Gen<String> { rng, _ in
        data.emailDomains.randomElement(using: &rng) ?? "example.com"
      }

    case .ipv4:
      return Gen<String> { rng, _ in
        let a = Int.random(in: 1...255, using: &rng)
        let b = Int.random(in: 0...255, using: &rng)
        let c = Int.random(in: 0...255, using: &rng)
        let d = Int.random(in: 0...255, using: &rng)
        return "\(a).\(b).\(c).\(d)"
      }

    case .ipv6:
      return Gen<String> { rng, _ in
        (0..<8).map { _ in String(format: "%04x", Int.random(in: 0...65535, using: &rng)) }
          .joined(separator: ":")
      }

    case .macAddress:
      return Gen<String> { rng, _ in
        (0..<6).map { _ in String(format: "%02X", Int.random(in: 0...255, using: &rng)) }
          .joined(separator: ":")
      }

    case .userAgent:
      return Gen<String> { rng, _ in
        let agents = [
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
          "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)",
          "Mozilla/5.0 (Linux; Android 11; Pixel 5)",
        ]
        return agents.randomElement(using: &rng) ?? agents[0]
      }

    // MARK: - Phone
    case .phoneNumber, .cellPhone:
      return Gen<String> { rng, _ in
        let format = data.phoneFormats.randomElement(using: &rng) ?? "###-###-####"
        var result = ""
        for char in format {
          if char == "#" {
            result.append(String(Int.random(in: 0...9, using: &rng)))
          } else {
            result.append(char)
          }
        }
        return result
      }

    case .countryCallingCode:
      return Gen<String> { rng, _ in
        ["+1", "+44", "+49", "+33", "+55", "+81", "+86", "+91"].randomElement(using: &rng) ?? "+1"
      }

    // MARK: - Address
    case .streetAddress:
      return Gen<String> { rng, _ in
        let number = Int.random(in: 1...9999, using: &rng)
        let name = data.lastNames.randomElement(using: &rng) ?? "Main"
        let suffix = data.streetSuffixes.randomElement(using: &rng) ?? "Street"
        return "\(number) \(name) \(suffix)"
      }

    case .city:
      return Gen<String> { rng, _ in
        data.cities.randomElement(using: &rng) ?? "New York"
      }

    case .state:
      return Gen<String> { rng, _ in
        data.states.randomElement(using: &rng) ?? "New York"
      }

    case .zipCode:
      return Gen<String> { rng, _ in
        String(Int.random(in: 10000...99999, using: &rng))
      }

    case .country:
      return Gen<String> { rng, _ in
        data.countries.randomElement(using: &rng) ?? "United States"
      }

    case .latitude:
      return Gen<String> { rng, _ in
        String(format: "%.6f", Double.random(in: -90.0...90.0, using: &rng))
      }

    case .longitude:
      return Gen<String> { rng, _ in
        String(format: "%.6f", Double.random(in: -180.0...180.0, using: &rng))
      }

    case .fullAddress:
      return Gen<String> { rng, _ in
        let number = Int.random(in: 1...9999, using: &rng)
        let streetName = data.lastNames.randomElement(using: &rng) ?? "Main"
        let streetSuffix = data.streetSuffixes.randomElement(using: &rng) ?? "Street"
        let city = data.cities.randomElement(using: &rng) ?? "New York"
        let state = data.states.randomElement(using: &rng) ?? "NY"
        let zip = Int.random(in: 10000...99999, using: &rng)
        return "\(number) \(streetName) \(streetSuffix), \(city), \(state) \(zip)"
      }

    // MARK: - Company
    case .companyName:
      return Gen<String> { rng, _ in
        let name = data.companyNames.randomElement(using: &rng) ?? "Acme"
        let suffix = data.companySuffixes.randomElement(using: &rng) ?? "Inc."
        return "\(name) \(suffix)"
      }

    case .industry:
      return Gen<String> { rng, _ in
        data.industries.randomElement(using: &rng) ?? "Technology"
      }

    case .jobTitle:
      return Gen<String> { rng, _ in
        data.jobTitles.randomElement(using: &rng) ?? "Developer"
      }

    case .department:
      return Gen<String> { rng, _ in
        data.departments.randomElement(using: &rng) ?? "Engineering"
      }

    case .catchPhrase:
      return Gen<String> { rng, _ in
        data.catchPhrases.randomElement(using: &rng) ?? "Innovate your future"
      }

    case .buzzword:
      return Gen<String> { rng, _ in
        data.buzzwords.randomElement(using: &rng) ?? "synergy"
      }

    // MARK: - Lorem
    case .word:
      return Gen<String> { rng, _ in
        data.loremWords.randomElement(using: &rng) ?? "lorem"
      }

    case .words(let count):
      return Gen<String> { rng, _ in
        (0..<count).map { _ in data.loremWords.randomElement(using: &rng) ?? "lorem" }
          .joined(separator: " ")
      }

    case .sentence:
      return Gen<String> { rng, _ in
        let wordCount = Int.random(in: 5...12, using: &rng)
        var words = (0..<wordCount).map { _ in data.loremWords.randomElement(using: &rng) ?? "lorem"
        }
        if let first = words.first {
          words[0] = first.capitalized
        }
        return words.joined(separator: " ") + "."
      }

    case .sentences(let count):
      return Gen<String> { rng, _ in
        (0..<count).map { _ in
          let wordCount = Int.random(in: 5...12, using: &rng)
          var words = (0..<wordCount).map { _ in
            data.loremWords.randomElement(using: &rng) ?? "lorem"
          }
          if let first = words.first {
            words[0] = first.capitalized
          }
          return words.joined(separator: " ") + "."
        }.joined(separator: " ")
      }

    case .paragraph:
      return Gen<String> { rng, _ in
        (0..<5).map { _ in
          let wordCount = Int.random(in: 5...12, using: &rng)
          var words = (0..<wordCount).map { _ in
            data.loremWords.randomElement(using: &rng) ?? "lorem"
          }
          if let first = words.first {
            words[0] = first.capitalized
          }
          return words.joined(separator: " ") + "."
        }.joined(separator: " ")
      }

    case .paragraphs(let count):
      return Gen<String> { rng, _ in
        (0..<count).map { _ in
          (0..<5).map { _ in
            let wordCount = Int.random(in: 5...12, using: &rng)
            var words = (0..<wordCount).map { _ in
              data.loremWords.randomElement(using: &rng) ?? "lorem"
            }
            if let first = words.first {
              words[0] = first.capitalized
            }
            return words.joined(separator: " ") + "."
          }.joined(separator: " ")
        }.joined(separator: "\n\n")
      }

    // MARK: - Finance
    case .creditCardNumber:
      return Gen<String> { rng, _ in
        String(Int.random(in: 4000_0000_0000_0000...4999_9999_9999_9999, using: &rng))
      }

    case .creditCardType:
      return Gen<String> { rng, _ in
        ["Visa", "Mastercard", "American Express", "Discover"].randomElement(using: &rng) ?? "Visa"
      }

    case .creditCardExpiry:
      return Gen<String> { rng, _ in
        let month = Int.random(in: 1...12, using: &rng)
        let year = Int.random(in: 25...30, using: &rng)
        return String(format: "%02d/%02d", month, year)
      }

    case .cvv:
      return Gen<String> { rng, _ in
        String(Int.random(in: 100...999, using: &rng))
      }

    case .iban:
      return Gen<String> { rng, _ in
        let country = ["DE", "FR", "ES", "IT", "NL"].randomElement(using: &rng) ?? "DE"
        let check = Int.random(in: 10...99, using: &rng)
        let digits = (0..<18).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
        return "\(country)\(check)\(digits)"
      }

    case .bic:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return String((0..<8).map { _ in chars.randomElement(using: &rng)! })
      }

    case .currency:
      return Gen<String> { rng, _ in
        ["US Dollar", "Euro", "British Pound", "Japanese Yen", "Brazilian Real"]
          .randomElement(using: &rng) ?? "US Dollar"
      }

    case .currencyCode:
      return Gen<String> { rng, _ in
        ["USD", "EUR", "GBP", "JPY", "BRL", "CNY", "CHF"]
          .randomElement(using: &rng) ?? "USD"
      }

    case .bitcoinAddress:
      return Gen<String> { rng, _ in
        let chars = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        let prefix = ["1", "3", "bc1"].randomElement(using: &rng) ?? "1"
        let rest = String((0..<32).map { _ in chars.randomElement(using: &rng)! })
        return prefix + rest
      }

    // MARK: - Date/Time
    case .date(let range):
      return Gen<String> { rng, _ in
        let duration = range.upperBound.timeIntervalSince(range.lowerBound)
        let offset = Double.random(in: 0...duration, using: &rng)
        let date = range.lowerBound.addingTimeInterval(offset)
        return ISO8601DateFormatter().string(from: date)
      }

    case .pastDate:
      return Gen<String> { rng, _ in
        let offset = Double.random(in: 0...(365 * 24 * 60 * 60), using: &rng)
        let date = Date().addingTimeInterval(-offset)
        return ISO8601DateFormatter().string(from: date)
      }

    case .futureDate:
      return Gen<String> { rng, _ in
        let offset = Double.random(in: 0...(365 * 24 * 60 * 60), using: &rng)
        let date = Date().addingTimeInterval(offset)
        return ISO8601DateFormatter().string(from: date)
      }

    case .birthday(let minAge, let maxAge):
      return Gen<String> { rng, _ in
        let yearsAgo = Double(Int.random(in: minAge...maxAge, using: &rng)) * 365 * 24 * 60 * 60
        let date = Date().addingTimeInterval(-yearsAgo)
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
      }

    case .timeZone:
      return Gen<String> { rng, _ in
        TimeZone.knownTimeZoneIdentifiers.randomElement(using: &rng) ?? "America/New_York"
      }

    // MARK: - Files
    case .fileName:
      return Gen<String> { rng, _ in
        let name = data.loremWords.randomElement(using: &rng) ?? "file"
        let ext = ["txt", "pdf", "doc", "xlsx", "png", "jpg"].randomElement(using: &rng) ?? "txt"
        return "\(name).\(ext)"
      }

    case .fileExtension:
      return Gen<String> { rng, _ in
        ["txt", "pdf", "doc", "xlsx", "png", "jpg", "mp3", "mp4"]
          .randomElement(using: &rng) ?? "txt"
      }

    case .mimeType:
      return Gen<String> { rng, _ in
        [
          "text/plain", "application/pdf", "image/png", "image/jpeg",
          "application/json", "text/html", "audio/mpeg", "video/mp4",
        ].randomElement(using: &rng) ?? "text/plain"
      }

    case .directoryPath:
      return Gen<String> { rng, _ in
        ["/Users/user/Documents", "/var/log", "/tmp", "/home/user"]
          .randomElement(using: &rng) ?? "/tmp"
      }

    case .filePath:
      return Gen<String> { rng, _ in
        let dir =
          ["/Users/user/Documents", "/tmp", "/home/user"].randomElement(using: &rng) ?? "/tmp"
        let name = data.loremWords.randomElement(using: &rng) ?? "file"
        let ext = ["txt", "pdf", "doc"].randomElement(using: &rng) ?? "txt"
        return "\(dir)/\(name).\(ext)"
      }

    // MARK: - Colors
    case .hexColor:
      return Gen<String> { rng, _ in
        String(format: "#%06X", Int.random(in: 0...0xFFFFFF, using: &rng))
      }

    case .rgbColor:
      return Gen<String> { rng, _ in
        let r = Int.random(in: 0...255, using: &rng)
        let g = Int.random(in: 0...255, using: &rng)
        let b = Int.random(in: 0...255, using: &rng)
        return "rgb(\(r), \(g), \(b))"
      }

    case .colorName:
      return Gen<String> { rng, _ in
        ["Red", "Blue", "Green", "Yellow", "Purple", "Orange", "Pink", "Cyan"]
          .randomElement(using: &rng) ?? "Blue"
      }

    // MARK: - IDs
    case .uuid:
      return Gen<String> { _, _ in UUID().uuidString }

    case .isbn10:
      return Gen<String> { rng, _ in
        (0..<10).map { _ in String(Int.random(in: 0...9, using: &rng)) }
          .joined(separator: "-")
      }

    case .isbn13:
      return Gen<String> { rng, _ in
        "978-" + (0..<10).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
      }

    case .ean13:
      return Gen<String> { rng, _ in
        (0..<13).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
      }

    case .ean8:
      return Gen<String> { rng, _ in
        (0..<8).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined()
      }

    // MARK: - Misc
    case .emoji:
      return Gen<String> { rng, _ in
        ["😀", "😎", "🎉", "❤️", "👍", "🔥", "✨", "🚀", "💡", "🎯"]
          .randomElement(using: &rng) ?? "😀"
      }

    case .boolean:
      return Gen<String> { rng, _ in
        Bool.random(using: &rng) ? "true" : "false"
      }

    case .locale:
      return Gen<String> { rng, _ in
        FakerLocale.allCases.randomElement(using: &rng)?.rawValue ?? "en_US"
      }

    case .countryISOCode:
      return Gen<String> { rng, _ in
        ["US", "BR", "DE", "FR", "JP", "CN", "GB", "IT", "ES", "CA"]
          .randomElement(using: &rng) ?? "US"
      }
    }
  }

  /// Create a domain-specific faker generator.
  public static func faker(domain: DomainFaker, locale: FakerLocale = .enUS) -> Gen<String> {
    switch domain {
    // Healthcare
    case .medicalCondition:
      return Gen<String> { rng, _ in
        [
          "Hypertension", "Diabetes", "Asthma", "Arthritis", "Migraine",
          "Anxiety", "Depression", "Allergies", "Anemia", "Hypothyroidism",
        ]
        .randomElement(using: &rng) ?? "Hypertension"
      }

    case .drugName:
      return Gen<String> { rng, _ in
        [
          "Aspirin", "Ibuprofen", "Acetaminophen", "Lisinopril", "Metformin",
          "Omeprazole", "Atorvastatin", "Levothyroxine", "Amlodipine", "Metoprolol",
        ]
        .randomElement(using: &rng) ?? "Aspirin"
      }

    case .bloodType:
      return Gen<String> { rng, _ in
        ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
          .randomElement(using: &rng) ?? "O+"
      }

    case .allergy:
      return Gen<String> { rng, _ in
        [
          "Peanuts", "Shellfish", "Penicillin", "Latex", "Pollen",
          "Dust Mites", "Eggs", "Milk", "Soy", "Wheat",
        ]
        .randomElement(using: &rng) ?? "Pollen"
      }

    // E-commerce
    case .productName:
      return Gen<String> { rng, _ in
        let adjectives = ["Premium", "Deluxe", "Essential", "Professional", "Ultimate"]
        let nouns = ["Widget", "Gadget", "Device", "Tool", "Kit", "Set", "Pack"]
        let adj = adjectives.randomElement(using: &rng) ?? "Premium"
        let noun = nouns.randomElement(using: &rng) ?? "Widget"
        return "\(adj) \(noun)"
      }

    case .productCategory:
      return Gen<String> { rng, _ in
        [
          "Electronics", "Clothing", "Home & Garden", "Sports", "Books",
          "Toys", "Health & Beauty", "Automotive", "Food & Beverages",
        ]
        .randomElement(using: &rng) ?? "Electronics"
      }

    case .sku:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let letters = String((0..<3).map { _ in chars.randomElement(using: &rng)! })
        let num = Int.random(in: 1000...9999, using: &rng)
        return "\(letters)-\(num)"
      }

    case .price(_, let min, let max):
      return Gen<String> { rng, _ in
        String(format: "%.2f", Double.random(in: min...max, using: &rng))
      }

    case .review:
      return Gen<String> { rng, _ in
        [
          "Great product, highly recommend!",
          "Good value for money.",
          "Works as expected.",
          "Could be better.",
          "Exceeded my expectations!",
          "Fast shipping, good quality.",
        ]
        .randomElement(using: &rng) ?? "Great product!"
      }

    // Social
    case .hashtag:
      return Gen<String> { rng, _ in
        let tags = ["trending", "viral", "innovation", "tech", "startup", "coding"]
        return "#" + (tags.randomElement(using: &rng) ?? "trending")
      }

    case .mention:
      return Gen<String> { rng, _ in
        let data = FakerData.shared.data(for: locale)
        let first = data.firstNames.randomElement(using: &rng)?.lowercased() ?? "user"
        let num = Int.random(in: 1...99, using: &rng)
        return "@\(first)\(num)"
      }

    case .tweetText:
      return Gen<String> { rng, _ in
        let data = FakerData.shared.data(for: locale)
        let words = (0..<8).map { _ in data.loremWords.randomElement(using: &rng) ?? "lorem" }
        var sentence = words.joined(separator: " ")
        if let first = sentence.first {
          sentence = first.uppercased() + sentence.dropFirst()
        }
        let tag = ["trending", "tech", "coding"].randomElement(using: &rng) ?? "tech"
        return sentence + ". #\(tag)"
      }

    case .postContent:
      return Gen<String> { rng, _ in
        let data = FakerData.shared.data(for: locale)
        return (0..<3).map { _ in
          let words = (0..<10).map { _ in data.loremWords.randomElement(using: &rng) ?? "lorem" }
          var sentence = words.joined(separator: " ")
          if let first = sentence.first {
            sentence = first.uppercased() + sentence.dropFirst()
          }
          return sentence + "."
        }.joined(separator: " ")
      }

    // Technical
    case .httpMethod:
      return Gen<String> { rng, _ in
        ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
          .randomElement(using: &rng) ?? "GET"
      }

    case .httpStatusCode:
      return Gen<String> { rng, _ in
        ["200", "201", "400", "401", "403", "404", "500", "502", "503"]
          .randomElement(using: &rng) ?? "200"
      }

    case .semanticVersion:
      return Gen<String> { rng, _ in
        let major = Int.random(in: 0...9, using: &rng)
        let minor = Int.random(in: 0...99, using: &rng)
        let patch = Int.random(in: 0...99, using: &rng)
        return "\(major).\(minor).\(patch)"
      }

    case .gitCommitHash:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return String((0..<40).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .branchName:
      return Gen<String> { rng, _ in
        let prefixes = ["feature", "bugfix", "hotfix", "release", "chore"]
        let prefix = prefixes.randomElement(using: &rng) ?? "feature"
        let num = Int.random(in: 1...999, using: &rng)
        return "\(prefix)/TICKET-\(num)"
      }
    }
  }
}
