# ISP-0010: Faker Integration for Realistic Test Data

- **Status:** Implemented
- **Priority:** P3 (Low)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.0+

## Summary

Introduce built-in faker generators for producing realistic test data like names, emails, addresses, and domain-specific values while preserving property-based testing shrinking capabilities.

## Motivation

### The Problem

Random string generation produces gibberish:

```swift
@PropertyTest
func testUserRegistration(name: String, email: String) {
    let user = register(name: name, email: email)
    #expect(user.isValid)
}

// Generated inputs:
// name: "🎭\u{0000}xK2$"
// email: "∆∆∆"
// 
// These find bugs, but:
// 1. Hard to read in failure reports
// 2. Don't represent realistic usage
// 3. Miss domain-specific edge cases
```

### The Solution

Faker generators that produce realistic, shrinkable data:

```swift
@PropertyTest
func testUserRegistration(
    @Gen(.faker(.name)) name: String,
    @Gen(.faker(.email)) email: String,
    @Gen(.faker(.phoneNumber, locale: .ptBR)) phone: String
) {
    let user = register(name: name, email: email, phone: phone)
    #expect(user.isValid)
}

// Generated inputs:
// name: "João Silva"
// email: "joao.silva@exemplo.com.br"  
// phone: "+55 11 98765-4321"
```

## Detailed Design

### Faker Generator API

```swift
extension Gen {
    /// Access faker generators
    public static func faker(_ type: FakerType) -> Gen<String>
    
    /// Access faker generators with locale
    public static func faker(
        _ type: FakerType,
        locale: FakerLocale = .default
    ) -> Gen<String>
    
    /// Access typed faker generators
    public static func faker<T>(_ type: TypedFakerType<T>) -> Gen<T>
}

public enum FakerType: Sendable {
    // Names
    case name
    case firstName
    case lastName
    case fullName
    case prefix  // Mr., Mrs., Dr.
    case suffix  // Jr., Sr., III
    
    // Internet
    case email
    case username
    case password(strength: PasswordStrength = .medium)
    case url
    case domain
    case ipv4
    case ipv6
    case macAddress
    case userAgent
    
    // Phone
    case phoneNumber
    case cellPhone
    case countryCode
    
    // Address
    case streetAddress
    case city
    case state
    case zipCode
    case country
    case latitude
    case longitude
    case fullAddress
    
    // Company
    case companyName
    case industry
    case jobTitle
    case department
    case catchPhrase
    case buzzword
    
    // Lorem
    case word
    case words(count: Int)
    case sentence
    case sentences(count: Int)
    case paragraph
    case paragraphs(count: Int)
    
    // Finance
    case creditCardNumber
    case creditCardType
    case creditCardExpiry
    case cvv
    case iban
    case bic
    case currency
    case currencyCode
    case bitcoinAddress
    
    // Date/Time
    case date(in: ClosedRange<Date>)
    case pastDate
    case futureDate
    case birthday(minAge: Int = 0, maxAge: Int = 100)
    case timeZone
    
    // Files
    case fileName
    case fileExtension
    case mimeType
    case directoryPath
    case filePath
    
    // Colors
    case hexColor
    case rgbColor
    case colorName
    
    // IDs
    case uuid
    case isbn10
    case isbn13
    case ean13
    case ean8
    
    // Misc
    case emoji
    case boolean
    case locale
    case countryISOCode
}
```

### Locale Support

```swift
public enum FakerLocale: String, Sendable, CaseIterable {
    case `default` = "en_US"
    
    // Americas
    case enUS = "en_US"
    case enCA = "en_CA"
    case enGB = "en_GB"
    case ptBR = "pt_BR"
    case esMX = "es_MX"
    case esAR = "es_AR"
    case frCA = "fr_CA"
    
    // Europe
    case deDE = "de_DE"
    case frFR = "fr_FR"
    case itIT = "it_IT"
    case esES = "es_ES"
    case ptPT = "pt_PT"
    case nlNL = "nl_NL"
    case plPL = "pl_PL"
    case ruRU = "ru_RU"
    case ukUA = "uk_UA"
    
    // Asia
    case jaJP = "ja_JP"
    case koKR = "ko_KR"
    case zhCN = "zh_CN"
    case zhTW = "zh_TW"
    case hiIN = "hi_IN"
    
    // Other
    case arSA = "ar_SA"
    case heIL = "he_IL"
}
```

### Typed Faker Generators

```swift
public enum TypedFakerType<T>: Sendable {
    // Returns Date
    case date(DateFakerOptions)
    
    // Returns Int
    case age(min: Int = 0, max: Int = 120)
    case year(in: ClosedRange<Int>)
    
    // Returns Double
    case price(currency: String = "USD", min: Double = 0, max: Double = 1000)
    case latitude
    case longitude
    
    // Returns URL
    case url
    case imageURL(width: Int = 200, height: Int = 200)
    
    // Returns Data
    case image(format: ImageFormat = .png, size: CGSize = CGSize(width: 100, height: 100))
    
    // Returns UUID
    case uuid
}
```

