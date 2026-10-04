func throwingAssertions(value: Int) throws {
  try validate(value)
}

private enum throwingAssertions_PropertyTest {
    @Test("throwingAssertions", InvariantSwiftPropertyExecutionTrait(testName: "throwingAssertions", labels: ["value"], configuredSeed: nil), .tags(.invariantSwiftPropertyBased)) static func run() throws {
        let generator: Gen<Int> = Gen<Int>.int
        let property = Property(generator: generator) { (value: Int) in
            do {
                try { () throws -> Void in
                  try validate(value)
                }()
            } catch {
                Issue.record(error)
                return false
            }
            return true
        }
        let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
        try executeGeneratedPropertyTest(property, config: config, testName: "throwingAssertions", labels: ["value"], persistFailures: false)
    }
}
func throwingPredicate(value: Int) throws -> Bool {
  return value > 0
}

private enum throwingPredicate_PropertyTest {
    @Test("throwingPredicate", InvariantSwiftPropertyExecutionTrait(testName: "throwingPredicate", labels: ["value"], configuredSeed: nil), .tags(.invariantSwiftPropertyBased)) static func run() throws {
        let generator: Gen<Int> = Gen<Int>.int
        let property = Property(generator: generator) { (value: Int) in
            do {
                guard try { () throws -> Bool in
                  return value > 0
                }() else {
                    return false
                }
            } catch {
                Issue.record(error)
                return false
            }
            return true
        }
        let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
        try executeGeneratedPropertyTest(property, config: config, testName: "throwingPredicate", labels: ["value"], persistFailures: false)
    }
}
func replayingThrowingPredicate(value: Int) throws -> Bool {
  return value > 0
}

private enum replayingThrowingPredicate_PropertyTest {
    @Suite(.serialized) enum Serialized {
        @Test("replayingThrowingPredicate", InvariantSwiftPropertyExecutionTrait(testName: "replayingThrowingPredicate", labels: ["value"], configuredSeed: nil), .tags(.invariantSwiftPropertyBased)) static func run() throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { (value: Int) in
                do {
                    guard try { () throws -> Bool in
                      return value > 0
                    }() else {
                        return false
                    }
                } catch {
                    Issue.record(error)
                    return false
                }
                return true
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000, failingExampleDatabase: FailingExampleDatabase.shared, testIdentifier: TestIdentifier(module: "", file: String(describing: #file), function: String(describing: #function), signature: ""), replayFirst: true, maxReplayExamples: 2)
            try executeGeneratedPropertyTest(property, config: config, testName: "replayingThrowingPredicate", labels: ["value"], persistFailures: true)
        }
        @Test("replayingThrowingPredicate regressions", InvariantSwiftPropertyExecutionTrait(testName: "replayingThrowingPredicate regressions", labels: ["value"], configuredSeed: nil), .tags(.invariantSwiftPropertyBased, .invariantSwiftPropertyReplay), arguments: try await FailurePersistenceManager().loadReplayFailures(forTest: "replayingThrowingPredicate", maxExamples: 2)) static func replay(failure: PersistedFailure) throws {
            let generator: Gen<Int> = Gen<Int>.int
            let property = Property(generator: generator) { (value: Int) in
                do {
                    guard try { () throws -> Bool in
                      return value > 0
                    }() else {
                        return false
                    }
                } catch {
                    Issue.record(error)
                    return false
                }
                return true
            }
            let config = PropertyConfig(iterations: 100, maxShrinks: 1000, failingExampleDatabase: FailingExampleDatabase.shared, testIdentifier: TestIdentifier(module: "", file: String(describing: #file), function: String(describing: #function), signature: ""), replayFirst: true, maxReplayExamples: 2)
            try executePersistedFailureReplay(property, baseConfig: config, persistedFailure: failure, testName: "replayingThrowingPredicate", labels: ["value"])
        }
    }
}
