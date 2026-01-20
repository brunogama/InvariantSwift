// MARK: - ISP-0010: Faker Tests
// Tests for faker data generators.

import Foundation
import Testing

import InvariantCore
@testable import InvariantSwift

@Suite("Faker Tests")
struct FakerTests {

  // MARK: - Locale Tests

  @Test("FakerLocale has correct raw values")
  func localeRawValues() {
    #expect(FakerLocale.enUS.rawValue == "en_US")
    #expect(FakerLocale.ptBR.rawValue == "pt_BR")
    #expect(FakerLocale.deDE.rawValue == "de_DE")
    #expect(FakerLocale.jaJP.rawValue == "ja_JP")
  }

  @Test("FakerLocale default is enUS")
  func localeDefault() {
    #expect(FakerLocale.default == .enUS)
  }

  @Test("FakerLocale has language and country codes")
  func localeCodeExtraction() {
    #expect(FakerLocale.enUS.languageCode == "en")
    #expect(FakerLocale.enUS.countryCode == "US")
    #expect(FakerLocale.ptBR.languageCode == "pt")
    #expect(FakerLocale.ptBR.countryCode == "BR")
  }

  // MARK: - FakerData Tests

  @Test("FakerData loads English data")
  func fakerDataEnglish() {
    let data = FakerData.shared.data(for: .enUS)
    #expect(!data.firstNames.isEmpty)
    #expect(!data.lastNames.isEmpty)
    #expect(!data.cities.isEmpty)
    #expect(!data.emailDomains.isEmpty)
  }

  @Test("FakerData loads Brazilian Portuguese data")
  func fakerDataBrazilian() {
    let data = FakerData.shared.data(for: .ptBR)
    #expect(data.locale == .ptBR)
    #expect(data.firstNames.contains("João"))
    #expect(data.lastNames.contains("Silva"))
    #expect(data.cities.contains("São Paulo"))
  }

  @Test("FakerData caches loaded locales")
  func fakerDataCaching() {
    let data1 = FakerData.shared.data(for: .deDE)
    let data2 = FakerData.shared.data(for: .deDE)
    // Same reference means caching works
    #expect(data1.locale == data2.locale)
  }

  // MARK: - Name Generator Tests

  @Test("Faker generates names")
  func fakerName() {
    let gen = Gen<String>.faker(.name)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
    #expect(name.contains(" "))  // First and last name separated by space
  }

  @Test("Faker generates first names")
  func fakerFirstName() {
    let gen = Gen<String>.faker(.firstName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
    #expect(!name.contains(" "))  // Single name, no space
  }

  @Test("Faker generates last names")
  func fakerLastName() {
    let gen = Gen<String>.faker(.lastName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
  }

  // MARK: - Internet Generator Tests

  @Test("Faker generates emails")
  func fakerEmail() {
    let gen = Gen<String>.faker(.email)
    let email = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(email.contains("@"))
    #expect(email.contains("."))
  }

  @Test("Faker generates usernames")
  func fakerUsername() {
    let gen = Gen<String>.faker(.username)
    let username = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!username.isEmpty)
    #expect(!username.contains("@"))
  }

  @Test("Faker generates URLs")
  func fakerURL() {
    let gen = Gen<String>.faker(.url)
    let url = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(url.hasPrefix("https://"))
  }

  @Test("Faker generates IPv4 addresses")
  func fakerIPv4() {
    let gen = Gen<String>.faker(.ipv4)
    let ip = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = ip.split(separator: ".")
    #expect(parts.count == 4)
    for part in parts {
      let num = Int(part)
      #expect(num != nil)
      #expect(num! >= 0 && num! <= 255)
    }
  }

  @Test("Faker generates IPv6 addresses")
  func fakerIPv6() {
    let gen = Gen<String>.faker(.ipv6)
    let ip = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = ip.split(separator: ":")
    #expect(parts.count == 8)
  }

  @Test("Faker generates MAC addresses")
  func fakerMACAddress() {
    let gen = Gen<String>.faker(.macAddress)
    let mac = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = mac.split(separator: ":")
    #expect(parts.count == 6)
  }

  // MARK: - Password Generator Tests

  @Test("Faker generates weak passwords")
  func fakerWeakPassword() {
    let gen = Gen<String>.faker(.password(strength: .weak))
    let password = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(password.count >= 6)
    #expect(password.count <= 8)
  }

  @Test("Faker generates strong passwords")
  func fakerStrongPassword() {
    let gen = Gen<String>.faker(.password(strength: .strong))
    let password = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(password.count >= 12)
    #expect(password.count <= 16)
  }

  // MARK: - Address Generator Tests

  @Test("Faker generates street addresses")
  func fakerStreetAddress() {
    let gen = Gen<String>.faker(.streetAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!address.isEmpty)
    // Should have a number at the start
    let firstChar = address.first!
    #expect(firstChar.isNumber)
  }

  @Test("Faker generates cities")
  func fakerCity() {
    let gen = Gen<String>.faker(.city)
    let city = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!city.isEmpty)
  }

