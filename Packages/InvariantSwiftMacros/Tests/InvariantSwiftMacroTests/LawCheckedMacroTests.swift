import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantSwiftCore
@testable import InvariantSwiftMacros

final class LawCheckedMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "LawChecked": LawCheckedMacro.self
  ]

  // swiftlint:disable line_length
  // swiftlint:disable:next function_body_length
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

            @Test("MyBox Functor Composition Law: map(g ∘ f) == map(g) ∘ map(f)")
            func test_MyBox_FunctorCompositionLaw() async {
                let property = Property<(MyBox, (Int) -> String, (String) -> Bool)>(
                    generator: Gen.zip3(MyBox.gen, Gen.function(Gen.string), Gen.function(Gen.bool)),
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
        }
        """,
      macros: testMacros
    )
  }
  // swiftlint:enable line_length

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
                        let left = a.combine(b).combine(c)
                        let right = a.combine(b.combine(c))
                        return left == right
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
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
                    predicate: { value in
                        let result = Sum.empty.combine(value)
                        return result == value
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
                )

                #expect(result.isSuccess, "Monoid left identity law failed")
            }

            @Test("Sum Monoid Right Identity Law: a <> empty == a")
            func test_Sum_MonoidRightIdentityLaw() async {
                let property = Property<Sum>(
                    generator: Sum.gen,
                    predicate: { value in
                        let result = value.combine(Sum.empty)
                        return result == value
                    }
                )

                let result = await PropertyRunner().runProperty(
                    property,
                    config: PropertyConfig(iterations: 100)
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
                let property = Property<Addition>(
                    generator: Addition.gen,
                    predicate: { value in
                        // Custom law expression: a + b == b + a
                        // This would need to be parsed and converted to executable code
                        return true // Placeholder - real implementation would parse expression
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

}
