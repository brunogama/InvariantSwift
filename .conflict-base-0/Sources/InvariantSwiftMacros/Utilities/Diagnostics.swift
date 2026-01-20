import SwiftDiagnostics

public enum PropertyMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.PropertyMacro"

  case mustBeFunction = "property_must_be_function"
  case noParameters = "property_no_parameters"
  case cannotInferGenerator = "property_cannot_infer_generator"
  case invalidIterations = "property_invalid_iterations"
  case invalidSeed = "property_invalid_seed"
  case closureParameter = "property_closure_parameter"
  case asyncMismatch = "property_async_mismatch"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeFunction:
      return "@Property can only be applied to functions"

    case .noParameters:
      return "@Property requires at least one parameter to generate test values"

    case .cannotInferGenerator:
      return
        "Cannot infer generator for this type. Add @Arbitrary to the type or use @Gen explicitly."

    case .invalidIterations:
      return "iterations must be a positive integer"

    case .invalidSeed:
      return "seed must be a UInt64 literal or nil"

    case .closureParameter:
      return "Closure parameters cannot be generated. Use @Gen to provide a custom generator."

    case .asyncMismatch:
      return "@Property on async function requires async test context"
    }
  }
}

public enum ArbitraryMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.ArbitraryMacro"

  case mustBeStructOrEnum = "arbitrary_must_be_struct_or_enum"
  case noStoredProperties = "arbitrary_no_stored_properties"
  case noEnumCases = "arbitrary_no_enum_cases"
  case cannotInferFieldGenerator = "arbitrary_cannot_infer_field_generator"
  case invalidConstraint = "arbitrary_invalid_constraint"
  case initParameterMismatch = "arbitrary_init_parameter_mismatch"
  case privateFieldAccess = "arbitrary_private_field_access"
  case recursiveType = "arbitrary_recursive_type"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeStructOrEnum:
      return "@Arbitrary can only be applied to structs or enums"

    case .noStoredProperties:
      return "@Arbitrary requires at least one stored property"

    case .noEnumCases:
      return "@Arbitrary requires at least one enum case"

    case .cannotInferFieldGenerator:
      return "Cannot infer generator for field type"

    case .invalidConstraint:
      return "Invalid constraint specification"

    case .initParameterMismatch:
      return
        // swiftlint:disable:next line_length
        "@Arbitrary requires stored property names to match init parameter labels. Use manual Generatable conformance for types with custom initializers."

    case .privateFieldAccess:
      return
        // swiftlint:disable:next line_length
        "@Arbitrary cannot generate values for types with private fields without a public memberwise init"

    case .recursiveType:
      return
        "@Arbitrary detected recursive type. Use manual Generatable conformance with Gen.recursive."
    }
  }
}
