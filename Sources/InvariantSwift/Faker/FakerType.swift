// MARK: - ISP-0010: Faker Type Definitions
// Types of fake data that can be generated.

import Foundation

// MARK: - Faker Type

/// Types of fake data that can be generated.
public enum FakerType: Sendable {
  // MARK: - Names

  /// Full name (first + last)
  case name
  /// First name only
  case firstName
  /// Last name only
  case lastName
  /// Full name with optional prefix/suffix
  case fullName
  /// Name prefix (Mr., Mrs., Dr., etc.)
  case prefix
  /// Name suffix (Jr., Sr., III, etc.)
  case suffix

  // MARK: - Internet

  /// Email address
  case email
  /// Username
  case username
  /// Password with configurable strength
  case password(strength: PasswordStrength = .medium)
  /// URL
  case url
  /// Domain name
  case domain
  /// IPv4 address
  case ipv4
  /// IPv6 address
  case ipv6
  /// MAC address
  case macAddress
  /// User agent string
  case userAgent

  // MARK: - Phone

  /// Phone number in locale format
  case phoneNumber
  /// Cell/mobile phone number
  case cellPhone
  /// Country calling code (+1, +55, etc.)
  case countryCallingCode

  // MARK: - Address

  /// Street address
  case streetAddress
  /// City name
  case city
  /// State/province/region
  case state
  /// ZIP/postal code
  case zipCode
  /// Country name
  case country
  /// Latitude coordinate
  case latitude
  /// Longitude coordinate
  case longitude
  /// Full formatted address
  case fullAddress

  // MARK: - Company

  /// Company name
  case companyName
  /// Industry type
  case industry
  /// Job title
  case jobTitle
  /// Department name
  case department
  /// Business catch phrase
  case catchPhrase
  /// Business buzzword
  case buzzword

  // MARK: - Lorem

  /// Single word
  case word
  /// Multiple words
  case words(count: Int = 3)
  /// Single sentence
  case sentence
  /// Multiple sentences
  case sentences(count: Int = 3)
  /// Single paragraph
  case paragraph
  /// Multiple paragraphs
  case paragraphs(count: Int = 3)

  // MARK: - Finance

  /// Credit card number
  case creditCardNumber
  /// Credit card type (Visa, Mastercard, etc.)
  case creditCardType
  /// Credit card expiry (MM/YY)
  case creditCardExpiry
  /// CVV/CVC code
  case cvv
  /// IBAN number
  case iban
  /// BIC/SWIFT code
  case bic
  /// Currency name
  case currency
  /// Currency code (USD, EUR, etc.)
  case currencyCode
  /// Bitcoin address
  case bitcoinAddress

  // MARK: - Date/Time

  /// Date within a range
  case date(in: ClosedRange<Date>)
  /// Past date
  case pastDate
  /// Future date
  case futureDate
  /// Birthday with age constraints
  case birthday(minAge: Int = 0, maxAge: Int = 100)
  /// Time zone identifier
  case timeZone

  // MARK: - Files

  /// File name with extension
  case fileName
  /// File extension
  case fileExtension
  /// MIME type
  case mimeType
  /// Directory path
  case directoryPath
  /// Full file path
  case filePath

  // MARK: - Colors

  /// Hex color code
  case hexColor
  /// RGB color tuple
  case rgbColor
  /// Color name
  case colorName

  // MARK: - IDs

  /// UUID string
  case uuid
  /// ISBN-10
  case isbn10
  /// ISBN-13
  case isbn13
  /// EAN-13 barcode
  case ean13
  /// EAN-8 barcode
  case ean8

  // MARK: - Misc

  /// Random emoji
  case emoji
  /// Boolean value
  case boolean
  /// Locale identifier
  case locale
  /// ISO country code
  case countryISOCode
}

// MARK: - Password Strength

/// Password strength levels for generation.
public enum PasswordStrength: Sendable {
  /// Simple password (6-8 chars, lowercase only)
  case weak
  /// Medium password (8-12 chars, mixed case + numbers)
  case medium
  /// Strong password (12-16 chars, mixed case + numbers + symbols)
  case strong
  /// Very strong password (16-24 chars, all character types)
  case veryStrong

  /// Minimum length for this strength
  public var minLength: Int {
    switch self {
    case .weak: return 6
    case .medium: return 8
    case .strong: return 12
    case .veryStrong: return 16
    }
  }

  /// Maximum length for this strength
  public var maxLength: Int {
    switch self {
    case .weak: return 8
    case .medium: return 12
    case .strong: return 16
    case .veryStrong: return 24
    }
  }
}

// MARK: - Domain Faker

/// Domain-specific faker types for specialized data.
public enum DomainFaker: Sendable {
  // Healthcare
  case medicalCondition
  case drugName
  case bloodType
  case allergy

  // E-commerce
  case productName
  case productCategory
  case sku
  case price(currency: String = "USD", min: Double = 0.01, max: Double = 1000.0)
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
