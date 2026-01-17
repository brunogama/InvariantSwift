import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import InvariantSwiftMacros

final class ArbitraryMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "Arbitrary": ArbitraryMacro.self
  ]

  func testSimpleStructExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct User {
          let name: String
          let age: Int
      }
      """,
      expandedSource: """
        struct User {
            let name: String
            let age: Int

            public static var arbitrary: Gen<User> {
                Gen.zip(Gen<String>.string, Gen<Int>.int).map {
                    User(name: $0, age: $1)
                }
            }

            public static var shrink: Shrink<User> {
                Shrink { value in
                    var results: [User] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(User(name: shrunkName, age: value.age))
                    }
                    for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
                        results.append(User(name: value.name, age: shrunkAge))
                    }
                    return results
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
      @Arbitrary
      struct Wrapper {
          let value: Int
      }
      """,
      expandedSource: """
        struct Wrapper {
            let value: Int

            public static var arbitrary: Gen<Wrapper> {
                Gen<Int>.int.map {
                    Wrapper(value: $0)
                }
            }

            public static var shrink: Shrink<Wrapper> {
                Shrink { value in
                    var results: [Wrapper] = []
                    for shrunkValue in Gen<Int>.int.shrink.shrink(value.value) {
                        results.append(Wrapper(value: shrunkValue))
                    }
                    return results
                }
            }
        }

        extension Wrapper: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testSimpleEnumExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
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

            public static var arbitrary: Gen<Status> {
                Gen.oneOf([Gen.pure(Status.active), Gen.pure(Status.inactive), Gen.pure(Status.pending)])
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
      @Arbitrary
      enum Result {
          case success(value: Int)
          case failure(message: String)
      }
      """,
      expandedSource: """
        enum Result {
            case success(value: Int)
            case failure(message: String)

            public static var arbitrary: Gen<Result> {
                Gen.oneOf([Gen<Int>.int.map {
                            Result.success(value: $0)
                        }, Gen<String>.string.map {
                            Result.failure(message: $0)
                        }])
            }
        }

        extension Result: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testShrinkNoneExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary(shrink: .none)
      struct Point {
          let x: Int
          let y: Int
      }
      """,
      expandedSource: """
        struct Point {
            let x: Int
            let y: Int

            public static var arbitrary: Gen<Point> {
                Gen.zip(Gen<Int>.int, Gen<Int>.int).map {
                    Point(x: $0, y: $1)
                }
            }
        }

        extension Point: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testErrorOnClass() {
    assertMacroExpansion(
      """
      @Arbitrary
      class MyClass {
          var value: Int
      }
      """,
      expandedSource: """
        class MyClass {
            var value: Int
        }

        extension MyClass: Generatable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Arbitrary can only be applied to structs or enums",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testErrorOnEmptyStruct() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Empty {}
      """,
      expandedSource: """
        struct Empty {}

        extension Empty: Generatable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Arbitrary requires at least one stored property",
          line: 2,
          column: 8
        )
      ],
      macros: testMacros
    )
  }

  func testErrorOnEmptyEnum() {
    assertMacroExpansion(
      """
      @Arbitrary
      enum NoCase {}
      """,
      expandedSource: """
        enum NoCase {}

        extension NoCase: Generatable {
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@Arbitrary requires at least one enum case",
          line: 2,
          column: 6
        )
      ],
      macros: testMacros
    )
  }

  func testStructWithDefaultValuesExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct PersonWithDefaults {
          let name: String
          let age: Int = 0
          let active: Bool = true
      }
      """,
      expandedSource: """
        struct PersonWithDefaults {
            let name: String
            let age: Int = 0
            let active: Bool = true

            public static var arbitrary: Gen<PersonWithDefaults> {
                Gen.zip(Gen<String>.string, Gen<Int>.int, Gen<Bool>.bool).map {
                    PersonWithDefaults(name: $0, age: $1, active: $2)
                }
            }

            public static var shrink: Shrink<PersonWithDefaults> {
                Shrink.towards(PersonWithDefaults(name: "", age: 0, active: true))
            }
        }

        extension PersonWithDefaults: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithAllDefaultValuesExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Config {
          let timeout: Int = 30
          let retries: Int = 3
      }
      """,
      expandedSource: """
        struct Config {
            let timeout: Int = 30
            let retries: Int = 3

            public static var arbitrary: Gen<Config> {
                Gen.zip(Gen<Int>.int, Gen<Int>.int).map {
                    Config(timeout: $0, retries: $1)
                }
            }

            public static var shrink: Shrink<Config> {
                Shrink.towards(Config())
            }
        }

        extension Config: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testNestedStructExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Address {
          let street: String
          let city: String
      }
      """,
      expandedSource: """
        struct Address {
            let street: String
            let city: String

            public static var arbitrary: Gen<Address> {
                Gen.zip(Gen<String>.string, Gen<String>.string).map {
                    Address(street: $0, city: $1)
                }
            }

            public static var shrink: Shrink<Address> {
                Shrink { value in
                    var results: [Address] = []
                    for shrunkStreet in Gen<String>.string.shrink.shrink(value.street) {
                        results.append(Address(street: shrunkStreet, city: value.city))
                    }
                    for shrunkCity in Gen<String>.string.shrink.shrink(value.city) {
                        results.append(Address(street: value.street, city: shrunkCity))
                    }
                    return results
                }
            }
        }

        extension Address: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithCustomTypeFieldExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Person {
          let name: String
          let address: Address
      }
      """,
      expandedSource: """
        struct Person {
            let name: String
            let address: Address

            public static var arbitrary: Gen<Person> {
                Gen.zip(Gen<String>.string, Address.arbitrary).map {
                    Person(name: $0, address: $1)
                }
            }

            public static var shrink: Shrink<Person> {
                Shrink { value in
                    var results: [Person] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(Person(name: shrunkName, address: value.address))
                    }
                    for shrunkAddress in Address.arbitrary.shrink.shrink(value.address) {
                        results.append(Person(name: value.name, address: shrunkAddress))
                    }
                    return results
                }
            }
        }

        extension Person: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testDeeplyNestedStructExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Company {
          let name: String
          let ceo: Person
          let headquarters: Address
      }
      """,
      expandedSource: """
        struct Company {
            let name: String
            let ceo: Person
            let headquarters: Address

            public static var arbitrary: Gen<Company> {
                Gen.zip(Gen<String>.string, Person.arbitrary, Address.arbitrary).map {
                    Company(name: $0, ceo: $1, headquarters: $2)
                }
            }

            public static var shrink: Shrink<Company> {
                Shrink { value in
                    var results: [Company] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(Company(name: shrunkName, ceo: value.ceo, headquarters: value.headquarters))
                    }
                    for shrunkCeo in Person.arbitrary.shrink.shrink(value.ceo) {
                        results.append(Company(name: value.name, ceo: shrunkCeo, headquarters: value.headquarters))
                    }
                    for shrunkHeadquarters in Address.arbitrary.shrink.shrink(value.headquarters) {
                        results.append(Company(name: value.name, ceo: value.ceo, headquarters: shrunkHeadquarters))
                    }
                    return results
                }
            }
        }

        extension Company: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithOptionalCustomTypeExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Employee {
          let name: String
          let manager: Person?
      }
      """,
      expandedSource: """
        struct Employee {
            let name: String
            let manager: Person?

            public static var arbitrary: Gen<Employee> {
                Gen.zip(Gen<String>.string, Gen.optional(Person.arbitrary)).map {
                    Employee(name: $0, manager: $1)
                }
            }

            public static var shrink: Shrink<Employee> {
                Shrink { value in
                    var results: [Employee] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(Employee(name: shrunkName, manager: value.manager))
                    }
                    for shrunkManager in Gen.optional(Person.arbitrary).shrink.shrink(value.manager) {
                        results.append(Employee(name: value.name, manager: shrunkManager))
                    }
                    return results
                }
            }
        }

        extension Employee: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithArrayOfCustomTypeExpansion() {
    assertMacroExpansion(
      """
      @Arbitrary
      struct Team {
          let name: String
          let members: [Person]
      }
      """,
      expandedSource: """
        struct Team {
            let name: String
            let members: [Person]

            public static var arbitrary: Gen<Team> {
                Gen.zip(Gen<String>.string, Gen.array(Person.arbitrary)).map {
                    Team(name: $0, members: $1)
                }
            }

            public static var shrink: Shrink<Team> {
                Shrink { value in
                    var results: [Team] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(Team(name: shrunkName, members: value.members))
                    }
                    for shrunkMembers in Gen.array(Person.arbitrary).shrink.shrink(value.members) {
                        results.append(Team(name: value.name, members: shrunkMembers))
                    }
                    return results
                }
            }
        }

        extension Team: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithRangeConstraint() {
    assertMacroExpansion(
      """
      @Arbitrary(constraints: ["age": "0...120"])
      struct Person {
          let name: String
          let age: Int
      }
      """,
      expandedSource: """
        struct Person {
            let name: String
            let age: Int

            public static var arbitrary: Gen<Person> {
                Gen.zip(Gen<String>.string, Gen<Int>.int(in: 0 ... 120)).map {
                    Person(name: $0, age: $1)
                }
            }

            public static var shrink: Shrink<Person> {
                Shrink { value in
                    var results: [Person] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(Person(name: shrunkName, age: value.age))
                    }
                    for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
                        results.append(Person(name: value.name, age: shrunkAge))
                    }
                    return results
                }
            }
        }

        extension Person: Generatable {
        }
        """,
      macros: testMacros
    )
  }

  func testStructWithNonEmptyConstraint() {
    assertMacroExpansion(
      """
      @Arbitrary(constraints: ["name": "nonEmpty"])
      struct User {
          let name: String
          let age: Int
      }
      """,
      expandedSource: """
        struct User {
            let name: String
            let age: Int

            public static var arbitrary: Gen<User> {
                Gen.zip(Gen<String>.string.suchThat({ s in
                            !s.isEmpty
                        }), Gen<Int>.int).map {
                    User(name: $0, age: $1)
                }
            }

            public static var shrink: Shrink<User> {
                Shrink { value in
                    var results: [User] = []
                    for shrunkName in Gen<String>.string.shrink.shrink(value.name) {
                        results.append(User(name: shrunkName, age: value.age))
                    }
                    for shrunkAge in Gen<Int>.int.shrink.shrink(value.age) {
                        results.append(User(name: value.name, age: shrunkAge))
                    }
                    return results
                }
            }
        }

        extension User: Generatable {
        }
        """,
      macros: testMacros
    )
  }
}
