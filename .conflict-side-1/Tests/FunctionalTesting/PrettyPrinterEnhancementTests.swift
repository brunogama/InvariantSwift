import Foundation
import Testing
@testable import InvariantCore
@testable import InvariantSwift

@Suite("PrettyPrinter Enhancement Tests")
struct PrettyPrinterEnhancementTests {

  // MARK: - ObjectTracker Cycle Detection Tests

  @Test("ObjectTracker detects first visit")
  func objectTrackerFirstVisit() {
    var tracker = ObjectTracker()
    let obj = NSObject()

    let result = tracker.beginVisit(obj)

    switch result {
    case .firstVisit(let id):
      #expect(id == 1)
    case .cycleDetected:
      Issue.record("Expected first visit, got cycle detected")
    }
  }

  @Test("ObjectTracker detects cycle on revisit")
  func objectTrackerCycleDetection() {
    var tracker = ObjectTracker()
    let obj = NSObject()

    _ = tracker.beginVisit(obj)
    let result = tracker.beginVisit(obj)

    switch result {
    case .firstVisit:
      Issue.record("Expected cycle detected, got first visit")
    case .cycleDetected(let refID):
      #expect(refID == 1)
    }
  }

  @Test("ObjectTracker assigns sequential IDs")
  func objectTrackerSequentialIDs() {
    var tracker = ObjectTracker()
    let obj1 = NSObject()
    let obj2 = NSObject()
    let obj3 = NSObject()

    let result1 = tracker.beginVisit(obj1)
    tracker.endVisit(obj1)
    let result2 = tracker.beginVisit(obj2)
    tracker.endVisit(obj2)
    let result3 = tracker.beginVisit(obj3)

    switch (result1, result2, result3) {
    case (.firstVisit(let id1), .firstVisit(let id2), .firstVisit(let id3)):
      #expect(id1 == 1)
      #expect(id2 == 2)
      #expect(id3 == 3)
    default:
      Issue.record("Expected sequential first visits")
    }
  }

  @Test("ObjectTracker allows revisit after endVisit")
  func objectTrackerRevisitAfterEnd() {
    var tracker = ObjectTracker()
    let obj = NSObject()

    _ = tracker.beginVisit(obj)
    tracker.endVisit(obj)
    let result = tracker.beginVisit(obj)

    switch result {
    case .cycleDetected:
      Issue.record("Should allow revisit after endVisit")
    case .firstVisit:
      break
    }
  }

  @Test("ObjectTracker cycle marker formatting")
  func cycleMarkerFormatting() {
    let marker = ObjectTracker.cycleMarker(referenceID: 42)
    #expect(marker.contains("42"))
    #expect(marker.contains("↩︎"))
  }

  @Test("ObjectTracker ID marker formatting")
  func idMarkerFormatting() {
    let marker = ObjectTracker.idMarker(assignedID: 7)
    #expect(marker == "#7")
  }

  // MARK: - DiffFormat Tests

  @Test("DiffFormat default uses ASCII characters")
  func diffFormatDefault() {
    let format = DiffFormat.default
    #expect(format.first == "-")
    #expect(format.second == "+")
    #expect(format.unchanged == " ")
  }

  @Test("DiffFormat proportional uses Unicode characters")
  func diffFormatProportional() {
    let format = DiffFormat.proportional
    #expect(format.first == "\u{2212}")
    #expect(format.second == "+")
    #expect(format.unchanged == "\u{2007}")
  }

  @Test("DiffFormat equality")
  func diffFormatEquality() {
    #expect(DiffFormat.default == DiffFormat.default)
    #expect(DiffFormat.proportional == DiffFormat.proportional)
    #expect(DiffFormat.default != DiffFormat.proportional)
  }

  // MARK: - StructuredDiff Render Tests

  @Test("StructuredDiff renders unchanged")
  func structuredDiffUnchanged() {
    let diff = StructuredDiff.unchanged("value")
    let result = diff.render(format: .default)
    #expect(result.contains("value"))
    #expect(result.hasPrefix(" "))
  }

  @Test("StructuredDiff renders changed")
  func structuredDiffChanged() {
    let diff = StructuredDiff.changed(old: "old", new: "new")
    let result = diff.render(format: .default)
    #expect(result.contains("- old"))
    #expect(result.contains("+ new"))
  }

  @Test("StructuredDiff renders added")
  func structuredDiffAdded() {
    let diff = StructuredDiff.added("new")
    let result = diff.render(format: .default)
    #expect(result.contains("+ new"))
  }

  @Test("StructuredDiff renders removed")
  func structuredDiffRemoved() {
    let diff = StructuredDiff.removed("old")
    let result = diff.render(format: .default)
    #expect(result.contains("- old"))
  }

  @Test("StructuredDiff renders collapsed")
  func structuredDiffCollapsed() {
    let diff = StructuredDiff.collapsed(unchangedCount: 5)
    let result = diff.render(format: .default)
    #expect(result.contains("5"))
    #expect(result.contains("unchanged"))
  }

