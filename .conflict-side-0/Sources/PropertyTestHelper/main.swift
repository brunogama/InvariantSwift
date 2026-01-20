import Foundation

@main
struct PropertyTestHelper {
  static func main() async {
    let stdin = FileHandle.standardInput
    let stdout = FileHandle.standardOutput

    do {
      let lengthData = stdin.readData(ofLength: 4)
      guard lengthData.count == 4 else {
        exit(1)
      }

      let length = UInt32(bigEndian: lengthData.withUnsafeBytes { $0.load(as: UInt32.self) })
      let requestData = stdin.readData(ofLength: Int(length))

      let decoder = JSONDecoder()
      let request = try decoder.decode(PropertyEvaluationRequest.self, from: requestData)

      let startTime = Date()
      let passed = evaluateProperty(request: request)
      let duration = Date().timeIntervalSince(startTime)

      let response = PropertyEvaluationResponse(
        testId: request.testId,
        passed: passed,
        failureReason: passed ? nil : "Property returned false",
        duration: duration
      )

      let encoder = JSONEncoder()
      let responseData = try encoder.encode(response)
      try stdout.write(contentsOf: responseData)

      exit(0)
    } catch {
      exit(2)
    }
  }

  static func evaluateProperty(request: PropertyEvaluationRequest) -> Bool {
    true
  }
}

struct PropertyEvaluationRequest: Codable {
  let testId: UUID
  let seed: UInt64
  let size: Int
  let testInput: Data
  let generatorType: String
}

struct PropertyEvaluationResponse: Codable {
  let testId: UUID
  let passed: Bool
  let failureReason: String?
  let duration: TimeInterval
}
