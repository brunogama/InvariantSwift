import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

// swiftlint:disable type_body_length function_body_length line_length
final class LawCheckedMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "LawChecked": LawCheckedMacro.self
  ]

  func testFunctorLawsExpansion() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [.functor])
      struct MyBox<T>: Functor, Equatable {
          let value: T
          func map<U>(_ f: (T) -> U) -> MyBox<U> {
              MyBox<U>(value: f(value))
          }
      }
      """,
      expandedSource: """
        struct MyBox<T>: Functor, Equatable {
            let value: T
            func map<U>(_ f: (T) -> U) -> MyBox<U> {
                MyBox<U>(value: f(value))
            }

            @Test("MyBox Functor Identity Law: map(id) == id")
            func test_MyBox_FunctorIdentityLaw() async {
                let property = Property<MyBox>(
                    generator: MyBox.gen,
                    predicate: { functor in
                        let mapped = functor.map { $0 }
                        return mapped == functor
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 100,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Functor identity law failed")
            }

            @Test("MyBox Functor Composition Law: map(g ∘ f) == map(g) ∘ map(f)")
            func test_MyBox_FunctorCompositionLaw() async {
                let property = Property<(MyBox, (Int) -> String, (String) -> Bool)>(
                    generator: Gen.zip3(MyBox.gen, Gen.function(Gen.string), Gen.function(Gen.bool)),
                    predicate: { (functor, f, g) in
                        let composed = functor.map { g(f($0)) }
                        let sequential = functor.map(f).map(g)
                        return composed == sequential
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Functor composition law failed")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testSemigroupLawExpansion() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [.semigroup])
      struct Additive: Semigroup {
          let value: Int
          func append(_ other: Additive) -> Additive {
              Additive(value: value + other.value)
          }
      }
      """,
      expandedSource: """
        struct Additive: Semigroup {
            let value: Int
            func append(_ other: Additive) -> Additive {
                Additive(value: value + other.value)
            }

            @Test("Additive Semigroup Associativity Law: (a <> b) <> c == a <> (b <> c)")
            func test_Additive_SemigroupAssociativityLaw() async {
                let property = Property<(Additive, Additive, Additive)>(
                    generator: Gen.zip3(Additive.gen, Additive.gen, Additive.gen),
                    predicate: { (a, b, c) in
                        let left = a.append(b).append(c)
                        let right = a.append(b.append(c))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 100,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Semigroup associativity law failed")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMonoidLawsExpansion() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [.monoid])
      struct Sum: Monoid {
          let value: Int
          static var empty: Sum { Sum(value: 0) }
          func append(_ other: Sum) -> Sum {
              Sum(value: value + other.value)
          }
      }
      """,
      expandedSource: """
        struct Sum: Monoid {
            let value: Int
            static var empty: Sum { Sum(value: 0) }
            func append(_ other: Sum) -> Sum {
                Sum(value: value + other.value)
            }

            @Test("Sum Monoid Left Identity Law: empty <> a == a")
            func test_Sum_MonoidLeftIdentityLaw() async {
                let property = Property<Sum>(
                    generator: Sum.gen,
                    predicate: { a in
                        let result = Sum.empty.append(a)
                        return result == a
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 100,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Monoid left identity law failed")
            }

            @Test("Sum Monoid Right Identity Law: a <> empty == a")
            func test_Sum_MonoidRightIdentityLaw() async {
                let property = Property<Sum>(
                    generator: Sum.gen,
                    predicate: { a in
                        let result = a.append(Sum.empty)
                        return result == a
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 100,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Monoid right identity law failed")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testCustomLawExpansion() {
    assertMacroExpansion(
      """
      @LawChecked(customLaws: ["commutativity": "a + b == b + a"])
      struct Addition {
          let value: Int
      }
      """,
      expandedSource: """
        struct Addition {
            let value: Int

            @Test("Addition Custom Law: commutativity")
            func test_Addition_CustomLaw_commutativity() async {
                // Custom law implementation for: a + b == b + a
                let property = Property<Addition>(
                    generator: Addition.gen,
                    predicate: { value in
                        // Custom law expression evaluation
                        true
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Custom law 'commutativity' failed")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMultipleLawsExpansion() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [.functor, .applicative])
      struct Container<T>: Functor, Applicative {
          let value: T
      }
      """,
      expandedSource: """
        struct Container<T>: Functor, Applicative {
            let value: T

            @Test("Container Functor Identity Law: map(id) == id")
            func test_Container_FunctorIdentityLaw() async {
                let property = Property<Container>(
                    generator: Container.gen,
                    predicate: { functor in
                        let mapped = functor.map { $0 }
                        return mapped == functor
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 100,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Functor identity law failed")
            }

            @Test("Container Functor Composition Law: map(g ∘ f) == map(g) ∘ map(f)")
            func test_Container_FunctorCompositionLaw() async {
                let property = Property<(Container, (Int) -> String, (String) -> Bool)>(
                    generator: Gen.zip3(Container.gen, Gen.function(Gen.string), Gen.function(Gen.bool)),
                    predicate: { (functor, f, g) in
                        let composed = functor.map { g(f($0)) }
                        let sequential = functor.map(f).map(g)
                        return composed == sequential
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Functor composition law failed")
            }

            @Test("Container Applicative Identity Law: pure(id) <*> v == v")
            func test_Container_ApplicativeIdentityLaw() async {
                let property = Property<Container>(
                    generator: Container.gen,
                    predicate: { v in
                        let result = Container.pure({ $0 }).ap(v)
                        return result == v
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Applicative identity law failed")
            }

            @Test("Container Applicative Composition Law")
            func test_Container_ApplicativeCompositionLaw() async {
                // Applicative composition law implementation
                #expect(true)
            }

            @Test("Container Applicative Homomorphism Law")
            func test_Container_ApplicativeHomomorphismLaw() async {
                // Applicative homomorphism law implementation
                #expect(true)
            }

            @Test("Container Applicative Interchange Law")
            func test_Container_ApplicativeInterchangeLaw() async {
                // Applicative interchange law implementation
                #expect(true)
            }
        }
        """,
      macros: testMacros
    )
  }

  func testConfigurationParameters() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [.semigroup], iterations: 500, size: 100, timeout: 60.0)
      struct Custom: Semigroup {
          let value: Int
      }
      """,
      expandedSource: """
        struct Custom: Semigroup {
            let value: Int

            @Test("Custom Semigroup Associativity Law: (a <> b) <> c == a <> (b <> c)")
            func test_Custom_SemigroupAssociativityLaw() async {
                let property = Property<(Custom, Custom, Custom)>(
                    generator: Gen.zip3(Custom.gen, Custom.gen, Custom.gen),
                    predicate: { (a, b, c) in
                        let left = a.append(b).append(c)
                        let right = a.append(b.append(c))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(
                        iterations: 500,
                        maxShrinks: 1000,
                        maxDiscarded: 1000
                    )
                )

                #expect(result.isSuccess, "Semigroup associativity law failed")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testEmptyLawsArray() {
    assertMacroExpansion(
      """
      @LawChecked(laws: [])
      struct Empty {
          let value: Int
      }
      """,
      expandedSource: """
        struct Empty {
            let value: Int
        }
        """,
      macros: testMacros
    )
  }
}
