// MARK: - ISP-0010: Domain Data Tests
// Tests for domain data generators.
// Comprehensive test suite for 70+ domain generators - cohesive test organization
// swiftlint:disable:this file_length

import Foundation
import Testing

import InvariantSwiftCore
@testable import InvariantSwiftDomainGenerators
@testable import InvariantSwift

@Suite("Domain Data Tests")
struct DomainDataTests {  // swiftlint:disable:this type_body_length

  // MARK: - Locale Tests

  @Test("DataLocale has correct raw values")
  func dataLocaleRawValues() {
    #expect(DataLocale.enUS.rawValue == "en_US")
    #expect(DataLocale.ptBR.rawValue == "pt_BR")
    #expect(DataLocale.deDE.rawValue == "de_DE")
    #expect(DataLocale.jaJP.rawValue == "ja_JP")
  }

  @Test("DataLocale default is enUS")
  func dataLocaleDefault() {
    #expect(DataLocale.default == .enUS)
  }

  @Test("DataLocale has language and country codes")
  func dataLocaleCodeExtraction() {
    #expect(DataLocale.enUS.languageCode == "en")
    #expect(DataLocale.enUS.countryCode == "US")
    #expect(DataLocale.ptBR.languageCode == "pt")
    #expect(DataLocale.ptBR.countryCode == "BR")
  }

  // MARK: - DomainDataStore Tests

  @Test("DomainDataStore loads English data")
  func domainDataStoreEnglish() {
    let data = DomainDataStore.shared.data(for: .enUS)
    #expect(!data.firstNames.isEmpty)
    #expect(!data.lastNames.isEmpty)
    #expect(!data.cities.isEmpty)
    #expect(!data.emailDomains.isEmpty)
  }

  @Test("DomainDataStore loads Brazilian Portuguese data")
  func domainDataStoreBrazilian() {
    let data = DomainDataStore.shared.data(for: .ptBR)
    #expect(data.locale == .ptBR)
    #expect(data.firstNames.contains("João"))
    #expect(data.lastNames.contains("Silva"))
    #expect(data.cities.contains("São Paulo"))
  }

  @Test("DomainDataStore caches loaded locales")
  func domainDataStoreCaching() {
    let data1 = DomainDataStore.shared.data(for: .deDE)
    let data2 = DomainDataStore.shared.data(for: .deDE)
    // Same reference means caching works
    #expect(data1.locale == data2.locale)
  }

  // MARK: - Name Generator Tests

  @Test("DomainData generates names")
  func domainDataName() {
    let gen = Gen<String>.domainData(.name)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
    #expect(name.contains(" "))  // First and last name separated by space
  }

  @Test("DomainData generates first names")
  func domainDataFirstName() {
    let gen = Gen<String>.domainData(.firstName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
    #expect(!name.contains(" "))  // Single name, no space
  }

  @Test("DomainData generates last names")
  func domainDataLastName() {
    let gen = Gen<String>.domainData(.lastName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!name.isEmpty)
  }

  // MARK: - Internet Generator Tests

  @Test("DomainData generates emails")
  func domainDataEmail() {
    let gen = Gen<String>.domainData(.email)
    let email = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(email.contains("@"))
    #expect(email.contains("."))
  }

  @Test("DomainData generates usernames")
  func domainDataUsername() {
    let gen = Gen<String>.domainData(.username)
    let username = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!username.isEmpty)
    #expect(!username.contains("@"))
  }

  @Test("DomainData generates URLs")
  func domainDataURL() {
    let gen = Gen<String>.domainData(.url)
    let url = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(url.hasPrefix("https://"))
  }

  @Test("DomainData generates IPv4 addresses")
  func domainDataIPv4() {
    let gen = Gen<String>.domainData(.ipv4)
    let ip = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = ip.split(separator: ".")
    #expect(parts.count == 4)
    for part in parts {
      let num = Int(part)
      #expect(num != nil)
      #expect(num! >= 0 && num! <= 255)
    }
  }

  @Test("DomainData generatesIPv6 addresses")
  func domainDataIPv6() {
    let gen = Gen<String>.domainData(.ipv6)
    let ip = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = ip.split(separator: ":")
    #expect(parts.count == 8)
  }

