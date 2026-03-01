import Testing
@testable import InvariantSwiftCore

/// Tests for IsolationCapability runtime detection and caching.
@Suite("IsolationCapability Tests")
struct IsolationCapabilityTests {

  // MARK: - Enum Cases

  @Test("IsolationCapability has fullSubprocess case")
  func fullSubprocessCase() {
    let cap = IsolationCapability.fullSubprocess
    #expect(cap == .fullSubprocess)
  }

  @Test("IsolationCapability has threadBased case")
  func threadBasedCase() {
    let cap = IsolationCapability.threadBased
    #expect(cap == .threadBased)
  }

  @Test("IsolationCapability has none case")
  func noneCase() {
    let cap = IsolationCapability.none
    #expect(cap == .none)
  }

  // MARK: - CustomStringConvertible

  @Test("IsolationCapability.fullSubprocess description is non-empty")
  func fullSubprocessDescription() {
    let desc = IsolationCapability.fullSubprocess.description
    #expect(!desc.isEmpty)
  }

  @Test("IsolationCapability.threadBased description is non-empty")
  func threadBasedDescription() {
    let desc = IsolationCapability.threadBased.description
    #expect(!desc.isEmpty)
  }

  @Test("IsolationCapability.none description is non-empty")
  func noneDescription() {
    let desc = IsolationCapability.none.description
    #expect(!desc.isEmpty)
  }

  @Test("IsolationCapability descriptions are distinct")
  func descriptionsAreDistinct() {
    let full = IsolationCapability.fullSubprocess.description
    let thread = IsolationCapability.threadBased.description
    let none = IsolationCapability.none.description
    #expect(full != thread)
    #expect(full != none)
    #expect(thread != none)
  }

  // MARK: - Runtime Detection

  @Test("IsolationCapability.detect() returns a valid capability")
  func detectReturnsValidCapability() {
    let cap = IsolationCapability.detect()
    // Must be one of the three valid cases — the switch exhaustiveness check guarantees this.
    switch cap {
    case .fullSubprocess, .threadBased, .none:
      #expect(Bool(true))
    }
  }

  @Test("IsolationCapability.current returns same value as detect()")
  func currentMatchesDetect() {
    let fromCurrent = IsolationCapability.current
    let fromDetect = IsolationCapability.detect()
    // On macOS detect() always returns .fullSubprocess; current is cached at startup.
    // Both must agree.
    #expect(fromCurrent == fromDetect)
  }

  @Test("IsolationCapability.current is stable across multiple accesses")
  func currentIsStable() {
    let cap1 = IsolationCapability.current
    let cap2 = IsolationCapability.current
    let cap3 = IsolationCapability.current
    #expect(cap1 == cap2)
    #expect(cap2 == cap3)
  }

  // MARK: - macOS-specific

  @Test("IsolationCapability.detect() returns .fullSubprocess on macOS")
  func detectOnMacOS() {
    #if os(macOS)
    #expect(IsolationCapability.detect() == .fullSubprocess)
    #endif
  }
}
