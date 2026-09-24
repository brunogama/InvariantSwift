import Foundation
import InvariantSwiftExpansionSupport

extension TestCodeGenerator {
  func analyzeDictionaryType(_ type: String) -> GeneratorTemplateResult? {
    let parts: (String, String)?
    if type.hasPrefix("[") && type.hasSuffix("]") {
      parts = splitDictionary(String(type.dropFirst().dropLast()), separator: ":")
    } else if type.hasPrefix("Dictionary<") && type.hasSuffix(">") {
      parts = splitDictionary(String(type.dropFirst(11).dropLast()), separator: ",")
    } else {
      return nil
    }

    guard let (key, value) = parts,
      Self.knownDictionaryKeyTypes.contains(key),
      case .success(let keyGenerator) = generatorTemplateResult(for: key),
      case .success(let valueGenerator) = generatorTemplateResult(for: value)
    else {
      return .todoRequired(
        typeName: type,
        reason: "Dictionary key and value need supported generators"
      )
    }

    return .success(
      .variable("Gen<[\(key): \(value)]>").method(
        "dictionary",
        arguments: [.unlabeled(keyGenerator), .unlabeled(valueGenerator)]
      )
    )
  }

  private static let knownDictionaryKeyTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Bool", "String", "Character", "UUID",
  ]
}

private func splitDictionary(_ contents: String, separator: Character) -> (String, String)? {
  var depth = 0
  for index in contents.indices {
    switch contents[index] {
    case "[", "<": depth += 1
    case "]", ">": depth -= 1
    default: break
    }
    guard depth == 0 && contents[index] == separator else { continue }
    let key = String(contents[..<index]).trimmingCharacters(in: .whitespaces)
    let value = String(contents[contents.index(after: index)...])
      .trimmingCharacters(in: .whitespaces)
    return key.isEmpty || value.isEmpty ? nil : (key, value)
  }
  return nil
}
