import InvariantSwiftAdvanced
import Testing

@Suite("Lens Smoke Tests")
struct LensSmokeTests {
  @Test("method-style set delegates to the stored setter")
  func methodStyleSetDelegatesToStoredSetter() {
    let lens = Lens<Person, Int>(
      get: \Person.age,
      set: { age, person in Person(name: person.name, age: age) }
    )

    let updated = lens.set(31, Person(name: "Ana", age: 30))

    #expect(updated == Person(name: "Ana", age: 31))
  }
}

private struct Person: Equatable, Sendable {
  let name: String
  let age: Int
}
