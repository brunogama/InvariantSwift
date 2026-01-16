import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Generator Inference

/// Complete type-to-generator mapping system.
/// Implements the type inference rules from the macro specification.
public enum GeneratorInference {

  // MARK: - Type Mapping Table

  /// Maps primitive type names to their generator member names
  private static let primitiveGenerators: [String: (type: String, member: String)] = [
    // Integer types
    "Int": ("Int", "int"),
    "Int8": ("Int8", "int"),
    "Int16": ("Int16", "int"),
    "Int32": ("Int32", "int"),
    "Int64": ("Int64", "int"),
    "UInt": ("UInt", "uint"),
    "UInt8": ("UInt8", "uint"),
    "UInt16": ("UInt16", "uint"),
    "UInt32": ("UInt32", "uint"),
    "UInt64": ("UInt64", "uint"),

    // Floating point
    "Double": ("Double", "double"),
    "Float": ("Float", "float"),

    // Boolean
    "Bool": ("Bool", "bool"),

    // String types
    "String": ("String", "string"),
    "Character": ("Character", "letter"),

    // Foundation types
    "UUID": ("UUID", "uuid"),
    "Date": ("Date", "date"),
    "Data": ("Data", "data"),
    "URL": ("URL", "url"),
  ]

  // MARK: - Public API

  /// Infers the generator expression for a given type syntax.
  ///
  /// Inference order:
  /// 1. Optional<T> -> Gen.optional(infer(T))
  /// 2. Array<T> or [T] -> Gen.array(infer(T))
  /// 3. Set<T> -> Gen.set(infer(T))
  /// 4. Dictionary<K,V> or [K:V] -> Gen.dictionary(infer(K), infer(V))
  /// 5. Result<Success, Failure> -> Gen.result(infer(Success), infer(Failure))
  /// 6. Primitive type -> Gen<Type>.member
  /// 7. Custom type -> Type.arbitrary
  public static func infer(for type: TypeSyntax) -> ExprSyntax {
    // 1. Handle Optional<T> or T?
    if let unwrapped = unwrapOptionalType(type) {
      let innerGen = infer(for: unwrapped)
      return buildOptionalGenerator(innerGen)
    }

    // 2. Handle Array<T> or [T]
    if let elementType = extractArrayElementType(type) {
      let elementGen = infer(for: elementType)
      return buildArrayGenerator(elementGen)
    }

    // 3. Handle Set<T>
    if let elementType = extractSetElementType(type) {
      let elementGen = infer(for: elementType)
      return buildSetGenerator(elementGen)
    }

    // 4. Handle Dictionary<K, V> or [K: V]
    if let (keyType, valueType) = extractDictionaryTypes(type) {
      let keyGen = infer(for: keyType)
      let valueGen = infer(for: valueType)
      return buildDictionaryGenerator(keyGen, valueGen)
    }

    // 5. Handle Result<Success, Failure>
    if let (successType, failureType) = extractResultTypes(type) {
      let successGen = infer(for: successType)
      let failureGen = infer(for: failureType)
      return buildResultGenerator(successGen, failureGen)
    }

    // 6. Check for primitive type
    let typeName = extractBaseTypeName(type)
    if let primitiveInfo = primitiveGenerators[typeName] {
      return buildPrimitiveGenerator(primitiveInfo.type, primitiveInfo.member)
    }

    // 7. Fall back to Type.arbitrary
    return buildArbitraryReference(typeName)
  }

  /// Checks if a type can be inferred (has a known generator)
  public static func canInfer(for type: TypeSyntax) -> Bool {
    // Optional, Array, Set, Dictionary, Result are always inferable if inner types are
    if unwrapOptionalType(type) != nil { return true }
    if extractArrayElementType(type) != nil { return true }
    if extractSetElementType(type) != nil { return true }
    if extractDictionaryTypes(type) != nil { return true }
    if extractResultTypes(type) != nil { return true }

    // Primitives are known
    let typeName = extractBaseTypeName(type)
    return primitiveGenerators[typeName] != nil
  }

  // MARK: - Type Unwrapping Helpers

  /// Unwraps Optional<T> or T? to get T
  private static func unwrapOptionalType(_ type: TypeSyntax) -> TypeSyntax? {
    // Check for T? syntax
    if let optional = type.as(OptionalTypeSyntax.self) {
      return optional.wrappedType
    }

    // Check for Optional<T> syntax
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Optional",
      let genericArgs = identifier.genericArgumentClause,
      let firstArg = genericArgs.arguments.first
    {
      return firstArg.argument
    }

    return nil
  }

