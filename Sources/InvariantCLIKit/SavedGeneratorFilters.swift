import Foundation

extension GeneratorCatalogCommand {
  func saveFilter(name: String, query: String) -> Int32 {
    do {
      try filterStore.save(name: name, query: query)
      output.writeStandardOutput("Saved filter '\(name)' for '\(query)'.\n")
      return 0
    } catch {
      return reportFilterError(error)
    }
  }

  func listFilters() -> Int32 {
    do {
      let filters = try filterStore.load()
      guard !filters.isEmpty else {
        output.writeStandardOutput("No saved filters.\n")
        return 0
      }
      let entries = filters.sorted { $0.key < $1.key }.map { "  \($0.key): \($0.value)" }
      output.writeStandardOutput((["Saved filters:"] + entries).joined(separator: "\n") + "\n")
      return 0
    } catch {
      return reportFilterError(error)
    }
  }

  func searchFilter(_ name: String) -> Int32 {
    do {
      guard let query = try filterStore.load()[name] else {
        return reportFilterError(SavedFilterError.unknownName(name))
      }
      output.writeStandardOutput(search(query))
      return 0
    } catch {
      return reportFilterError(error)
    }
  }

  func deleteFilter(_ name: String) -> Int32 {
    do {
      try filterStore.delete(name: name)
      output.writeStandardOutput("Deleted filter '\(name)'.\n")
      return 0
    } catch {
      return reportFilterError(error)
    }
  }

  func runInteractiveFilterCommand(command: String, value: String) -> Int32 {
    let arguments: [String]
    if command == "save-filter" {
      let values = value.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
      arguments = ["generators", "--save-filter"] + values
    } else {
      arguments = ["generators", "--\(command)"] + (value.isEmpty ? [] : [value])
    }
    let parsed = InvariantCommandParser.parse(arguments)
    if let error = parsed.error {
      output.writeStandardError("error: \(error)\n")
      return 2
    }
    guard case .generators(let action) = parsed.command else { return 2 }
    return run(action)
  }

  private var filterStore: SavedGeneratorFilters {
    SavedGeneratorFilters(currentDirectory: currentDirectory)
  }

  private func reportFilterError(_ error: Error) -> Int32 {
    output.writeStandardError("error: \(error.localizedDescription)\n")
    return 1
  }
}

private struct SavedGeneratorFilters {
  let currentDirectory: String

  private var directory: URL {
    URL(fileURLWithPath: currentDirectory, isDirectory: true)
      .appendingPathComponent(".invariant", isDirectory: true)
  }

  private var file: URL { directory.appendingPathComponent("saved-filters.json") }

  func load() throws -> [String: String] {
    guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
    let data: Data
    do {
      data = try Data(contentsOf: file)
    } catch {
      throw SavedFilterError.readFailed(file.path, error.localizedDescription)
    }
    let filters: [String: String]
    do {
      filters = try JSONDecoder().decode([String: String].self, from: data)
    } catch {
      throw SavedFilterError.invalidData(file.path)
    }
    guard filters.allSatisfy({ valid(name: $0.key, query: $0.value) }) else {
      throw SavedFilterError.invalidData(file.path)
    }
    return filters
  }

  func save(name: String, query: String) throws {
    var filters = try load()
    filters[name] = query
    try write(filters)
  }

  func delete(name: String) throws {
    var filters = try load()
    guard filters.removeValue(forKey: name) != nil else {
      throw SavedFilterError.unknownName(name)
    }
    try write(filters)
  }

  private func write(_ filters: [String: String]) throws {
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      var data = try encoder.encode(filters)
      data.append(contentsOf: [0x0A])
      try data.write(to: file, options: .atomic)
    } catch {
      throw SavedFilterError.writeFailed(file.path, error.localizedDescription)
    }
  }

  private func valid(name: String, query: String) -> Bool {
    !name.isEmpty && !name.contains(where: \.isWhitespace)
      && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

private enum SavedFilterError: LocalizedError {
  case unknownName(String)
  case invalidData(String)
  case readFailed(String, String)
  case writeFailed(String, String)

  var errorDescription: String? {
    switch self {
    case .unknownName(let name): "unknown saved filter '\(name)'"
    case .invalidData(let path): "invalid saved filters at '\(path)'"
    case .readFailed(let path, let detail): "failed to read '\(path)': \(detail)"
    case .writeFailed(let path, let detail): "failed to write '\(path)': \(detail)"
    }
  }
}