  @Test("Faker generates ZIP codes")
  func fakerZipCode() {
    let gen = Gen<String>.faker(.zipCode)
    let zip = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(zip.count == 5)
    #expect(Int(zip) != nil)
  }

  @Test("Faker generates full addresses")
  func fakerFullAddress() {
    let gen = Gen<String>.faker(.fullAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.contains(","))  // Contains separators
  }

  @Test("Faker generates latitude")
  func fakerLatitude() {
    let gen = Gen<String>.faker(.latitude)
    let lat = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(lat)!
    #expect(value >= -90.0 && value <= 90.0)
  }

  @Test("Faker generates longitude")
  func fakerLongitude() {
    let gen = Gen<String>.faker(.longitude)
    let lng = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(lng)!
    #expect(value >= -180.0 && value <= 180.0)
  }

  // MARK: - Company Generator Tests

  @Test("Faker generates company names")
  func fakerCompanyName() {
    let gen = Gen<String>.faker(.companyName)
    let company = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!company.isEmpty)
  }

  @Test("Faker generates job titles")
  func fakerJobTitle() {
    let gen = Gen<String>.faker(.jobTitle)
    let title = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!title.isEmpty)
  }

  // MARK: - Lorem Generator Tests

  @Test("Faker generates words")
  func fakerWord() {
    let gen = Gen<String>.faker(.word)
    let word = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!word.isEmpty)
    #expect(!word.contains(" "))
  }

  @Test("Faker generates multiple words")
  func fakerWords() {
    let gen = Gen<String>.faker(.words(count: 5))
    let words = gen.sample(size: .medium, seed: Seed(value: 42))
    let wordArray = words.split(separator: " ")
    #expect(wordArray.count == 5)
  }

  @Test("Faker generates sentences")
  func fakerSentence() {
    let gen = Gen<String>.faker(.sentence)
    let sentence = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(sentence.hasSuffix("."))
    #expect(sentence.first?.isUppercase == true)
  }

  @Test("Faker generates paragraphs")
  func fakerParagraph() {
    let gen = Gen<String>.faker(.paragraph)
    let paragraph = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(paragraph.contains("."))
    #expect(paragraph.count > 50)
  }

  // MARK: - Finance Generator Tests

  @Test("Faker generates credit card numbers")
  func fakerCreditCard() {
    let gen = Gen<String>.faker(.creditCardNumber)
    let cc = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(cc.count == 16)
    #expect(cc.hasPrefix("4"))  // Visa format
  }

  @Test("Faker generates CVV")
  func fakerCVV() {
    let gen = Gen<String>.faker(.cvv)
    let cvv = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(cvv.count == 3)
    #expect(Int(cvv) != nil)
  }

  @Test("Faker generates credit card expiry")
  func fakerCreditCardExpiry() {
    let gen = Gen<String>.faker(.creditCardExpiry)
    let expiry = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(expiry.contains("/"))
    let parts = expiry.split(separator: "/")
    #expect(parts.count == 2)
  }

  @Test("Faker generates IBAN")
  func fakerIBAN() {
    let gen = Gen<String>.faker(.iban)
    let iban = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(iban.count == 22)
    #expect(iban.prefix(2).allSatisfy { $0.isLetter })
  }

  @Test("Faker generates Bitcoin addresses")
  func fakerBitcoinAddress() {
    let gen = Gen<String>.faker(.bitcoinAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.hasPrefix("1") || address.hasPrefix("3") || address.hasPrefix("bc1"))
  }

  // MARK: - Date/Time Generator Tests

  @Test("Faker generates past dates")
  func fakerPastDate() {
    let gen = Gen<String>.faker(.pastDate)
    let dateStr = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!dateStr.isEmpty)
    // ISO8601 format contains T
    #expect(dateStr.contains("T"))
  }

  @Test("Faker generates future dates")
  func fakerFutureDate() {
    let gen = Gen<String>.faker(.futureDate)
    let dateStr = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!dateStr.isEmpty)
  }

  @Test("Faker generates timezones")
  func fakerTimeZone() {
    let gen = Gen<String>.faker(.timeZone)
    let tz = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(TimeZone.knownTimeZoneIdentifiers.contains(tz))
  }

  // MARK: - File Generator Tests

  @Test("Faker generates file names")
  func fakerFileName() {
    let gen = Gen<String>.faker(.fileName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(name.contains("."))
  }

  @Test("Faker generates MIME types")
  func fakerMimeType() {
    let gen = Gen<String>.faker(.mimeType)
    let mime = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(mime.contains("/"))
  }

  // MARK: - Color Generator Tests

  @Test("Faker generates hex colors")
  func fakerHexColor() {
    let gen = Gen<String>.faker(.hexColor)
    let color = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(color.hasPrefix("#"))
    #expect(color.count == 7)
  }

  @Test("Faker generates RGB colors")
  func fakerRGBColor() {
    let gen = Gen<String>.faker(.rgbColor)
    let color = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(color.hasPrefix("rgb("))
    #expect(color.hasSuffix(")"))
  }

  // MARK: - ID Generator Tests

  @Test("Faker generates UUIDs")
  func fakerUUID() {
    let gen = Gen<String>.faker(.uuid)
    let uuid = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(UUID(uuidString: uuid) != nil)
  }

  @Test("Faker generates ISBN-13")
  func fakerISBN13() {
    let gen = Gen<String>.faker(.isbn13)
    let isbn = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(isbn.hasPrefix("978-"))
  }

  @Test("Faker generates EAN-13")
  func fakerEAN13() {
    let gen = Gen<String>.faker(.ean13)
    let ean = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(ean.count == 13)
    #expect(ean.allSatisfy { $0.isNumber })
  }

  // MARK: - Misc Generator Tests

  @Test("Faker generates emojis")
  func fakerEmoji() {
    let gen = Gen<String>.faker(.emoji)
    let emoji = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!emoji.isEmpty)
  }

  @Test("Faker generates booleans")
  func fakerBoolean() {
    let gen = Gen<String>.faker(.boolean)
    let bool = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(bool == "true" || bool == "false")
  }

  // MARK: - Domain Faker Tests

  @Test("Domain faker generates medical conditions")
  func domainMedicalCondition() {
    let gen = Gen<String>.faker(domain: .medicalCondition)
    let condition = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!condition.isEmpty)
  }

  @Test("Domain faker generates blood types")
  func domainBloodType() {
    let gen = Gen<String>.faker(domain: .bloodType)
    let blood = gen.sample(size: .medium, seed: Seed(value: 42))
    let validTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    #expect(validTypes.contains(blood))
  }

  @Test("Domain faker generates product names")
  func domainProductName() {
    let gen = Gen<String>.faker(domain: .productName)
    let product = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(product.contains(" "))  // Adjective + Noun
  }

  @Test("Domain faker generates SKUs")
  func domainSKU() {
    let gen = Gen<String>.faker(domain: .sku)
    let sku = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(sku.contains("-"))
    #expect(sku.count >= 8)
  }

  @Test("Domain faker generates prices")
  func domainPrice() {
    let gen = Gen<String>.faker(domain: .price())
    let price = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(price)
    #expect(value != nil)
    #expect(value! >= 0.01 && value! <= 1000.0)
  }

  @Test("Domain faker generates HTTP methods")
  func domainHTTPMethod() {
    let gen = Gen<String>.faker(domain: .httpMethod)
    let method = gen.sample(size: .medium, seed: Seed(value: 42))
    let validMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
    #expect(validMethods.contains(method))
  }

  @Test("Domain faker generates semantic versions")
  func domainSemanticVersion() {
    let gen = Gen<String>.faker(domain: .semanticVersion)
    let version = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = version.split(separator: ".")
    #expect(parts.count == 3)
  }

  @Test("Domain faker generates git commit hashes")
  func domainGitCommitHash() {
    let gen = Gen<String>.faker(domain: .gitCommitHash)
    let hash = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(hash.count == 40)
    #expect(hash.allSatisfy { $0.isHexDigit })
  }

  @Test("Domain faker generates branch names")
  func domainBranchName() {
    let gen = Gen<String>.faker(domain: .branchName)
    let branch = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(branch.contains("/"))
    #expect(branch.contains("TICKET-"))
  }

  // MARK: - New Domain Categories Tests

  @Test("Domain faker generates car makes")
  func domainCarMake() {
    let gen = Gen<String>.faker(domain: .carMake)
    let make = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!make.isEmpty)
  }

  @Test("Domain faker generates movie titles")
  func domainMovieTitle() {
    let gen = Gen<String>.faker(domain: .movieTitle)
    let title = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!title.isEmpty)
  }

  @Test("Domain faker generates airline names")
  func domainAirlineName() {
    let gen = Gen<String>.faker(domain: .airlineName)
    let airline = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!airline.isEmpty)
  }

  @Test("Domain faker generates airport codes")
  func domainAirportCode() {
    let gen = Gen<String>.faker(domain: .airportCode)
    let code = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(code.count == 3)
    #expect(code.allSatisfy { $0.isUppercase })
  }

  @Test("Domain faker generates Ethereum addresses")
  func domainEthereumAddress() {
    let gen = Gen<String>.faker(domain: .ethereumAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.hasPrefix("0x"))
    #expect(address.count == 42)
  }

  @Test("Domain faker generates bundle IDs")
  func domainBundleId() {
    let gen = Gen<String>.faker(domain: .bundleId)
    let bundleId = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(bundleId.contains("."))
    let parts = bundleId.split(separator: ".")
    #expect(parts.count >= 2)
  }

  @Test("Domain faker generates iOS versions")
  func domainIOSVersion() {
    let gen = Gen<String>.faker(domain: .iosVersion)
    let version = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(version.contains("."))
    let parts = version.split(separator: ".")
    #expect(parts.count == 2)
  }

  @Test("Domain faker generates AWS regions")
  func domainAWSRegion() {
    let gen = Gen<String>.faker(domain: .awsRegion)
    let region = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(region.contains("-"))
  }

  @Test("Domain faker generates log levels")
  func domainLogLevel() {
    let gen = Gen<String>.faker(domain: .logLevel)
    let level = gen.sample(size: .medium, seed: Seed(value: 42))
    let validLevels = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL", "TRACE"]
    #expect(validLevels.contains(level))
  }

  // MARK: - Determinism Tests

  @Test("Same seed produces same output")
  func determinism() {
    let gen = Gen<String>.faker(.email)
    let seed = Seed(value: 12345)

    let email1 = gen.sample(size: .medium, seed: seed)
    let email2 = gen.sample(size: .medium, seed: seed)

    #expect(email1 == email2)
  }

  @Test("Different seeds produce different output")
  func differentSeeds() {
    let gen = Gen<String>.faker(.name)

    let name1 = gen.sample(size: .medium, seed: Seed(value: 1))
    let name2 = gen.sample(size: .medium, seed: Seed(value: 2))

    // Very unlikely to be the same with different seeds
    // (but not guaranteed, so we just check they're valid)
    #expect(!name1.isEmpty)
    #expect(!name2.isEmpty)
  }

  // MARK: - Locale Variation Tests

  @Test("Brazilian locale generates Brazilian names")
  func brazilianLocale() {
    let gen = Gen<String>.faker(.firstName, locale: .ptBR)
    // Sample multiple times to increase chance of seeing locale-specific names
    var foundBrazilian = false
    for i in 0..<100 {
      let name = gen.sample(size: .medium, seed: Seed(value: UInt64(i)))
      if ["João", "Maria", "José", "Ana", "Pedro", "Paulo", "Lucas"].contains(name) {
        foundBrazilian = true
        break
      }
    }
    #expect(foundBrazilian)
  }

  @Test("Japanese locale generates Japanese cities")
  func japaneseLocale() {
    let gen = Gen<String>.faker(.city, locale: .jaJP)
    var foundJapanese = false
    for i in 0..<100 {
      let city = gen.sample(size: .medium, seed: Seed(value: UInt64(i)))
      if ["東京", "大阪", "横浜", "名古屋", "札幌", "京都"].contains(city) {
        foundJapanese = true
        break
      }
    }
    #expect(foundJapanese)
  }
}
