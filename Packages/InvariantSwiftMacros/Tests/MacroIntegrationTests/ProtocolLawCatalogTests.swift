import Testing
@testable import GhostwriterLib

@Suite("Ghostwriter protocol law catalog")
struct ProtocolLawCatalogTests {
  @Test("Every catalog law has a unique stable identifier")
  func uniqueLawIdentifiers() {
    let laws = ProtocolLawCatalog.all.flatMap(\.laws)
    let identifiers = laws.map(\.id)

    #expect(ProtocolLawCatalog.all.count == 70)
    #expect(Set(identifiers).count == identifiers.count)
    #expect(ProtocolLawCatalog.all.allSatisfy { !$0.laws.isEmpty })
  }

  @Test("Compound protocol groups are searchable by each conformance")
  func compoundConformances() {
    let signed = ProtocolLawCatalog.entries(forConformance: "SignedInteger")
    let unsigned = ProtocolLawCatalog.entries(forConformance: "UnsignedInteger")
    let stringLiteral = ProtocolLawCatalog.entries(forConformance: "ExpressibleByStringLiteral")

    #expect(signed.contains { $0.protocolName == "SignedInteger / UnsignedInteger" })
    #expect(unsigned.contains { $0.protocolName == "SignedInteger / UnsignedInteger" })
    #expect(stringLiteral.contains { $0.protocolName.hasPrefix("ExpressibleBy*") })
  }

  @Test("Every marked implementation names a generated test pattern")
  func markedImplementationsExist() {
    let known = Set(GhostwriterTestPattern.allCases.map(\.rawValue))
    let marked = ProtocolLawCatalog.all
      .flatMap(\.laws)
      .compactMap(\.patternIdentifier)
      .map(\.rawValue)

    #expect(!marked.isEmpty)
    #expect(marked.allSatisfy { known.contains($0) })
  }
}