  @Test("StructuredDiff renders with proportional format")
  func structuredDiffProportionalFormat() {
    let diff = StructuredDiff.changed(old: "old", new: "new")
    let result = diff.render(format: .proportional)
    #expect(result.contains("\u{2212} old"))
    #expect(result.contains("+ new"))
  }

  // MARK: - Array Diff with Collapse Tests

  @Test("Array diff collapses unchanged elements")
  func arrayDiffCollapseUnchanged() {
    let before = ["a", "b", "c", "d", "e", "f"]
    let after = ["a", "b", "c", "X", "e", "f"]

    let diff = before.diff(other: after, collapseUnchanged: true, collapseThreshold: 2)
    let rendered = diff.render(format: .default)

    #expect(rendered.contains("unchanged"))
    #expect(rendered.contains("d"))
    #expect(rendered.contains("X"))
  }

  @Test("Array diff without collapse shows all elements")
  func arrayDiffNoCollapse() {
    let before = ["a", "b", "c"]
    let after = ["a", "b", "X"]

    let diff = before.diff(other: after, collapseUnchanged: false, collapseThreshold: 0)
    let rendered = diff.render(format: .default)

    #expect(rendered.contains("a"))
    #expect(rendered.contains("b"))
    #expect(rendered.contains("c"))
    #expect(rendered.contains("X"))
  }

  @Test("Array diff handles additions")
  func arrayDiffAdditions() {
    let before = ["a", "b"]
    let after = ["a", "b", "c", "d"]

    let diff = before.diff(other: after, collapseUnchanged: false, collapseThreshold: 0)
    let rendered = diff.render(format: .default)

    #expect(rendered.contains("+ c"))
    #expect(rendered.contains("+ d"))
  }

  @Test("Array diff handles removals")
  func arrayDiffRemovals() {
    let before = ["a", "b", "c", "d"]
    let after = ["a", "b"]

    let diff = before.diff(other: after, collapseUnchanged: false, collapseThreshold: 0)
    let rendered = diff.render(format: .default)

    #expect(rendered.contains("- c"))
    #expect(rendered.contains("- d"))
  }

  // MARK: - Dictionary Deterministic Output Tests

  @Test("Dictionary output is deterministic")
  func dictionaryDeterministicOutput() {
    let dict = ["zebra": 1, "apple": 2, "mango": 3]
    let printer = PrettyPrinter(config: .testOutput)

    let output1 = printer.print(dict)
    let output2 = printer.print(dict)

    #expect(output1 == output2)
  }

  @Test("Dictionary keys are sorted alphabetically")
  func dictionaryKeysSorted() {
    let dict = ["zebra": 1, "apple": 2, "mango": 3]
    let printer = PrettyPrinter(config: .testOutput)

    let output = printer.print(dict)

    guard let appleRange = output.range(of: "apple"),
      let mangoRange = output.range(of: "mango"),
      let zebraRange = output.range(of: "zebra")
    else {
      Issue.record("Could not find all keys in output")
      return
    }

    #expect(appleRange.lowerBound < mangoRange.lowerBound)
    #expect(mangoRange.lowerBound < zebraRange.lowerBound)
  }

  // MARK: - PrettyPrinter Diff Tests

  @Test("PrettyPrinter diff includes format markers")
  func prettyPrinterDiffFormat() {
    let printer = PrettyPrinter(config: .testOutput)
    let diff = printer.diff(title: "Test", old: "old", new: "new", format: .default)

    #expect(diff.contains("Diff: Test"))
    #expect(diff.contains("-") || diff.contains("old"))
    #expect(diff.contains("+") || diff.contains("new"))
  }

  @Test("PrettyPrinter diffAny returns nil for equal values")
  func prettyPrinterDiffAnyEqual() {
    let printer = PrettyPrinter(config: .testOutput)
    let result = printer.diffAny(title: "Test", old: 42, new: 42)

    #expect(result == nil)
  }

  @Test("PrettyPrinter diffAny returns diff for different values")
  func prettyPrinterDiffAnyDifferent() {
    let printer = PrettyPrinter(config: .testOutput)
    let result = printer.diffAny(title: "Test", old: 42, new: 43)

    #expect(result != nil)
    #expect(result?.contains("42") == true)
    #expect(result?.contains("43") == true)
  }
}

@Suite("ExpectDifference Tests")
struct ExpectDifferenceTests {

  @Test("expectNoDifference passes for equal values")
  func expectNoDifferenceEqual() {
    expectNoDifference(42, 42)
    expectNoDifference("hello", "hello")
    expectNoDifference([1, 2, 3], [1, 2, 3])
  }

  @Test("expectDifference passes when changes match")
  func expectDifferenceMatchingChanges() {
    var value = 0
    expectDifference(value) {
      value = 1
    } changes: {
      $0 = 1
    }
  }

  @Test("expectDifference with array changes")
  func expectDifferenceArrayChanges() {
    var arr = [1, 2, 3]
    expectDifference(arr) {
      arr.append(4)
    } changes: {
      $0 = [1, 2, 3, 4]
    }
  }
}
