import Foundation

struct MacroRuntimeFixturePackage {
  let directory: URL
  let attachmentsDirectory: URL
  let temporaryDirectory: URL
}

struct MacroRuntimeFixtureResult {
  let terminationStatus: Int32
  let output: String
}

enum MacroRuntimeFixtureSupport {
  /// Whether this toolchain's `swift test` accepts `--attachments-path`.
  ///
  /// Not every toolchain does: the CI runners' Swift 6.2.4 rejects it, and passing it
  /// anyway makes the fixture exit 64 with "Unknown option '--attachments-path'", which
  /// looks like the macro failing rather than the flag being absent. Asked of the
  /// toolchain once rather than inferred from a version number.
  static let supportsAttachmentsPath: Bool = {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "test", "--help"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    do {
      try process.run()
    } catch {
      return false
    }
    // Drain before waiting: --help outruns the pipe buffer on some toolchains.
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(data: data, encoding: .utf8)?.contains("--attachments-path") ?? false
  }()

  static func makePackage(source: String) throws -> MacroRuntimeFixturePackage {
    let packageDirectory = try repositoryRoot()
      .appendingPathComponent(".build/macro-runtime-fixtures")
      .appendingPathComponent("invariantswift-macro-fixture-\(UUID().uuidString)")
    let testsDirectory = packageDirectory.appendingPathComponent("Tests/FixtureTests")
    let attachmentsDirectory = packageDirectory.appendingPathComponent("Attachments")
    let temporaryDirectory = packageDirectory.appendingPathComponent("tmp")

    try FileManager.default.createDirectory(
      at: testsDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: attachmentsDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )

    try packageManifest().write(
      to: packageDirectory.appendingPathComponent("Package.swift"),
      atomically: true,
      encoding: .utf8
    )
    try source.write(
      to: testsDirectory.appendingPathComponent("FixtureTests.swift"),
      atomically: true,
      encoding: .utf8
    )

    return MacroRuntimeFixturePackage(
      directory: packageDirectory,
      attachmentsDirectory: attachmentsDirectory,
      temporaryDirectory: temporaryDirectory
    )
  }

  static func runTests(
    in package: MacroRuntimeFixturePackage
  ) throws -> MacroRuntimeFixtureResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    var environment = ProcessInfo.processInfo.environment
    environment["TMPDIR"] = package.temporaryDirectory.path + "/"
    process.environment = environment
    var arguments = [
      "swift",
      "test",
      "--package-path",
      package.directory.path,
    ]
    if supportsAttachmentsPath {
      arguments += ["--attachments-path", package.attachmentsDirectory.path]
    }
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    // `@unchecked Sendable`: all mutable state (`storage`) is protected by
    // `lock` (NSLock). The type crosses into the `readabilityHandler` closure
    // (a @Sendable context) only via the immutable `collected` binding.
    // Every read and write to `storage` is serialised through `lock.withLock`.
    final class LockedData: @unchecked Sendable {
      private let lock = NSLock()
      private var storage = Data()
      func append(_ chunk: Data) { lock.withLock { storage.append(chunk) } }
      var data: Data { lock.withLock { storage } }
    }
    let collected = LockedData()
    pipe.fileHandleForReading.readabilityHandler = { handle in
      collected.append(handle.availableData)
    }

    try process.run()
    process.waitUntilExit()

    pipe.fileHandleForReading.readabilityHandler = nil
    let trailing = pipe.fileHandleForReading.readDataToEndOfFile()
    if !trailing.isEmpty {
      collected.append(trailing)
    }

    let output = String(data: collected.data, encoding: .utf8) ?? ""

    return MacroRuntimeFixtureResult(
      terminationStatus: process.terminationStatus,
      output: output
    )
  }

  static func attachmentFileNames(in attachmentsDirectory: URL) throws -> Set<String> {
    let enumerator = FileManager.default.enumerator(
      at: attachmentsDirectory,
      includingPropertiesForKeys: nil
    )

    var fileNames = Set<String>()
    while let url = enumerator?.nextObject() as? URL {
      fileNames.insert(url.lastPathComponent)
    }

    return fileNames
  }

  private static func packageManifest() throws -> String {
    let repoRoot = try repositoryRoot()

    // The fixture resolves in its own scratch directory, so on its own it would
    // re-fetch every transitive dependency of the repository (swift-syntax and
    // friends) from the network or the SwiftPM cache, and a stale cache has
    // failed resolution on CI. The parent `swift test` has already checked those
    // dependencies out at exactly the versions it resolved, and a root package
    // may override a transitive dependency by declaring a path dependency with
    // the same identity, so point the fixture at those checkouts. When there are
    // none (a build that did not go through SwiftPM), resolution proceeds as
    // before.
    let checkoutOverrides = checkedOutDependencies(under: repoRoot)
      .map { "    .package(path: \"\($0.path)\"),\n" }
      .joined()

    // 6.0, as every manifest in this repository declares, and nothing here needs
    // more. A tools version is a floor on the toolchain that may build the package,
    // so 6.2 meant the fixture refused to build wherever `swift` was older than
    // that: on CI, where it is 6.1, every fixture failed with "is using Swift tools
    // version 6.2.0 but the installed version is 6.1.0".
    return """
      // swift-tools-version: 6.0
      import PackageDescription

      let package = Package(
        name: "MacroRuntimeFixture",
        platforms: [.macOS(.v14)],
        dependencies: [
          // `name:` pins the package name the targets below refer to. Without
          // it SwiftPM derives the name from the directory, which is only
          // "InvariantSwift" when the checkout happens to be called that.
          .package(name: "InvariantSwift", path: "\(repoRoot.path)"),
      \(checkoutOverrides)  ],
        targets: [
          .testTarget(
            name: "FixtureTests",
            dependencies: [
              .product(name: "InvariantSwiftTesting", package: "InvariantSwift"),
              .product(name: "InvariantSwiftMacroAPI", package: "InvariantSwift")
            ],
            path: "Tests/FixtureTests"
          )
        ]
      )
      """
  }

  /// The dependency checkouts the parent SwiftPM build has already fetched.
  ///
  /// SwiftPM derives a path dependency's identity from the directory name,
  /// which for a checkout is the repository name, so each of these matches the
  /// identity of the URL dependency it overrides.
  private static func checkedOutDependencies(under repoRoot: URL) -> [URL] {
    let checkouts = repoRoot.appendingPathComponent(".build/checkouts")
    let fileManager = FileManager.default
    guard
      let entries = try? fileManager.contentsOfDirectory(
        at: checkouts,
        includingPropertiesForKeys: [.isDirectoryKey]
      )
    else {
      return []
    }

    return
      entries
      .filter { fileManager.fileExists(atPath: $0.appendingPathComponent("Package.swift").path) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  private static func repositoryRoot() throws -> URL {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    while true {
      if isRepositoryRoot(directory) {
        return directory
      }

      let parent = directory.deletingLastPathComponent()
      guard parent.path != directory.path else {
        break
      }
      directory = parent
    }

    throw MacroRuntimeFixtureError.repositoryRootNotFound
  }

  private static func isRepositoryRoot(_ directory: URL) -> Bool {
    let fileManager = FileManager.default
    let packageManifest = directory.appendingPathComponent("Package.swift").path
    let testingIntegrationSources =
      directory
      .appendingPathComponent("Sources/InvariantSwiftTestingIntegration").path

    return fileManager.fileExists(atPath: packageManifest)
      && fileManager.fileExists(atPath: testingIntegrationSources)
  }
}

enum MacroRuntimeFixtureError: Error {
  case repositoryRootNotFound
}
