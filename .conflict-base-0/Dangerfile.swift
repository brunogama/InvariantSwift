import Danger

let danger = Danger()

// MARK: - PR Metadata Checks

// Warn if PR is too large
let bigPRThreshold = 500
let additions = danger.github.pullRequest.additions ?? 0
let deletions = danger.github.pullRequest.deletions ?? 0
if additions + deletions > bigPRThreshold {
  warn(
    "This PR is quite large (\(additions + deletions) lines). Consider breaking it into smaller PRs for easier review."
  )
}

// Warn if PR has no description
if let body = danger.github.pullRequest.body, body.isEmpty {
  warn("Please provide a description for this PR.")
} else if danger.github.pullRequest.body == nil {
  warn("Please provide a description for this PR.")
}

// Encourage linking issues
if let body = danger.github.pullRequest.body,
  !body.contains("#") && !body.lowercased().contains("fixes")
    && !body.lowercased().contains("closes")
{
  message("Consider linking related issues using `Fixes #123` or `Closes #123`.")
}

// MARK: - File Change Checks

let modifiedFiles = danger.git.modifiedFiles
let createdFiles = danger.git.createdFiles
let allChangedFiles = modifiedFiles + createdFiles

// Check for changes to critical files
let criticalFiles = ["Package.swift", "Package.resolved"]
let changedCriticalFiles = allChangedFiles.filter { criticalFiles.contains($0) }
if !changedCriticalFiles.isEmpty {
  message("📦 Dependencies changed: \(changedCriticalFiles.joined(separator: ", "))")
}

// Warn if Source files changed without corresponding test changes
let sourceChanges = allChangedFiles.filter { $0.hasPrefix("Sources/") && $0.hasSuffix(".swift") }
let testChanges = allChangedFiles.filter { $0.hasPrefix("Tests/") && $0.hasSuffix(".swift") }

if !sourceChanges.isEmpty && testChanges.isEmpty {
  warn("Source files were modified but no test files were changed. Please add or update tests.")
}

// MARK: - Code Quality Checks

// Check for debugging artifacts
for file in allChangedFiles where file.hasSuffix(".swift") {
  guard let diff = try? danger.utils.readFile(file) else { continue }

  if diff.contains("print(") || diff.contains("debugPrint(") {
    warn("Found `print` or `debugPrint` in \(file). Consider removing debugging statements.")
  }

  if diff.contains("TODO:") || diff.contains("FIXME:") {
    message("Found TODO/FIXME in \(file). Make sure to address or track these.")
  }

  if diff.contains("fatalError(") && !file.contains("Test") {
    warn("Found `fatalError` in \(file). Consider using proper error handling.")
  }
}

// MARK: - Changelog Check

if !modifiedFiles.contains("CHANGELOG.md") && !sourceChanges.isEmpty {
  warn("Please update CHANGELOG.md with a description of this change.")
}

// MARK: - Summary

message("Thanks for the contribution! 🎉")
