import InvariantSwiftMacroAPI
import InvariantSwiftTesting
import Testing

@CharacterizationTest(
  fixture: "Tests/GeneratedPropertyTests/Fixtures",
  inputs: [CharacterizationInput<Int>(id: "two", value: 2)]
)
func generatedCharacterization(_ input: Int) -> Int {
  input * 2
}
