// MARK: - Ghostwriter Access Level Tests
// Tests for FR-4.1: Access Level Filtering

import Foundation
import Testing

@testable import GhostwriterCLI

@Suite("Access Level Extraction Tests")
struct AccessLevelExtractionTests {

  @Test("AccessLevel enum has all five levels")
  func accessLevelEnumComplete() {
    let levels: [AccessLevel] = [.private, .fileprivate, .internal, .public, .open]
    #expect(levels.count == 5)
  }

  @Test("AccessLevel Comparable ordering is correct")
  func accessLevelOrdering() {
    #expect(AccessLevel.private < AccessLevel.fileprivate)
    #expect(AccessLevel.fileprivate < AccessLevel.internal)
    #expect(AccessLevel.internal < AccessLevel.public)
    #expect(AccessLevel.public < AccessLevel.open)
  }

  @Test("isPubliclyAccessible returns true for public and open only")
  func publiclyAccessibleCheck() {
    #expect(AccessLevel.private.isPubliclyAccessible == false)
    #expect(AccessLevel.fileprivate.isPubliclyAccessible == false)
    #expect(AccessLevel.internal.isPubliclyAccessible == false)
    #expect(AccessLevel.public.isPubliclyAccessible == true)
    #expect(AccessLevel.open.isPubliclyAccessible == true)
  }

  @Test("Extracts public access level from struct")
  func extractPublicStruct() {
    let source = """
      public struct User {
        public let name: String
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .public)
  }

  @Test("Extracts open access level from class")
  func extractOpenClass() {
    let source = """
      open class BaseController {
        open func handle() {}
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .open)
  }

  @Test("Defaults to internal when no access modifier")
  func defaultsToInternal() {
    let source = """
      struct InternalModel {
        var value: Int
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .internal)
  }

  @Test("Extracts private access level")
  func extractPrivate() {
    let source = """
      private struct PrivateHelper {
        let id: Int
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .private)
  }

  @Test("Extracts fileprivate access level")
  func extractFileprivate() {
    let source = """
      fileprivate struct FilePrivateHelper {
        var data: Data
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .fileprivate)
  }

  @Test("Backward compatible isPublic property")
  func backwardCompatibleIsPublic() {
    let source = """
      public struct PublicType {}
      struct InternalType {}
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    let publicType = result.types.first { $0.name == "PublicType" }
    let internalType = result.types.first { $0.name == "InternalType" }

    #expect(publicType?.isPublic == true)
    #expect(internalType?.isPublic == false)
  }

  @Test("Property access level extraction")
  func propertyAccessLevels() {
    let source = """
      public struct Container {
        public let publicProp: String
        private let privateProp: Int
        var internalProp: Bool
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    let container = result.types.first { $0.name == "Container" }
    #expect(container != nil)

    let publicProp = container?.properties.first { $0.name == "publicProp" }
    let privateProp = container?.properties.first { $0.name == "privateProp" }
    let internalProp = container?.properties.first { $0.name == "internalProp" }

    #expect(publicProp?.accessLevel == .public)
    #expect(privateProp?.accessLevel == .private)
    #expect(internalProp?.accessLevel == .internal)
  }

  @Test("Extracts internal explicitly specified")
  func extractExplicitInternal() {
    let source = """
      internal struct InternalExplicit {
        internal var count: Int
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    #expect(result.types[0].accessLevel == .internal)
    #expect(result.types[0].properties.count == 1)
    #expect(result.types[0].properties[0].accessLevel == .internal)
  }

  @Test("Mixed access levels in same type")
  func mixedAccessLevels() {
    let source = """
      public struct MixedAccess {
        public var publicVar: Int
        private var privateVar: String
        fileprivate var fileprivateVar: Bool
        internal var internalVar: Double
        var defaultVar: Float
      }
      """
    let extractor = SwiftSyntaxTypeExtractor()
    let result = extractor.analyze(source: source, filePath: "test.swift")

    #expect(result.types.count == 1)
    let type = result.types[0]
    #expect(type.accessLevel == .public)
    #expect(type.properties.count == 5)

    let publicProp = type.properties.first { $0.name == "publicVar" }
    let privateProp = type.properties.first { $0.name == "privateVar" }
    let fileprivateProp = type.properties.first { $0.name == "fileprivateVar" }
    let internalProp = type.properties.first { $0.name == "internalVar" }
    let defaultProp = type.properties.first { $0.name == "defaultVar" }

    #expect(publicProp?.accessLevel == .public)
    #expect(privateProp?.accessLevel == .private)
    #expect(fileprivateProp?.accessLevel == .fileprivate)
    #expect(internalProp?.accessLevel == .internal)
    #expect(defaultProp?.accessLevel == .internal)
  }
}

@Suite("Access Level CLI Tests")
struct AccessLevelCLITests {

  @Test("Config defaults includeInternal to false")
  func configDefaultIncludeInternal() {
    let config = GhostwriterCLI.Config()
    #expect(config.includeInternal == false)
  }

  @Test("--include-internal flag is parsed")
  func parseIncludeInternalFlag() {
    let args = ["ghostwriter", "--include-internal", "Sources/"]
    let config = GhostwriterCLI.parseArguments(args)
    #expect(config.includeInternal == true)
  }

  @Test("includeInternal defaults to false when not specified")
  func includeInternalDefaultsToFalse() {
    let args = ["ghostwriter", "Sources/"]
    let config = GhostwriterCLI.parseArguments(args)
    #expect(config.includeInternal == false)
  }
}
