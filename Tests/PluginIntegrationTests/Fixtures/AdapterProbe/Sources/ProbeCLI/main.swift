import Darwin
import Foundation

let environment = ProcessInfo.processInfo.environment
let arguments = CommandLine.arguments.dropFirst().joined(separator: "|")
let parentSentinel = environment["PARENT_SENTINEL"] ?? ""
let pluginMode = environment["FUNCTEST_PLUGIN_MODE"] ?? ""
let packagePath = environment["FUNCTEST_PACKAGE_PATH"] ?? ""
let packageName = environment["FUNCTEST_PACKAGE_NAME"] ?? ""
let values = [
  "arguments=\(arguments)",
  "cwd=\(FileManager.default.currentDirectoryPath)",
  "parent=\(parentSentinel)",
  "pluginMode=\(pluginMode)",
  "packagePath=\(packagePath)",
  "packageName=\(packageName)",
]
FileHandle.standardOutput.write(Data((values.joined(separator: "\n") + "\n").utf8))
if CommandLine.arguments.contains("--fail") { exit(23) }