### Shrinking Strategy

Faker generators preserve shrinking by mapping from smaller generators:

```swift
extension Gen where Value == String {
    public static func faker(_ type: FakerType, locale: FakerLocale = .default) -> Gen<String> {
        switch type {
        case .name:
            // Shrinks by trying shorter names
            return Gen<Int>.choose(from: 0..<FakerData.names(locale).count)
                .map { FakerData.names(locale)[$0] }
                .withShrinker { currentName in
                    // Shrink toward "A" (minimal valid name)
                    FakerData.names(locale)
                        .filter { $0.count < currentName.count }
                        .map { ShrinkTree.node($0, []) }
                }
                
        case .email:
            // Composed of username + domain
            return Gen.zip(
                faker(.username, locale: locale),
                faker(.domain, locale: locale)
            ).map { "\($0)@\($1)" }
            
        // ...
        }
    }
}
```

### Integration with @Arbitrary

```swift
@Arbitrary(fakerLocale: .ptBR)
struct BrazilianUser {
    @Gen(.faker(.name)) let name: String
    @Gen(.faker(.email)) let email: String
    @Gen(.faker(.phoneNumber)) let phone: String
    @Gen(.faker(.fullAddress)) let address: String
    @Gen(.age(min: 18, max: 65)) let age: Int
}

// Usage
@PropertyTest
func testBrazilianUserRegistration(user: BrazilianUser) {
    // All fields have Brazilian-localized realistic data
}
```

### Domain-Specific Fakers

```swift
public enum DomainFaker {
    // Healthcare
    case medicalCondition
    case drugName
    case bloodType
    case allergies
    
    // E-commerce
    case productName
    case productCategory
    case sku
    case price
    case review
    
    // Social
    case hashtag
    case mention
    case tweetText
    case postContent
    
    // Technical
    case httpMethod
    case httpStatusCode
    case semanticVersion
    case gitCommitHash
    case branchName
}

@PropertyTest
func testEcommerceOrder(
    @Gen(.faker(.domain(.productName))) product: String,
    @Gen(.faker(.domain(.price))) price: Decimal,
    @Gen(.faker(.domain(.sku))) sku: String
) {
    let order = Order(product: product, price: price, sku: sku)
    #expect(order.isValid)
}
```

### Composable Fakers

Build complex fake data:

```swift
@Composite
func realisticOrder() -> Gen<Order> {
    let customer = #draw(from: .faker(.fullName))
    let email = #draw(from: .faker(.email))
    let itemCount = #draw(Int.self, .between(1...5))
    
    var items: [OrderItem] = []
    for _ in 0..<itemCount {
        let name = #draw(from: .faker(.domain(.productName)))
        let price = #draw(from: .faker(.domain(.price)))
        let quantity = #draw(Int.self, .between(1...10))
        items.append(OrderItem(name: name, price: price, quantity: quantity))
    }
    
    let address = #draw(from: .faker(.fullAddress))
    
    return Order(
        customer: customer,
        email: email,
        items: items,
        shippingAddress: address
    )
}
```

### Faker Providers

Extensible faker system:

```swift
public protocol FakerProvider: Sendable {
    associatedtype Output
    static var category: String { get }
    static func generate(using rng: inout some RandomNumberGenerator, locale: FakerLocale) -> Output
    static func shrink(_ value: Output) -> [Output]
}

// Custom provider
struct SwiftVersionFaker: FakerProvider {
    typealias Output = String
    static let category = "swift"
    
    static func generate(using rng: inout some RandomNumberGenerator, locale: FakerLocale) -> String {
        let major = Int.random(in: 1...6, using: &rng)
        let minor = Int.random(in: 0...9, using: &rng)
        return "\(major).\(minor)"
    }
    
    static func shrink(_ value: String) -> [String] {
        ["1.0", "5.0", "6.0"]  // Common versions
    }
}

// Register
FakerRegistry.register(SwiftVersionFaker.self)

// Use
@Gen(.faker(.custom(SwiftVersionFaker.self)))
```

## When to Use

### ✅ Ideal Use Cases

1. **User-Facing Data**
   ```swift
   @PropertyTest
   func testUserProfile(
       @Gen(.faker(.name)) name: String,
       @Gen(.faker(.email)) email: String,
       @Gen(.faker(.username)) username: String
   ) {
       // Readable failure messages
       // Realistic edge cases (accents, special chars)
   }
   ```

