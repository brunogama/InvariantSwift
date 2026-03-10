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
        process.arguments = [
            "swift",
            "test",
            "--package-path",
            package.directory.path,
            "--attachments-path",
            package.attachmentsDirectory.path,
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        var collectedData = Data()
        let lock = NSLock()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            lock.withLock { collectedData.append(chunk) }
        }

        try process.run()
        process.waitUntilExit()

        pipe.fileHandleForReading.readabilityHandler = nil
        let trailing = pipe.fileHandleForReading.readDataToEndOfFile()
        lock.withLock { collectedData.append(trailing) }

        let output = String(data: collectedData, encoding: .utf8) ?? ""

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
        let repoRoot = try repositoryRoot().path

        return """
      // swift-tools-version: 6.2
      import PackageDescription

      let package = Package(
        name: "MacroRuntimeFixture",
        platforms: [.macOS(.v14)],
        dependencies: [
          .package(path: "\(repoRoot)")
        ],
        targets: [
          .testTarget(
            name: "FixtureTests",
            dependencies: [
              .product(name: "InvariantSwiftTesting", package: "InvariantSwift")
            ],
            path: "Tests/FixtureTests"
          )
        ]
      )
      """
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
