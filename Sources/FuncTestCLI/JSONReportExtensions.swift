import Foundation
import InvariantSwift
import InvariantSwiftCore

extension FuncTestCLI {
  static func saveJSONReport(
    result: PropertyResult<[Int]>,
    propertyName: String,
    durationMs: Int,
    config: PropertyConfig,
    path: String
  ) async {
    do {
      let report = RunReport.from(
        result,
        propertyName: propertyName,
        durationMs: durationMs,
        config: config
      )

      try report.writeJSON(to: path, prettyPrinted: true)
      print("✅ JSON report saved to: \(path)")
    } catch {
      print("❌ Failed to save JSON report: \(error)")
    }
  }

  static func saveJSONReportAggregate(
    results: [(name: String, result: PropertyResult<Any>, durationMs: Int)],
    config: PropertyConfig,
    path: String
  ) async {
    print("💾 Saving JSON reports to: \(path)")
    print("⚠️  Aggregate JSON reporting not yet fully implemented.")
    print("   Individual reports can be generated per property test.")
  }
}
