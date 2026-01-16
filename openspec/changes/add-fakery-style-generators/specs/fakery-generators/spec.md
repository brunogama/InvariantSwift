## ADDED Requirements

### Requirement: Fake Data Namespace through Gen

The system SHALL provide fake data generators through `Gen.fake` namespace without requiring parentheses in the API.

#### Scenario: Access name generator through Gen.fake
- **WHEN** developer writes `Gen.fake.name.firstName`
- **THEN** a `Gen<String>` generator is returned that produces realistic first names

#### Scenario: Access email generator through Gen.fake
- **WHEN** developer writes `Gen.fake.internet.email`
- **THEN** a `Gen<String>` generator is returned that produces realistic email addresses

#### Scenario: Compose fake generators with existing Gen system
- **WHEN** developer writes `Gen.zip(Gen.fake.name.fullName, Gen.fake.internet.email)`
- **THEN** a tuple generator is returned combining realistic names and emails

### Requirement: Name Generators

The system SHALL provide realistic name generators under `Gen.fake.name` namespace.

#### Scenario: Generate first names
- **WHEN** `Gen.fake.name.firstName` is used
- **THEN** generates realistic first names from various cultural backgrounds

#### Scenario: Generate last names
- **WHEN** `Gen.fake.name.lastName` is used
- **THEN** generates realistic last names from various cultural backgrounds

#### Scenario: Generate full names
- **WHEN** `Gen.fake.name.fullName` is used
- **THEN** generates realistic full names combining first and last names

#### Scenario: Generate name prefixes
- **WHEN** `Gen.fake.name.prefix` is used
- **THEN** generates realistic name prefixes (Mr., Mrs., Dr., etc.)

#### Scenario: Generate name suffixes
- **WHEN** `Gen.fake.name.suffix` is used
- **THEN** generates realistic name suffixes (Jr., Sr., PhD, etc.)

### Requirement: Address Generators

The system SHALL provide realistic address generators under `Gen.fake.address` namespace.

#### Scenario: Generate city names
- **WHEN** `Gen.fake.address.city` is used
- **THEN** generates realistic city names

#### Scenario: Generate street names
- **WHEN** `Gen.fake.address.streetName` is used
- **THEN** generates realistic street names

#### Scenario: Generate street addresses
- **WHEN** `Gen.fake.address.streetAddress` is used
- **THEN** generates realistic full street addresses with numbers

#### Scenario: Generate ZIP codes
- **WHEN** `Gen.fake.address.zipCode` is used
- **THEN** generates realistic postal/ZIP codes

#### Scenario: Generate states
- **WHEN** `Gen.fake.address.state` is used
- **THEN** generates realistic state names

#### Scenario: Generate countries
- **WHEN** `Gen.fake.address.country` is used
- **THEN** generates realistic country names

#### Scenario: Generate coordinates
- **WHEN** `Gen.fake.address.latitude` is used
- **THEN** generates valid latitude values between -90 and 90

#### Scenario: Generate longitude
- **WHEN** `Gen.fake.address.longitude` is used
- **THEN** generates valid longitude values between -180 and 180

### Requirement: Internet Generators

The system SHALL provide realistic internet-related generators under `Gen.fake.internet` namespace.

#### Scenario: Generate email addresses
- **WHEN** `Gen.fake.internet.email` is used
- **THEN** generates realistic email addresses

#### Scenario: Generate usernames
- **WHEN** `Gen.fake.internet.username` is used
- **THEN** generates realistic usernames

#### Scenario: Generate domain names
- **WHEN** `Gen.fake.internet.domainName` is used
- **THEN** generates realistic domain names

#### Scenario: Generate URLs
- **WHEN** `Gen.fake.internet.url` is used
- **THEN** generates realistic HTTP/HTTPS URLs

#### Scenario: Generate IPv4 addresses
- **WHEN** `Gen.fake.internet.ipV4Address` is used
- **THEN** generates valid IPv4 addresses

#### Scenario: Generate IPv6 addresses
- **WHEN** `Gen.fake.internet.ipV6Address` is used
- **THEN** generates valid IPv6 addresses

#### Scenario: Generate passwords
- **WHEN** `Gen.fake.internet.password` is used
- **THEN** generates random password strings

### Requirement: Company Generators

The system SHALL provide realistic company-related generators under `Gen.fake.company` namespace.

#### Scenario: Generate company names
- **WHEN** `Gen.fake.company.name` is used
- **THEN** generates realistic company names