  /// Extracts element type from Array<T> or [T]
  private static func extractArrayElementType(_ type: TypeSyntax) -> TypeSyntax? {
    // Check for [T] syntax
    if let array = type.as(ArrayTypeSyntax.self) {
      return array.element
    }

    // Check for Array<T> syntax
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Array",
      let genericArgs = identifier.genericArgumentClause,
      let firstArg = genericArgs.arguments.first
    {
      return firstArg.argument
    }

    return nil
  }

  /// Extracts element type from Set<T>
  private static func extractSetElementType(_ type: TypeSyntax) -> TypeSyntax? {
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Set",
      let genericArgs = identifier.genericArgumentClause,
      let firstArg = genericArgs.arguments.first
    {
      return firstArg.argument
    }
    return nil
  }

  /// Extracts key and value types from Dictionary<K, V> or [K: V]
  private static func extractDictionaryTypes(
    _ type: TypeSyntax
  ) -> (key: TypeSyntax, value: TypeSyntax)? {
    // Check for [K: V] syntax
    if let dict = type.as(DictionaryTypeSyntax.self) {
      return (dict.key, dict.value)
    }

    // Check for Dictionary<K, V> syntax
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Dictionary",
      let genericArgs = identifier.genericArgumentClause
    {
      let args = Array(genericArgs.arguments)
      if args.count == 2 {
        return (args[0].argument, args[1].argument)
      }
    }

    return nil
  }

  /// Extracts Success and Failure types from Result<Success, Failure>
  private static func extractResultTypes(
    _ type: TypeSyntax
  ) -> (success: TypeSyntax, failure: TypeSyntax)? {
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Result",
      let genericArgs = identifier.genericArgumentClause
    {
      let args = Array(genericArgs.arguments)
      if args.count == 2 {
        return (args[0].argument, args[1].argument)
      }
    }
    return nil
  }

  /// Extracts the base type name without generics or optionality
  private static func extractBaseTypeName(_ type: TypeSyntax) -> String {
    if let optional = type.as(OptionalTypeSyntax.self) {
      return extractBaseTypeName(optional.wrappedType)
    }
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return identifier.name.text
    }
    if type.is(ArrayTypeSyntax.self) {
      return "Array"
    }
    if type.is(DictionaryTypeSyntax.self) {
      return "Dictionary"
    }
    // For member types like Module.Type, get the last component
    if let member = type.as(MemberTypeSyntax.self) {
      return member.name.text
    }
    return type.trimmedDescription
  }

  // MARK: - Generator Expression Builders

  /// Builds Gen<Type>.member expression
  private static func buildPrimitiveGenerator(_ typeName: String, _ member: String) -> ExprSyntax {
    // Build Gen<Type>
    let genType = GenericSpecializationExprSyntax(
      expression: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
      genericArgumentClause: GenericArgumentClauseSyntax {
        GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier(typeName)))
      }
    )
    // Build Gen<Type>.member
    return ExprSyntax(
      MemberAccessExprSyntax(
        base: ExprSyntax(genType),
        declName: DeclReferenceExprSyntax(baseName: .identifier(member))
      )
    )
  }

  /// Builds Gen.optional(innerGen)
  private static func buildOptionalGenerator(_ inner: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("optional"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: inner)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds Gen.array(elementGen)
  private static func buildArrayGenerator(_ element: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("array"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: element)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds Gen.set(elementGen)
  private static func buildSetGenerator(_ element: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("set"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: element)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds Gen.dictionary(keyGen, valueGen)
  private static func buildDictionaryGenerator(_ key: ExprSyntax, _ value: ExprSyntax) -> ExprSyntax
  {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("dictionary"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: key)
          LabeledExprSyntax(expression: value)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds Gen.result(successGen, failureGen)
  private static func buildResultGenerator(
    _ success: ExprSyntax,
    _ failure: ExprSyntax
  ) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("result"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: success)
          LabeledExprSyntax(expression: failure)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  /// Builds Type.arbitrary reference
  private static func buildArbitraryReference(_ typeName: String) -> ExprSyntax {
    ExprSyntax(
      MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
        declName: DeclReferenceExprSyntax(baseName: .identifier("arbitrary"))
      )
    )
  }

  // MARK: - Shrink Inference

  /// Infers the shrink expression for a given type by accessing the generator's shrink property.
  /// Returns the expression to get the Shrink<T> for the type.
  public static func inferShrink(for type: TypeSyntax) -> ExprSyntax {
    let generatorExpr = infer(for: type)
    return ExprSyntax(
      MemberAccessExprSyntax(
        base: generatorExpr,
        declName: DeclReferenceExprSyntax(baseName: .identifier("shrink"))
      )
    )
  }
}
