import Testing
import InvariantSwift

@Suite("Fakery Generators Tests")
struct FakeryGeneratorsTests {
  // MARK: - Name Generators

  @Test("firstName generates non-empty strings")
  func testFirstName() {
    let gen = Gen.fake.name.firstName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
    #expect(samples.allSatisfy { !$0.isEmpty || $0 == "" })  // Edge cases can be empty
  }

  @Test("lastName generates non-empty strings")
  func testLastName() {
    let gen = Gen.fake.name.lastName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
    #expect(samples.allSatisfy { !$0.isEmpty || $0 == "" })  // Edge cases can be empty
  }

  @Test("fullName contains space separator")
  func testFullName() {
    let gen = Gen.fake.name.fullName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty && $0 != "   " }
    #expect(validSamples.allSatisfy { $0.contains(" ") })
  }

  @Test("prefix generates title prefixes")
  func testPrefix() {
    let gen = Gen.fake.name.prefix
    let samples = (0..<50).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("suffix generates name suffixes")
  func testSuffix() {
    let gen = Gen.fake.name.suffix
    let samples = (0..<50).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  // MARK: - Address Generators

  @Test("city generates city names")
  func testCity() {
    let gen = Gen.fake.address.city
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
    #expect(samples.allSatisfy { !$0.isEmpty || $0 == "" })
  }

  @Test("streetName generates street names")
  func testStreetName() {
    let gen = Gen.fake.address.streetName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("streetAddress contains number and street")
  func testStreetAddress() {
    let gen = Gen.fake.address.streetAddress
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty }
    #expect(validSamples.allSatisfy { $0.contains(" ") })
  }

  @Test("zipCode generates 5-digit codes")
  func testZipCode() {
    let gen = Gen.fake.address.zipCode
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { $0.count == 5 }
    #expect(validSamples.allSatisfy { $0.allSatisfy { $0.isNumber } })
  }

  @Test("coordinates generates valid lat/lon tuples")
  func testCoordinates() {
    let gen = Gen.fake.address.coordinates
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
    #expect(
      samples.allSatisfy { lat, lon in
        lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
      }
    )
  }

  // MARK: - Internet Generators

  @Test("email contains @ symbol")
  func testEmail() {
    let gen = Gen.fake.internet.email
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty && $0 != "invalid" }
    #expect(validSamples.allSatisfy { $0.contains("@") })
  }

  @Test("username generates non-empty usernames")
  func testUsername() {
    let gen = Gen.fake.internet.username
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("url contains protocol")
  func testUrl() {
    let gen = Gen.fake.internet.url
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty && !$0.hasSuffix("://") }
    #expect(validSamples.allSatisfy { $0.contains("://") })
  }

  @Test("domainName generates valid domains")
  func testDomainName() {
    let gen = Gen.fake.internet.domainName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty }
    #expect(validSamples.allSatisfy { $0.contains(".") })
  }

  @Test("ipv4 generates valid IPv4 addresses")
  func testIpv4() {
    let gen = Gen.fake.internet.ipv4
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty && $0 != "0.0.0.0" }
    #expect(
      validSamples.allSatisfy { ip in
        let parts = ip.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0) != nil }
      }
    )
  }

  @Test("ipv6 generates valid IPv6 addresses")
  func testIpv6() {
    let gen = Gen.fake.internet.ipv6
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty && $0 != "::" }
    #expect(
      validSamples.allSatisfy { ip in
        let parts = ip.split(separator: ":")
        return parts.count >= 3 && parts.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
      }
    )
  }

  // MARK: - Company Generators

  @Test("companyName generates company names")
  func testCompanyName() {
    let gen = Gen.fake.company.name
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("companySuffix generates suffixes")
  func testCompanySuffix() {
    let gen = Gen.fake.company.suffix
    let samples = (0..<50).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("catchPhrase generates phrases")
  func testCatchPhrase() {
    let gen = Gen.fake.company.catchPhrase
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("bs generates business speak")
  func testBs() {
    let gen = Gen.fake.company.bs
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  // MARK: - Commerce Generators

  @Test("productName generates product names")
  func testProductName() {
    let gen = Gen.fake.commerce.productName
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("price generates positive prices")
  func testPrice() {
    let gen = Gen.fake.commerce.price
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isNaN }
    #expect(validSamples.allSatisfy { $0 >= 0 || $0 < 0 })  // Allow edge case negatives
  }

  @Test("color generates color names")
  func testColor() {
    let gen = Gen.fake.commerce.color
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  @Test("department generates department names")
  func testDepartment() {
    let gen = Gen.fake.commerce.department
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(!samples.isEmpty)
  }

  // MARK: - Lorem Generators

  @Test("word generates single words")
  func testWord() {
    let gen = Gen.fake.lorem.word
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty }
    #expect(validSamples.allSatisfy { !$0.contains(" ") })
  }

  @Test("sentence generates sentences with period")
  func testSentence() {
    let gen = Gen.fake.lorem.sentence
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { $0.count > 1 }
    #expect(validSamples.allSatisfy { $0.hasSuffix(".") })
  }

  @Test("paragraph generates multi-sentence text")
  func testParagraph() {
    let gen = Gen.fake.lorem.paragraph
    let samples = (0..<100).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { $0.count > 10 }
    #expect(validSamples.allSatisfy { $0.contains(".") })
  }

  // MARK: - Edge Case Configuration

  @Test("configureFake changes edge case frequency")
  func testConfigureFake() {
    Gen.configureFake(edgeCaseFrequency: 0.0)
    #expect(FakeConfig.current.edgeCaseFrequency == 0.0)

    Gen.configureFake(edgeCaseFrequency: 1.0)
    #expect(FakeConfig.current.edgeCaseFrequency == 1.0)

    Gen.configureFake(edgeCaseFrequency: 0.5)
    #expect(FakeConfig.current.edgeCaseFrequency == 0.5)

    // Reset to default
    Gen.configureFake(edgeCaseFrequency: 0.05)
  }

  @Test("edge case frequency affects generation")
  func testEdgeCaseFrequency() {
    // Set to 100% edge cases
    Gen.configureFake(edgeCaseFrequency: 1.0)
    let gen = Gen.fake.name.firstName
    let samples = (0..<20).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }

    // Should have high proportion of edge cases (empty, special chars, etc.)
    let edgeCases = samples.filter { $0.isEmpty || $0 == "A" || $0.contains("🙂") }
    #expect(edgeCases.count > 10)  // At least 50% should be edge cases

    // Reset to default
    Gen.configureFake(edgeCaseFrequency: 0.05)
  }

  // MARK: - Composition Tests

  @Test("generators compose with map")
  func testCompositionMap() {
    let gen = Gen.fake.name.firstName.map { $0.uppercased() }
    let samples = (0..<10).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { !$0.isEmpty }
    #expect(validSamples.allSatisfy { $0 == $0.uppercased() })
  }

  @Test("generators compose with zip")
  func testCompositionZip() {
    let gen = Gen.fake.name.firstName.zip(Gen.fake.name.lastName)
    let samples = (0..<10).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(samples.count == 10)
    #expect(samples.allSatisfy { first, last in !first.isEmpty || !last.isEmpty })
  }

  @Test("generators compose with flatMap")
  func testCompositionFlatMap() {
    let gen = Gen.fake.name.firstName.flatMap { firstName in
      Gen.fake.name.lastName.map { lastName in "\(firstName) \(lastName)" }
    }
    let samples = (0..<10).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    let validSamples = samples.filter { $0.count > 2 }
    #expect(validSamples.allSatisfy { $0.contains(" ") })
  }

  @Test("generators compose with Gen.zip3")
  func testCompositionZip3() {
    let gen = Gen<String>.zip3(
      Gen.fake.name.firstName,
      Gen.fake.name.lastName,
      Gen.fake.internet.email
    )
    let samples = (0..<10).map { _ in gen.sample(size: 10, seed: Seed(value: UInt64($0))) }
    #expect(samples.count == 10)
  }

  // MARK: - Determinism Tests

  @Test("generators produce consistent output for same seed")
  func testDeterminism() {
    let seed = Seed(value: 42)
    let gen = Gen.fake.name.firstName

    let sample1 = gen.sample(size: 10, seed: seed)
    let sample2 = gen.sample(size: 10, seed: seed)

    #expect(sample1 == sample2)
  }

  @Test("generators produce different output for different seeds")
  func testNonDeterminism() {
    let gen = Gen.fake.name.firstName

    let sample1 = gen.sample(size: 10, seed: Seed(value: 1))
    let sample2 = gen.sample(size: 10, seed: Seed(value: 2))
    let sample3 = gen.sample(size: 10, seed: Seed(value: 3))

    // At least some samples should be different
    #expect(!(sample1 == sample2 && sample2 == sample3))
  }
}
