@PropertyTest
func throwingAssertions(value: Int) throws {
  try validate(value)
}

@PropertyTest
func throwingPredicate(value: Int) throws -> Bool {
  return value > 0
}

@PropertyTest(serialized: true)
@Regression(maxExamples: 2, exposeCasesAsTests: true)
func replayingThrowingPredicate(value: Int) throws -> Bool {
  return value > 0
}
