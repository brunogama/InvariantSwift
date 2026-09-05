import Foundation
import InvariantSwift
import Testing

struct PropertyRunRecord {
  let testName: String
  let seed: UInt64?
  let iterations: Int
  let outcome: String
  let reason: String
  let reproductionCommand: String?
}

private struct PropertyRunAttachment: Encodable {
  let testName: String
  let seed: UInt64?
  let iterations: Int
  let outcome: String
  let reason: String
  let file: String
  let line: Int
  let labels: [String]
  let reproductionCommand: String?
  let replayFailureID: String?
}

private func propertyRunJSON(
  for record: PropertyRunRecord,
  context: PropertyIssueContext
) -> String? {
  let attachment = PropertyRunAttachment(
    testName: record.testName,
    seed: record.seed,
    iterations: record.iterations,
    outcome: record.outcome,
    reason: record.reason,
    file: String(describing: context.file),
    line: Int(context.line),
    labels: context.labels,
    reproductionCommand: record.reproductionCommand,
    replayFailureID: context.replayFailureID?.uuidString
  )

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try? String(data: encoder.encode(attachment), encoding: .utf8)
}

func stringifyValue<T>(_ value: T) -> String {
  let printer = PrettyPrinter(config: .testOutput)

  if let printable = value as? PrettyPrintable {
    // swiftlint:disable:next no_print
    return printer.print(printable)
  }

  return String(describing: value)
}

func stringifyAttachment(_ value: String) -> String {
  value.hasSuffix("\n") ? value : value + "\n"
}

func recordAttachment(
  _ value: String,
  named name: String,
  location: Testing.SourceLocation
) {
  #if compiler(>=6.2)
  Testing.Attachment.record(value, named: name, sourceLocation: location)
  #else
  _ = (value, name, location)
  #endif
}

func recordRunJSON(
  _ record: PropertyRunRecord,
  context: PropertyIssueContext,
  location: Testing.SourceLocation
) {
  if let json = propertyRunJSON(for: record, context: context) {
    recordAttachment(json, named: "property-run.json", location: location)
  }
}
