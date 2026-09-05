import Foundation
import InvariantSwiftCore

// MARK: - Entry Point

@main
enum PropertyTestHelper {

  static func main() async {
    let request = decodeRequest(from: readFramedRequestData())

    // Protocol version check.
    guard request.protocolVersion == PropertyEvaluationWireProtocol.version
    else {
      exit(3)  // Exit code 3: protocol version mismatch
    }

    writeResponse(evaluating: request)
    exit(0)
  }

  /// Reads the 4-byte big-endian length prefix and the framed payload.
  private static func readFramedRequestData() -> Data {
    let stdin = FileHandle.standardInput
    let lengthData = stdin.readData(ofLength: 4)
    guard lengthData.count == 4 else {
      exit(1)  // Exit code 1: incomplete length header
    }
    let length = UInt32(
      bigEndian: lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }
    )
    return stdin.readData(ofLength: Int(length))
  }

  private static func decodeRequest(
    from requestData: Data
  ) -> PropertyEvaluationRequest {
    do {
      return try JSONDecoder().decode(
        PropertyEvaluationRequest.self,
        from: requestData
      )
    } catch {
      exit(2)  // Exit code 2: JSON decode error
    }
  }

  private static func writeResponse(
    evaluating request: PropertyEvaluationRequest
  ) {
    let startTime = Date()
    let passed = evaluateProperty(request: request)
    let duration = Date().timeIntervalSince(startTime)

    let response = PropertyEvaluationResponse(
      testId: request.testId,
      passed: passed,
      duration: duration,
      failureReason: passed ? nil : "Property returned false"
    )

    do {
      let responseData = try JSONEncoder().encode(response)
      try FileHandle.standardOutput.write(contentsOf: responseData)
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
