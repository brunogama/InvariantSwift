import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class LawCheckedMacroAdditionalTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "LawChecked": LawCheckedMacro.self
  ]

  // swiftlint:disable line_length
  // swiftlint:disable:next function_body_length
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
                        let mapped = functor.map {
                            $0
                        }
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
                        let composed = functor.map {
                            g(f($0))
                        }
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
                    predicate: { applicative in
                        let identity = Container.pure {
                            $0
                        }
                        let result = identity.apply(applicative)
                        return result == applicative
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
                let property = Property<(Container, Container, Container)>(
                    generator: Gen.zip3(Container.gen, Container.gen, Container.gen),
                    predicate: { (u, v, w) in
                        let compose: (Any) -> (Any) -> (Any) -> Any = { f in
                            { g in
                                { x in
                                    f(g(x))
                                }
                            }
                        }
                        let left = Container.pure(compose).apply(u).apply(v).apply(w)
                        let right = u.apply(v.apply(w))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Applicative composition law failed")
            }

            @Test("Container Applicative Homomorphism Law: pure(f) <*> pure(x) == pure(f(x))")
            func test_Container_ApplicativeHomomorphismLaw() async {
                let property = Property<(Int, (Int) -> String)>(
                    generator: Gen.zip(Gen.int, Gen.function(Gen.string)),
                    predicate: { (x, f) in
                        let left = Container.pure(f).apply(Container.pure(x))
                        let right = Container.pure(f(x))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Applicative homomorphism law failed")
            }

            @Test("Container Applicative Interchange Law: u <*> pure(y) == pure($ y) <*> u")
            func test_Container_ApplicativeInterchangeLaw() async {
                let property = Property<(Container, Int)>(
                    generator: Gen.zip(Container.gen, Gen.int),
                    predicate: { (u, y) in
                        let left = u.apply(Container.pure(y))
                        let right = Container.pure { f in
                            f(y)
                        } .apply(u)
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Applicative interchange law failed")
            }
        }
        """,
      macros: testMacros
    )
  }
  // swiftlint:enable line_length

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
                        let left = a.combine(b).combine(c)
                        let right = a.combine(b.combine(c))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 500)
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
