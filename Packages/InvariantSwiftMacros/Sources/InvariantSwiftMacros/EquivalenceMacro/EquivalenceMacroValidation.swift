import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - ValidatedEquivalenceParameters

/// The two implementations `@Equivalence` compares, once they are known to be usable.
///
/// `refFuncType` is the reference parameter's closure type with any attributes stripped.
/// Everything the generated test needs to know about inputs, effects and the compared
/// output type is read from it, so the candidate only has to be a function type as well.
struct ValidatedEquivalenceParameters {
  let reference: ExtractedParameter
  let candidate: ExtractedParameter
  let refFuncType: FunctionTypeSyntax
}

// MARK: - Validation

extension EquivalenceMacro {

  /// The two compared parameters, or `nil` once a diagnostic has been emitted.
  static func validatedParameters(
    of funcDecl: FunctionDeclSyntax,
    in context: some MacroExpansionContext
  ) -> ValidatedEquivalenceParameters? {
    let parameterClause = funcDecl.signature.parameterClause
    let parameters = ParameterExtractor.extract(from: funcDecl)

    guard parameters.count == 2 else {
      context.diagnose(
        Diagnostic(
          node: parameterClause,
          message: EquivalenceDiagnostic.requiresTwoFunctionParameters
        )
      )
      return nil
    }

    // The generated test is a peer of the annotated function, not a nested declaration,
    // so it cannot see the function's generic parameters.
    if let genericClause = funcDecl.genericParameterClause {
      context.diagnose(
        Diagnostic(
          node: genericClause,
          message: EquivalenceDiagnostic.genericFunctionUnsupported
        )
      )
      return nil
    }

    let refParam = parameters[0]
    let candParam = parameters[1]

    // Both parameters should be function types. `@escaping (Int) -> Int` is an
    // AttributedTypeSyntax around the function type, so the attributes come off first;
    // without that this rejected every escaping closure parameter, which is what the
    // documented form of this macro uses.
    guard let refFuncType = TypeAnalyzer.unattributed(refParam.type).as(FunctionTypeSyntax.self),
      let candFuncType = TypeAnalyzer.unattributed(candParam.type).as(FunctionTypeSyntax.self)
    else {
      context.diagnose(
        Diagnostic(
          node: parameterClause,
          message: EquivalenceDiagnostic.incompatibleFunctionTypes
        )
      )
      return nil
    }

    // The generated test calls both implementations identically, deriving inputs and
    // effects from the reference alone. A candidate that differs would be called with the
    // wrong arity, or without the `try`/`await` its own type requires, so the mismatch
    // has to be rejected here rather than surface as an error in generated code.
    guard refFuncType.trimmedDescription == candFuncType.trimmedDescription else {
      context.diagnose(
        Diagnostic(node: parameterClause, message: EquivalenceDiagnostic.signatureMismatch)
      )
      return nil
    }

    guard validateInputs(of: refFuncType, at: parameterClause, in: context) else { return nil }

    // Comparing two Void results is `() == ()`, which holds whatever the implementations
    // did, so the generated test could never fail.
    guard !TypeAnalyzer.isVoid(refFuncType.returnClause.type) else {
      context.diagnose(
        Diagnostic(node: parameterClause, message: EquivalenceDiagnostic.voidOutputNotComparable)
      )
      return nil
    }

    // The generated test is a peer, so the annotated function's parameters are not in
    // scope inside it. The implementations to compare therefore have to be named
    // somewhere the peer can see, which is what the parameters' default values are for.
    guard refParam.defaultValue != nil, candParam.defaultValue != nil else {
      context.diagnose(
        Diagnostic(
          node: parameterClause,
          message: EquivalenceDiagnostic.requiresDefaultImplementations
        )
      )
      return nil
    }

    return ValidatedEquivalenceParameters(
      reference: refParam,
      candidate: candParam,
      refFuncType: refFuncType
    )
  }

  /// Bounds the input arity to what input generation can actually express.
  private static func validateInputs(
    of refFuncType: FunctionTypeSyntax,
    at parameterClause: FunctionParameterClauseSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    let inputCount = refFuncType.parameters.count

    // With no input there is nothing to generate, and `Gen.zip()` does not exist.
    guard inputCount > 0 else {
      context.diagnose(
        Diagnostic(node: parameterClause, message: EquivalenceDiagnostic.requiresInputParameters)
      )
      return false
    }

    // Gen.zip is defined for two and three generators only.
    guard inputCount <= 3 else {
      context.diagnose(
        Diagnostic(node: parameterClause, message: EquivalenceDiagnostic.tooManyInputParameters)
      )
      return false
    }

    return true
  }

  /// Rejects a `tolerance` applied to an output type that cannot use it.
  static func validateTolerance(
    _ config: EquivalenceMacroConfig,
    returnType: TypeSyntax,
    at node: AttributeSyntax,
    in context: some MacroExpansionContext
  ) -> Bool {
    guard config.tolerance != nil else { return true }

    let floatingPointTypes: Set<String> = ["Double", "Float", "Float16", "Float80", "CGFloat"]
    guard floatingPointTypes.contains(TypeAnalyzer.baseTypeName(from: returnType)) else {
      context.diagnose(
        Diagnostic(
          node: node,
          message: EquivalenceDiagnostic.toleranceRequiresBinaryFloatingPoint
        )
      )
      return false
    }

    return true
  }
}