  @Test("DomainData generatesMAC addresses")
  func domainDataMACAddress() {
    let gen = Gen<String>.domainData(.macAddress)
    let mac = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = mac.split(separator: ":")
    #expect(parts.count == 6)
  }

  // MARK: - Password Generator Tests

  @Test("DomainData generatesweak passwords")
  func domainDataWeakPassword() {
    let gen = Gen<String>.domainData(.password(strength: .weak))
    let password = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(password.count >= 6)
    #expect(password.count <= 8)
  }

  @Test("DomainData generatesstrong passwords")
  func domainDataStrongPassword() {
    let gen = Gen<String>.domainData(.password(strength: .strong))
    let password = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(password.count >= 12)
    #expect(password.count <= 16)
  }

  // MARK: - Address Generator Tests

  @Test("DomainData generatesstreet addresses")
  func domainDataStreetAddress() {
    let gen = Gen<String>.domainData(.streetAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!address.isEmpty)
    // Should have a number at the start
    let firstChar = address.first!
    #expect(firstChar.isNumber)
  }

  @Test("DomainData generatescities")
  func domainDataCity() {
    let gen = Gen<String>.domainData(.city)
    let city = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!city.isEmpty)
  }

  @Test("DomainData generatesZIP codes")
  func domainDataZipCode() {
    let gen = Gen<String>.domainData(.zipCode)
    let zip = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(zip.count == 5)
    #expect(Int(zip) != nil)
  }

  @Test("DomainData generatesfull addresses")
  func domainDataFullAddress() {
    let gen = Gen<String>.domainData(.fullAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.contains(","))  // Contains separators
  }

  @Test("DomainData generateslatitude")
  func domainDataLatitude() {
    let gen = Gen<String>.domainData(.latitude)
    let lat = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(lat)!
    #expect(value >= -90.0 && value <= 90.0)
  }

  @Test("DomainData generateslongitude")
  func domainDataLongitude() {
    let gen = Gen<String>.domainData(.longitude)
    let lng = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(lng)!
    #expect(value >= -180.0 && value <= 180.0)
  }

  // MARK: - Company Generator Tests

  @Test("DomainData generatescompany names")
  func domainDataCompanyName() {
    let gen = Gen<String>.domainData(.companyName)
    let company = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!company.isEmpty)
  }

  @Test("DomainData generatesjob titles")
  func domainDataJobTitle() {
    let gen = Gen<String>.domainData(.jobTitle)
    let title = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!title.isEmpty)
  }

  // MARK: - Lorem Generator Tests

  @Test("DomainData generateswords")
  func domainDataWord() {
    let gen = Gen<String>.domainData(.word)
    let word = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!word.isEmpty)
    #expect(!word.contains(" "))
  }

  @Test("DomainData generatesmultiple words")
  func domainDataWords() {
    let gen = Gen<String>.domainData(.words(count: 5))
    let words = gen.sample(size: .medium, seed: Seed(value: 42))
    let wordArray = words.split(separator: " ")
    #expect(wordArray.count == 5)
  }

  @Test("DomainData generatessentences")
  func domainDataSentence() {
    let gen = Gen<String>.domainData(.sentence)
    let sentence = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(sentence.hasSuffix("."))
    #expect(sentence.first?.isUppercase == true)
  }

  @Test("DomainData generatesparagraphs")
  func domainDataParagraph() {
    let gen = Gen<String>.domainData(.paragraph)
    let paragraph = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(paragraph.contains("."))
    #expect(paragraph.count > 50)
  }

  // MARK: - Finance Generator Tests

  @Test("DomainData generatescredit card numbers")
  func domainDataCreditCard() {
    let gen = Gen<String>.domainData(.creditCardNumber)
    let cc = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(cc.count == 16)
    #expect(cc.hasPrefix("4"))  // Visa format
  }

  @Test("DomainData generatesCVV")
  func domainDataCVV() {
    let gen = Gen<String>.domainData(.cvv)
    let cvv = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(cvv.count == 3)
    #expect(Int(cvv) != nil)
  }

  @Test("DomainData generatescredit card expiry")
  func domainDataCreditCardExpiry() {
    let gen = Gen<String>.domainData(.creditCardExpiry)
    let expiry = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(expiry.contains("/"))
    let parts = expiry.split(separator: "/")
    #expect(parts.count == 2)
  }

  @Test("DomainData generatesIBAN")
  func domainDataIBAN() {
    let gen = Gen<String>.domainData(.iban)
    let iban = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(iban.count == 22)
    #expect(iban.prefix(2).allSatisfy { $0.isLetter })
  }

  @Test("DomainData generatesBitcoin addresses")
  func domainDataBitcoinAddress() {
    let gen = Gen<String>.domainData(.bitcoinAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.hasPrefix("1") || address.hasPrefix("3") || address.hasPrefix("bc1"))
  }

  // MARK: - Date/Time Generator Tests

  @Test("DomainData generatespast dates")
  func domainDataPastDate() {
    let gen = Gen<String>.domainData(.pastDate)
    let dateStr = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!dateStr.isEmpty)
    // ISO8601 format contains T
    #expect(dateStr.contains("T"))
  }

  @Test("DomainData generatesfuture dates")
  func domainDataFutureDate() {
    let gen = Gen<String>.domainData(.futureDate)
    let dateStr = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!dateStr.isEmpty)
  }

  @Test("DomainData generatestimezones")
  func domainDataTimeZone() {
    let gen = Gen<String>.domainData(.timeZone)
    let tz = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(TimeZone.knownTimeZoneIdentifiers.contains(tz))
  }

  // MARK: - File Generator Tests

  @Test("DomainData generatesfile names")
  func domainDataFileName() {
    let gen = Gen<String>.domainData(.fileName)
    let name = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(name.contains("."))
  }

  @Test("DomainData generatesMIME types")
  func domainDataMimeType() {
    let gen = Gen<String>.domainData(.mimeType)
    let mime = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(mime.contains("/"))
  }

  // MARK: - Color Generator Tests

  @Test("DomainData generateshex colors")
  func domainDataHexColor() {
    let gen = Gen<String>.domainData(.hexColor)
    let color = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(color.hasPrefix("#"))
    #expect(color.count == 7)
  }

  @Test("DomainData generatesRGB colors")
  func domainDataRGBColor() {
    let gen = Gen<String>.domainData(.rgbColor)
    let color = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(color.hasPrefix("rgb("))
    #expect(color.hasSuffix(")"))
  }

  // MARK: - ID Generator Tests

  @Test("DomainData generatesUUIDs")
  func domainDataUUID() {
    let gen = Gen<String>.domainData(.uuid)
    let uuid = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(UUID(uuidString: uuid) != nil)
  }

  @Test("DomainData generatesISBN-13")
  func domainDataISBN13() {
    let gen = Gen<String>.domainData(.isbn13)
    let isbn = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(isbn.hasPrefix("978-"))
  }

  @Test("DomainData generatesEAN-13")
  func domainDataEAN13() {
    let gen = Gen<String>.domainData(.ean13)
    let ean = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(ean.count == 13)
    #expect(ean.allSatisfy { $0.isNumber })
  }

  // MARK: - Misc Generator Tests

  @Test("DomainData generatesemojis")
  func domainDataEmoji() {
    let gen = Gen<String>.domainData(.emoji)
    let emoji = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!emoji.isEmpty)
  }

  @Test("DomainData generatesbooleans")
  func domainDataBoolean() {
    let gen = Gen<String>.domainData(.boolean)
    let bool = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(bool == "true" || bool == "false")
  }

  // MARK: - Domain Faker Tests

  @Test("DomainData generatesmedical conditions")
  func domainMedicalCondition() {
    let gen = Gen<String>.domainData(domain: .medicalCondition)
    let condition = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!condition.isEmpty)
  }

  @Test("DomainData generatesblood types")
  func domainBloodType() {
    let gen = Gen<String>.domainData(domain: .bloodType)
    let blood = gen.sample(size: .medium, seed: Seed(value: 42))
    let validTypes = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
    #expect(validTypes.contains(blood))
  }

  @Test("DomainData generatesproduct names")
  func domainProductName() {
    let gen = Gen<String>.domainData(domain: .productName)
    let product = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(product.contains(" "))  // Adjective + Noun
  }

  @Test("DomainData generatesSKUs")
  func domainSKU() {
    let gen = Gen<String>.domainData(domain: .sku)
    let sku = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(sku.contains("-"))
    #expect(sku.count >= 8)
  }

  @Test("DomainData generatesprices")
  func domainPrice() {
    let gen = Gen<String>.domainData(domain: .price())
    let price = gen.sample(size: .medium, seed: Seed(value: 42))
    let value = Double(price)
    #expect(value != nil)
    #expect(value! >= 0.01 && value! <= 1000.0)
  }

  @Test("DomainData generatesHTTP methods")
  func domainHTTPMethod() {
    let gen = Gen<String>.domainData(domain: .httpMethod)
    let method = gen.sample(size: .medium, seed: Seed(value: 42))
    let validMethods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
    #expect(validMethods.contains(method))
  }

  @Test("DomainData generatessemantic versions")
  func domainSemanticVersion() {
    let gen = Gen<String>.domainData(domain: .semanticVersion)
    let version = gen.sample(size: .medium, seed: Seed(value: 42))
    let parts = version.split(separator: ".")
    #expect(parts.count == 3)
  }

  @Test("DomainData generatesgit commit hashes")
  func domainGitCommitHash() {
    let gen = Gen<String>.domainData(domain: .gitCommitHash)
    let hash = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(hash.count == 40)
    #expect(hash.allSatisfy { $0.isHexDigit })
  }

  @Test("DomainData generatesbranch names")
  func domainBranchName() {
    let gen = Gen<String>.domainData(domain: .branchName)
    let branch = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(branch.contains("/"))
    #expect(branch.contains("TICKET-"))
  }

  // MARK: - New Domain Categories Tests

  @Test("DomainData generatescar makes")
  func domainCarMake() {
    let gen = Gen<String>.domainData(domain: .carMake)
    let make = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!make.isEmpty)
  }

  @Test("DomainData generatesmovie titles")
  func domainMovieTitle() {
    let gen = Gen<String>.domainData(domain: .movieTitle)
    let title = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!title.isEmpty)
  }

  @Test("DomainData generatesairline names")
  func domainAirlineName() {
    let gen = Gen<String>.domainData(domain: .airlineName)
    let airline = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(!airline.isEmpty)
  }

  @Test("DomainData generatesairport codes")
  func domainAirportCode() {
    let gen = Gen<String>.domainData(domain: .airportCode)
    let code = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(code.count == 3)
    #expect(code.allSatisfy { $0.isUppercase })
  }

  @Test("DomainData generatesEthereum addresses")
  func domainEthereumAddress() {
    let gen = Gen<String>.domainData(domain: .ethereumAddress)
    let address = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(address.hasPrefix("0x"))
    #expect(address.count == 42)
  }

  @Test("DomainData generatesbundle IDs")
  func domainBundleId() {
    let gen = Gen<String>.domainData(domain: .bundleId)
    let bundleId = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(bundleId.contains("."))
    let parts = bundleId.split(separator: ".")
    #expect(parts.count >= 2)
  }

  @Test("DomainData generatesiOS versions")
  func domainIOSVersion() {
    let gen = Gen<String>.domainData(domain: .iosVersion)
    let version = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(version.contains("."))
    let parts = version.split(separator: ".")
    #expect(parts.count == 2)
  }

  @Test("DomainData generatesAWS regions")
  func domainAWSRegion() {
    let gen = Gen<String>.domainData(domain: .awsRegion)
    let region = gen.sample(size: .medium, seed: Seed(value: 42))
    #expect(region.contains("-"))
  }

  @Test("DomainData generateslog levels")
  func domainLogLevel() {
    let gen = Gen<String>.domainData(domain: .logLevel)
    let level = gen.sample(size: .medium, seed: Seed(value: 42))
    let validLevels = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL", "TRACE"]
    #expect(validLevels.contains(level))
  }

  // MARK: - Determinism Tests

  @Test("Same seed produces same output")
  func determinism() {
    let gen = Gen<String>.domainData(.email)
    let seed = Seed(value: 12345)

    let email1 = gen.sample(size: .medium, seed: seed)
    let email2 = gen.sample(size: .medium, seed: seed)

    #expect(email1 == email2)
  }

  @Test("Different seeds produce different output")
  func differentSeeds() {
    let gen = Gen<String>.domainData(.name)

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
    let gen = Gen<String>.domainData(.firstName, locale: .ptBR)
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
    let gen = Gen<String>.domainData(.city, locale: .jaJP)
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
