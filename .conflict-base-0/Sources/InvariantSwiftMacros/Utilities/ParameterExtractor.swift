import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Parameter Extractor

/// Represents an extracted function parameter
public struct ExtractedParameter {
  public let name: String
  public let type: TypeSyntax
  public let isOptional: Bool
  public let hasDefaultValue: Bool
  public let attributes: [AttributeSyntax]

  public init(
    name: String,
    type: TypeSyntax,
    isOptional: Bool = false,
    hasDefaultValue: Bool = false,
    attributes: [AttributeSyntax] = []
  ) {
    self.name = name
    self.type = type
    self.isOptional = isOptional
    self.hasDefaultValue = hasDefaultValue
    self.attributes = attributes
  }
}

/// Extracts parameter information from function declarations
public enum ParameterExtractor {

  /// Extract all parameters from a function declaration
  public static func extract(from funcDecl: FunctionDeclSyntax) -> [ExtractedParameter] {
    let params = funcDecl.signature.parameterClause.parameters
    return params.compactMap { extract(from: $0) }
  }

  /// Extract a single parameter
  public static func extract(from param: FunctionParameterSyntax) -> ExtractedParameter? {
    // Get parameter name (internal name or label)
    let name: String
    if let secondName = param.secondName {
      name = secondName.text
    } else {
      name = param.firstName.text
    }

    // Skip underscore-only names
    guard name != "_" else { return nil }

    let type = param.type
    let isOptional = TypeAnalyzer.isOptional(type)
    let hasDefault = param.defaultValue != nil
    let attributes = param.attributes.compactMap { $0.as(AttributeSyntax.self) }

    return ExtractedParameter(
      name: name,
      type: type,
      isOptional: isOptional,
      hasDefaultValue: hasDefault,
      attributes: attributes
    )
  }

  /// Find a specific attribute on a parameter
  public static func findAttribute(
    named name: String,
    in param: ExtractedParameter
  ) -> AttributeSyntax? {
    param.attributes.first { attr in
      guard let identifier = attr.attributeName.as(IdentifierTypeSyntax.self) else {
        return false
      }
      return identifier.name.text == name
    }
  }

  /// Check if parameter has @Gen attribute
  public static func hasGenAttribute(_ param: ExtractedParameter) -> Bool {
    findAttribute(named: "Gen", in: param) != nil
  }

  /// Extract @Gen attribute arguments if present
  public static func extractGenAttribute(
    _ param: ExtractedParameter
  ) -> AttributeSyntax? {
    findAttribute(named: "Gen", in: param)
  }
}

// MARK: - Struct Field Extractor

/// Represents an extracted struct field
public struct ExtractedField {
  public let name: String
  public let type: TypeSyntax
  public let isVar: Bool
  public let isOptional: Bool
  public let hasInitializer: Bool

  public init(
    name: String,
    type: TypeSyntax,
    isVar: Bool = false,
    isOptional: Bool = false,
    hasInitializer: Bool = false
  ) {
    self.name = name
    self.type = type
    self.isVar = isVar
    self.isOptional = isOptional
    self.hasInitializer = hasInitializer
  }
}

/// Extracts field information from struct declarations
public enum FieldExtractor {

  /// Extract all stored properties from a struct
  public static func extract(from structDecl: StructDeclSyntax) -> [ExtractedField] {
    var fields: [ExtractedField] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }

      let isVar = varDecl.bindingSpecifier.tokenKind == .keyword(.var)

      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
          let typeAnnotation = binding.typeAnnotation
        else {
          continue
        }

        // Skip computed properties
        if binding.accessorBlock != nil {
          continue
        }

        let type = typeAnnotation.type
        fields.append(
          ExtractedField(
            name: pattern.identifier.text,
            type: type,
            isVar: isVar,
            isOptional: TypeAnalyzer.isOptional(type),
            hasInitializer: binding.initializer != nil
          )
        )
      }
    }

    return fields
  }
}

// MARK: - Enum Case Extractor

/// Represents an extracted enum case
public struct ExtractedEnumCase {
  public let name: String
  public let associatedValues: [ExtractedAssociatedValue]

  public var hasAssociatedValues: Bool {
    !associatedValues.isEmpty
  }
}

/// Represents an associated value in an enum case
public struct ExtractedAssociatedValue {
  public let label: String?
  public let type: TypeSyntax
}

/// Extracts case information from enum declarations
public enum EnumCaseExtractor {

  /// Extract all cases from an enum
  public static func extract(from enumDecl: EnumDeclSyntax) -> [ExtractedEnumCase] {
    var cases: [ExtractedEnumCase] = []

    for member in enumDecl.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        let associatedValues: [ExtractedAssociatedValue]

        if let params = element.parameterClause?.parameters {
          associatedValues = params.map { param in
            ExtractedAssociatedValue(
              label: param.firstName?.text,
              type: param.type
            )
          }
        } else {
          associatedValues = []
        }

        cases.append(
          ExtractedEnumCase(
            name: element.name.text,
            associatedValues: associatedValues
          )
        )
      }
    }

    return cases
  }
}
