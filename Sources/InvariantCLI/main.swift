import Foundation
import InvariantCLIKit

@main
struct InvariantCLIExecutable {
  static func main() async {
    let status = await InvariantCLI().run(arguments: Array(CommandLine.arguments.dropFirst()))
    if status != 0 {
      exit(status)
    }
  }
}
