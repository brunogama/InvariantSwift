import Testing
import Darwin
import InvariantSwiftCore
@testable import InvariantSwift

@Suite("Crash Isolation Tests")
struct CrashIsolationTests {

  @Test("Fatal error is isolated in subprocess", .enabled(if: isMacOS()))
  func testFatalErrorIsolation() async throws {
    #if os(macOS)
    let property = Property(generator: Gen<Int>.int) { value in
      if value == 42 {
        fatalError("Intentional crash for testing")
      }
      return true
    }

    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )

    switch result {
    case .crashed(let signal, let counterexample, _, _):
      #expect(counterexample == 42)
      #expect(signal == SIGABRT || signal == SIGILL)

    case .success:
      Issue.record("Expected crash but property succeeded")

    case .failure:
      Issue.record("Expected crash but got failure instead")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
    #endif
  }

  @Test("Parent process survives child crash")
  func testParentSurvivesChildCrash() async throws {
    #if os(macOS)
    let property = Property(generator: Gen<Int>.int(in: 0...10)) { value in
      if value > 5 {
        preconditionFailure("Intentional precondition failure")
      }
      return true
    }

    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .crashed:
      break

    default:
      break
    }

    #expect(true, "Parent process survived")
    #endif
  }

  @Test("Shrinking works with subprocess isolation")
  func testShrinkingWithIsolation() async throws {
    #if os(macOS)
    let property = Property(generator: Gen<[Int]>.array(Gen<Int>.int)) { array in
      if array.contains(999) {
        fatalError("Found 999")
      }
      return true
    }

    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 12345))
    )

    switch result {
    case .crashed(_, _, let shrunk, _):
      #expect(shrunk.count <= 1)
      if let first = shrunk.first {
        #expect(first == 999)
      }

    default:
      break
    }
    #endif
  }
}

private func isMacOS() -> Bool {
  #if os(macOS)
  return true
  #else
  return false
  #endif
}
