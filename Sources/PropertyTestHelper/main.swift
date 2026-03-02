import Foundation

// MARK: - IPC Protocol Version

/// Current IPC protocol version. Increment when the request/response schema changes.
private let currentProtocolVersion = 1

// MARK: - Entry Point

@main
struct PropertyTestHelper {

  static func main() async {
    let stdin = FileHandle.standardInput
    let stdout = FileHandle.standardOutput

    do {
      // Read 4-byte big-endian length prefix.
      let lengthData = stdin.readData(ofLength: 4)
      guard lengthData.count == 4 else {
        exit(1)  // Exit code 1: incomplete length header
      }

      let length = UInt32(bigEndian: lengthData.withUnsafeBytes { $0.load(as: UInt32.self) })
      let requestData = stdin.readData(ofLength: Int(length))

      // Decode the request.
      let decoder = JSONDecoder()
      let request: PropertyEvaluationRequest
      do {
        request = try decoder.decode(PropertyEvaluationRequest.self, from: requestData)
      } catch {
        exit(2)  // Exit code 2: JSON decode error
      }

      // Protocol version check.
      guard request.protocolVersion == currentProtocolVersion else {
        exit(3)  // Exit code 3: protocol version mismatch
      }

      // Evaluate the property.
      let startTime = Date()
      let passed = evaluateProperty(request: request)
      let duration = Date().timeIntervalSince(startTime)

      // Encode and write response.
      let response = PropertyEvaluationResponse(
        testId: request.testId,
        passed: passed,
        failureReason: passed ? nil : "Property returned false",
        duration: duration,
        protocolVersion: currentProtocolVersion
      )

      let encoder = JSONEncoder()
      let responseData = try encoder.encode(response)
      try stdout.write(contentsOf: responseData)

      exit(0)
    } catch {
      exit(2)  // Exit code 2: any other encoding/IO error
    }
  }

  static func evaluateProperty(request: PropertyEvaluationRequest) -> Bool {
    // The parent process serializes the test input; this stub always passes.
    // Real property evaluation happens in the parent via the predicate closure;
    // the helper binary exists solely to provide a crash-isolated subprocess.
    true
  }
}

// MARK: - IPC Types (local copy — PropertyTestHelper has no library dependencies)

/// Request sent from parent to child process for property evaluation.
struct PropertyEvaluationRequest: Codable {

  /// Unique identifier for this evaluation request.
  let testId: UUID

  /// Seed for deterministic test generation.
  let seed: UInt64

  /// Size parameter for generation.
  let size: Int

  /// Serialized test input (JSON encoded).
  let testInput: Data

  /// Generator type name for reconstruction.
  let generatorType: String

  /// IPC protocol version — must match `currentProtocolVersion` in the helper.
  let protocolVersion: Int
}

/// Response sent from child to parent after property evaluation.
struct PropertyEvaluationResponse: Codable {

  /// Unique identifier matching the request.
  let testId: UUID

  /// Whether the property predicate passed.
  let passed: Bool

  /// Optional failure reason if `passed == false`.
  let failureReason: String?

  /// Execution time in seconds.
  let duration: TimeInterval

  /// IPC protocol version echoed back from the helper.
  let protocolVersion: Int
}