#### Scenario: Generate company suffixes
- **WHEN** `Gen.fake.company.suffix` is used
- **THEN** generates company suffixes (Inc, LLC, Ltd, etc.)

#### Scenario: Generate catch phrases
- **WHEN** `Gen.fake.company.catchPhrase` is used
- **THEN** generates business catch phrases

#### Scenario: Generate business buzzwords
- **WHEN** `Gen.fake.company.bs` is used
- **THEN** generates business buzzword phrases

### Requirement: Commerce Generators

The system SHALL provide realistic commerce-related generators under `Gen.fake.commerce` namespace.

#### Scenario: Generate product names
- **WHEN** `Gen.fake.commerce.productName` is used
- **THEN** generates realistic product names

#### Scenario: Generate prices
- **WHEN** `Gen.fake.commerce.price` is used
- **THEN** generates realistic price values as Double

#### Scenario: Generate colors
- **WHEN** `Gen.fake.commerce.color` is used
- **THEN** generates color names

#### Scenario: Generate departments
- **WHEN** `Gen.fake.commerce.department` is used
- **THEN** generates retail department names

### Requirement: Lorem Ipsum Generators

The system SHALL provide Lorem Ipsum text generators under `Gen.fake.lorem` namespace.

#### Scenario: Generate words
- **WHEN** `Gen.fake.lorem.word` is used
- **THEN** generates a random Lorem Ipsum word

#### Scenario: Generate sentences
- **WHEN** `Gen.fake.lorem.sentence` is used
- **THEN** generates a random Lorem Ipsum sentence

#### Scenario: Generate paragraphs
- **WHEN** `Gen.fake.lorem.paragraph` is used
- **THEN** generates a random Lorem Ipsum paragraph

### Requirement: Edge Case Generation

The system SHALL occasionally generate intentionally malformed data to stress-test properties and find edge cases.

#### Scenario: Default edge case frequency
- **WHEN** using any Gen.fake generator without configuration
- **THEN** 5% of generated values are intentionally malformed (empty strings, special characters, boundary values)
- **AND** 95% of generated values are realistic and valid

#### Scenario: Empty string edge cases
- **WHEN** generating strings via Gen.fake generators
- **THEN** occasionally generates empty strings ""

#### Scenario: Special character edge cases
- **WHEN** generating text via Gen.fake generators
- **THEN** occasionally includes special characters (emoji, unicode, control chars)

#### Scenario: Boundary value edge cases
- **WHEN** generating numbers via Gen.fake generators
- **THEN** occasionally generates boundary values (0, Int.max, Int.min, negative values)

#### Scenario: Invalid format edge cases
- **WHEN** generating emails via `Gen.fake.internet.email`
- **THEN** occasionally generates malformed emails (missing @, multiple @, invalid domains)

### Requirement: Edge Case Configuration

The system SHALL allow developers to configure the frequency of edge case generation.

#### Scenario: Configure edge case frequency
- **WHEN** developer calls `Gen.configureFake(edgeCaseFrequency: 0.1)`
- **THEN** 10% of generated values become intentionally malformed
- **AND** 90% of generated values remain realistic and valid

#### Scenario: Disable edge cases
- **WHEN** developer calls `Gen.configureFake(edgeCaseFrequency: 0.0)`
- **THEN** all generated values are realistic and valid
- **AND** no malformed data is generated

#### Scenario: Full edge case mode
- **WHEN** developer calls `Gen.configureFake(edgeCaseFrequency: 1.0)`
- **THEN** all generated values are intentionally malformed
- **AND** no realistic data is generated

### Requirement: Gen System Integration

The system SHALL integrate fake generators seamlessly with the existing Gen<T> system through Gen.fake namespace.

#### Scenario: Use fake generator as Gen<String>
- **WHEN** a function expects `Gen<String>`
- **THEN** `Gen.fake.name.firstName` can be passed directly

#### Scenario: Compose fake generators
- **WHEN** using Gen combinators (map, flatMap, zip)
- **THEN** Gen.fake generators compose naturally with other Gen instances

#### Scenario: Shrink fake generated values
- **WHEN** a property test fails using Gen.fake generators
- **THEN** generated values shrink toward simpler counterexamples

### Requirement: Extensibility

The system SHALL allow developers to add custom fake data providers.

#### Scenario: Register custom fake data provider
- **WHEN** developer implements a custom FakeProvider protocol
- **THEN** the custom provider can be registered and used via Gen.fake namespace

#### Scenario: Override default providers
- **WHEN** developer registers a custom provider with same key
- **THEN** the custom provider replaces the default for that category
