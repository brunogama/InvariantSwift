// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AdapterProbe",
  targets: [
    .executableTarget(name: "invariant-cli", path: "Sources/ProbeCLI"),
    .plugin(
      name: "InvariantSwiftPlugin",
      capability: .command(
        intent: .custom(verb: "invariant", description: "Probe invariant adapter"),
        permissions: [.writeToPackageDirectory(reason: "Exercise adapter contract")]
      ),
      dependencies: ["invariant-cli"],
      path: "Plugins/InvariantSwiftPlugin"
    ),
    .plugin(
      name: "GhostwriterPlugin",
      capability: .command(
        intent: .custom(verb: "ghostwrite", description: "Probe ghostwrite adapter"),
        permissions: [.writeToPackageDirectory(reason: "Exercise adapter contract")]
      ),
      dependencies: ["invariant-cli"],
      path: "Plugins/GhostwriterPlugin"
    ),
    .plugin(
      name: "GeneratorCatalogPlugin",
      capability: .command(
        intent: .custom(verb: "browse-generators", description: "Probe catalog adapter"),
        permissions: []
      ),
      dependencies: ["invariant-cli"],
      path: "Plugins/GeneratorCatalogPlugin"
    ),
  ]
)
