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

    case .apiKey:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return "sk_" + String((0..<32).map { _ in chars.randomElement(using: &rng)! })
      }

    case .jwtToken:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let header = String((0..<36).map { _ in chars.randomElement(using: &rng)! })
        let payload = String((0..<100).map { _ in chars.randomElement(using: &rng)! })
        let sig = String((0..<43).map { _ in chars.randomElement(using: &rng)! })
        return "eyJ\(header).\(payload).\(sig)"
      }

    case .oauthToken:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return "oauth_" + String((0..<40).map { _ in chars.randomElement(using: &rng)! })
      }

    // MARK: - Rating
    case .rating:
      return Gen<String> { rng, _ in
        let stars = Int.random(in: 1...5, using: &rng)
        return String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)
      }

    // MARK: - Vehicles
    case .licensePlate:
      return Gen<String> { rng, _ in
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let l1 = String((0..<3).map { _ in letters.randomElement(using: &rng)! })
        let n = Int.random(in: 1000...9999, using: &rng)
        return "\(l1)-\(n)"
      }

    case .vin:
      return Gen<String> { rng, _ in
        let chars = Array("ABCDEFGHJKLMNPRSTUVWXYZ0123456789")
        return String((0..<17).map { _ in chars.randomElement(using: &rng)! })
      }

    case .carMake:
      return Gen<String> { rng, _ in
        [
          "Toyota", "Honda", "Ford", "Chevrolet", "BMW", "Mercedes-Benz",
          "Audi", "Volkswagen", "Tesla", "Nissan", "Hyundai", "Kia",
        ].randomElement(using: &rng) ?? "Toyota"
      }

    case .carModel:
      return Gen<String> { rng, _ in
        [
          "Camry", "Accord", "Mustang", "Model 3", "Civic", "Corolla",
          "F-150", "Silverado", "CR-V", "RAV4", "Model Y", "Altima",
        ].randomElement(using: &rng) ?? "Camry"
      }

    case .fuelType:
      return Gen<String> { rng, _ in
        ["Gasoline", "Diesel", "Electric", "Hybrid", "Plug-in Hybrid", "Hydrogen"]
          .randomElement(using: &rng) ?? "Gasoline"
      }

    // MARK: - Entertainment
    case .movieTitle:
      return Gen<String> { rng, _ in
        [
          "The Dark Knight", "Inception", "Pulp Fiction", "The Matrix",
          "Forrest Gump", "The Godfather", "Fight Club", "Interstellar",
          "The Shawshank Redemption", "Gladiator", "Avatar", "Titanic",
        ].randomElement(using: &rng) ?? "Inception"
      }

    case .tvShowTitle:
      return Gen<String> { rng, _ in
        [
          "Breaking Bad", "Game of Thrones", "The Office", "Friends",
          "Stranger Things", "The Crown", "Ted Lasso", "Succession",
          "The Mandalorian", "Better Call Saul", "Severance", "Loki",
        ].randomElement(using: &rng) ?? "Breaking Bad"
      }

    case .actorName:
      return Gen<String> { rng, _ in
        [
          "Tom Hanks", "Leonardo DiCaprio", "Brad Pitt", "Morgan Freeman",
          "Meryl Streep", "Cate Blanchett", "Denzel Washington", "Samuel L. Jackson",
          "Robert Downey Jr.", "Scarlett Johansson", "Chris Evans", "Emma Stone",
        ].randomElement(using: &rng) ?? "Tom Hanks"
      }

    case .director:
      return Gen<String> { rng, _ in
        [
          "Christopher Nolan", "Steven Spielberg", "Martin Scorsese",
          "Quentin Tarantino", "Denis Villeneuve", "Greta Gerwig",
          "Ridley Scott", "James Cameron", "David Fincher", "Wes Anderson",
        ].randomElement(using: &rng) ?? "Christopher Nolan"
      }

    case .movieGenre:
      return Gen<String> { rng, _ in
        [
          "Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Romance",
          "Thriller", "Documentary", "Animation", "Fantasy", "Mystery",
        ].randomElement(using: &rng) ?? "Action"
      }

    case .imdbId:
      return Gen<String> { rng, _ in
        "tt" + String(format: "%07d", Int.random(in: 1...9_999_999, using: &rng))
      }

    case .songTitle:
      return Gen<String> { rng, _ in
        [
          "Bohemian Rhapsody", "Stairway to Heaven", "Hotel California",
          "Imagine", "Billie Jean", "Sweet Child O' Mine", "Purple Rain",
          "Smells Like Teen Spirit", "Shape of You", "Blinding Lights",
        ].randomElement(using: &rng) ?? "Bohemian Rhapsody"
      }

    case .artistName:
      return Gen<String> { rng, _ in
        [
          "The Beatles", "Queen", "Michael Jackson", "Taylor Swift",
          "Ed Sheeran", "Beyoncé", "Drake", "The Weeknd", "Adele",
          "Coldplay", "Bruno Mars", "Lady Gaga", "Dua Lipa",
        ].randomElement(using: &rng) ?? "The Beatles"
      }

    case .albumName:
      return Gen<String> { rng, _ in
        [
          "Abbey Road", "Thriller", "Back in Black", "The Dark Side of the Moon",
          "1989", "21", "Random Access Memories", "good kid, m.A.A.d city",
          "Lemonade", "After Hours", "Folklore", "Dawn FM",
        ].randomElement(using: &rng) ?? "Abbey Road"
      }

    case .musicGenre:
      return Gen<String> { rng, _ in
        [
          "Pop", "Rock", "Hip Hop", "R&B", "Jazz", "Classical",
          "Electronic", "Country", "Latin", "Indie", "Metal", "Folk",
        ].randomElement(using: &rng) ?? "Pop"
      }

    case .bookTitle:
      return Gen<String> { rng, _ in
        [
          "To Kill a Mockingbird", "1984", "Pride and Prejudice",
          "The Great Gatsby", "Harry Potter", "The Lord of the Rings",
          "The Catcher in the Rye", "Brave New World", "Dune",
        ].randomElement(using: &rng) ?? "1984"
      }

    case .authorName:
      return Gen<String> { rng, _ in
        [
          "Stephen King", "J.K. Rowling", "George Orwell", "Ernest Hemingway",
          "Jane Austen", "Mark Twain", "Agatha Christie", "Isaac Asimov",
          "Neil Gaiman", "Brandon Sanderson", "Margaret Atwood",
        ].randomElement(using: &rng) ?? "Stephen King"
      }

    case .publisher:
      return Gen<String> { rng, _ in
        [
          "Penguin Random House", "HarperCollins", "Simon & Schuster",
          "Macmillan", "Hachette", "Scholastic", "Tor Books", "Del Rey",
        ].randomElement(using: &rng) ?? "Penguin Random House"
      }

    case .bookGenre:
      return Gen<String> { rng, _ in
        [
          "Fiction", "Non-Fiction", "Mystery", "Science Fiction", "Fantasy",
          "Biography", "History", "Self-Help", "Romance", "Thriller",
        ].randomElement(using: &rng) ?? "Fiction"
      }

    // MARK: - Food
    case .dishName:
      return Gen<String> { rng, _ in
        [
          "Spaghetti Carbonara", "Chicken Tikka Masala", "Sushi Roll",
          "Beef Tacos", "Pad Thai", "Margherita Pizza", "Caesar Salad",
          "Ramen", "Fish and Chips", "Cheeseburger", "Burrito Bowl",
        ].randomElement(using: &rng) ?? "Spaghetti Carbonara"
      }

    case .ingredient:
      return Gen<String> { rng, _ in
        [
          "Tomato", "Onion", "Garlic", "Chicken", "Beef", "Salmon",
          "Rice", "Pasta", "Olive Oil", "Cheese", "Butter", "Egg",
          "Pepper", "Salt", "Basil", "Oregano", "Lemon", "Avocado",
        ].randomElement(using: &rng) ?? "Tomato"
      }

    case .cuisine:
      return Gen<String> { rng, _ in
        [
          "Italian", "Mexican", "Japanese", "Chinese", "Indian", "French",
          "Thai", "American", "Mediterranean", "Korean", "Vietnamese", "Greek",
        ].randomElement(using: &rng) ?? "Italian"
      }

    case .restaurantName:
      return Gen<String> { rng, _ in
        let prefixes = ["The", "Café", "Chez", "La", "El", ""]
        let names = ["Kitchen", "Bistro", "Grill", "Garden", "House", "Table"]
        let adjectives = ["Golden", "Blue", "Green", "Secret", "Royal", "Urban"]
        let p = prefixes.randomElement(using: &rng) ?? ""
        let a = adjectives.randomElement(using: &rng) ?? "Golden"
        let n = names.randomElement(using: &rng) ?? "Kitchen"
        return p.isEmpty ? "\(a) \(n)" : "\(p) \(a) \(n)"
      }

    case .beverageName:
      return Gen<String> { rng, _ in
        [
          "Espresso", "Latte", "Cappuccino", "Green Tea", "Orange Juice",
          "Coca-Cola", "Lemonade", "Smoothie", "Mojito", "Margarita",
        ].randomElement(using: &rng) ?? "Latte"
      }

    // MARK: - Sports
    case .sportName:
      return Gen<String> { rng, _ in
        [
          "Football", "Basketball", "Soccer", "Baseball", "Tennis",
          "Golf", "Hockey", "Cricket", "Rugby", "Swimming", "Boxing",
        ].randomElement(using: &rng) ?? "Soccer"
      }

    case .teamName:
      return Gen<String> { rng, _ in
        [
          "Lakers", "Warriors", "Patriots", "Yankees", "Cowboys",
          "Red Sox", "Chiefs", "Dodgers", "Eagles", "Bulls",
          "Manchester United", "Real Madrid", "Barcelona",
        ].randomElement(using: &rng) ?? "Lakers"
      }

    case .playerName:
      return Gen<String> { rng, _ in
        [
          "LeBron James", "Tom Brady", "Lionel Messi", "Cristiano Ronaldo",
          "Michael Jordan", "Serena Williams", "Roger Federer", "Tiger Woods",
          "Kobe Bryant", "Stephen Curry", "Patrick Mahomes",
        ].randomElement(using: &rng) ?? "LeBron James"
      }

    case .leagueName:
      return Gen<String> { rng, _ in
        [
          "NFL", "NBA", "MLB", "NHL", "Premier League", "La Liga",
          "Serie A", "Bundesliga", "UFC", "PGA Tour", "ATP Tour",
        ].randomElement(using: &rng) ?? "NFL"
      }

    case .stadiumName:
      return Gen<String> { rng, _ in
        [
          "Madison Square Garden", "Wembley Stadium", "Camp Nou",
          "Yankee Stadium", "Staples Center", "Old Trafford",
          "Fenway Park", "Lambeau Field", "Santiago Bernabéu",
        ].randomElement(using: &rng) ?? "Madison Square Garden"
      }

    // MARK: - Education
    case .universityName:
      return Gen<String> { rng, _ in
        [
          "Harvard University", "Stanford University", "MIT",
          "Yale University", "Princeton University", "Columbia University",
          "UC Berkeley", "Oxford University", "Cambridge University",
          "UCLA", "NYU", "University of Michigan",
        ].randomElement(using: &rng) ?? "Stanford University"
      }

    case .courseName:
      return Gen<String> { rng, _ in
        [
          "Introduction to Computer Science", "Calculus I", "Organic Chemistry",
          "Microeconomics", "World History", "Creative Writing",
          "Data Structures", "Machine Learning", "Statistics 101",
        ].randomElement(using: &rng) ?? "Introduction to Computer Science"
      }

    case .degree:
      return Gen<String> { rng, _ in
        [
          "Bachelor of Science", "Bachelor of Arts", "Master of Science",
          "Master of Arts", "Master of Business Administration",
          "Doctor of Philosophy", "Associate Degree",
        ].randomElement(using: &rng) ?? "Bachelor of Science"
      }

    case .major:
      return Gen<String> { rng, _ in
        [
          "Computer Science", "Business Administration", "Psychology",
          "Biology", "Engineering", "Economics", "English Literature",
          "Mathematics", "Political Science", "Chemistry", "Physics",
        ].randomElement(using: &rng) ?? "Computer Science"
      }

    case .gpa:
      return Gen<String> { rng, _ in
        String(format: "%.2f", Double.random(in: 2.0...4.0, using: &rng))
      }

    // MARK: - Gaming
    case .gameTitle:
      return Gen<String> { rng, _ in
        [
          "The Legend of Zelda", "Grand Theft Auto V", "Minecraft",
          "Fortnite", "Call of Duty", "FIFA 24", "The Witcher 3",
          "Red Dead Redemption 2", "Elden Ring", "Cyberpunk 2077",
        ].randomElement(using: &rng) ?? "Minecraft"
      }

    case .gamePlatform:
      return Gen<String> { rng, _ in
        [
          "PlayStation 5", "Xbox Series X", "Nintendo Switch", "PC",
          "PlayStation 4", "Xbox One", "Steam Deck", "Mobile",
        ].randomElement(using: &rng) ?? "PlayStation 5"
      }

    case .gameGenre:
      return Gen<String> { rng, _ in
        [
          "Action", "RPG", "FPS", "Sports", "Racing", "Strategy",
          "Puzzle", "Adventure", "Simulation", "Horror", "Battle Royale",
        ].randomElement(using: &rng) ?? "Action"
      }

    case .playerTag:
      return Gen<String> { rng, _ in
        let prefixes = ["Shadow", "Dark", "Epic", "Pro", "Ultra", "Mega", "Neo"]
        let suffixes = ["Ninja", "Gamer", "Player", "Master", "King", "Legend"]
        let p = prefixes.randomElement(using: &rng) ?? "Epic"
        let s = suffixes.randomElement(using: &rng) ?? "Gamer"
        let n = Int.random(in: 1...999, using: &rng)
        return "\(p)\(s)\(n)"
      }

    case .achievementName:
      return Gen<String> { rng, _ in
        [
          "First Blood", "Champion", "Speedrunner", "Collector",
          "Master Explorer", "Completionist", "Legend", "Perfectionist",
          "Survivor", "Unstoppable", "World Record",
        ].randomElement(using: &rng) ?? "Champion"
      }

    // MARK: - Crypto
    case .ethereumAddress:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return "0x" + String((0..<40).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .tokenName:
      return Gen<String> { rng, _ in
        [
          "Bitcoin", "Ethereum", "Tether", "BNB", "Solana", "XRP",
          "Cardano", "Dogecoin", "Polygon", "Chainlink", "Litecoin",
        ].randomElement(using: &rng) ?? "Ethereum"
      }

    case .transactionHash:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return "0x" + String((0..<64).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .walletName:
      return Gen<String> { rng, _ in
        [
          "MetaMask", "Trust Wallet", "Ledger", "Coinbase Wallet",
          "Phantom", "Rainbow", "Exodus", "Atomic Wallet",
        ].randomElement(using: &rng) ?? "MetaMask"
      }

    // MARK: - Travel
    case .airlineName:
      return Gen<String> { rng, _ in
        [
          "American Airlines", "Delta Air Lines", "United Airlines",
          "Southwest Airlines", "JetBlue", "British Airways",
          "Lufthansa", "Emirates", "Qatar Airways", "Singapore Airlines",
        ].randomElement(using: &rng) ?? "Delta Air Lines"
      }

    case .airportCode:
      return Gen<String> { rng, _ in
        [
          "JFK", "LAX", "ORD", "DFW", "DEN", "SFO", "MIA", "SEA",
          "LHR", "CDG", "NRT", "HKG", "SIN", "DXB", "FRA", "AMS",
        ].randomElement(using: &rng) ?? "JFK"
      }

    case .flightNumber:
      return Gen<String> { rng, _ in
        let airlines = ["AA", "DL", "UA", "SW", "BA", "LH", "EK"]
        let airline = airlines.randomElement(using: &rng) ?? "AA"
        let num = Int.random(in: 100...9999, using: &rng)
        return "\(airline)\(num)"
      }

    case .hotelName:
      return Gen<String> { rng, _ in
        [
          "Hilton", "Marriott", "Hyatt", "Four Seasons", "Ritz-Carlton",
          "Sheraton", "Westin", "Fairmont", "InterContinental", "W Hotels",
        ].randomElement(using: &rng) ?? "Marriott"
      }

    case .destinationCity:
      return Gen<String> { rng, _ in
        [
          "Paris", "Tokyo", "New York", "London", "Rome", "Barcelona",
          "Sydney", "Dubai", "Amsterdam", "Singapore", "Bangkok", "Miami",
        ].randomElement(using: &rng) ?? "Paris"
      }

    // MARK: - Banking
    case .accountNumber:
      return Gen<String> { rng, _ in
        String((0..<12).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined())
      }

    case .routingNumber:
      return Gen<String> { rng, _ in
        String((0..<9).map { _ in String(Int.random(in: 0...9, using: &rng)) }.joined())
      }

    case .transactionType:
      return Gen<String> { rng, _ in
        [
          "Deposit", "Withdrawal", "Transfer", "Payment", "Refund",
          "Wire Transfer", "ACH", "Direct Deposit", "Check",
        ].randomElement(using: &rng) ?? "Transfer"
      }

    case .bankName:
      return Gen<String> { rng, _ in
        [
          "Chase", "Bank of America", "Wells Fargo", "Citibank",
          "Capital One", "PNC Bank", "US Bank", "TD Bank",
          "Goldman Sachs", "Morgan Stanley", "HSBC", "Barclays",
        ].randomElement(using: &rng) ?? "Chase"
      }

    // MARK: - Apple Platform
    case .bundleId:
      return Gen<String> { rng, _ in
        let companies = ["com.apple", "com.google", "io.github", "dev.indie"]
        let apps = ["myapp", "awesome", "super", "ultra", "mega"]
        let company = companies.randomElement(using: &rng) ?? "com.apple"
        let app = apps.randomElement(using: &rng) ?? "myapp"
        let num = Int.random(in: 1...99, using: &rng)
        return "\(company).\(app)\(num)"
      }

    case .appName:
      return Gen<String> { rng, _ in
        let adjectives = ["Super", "Ultra", "Pro", "Fast", "Smart", "Easy"]
        let nouns = ["Notes", "Photos", "Timer", "Scanner", "Tracker", "Manager"]
        let adj = adjectives.randomElement(using: &rng) ?? "Super"
        let noun = nouns.randomElement(using: &rng) ?? "Notes"
        return "\(adj) \(noun)"
      }

    case .appVersion:
      return Gen<String> { rng, _ in
        let major = Int.random(in: 1...20, using: &rng)
        let minor = Int.random(in: 0...99, using: &rng)
        let patch = Int.random(in: 0...99, using: &rng)
        return "\(major).\(minor).\(patch)"
      }

    case .deviceName:
      return Gen<String> { rng, _ in
        [
          "iPhone 15 Pro", "iPhone 15", "iPhone 14 Pro Max", "iPhone SE",
          "iPad Pro 12.9-inch", "iPad Air", "iPad mini", "MacBook Pro",
          "MacBook Air", "iMac", "Mac Studio", "Apple Watch Series 9",
        ].randomElement(using: &rng) ?? "iPhone 15 Pro"
      }

    case .iosVersion:
      return Gen<String> { rng, _ in
        let major = Int.random(in: 14...18, using: &rng)
        let minor = Int.random(in: 0...6, using: &rng)
        return "\(major).\(minor)"
      }

    case .screenResolution:
      return Gen<String> { rng, _ in
        [
          "375x812", "390x844", "393x852", "414x896", "428x926",
          "768x1024", "810x1080", "820x1180", "834x1194",
          "1024x1366", "1440x900", "2560x1440", "2880x1800",
        ].randomElement(using: &rng) ?? "390x844"
      }

    case .apnsToken:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return String((0..<64).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .productId:
      return Gen<String> { rng, _ in
        let prefixes = ["premium", "pro", "basic", "subscription"]
        let products = ["monthly", "yearly", "lifetime", "tier1", "tier2"]
        let p = prefixes.randomElement(using: &rng) ?? "premium"
        let pr = products.randomElement(using: &rng) ?? "monthly"
        return "\(p)_\(pr)"
      }

    case .subscriptionPeriod:
      return Gen<String> { rng, _ in
        ["1 week", "1 month", "3 months", "6 months", "1 year", "Lifetime"]
          .randomElement(using: &rng) ?? "1 month"
      }

    // MARK: - Database/Cloud
    case .tableName:
      return Gen<String> { rng, _ in
        [
          "users", "orders", "products", "customers", "transactions",
          "sessions", "logs", "events", "settings", "profiles",
        ].randomElement(using: &rng) ?? "users"
      }

    case .columnName:
      return Gen<String> { rng, _ in
        [
          "id", "created_at", "updated_at", "name", "email", "status",
          "user_id", "amount", "type", "description", "is_active",
        ].randomElement(using: &rng) ?? "id"
      }

    case .mongoObjectId:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return String((0..<24).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .s3BucketName:
      return Gen<String> { rng, _ in
        let prefixes = ["my", "app", "prod", "dev", "staging"]
        let suffixes = ["assets", "uploads", "backup", "data", "media"]
        let p = prefixes.randomElement(using: &rng) ?? "my"
        let s = suffixes.randomElement(using: &rng) ?? "assets"
        let n = Int.random(in: 1...999, using: &rng)
        return "\(p)-\(s)-\(n)"
      }

    case .awsRegion:
      return Gen<String> { rng, _ in
        [
          "us-east-1", "us-west-2", "eu-west-1", "eu-central-1",
          "ap-northeast-1", "ap-southeast-1", "sa-east-1", "ca-central-1",
        ].randomElement(using: &rng) ?? "us-east-1"
      }

    // MARK: - Logging
    case .logLevel:
      return Gen<String> { rng, _ in
        ["DEBUG", "INFO", "WARN", "ERROR", "FATAL", "TRACE"]
          .randomElement(using: &rng) ?? "INFO"
      }

    case .traceId:
      return Gen<String> { rng, _ in
        let hexChars = Array("0123456789abcdef")
        return String((0..<32).map { _ in hexChars.randomElement(using: &rng)! })
      }

    case .correlationId:
      return Gen<String> { rng, _ in
        return UUID().uuidString.lowercased()
      }
    }
  }
}
