import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class DeriveGenMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "DeriveGen": DeriveGenMacro.self
  ]

  func testSimpleStructExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct User {
          let name: String
          let age: Int
      }
      """,
      expandedSource: """
        struct User {
            let name: String
            let age: Int

            public static var gen: Gen<User> {
                Gen.zip(
                    Gen.string,
                    Gen.int
                ).map { name, age in
                    User(name: name, age: age)
                }
            }
        }

        extension User: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testSingleFieldStructExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct Wrapper {
          let value: Int
      }
      """,
      expandedSource: """
        struct Wrapper {
            let value: Int

            public static var gen: Gen<Wrapper> {
                Gen.zip(
                    Gen.int
                ).map { value in
                    Wrapper(value: value)
                }
            }
        }

        extension Wrapper: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testOptionalFieldExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct Profile {
          let name: String
          let bio: String?
      }
      """,
      expandedSource: """
        struct Profile {
            let name: String
            let bio: String?

            public static var gen: Gen<Profile> {
                Gen.zip(
                    Gen.string,
                    Gen.optional(Gen.string)
                ).map { name, bio in
                    Profile(name: name, bio: bio)
                }
            }
        }

        extension Profile: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testCustomFieldsExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen(customFields: ["name": "Gen.asciiString"])
      struct Person {
          let name: String
          let id: Int
      }
      """,
      expandedSource: """
        struct Person {
            let name: String
            let id: Int

            public static var gen: Gen<Person> {
                Gen.zip(
                    Gen.asciiString,
                    Gen.int
                ).map { name, id in
                    Person(name: name, id: id)
                }
            }
        }

        extension Person: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testSimpleEnumExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      enum Status {
          case active
          case inactive
          case pending
      }
      """,
      expandedSource: """
        enum Status {
            case active
            case inactive
            case pending

            public static var gen: Gen<Status> {
                Gen.oneOf([
                    Gen.pure(Status.active),
                    Gen.pure(Status.inactive),
                    Gen.pure(Status.pending)
                ])
            }
        }

        extension Status: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testEnumWithAssociatedValuesExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      enum Result {
          case success(value: Int)
          case failure(message: String)
      }
      """,
      expandedSource: """
        enum Result {
            case success(value: Int)
            case failure(message: String)

            public static var gen: Gen<Result> {
                Gen.oneOf([
                    Gen.zip(Gen.int).map { value0 in
                        Result.success(value0)
                    },
                    Gen.zip(Gen.string).map { value0 in
                        Result.failure(value0)
                    }
                ])
            }
        }

        extension Result: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testArrayFieldExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct Team {
          let name: String
          let members: [String]
      }
      """,
      expandedSource: """
        struct Team {
            let name: String
            let members: [String]

            public static var gen: Gen<Team> {
                Gen.zip(
                    Gen.string,
                    Gen.array(Gen.string)
                ).map { name, members in
                    Team(name: name, members: members)
                }
            }
        }

        extension Team: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testNestedCustomTypeExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct Address {
          let street: String
          let city: String
      }
      """,
      expandedSource: """
        struct Address {
            let street: String
            let city: String

            public static var gen: Gen<Address> {
                Gen.zip(
                    Gen.string,
                    Gen.string
                ).map { street, city in
                    Address(street: street, city: city)
                }
            }
        }

        extension Address: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testMultipleFieldTypesExpansion() {
    assertMacroExpansion(
      """
      @DeriveGen
      struct Data {
          let count: Int
          let label: String
          let flag: Bool
          let score: Double
          let id: UUID
      }
      """,
      expandedSource: """
        struct Data {
            let count: Int
            let label: String
            let flag: Bool
            let score: Double
            let id: UUID

            public static var gen: Gen<Data> {
                Gen.zip(
                    Gen.int,
                    Gen.string,
                    Gen.bool,
                    Gen.double,
                    Gen.uuid
                ).map { count, label, flag, score, id in
                    Data(count: count, label: label, flag: flag, score: score, id: id)
                }
            }
        }

        extension Data: Generatable {
        }
        """,
      macros: testMacros
    )
  }
}
