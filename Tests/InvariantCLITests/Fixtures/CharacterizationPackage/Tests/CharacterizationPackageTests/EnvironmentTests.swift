import Foundation
import Testing

@Test("Characterization child receives canonical execution context")
func executionContext() {
  let environment = ProcessInfo.processInfo.environment
  #expect(environment["INVARIANT_CHARACTERIZATION_MODE"] == "verify")
  #expect(environment["PARENT_SENTINEL"] == "preserved")
  let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .resolvingSymlinksInPath().path
  let expected = environment["EXPECTED_PACKAGE_ROOT"].map {
    URL(fileURLWithPath: $0).resolvingSymlinksInPath().path
  }
  #expect(current == expected)
}
