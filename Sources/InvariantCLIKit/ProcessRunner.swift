import Foundation

struct ProcessRequest: Equatable, Sendable {
  let executable: String
  let arguments: [String]
  let currentDirectory: String
  let environment: [String: String]
}

protocol ProcessRunning: Sendable {
  func run(_ request: ProcessRequest) async throws -> Int32
}

struct LiveProcessRunner: ProcessRunning {

  func run(_ request: ProcessRequest) async throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: request.executable)
    process.arguments = request.arguments
    process.currentDirectoryURL = URL(fileURLWithPath: request.currentDirectory)
    process.environment = request.environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
  }
}
