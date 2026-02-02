// MARK: - InvariantSwift Macro Utilities
//
// Re-exports all utility modules for convenient access.
// Import this file to get all utilities in one import.

@_exported import SwiftSyntax
@_exported import SwiftSyntaxBuilder

// MARK: - Public API Summary
//
// SyntaxFactory:
//   - identifier(_:), declRef(_:), memberAccess(base:member:)
//   - simpleType(_:), genericType(_:arguments:), optionalType(_:), arrayType(_:)
//   - intLiteral(_:), stringLiteral(_:), boolLiteral(_:), nilLiteral()
//
// FunctionCallBuilder:
//   - init(_:), init(type:member:), init(callee:)
//   - arg(_:), arg(_:_:), arg(_:int:), arg(_:string:), arg(_:bool:), arg(_:ref:)
//   - trailing(_:), build(), buildExpr()
//   - genZip(_:), genPure(_:), initCall(type:arguments:)
//
// ClosureBuilder:
//   - param(_:), params(_:)
//   - statement(_:), expr(_:), return(_:)
//   - build(), buildExpr()
//   - mapToInit(type:fields:), propertyAccess(_:)
//
// TypeAnalyzer:
//   - typeName(from:), baseTypeName(from:)
//   - isOptional(_:), unwrapOptional(_:)
//   - isArray(_:), arrayElementType(_:)
//   - isSet(_:), isDictionary(_:)
//   - genericArguments(_:)
//   - isPrimitive(_:), primitiveTypes
//
// ParameterExtractor:
//   - extract(from: FunctionDeclSyntax) -> [ExtractedParameter]
//   - findAttribute(named:in:), hasGenAttribute(_:)
//
// FieldExtractor:
//   - extract(from: StructDeclSyntax) -> [ExtractedField]
//
// EnumCaseExtractor:
//   - extract(from: EnumDeclSyntax) -> [ExtractedEnumCase]
//
// GeneratorBuilder:
//   - primitive(_:) -> ExprSyntax?
//   - optional(_:), array(_:), set(_:), dictionary(keys:values:)
//   - zip(_:), map(_:closure:)
//   - arbitraryRef(_:)
//   - infer(for:) -> ExprSyntax
//
// AttributeBuilder:
//   - arg(_:), arg(_:_:), arg(_:int:)
//   - build() -> AttributeSyntax
//   - test, testWithArguments(_:), availableAsync
//
// Diagnostics:
//   - PropertyMacroDiagnostic, ArbitraryMacroDiagnostic
//   - DiagnosticEmitter: error(_:at:), warning(_:at:)