2. **Internationalization Testing**
   ```swift
   @PropertyTest
   func testI18NSupport(
       @Gen(.faker(.name, locale: .jaJP)) japaneseName: String,
       @Gen(.faker(.name, locale: .arSA)) arabicName: String,
       @Gen(.faker(.name, locale: .zhCN)) chineseName: String
   ) {
       // Test handling of various character sets
   }
   ```

3. **Database Seeding**
   ```swift
   @PropertyTest
   func testDatabaseQueries(
       @Gen(.array(of: .faker(.fullName), count: 100)) names: [String],
       @Gen(.array(of: .faker(.email), count: 100)) emails: [String]
   ) {
       let users = zip(names, emails).map { User(name: $0, email: $1) }
       database.insert(users)
       // Test queries with realistic data
   }
   ```

4. **UI Testing**
   ```swift
   @PropertyTest
   func testUserListDisplay(
       @Gen(.faker(.fullName)) name: String,
       @Gen(.faker(.jobTitle)) title: String
   ) {
       // Test with realistic lengths
       // "Dr. João Francisco de Almeida Silva Jr." vs "X"
   }
   ```

5. **Demo Data Generation**
   ```swift
   func generateDemoData() -> [Product] {
       (0..<100).map { _ in
           Product(
               name: Gen.faker(.domain(.productName)).sample()!,
               price: Gen.faker(.domain(.price)).sample()!,
               description: Gen.faker(.paragraph).sample()!
           )
       }
   }
   ```

### ❌ When NOT to Use

1. **Security testing** — Need truly random data
2. **Boundary testing** — Faker produces "normal" data
3. **Protocol compliance** — Need precise formats
4. **Performance testing** — Faker adds overhead

## Importance

### Why This Matters

1. **Readable Test Failures**
   ```
   // Without faker:
   ❌ testUser failed with name: "🎭\u{0000}xK2$"
   
   // With faker:
   ❌ testUser failed with name: "José García-López"
   ```

2. **Realistic Edge Cases**
   - Names with accents: "Müller", "O'Brien", "李明"
   - Multi-word names: "Mary Jane Watson"
   - Long emails: "very.long.email.address@subdomain.example.com"

3. **Internationalization**
   - Test character encoding
   - RTL text support
   - Unicode normalization

4. **Developer Experience**
   - Tests are self-documenting
   - Easy to understand data flow
   - Realistic debugging scenarios

### Comparison with Pure Random

| Aspect | Pure Random | Faker |
|--------|-------------|-------|
| Edge cases | Extreme (empty, huge) | Realistic edge cases |
| Readability | Poor | Excellent |
| Domain relevance | None | High |
| Shrinking | To empty/minimal | To simple valid data |
| Performance | Fast | Slightly slower |

## Implementation Notes

### Phase 1: Core Fakers
- Names, emails, addresses
- Basic locale support (en_US, pt_BR)
- Integration with @Gen

### Phase 2: Extended Categories
- Finance, company, lorem
- All major locales
- Domain-specific fakers

### Phase 3: Composability
- @Composite integration
- Custom providers
- Shrinking optimization

### Data Sources

Faker data sourced from:
- [Faker.js locales](https://github.com/faker-js/faker/tree/main/src/locales)
- [Python Faker providers](https://github.com/joke2k/faker/tree/master/faker/providers)
- Public name/address datasets
- Localized phone number formats

### Memory Efficiency

```swift
// Lazy loading of locale data
final class FakerData: @unchecked Sendable {
    static let shared = FakerData()
    private var loadedLocales: [FakerLocale: LocaleData] = [:]
    private let lock = NSLock()
    
    func data(for locale: FakerLocale) -> LocaleData {
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = loadedLocales[locale] {
            return cached
        }
        
        let data = LocaleData.load(locale)
        loadedLocales[locale] = data
        return data
    }
}
```

## Alternatives Considered

### 1. External Faker Library Dependency
```swift
dependencies: [
    .package(url: "https://github.com/vadymmarkov/Fakery", from: "5.0.0")
]
```
- **Rejected**: Adds dependency, not designed for shrinking

### 2. Annotation-Based Only
```swift
@Faker("name")
let name: String
```
- **Rejected**: Can't compose with other generators

### 3. Separate Faker Module
```swift
import InvariantSwiftFaker
```
- **Considered**: May split out if data gets large

## References

- [Faker.js](https://fakerjs.dev/) — JavaScript faker library
- [Python Faker](https://faker.readthedocs.io/) — Python faker library
- [Fakery (Swift)](https://github.com/vadymmarkov/Fakery) — Existing Swift faker
- [Bogus (.NET)](https://github.com/bchavez/Bogus) — .NET faker with strong typing
- [Hypothesis Strategies](https://hypothesis.readthedocs.io/en/latest/data.html#hypothesis.strategies.emails) — Email/text strategies
