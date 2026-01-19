import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Generator Expression Builder

/// Builds generator expressions for various types.
/// Maps Swift types to their corresponding Gen<T> expressions.
public enum GeneratorBuilder {

  // MARK: - Primitive Generators

  /// Returns the generator expression for a primitive type
  // swiftlint:disable:next cyclomatic_complexity
  public static func primitive(_ typeName: String) -> ExprSyntax? {
    switch typeName {
    case "Int":
      return genMemberAccess("Int", "int")

    case "Int8":
      return genMemberAccess("Int8", "int8")

    case "Int16":
      return genMemberAccess("Int16", "int16")

    case "Int32":
      return genMemberAccess("Int32", "int32")

    case "Int64":
      return genMemberAccess("Int64", "int64")

    case "UInt":
      return genMemberAccess("UInt", "uint")

    case "UInt8":
      return genMemberAccess("UInt8", "uint8")

    case "UInt16":
      return genMemberAccess("UInt16", "uint16")

    case "UInt32":
      return genMemberAccess("UInt32", "uint32")

    case "UInt64":
      return genMemberAccess("UInt64", "uint64")

    case "Bool":
      return genMemberAccess("Bool", "bool")

    case "Double":
      return genMemberAccess("Double", "double")

    case "Float":
      return genMemberAccess("Float", "float")

    case "String":
      return genMemberAccess("String", "string")

    case "Character":
      return genMemberAccess("Character", "letter")

    case "UUID":
      return genMemberAccess("UUID", "uuid")

    case "Date":
      return genMemberAccess("Date", "date")

    case "Data":
      return genMemberAccess("Data", "data")

    case "URL":
      return genMemberAccess("URL", "url")

    default:
      return nil
    }
  }

  /// Creates Gen<Type>.member expression
  private static func genMemberAccess(_ type: String, _ member: String) -> ExprSyntax {
    let typeNode = TypeSyntax(SyntaxFactory.simpleType(type))
    let genType = ExprSyntax(
      GenericSpecializationExprSyntax(
        expression: SyntaxFactory.declRef("Gen"),
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(argument: typeNode)
        }
      )
    )
    return ExprSyntax(SyntaxFactory.memberAccess(base: genType, member: member))
  }

  // MARK: - Composite Generators

  /// Creates Gen.optional(innerGen)
  public static func optional(_ innerGen: ExprSyntax) -> ExprSyntax {
    FunctionCallBuilder(type: "Gen", member: "optional")
      .arg(innerGen)
      .buildExpr()
  }

  /// Creates Gen.array(elementGen)
  public static func array(_ elementGen: ExprSyntax) -> ExprSyntax {
    FunctionCallBuilder(type: "Gen", member: "array")
      .arg(elementGen)
      .buildExpr()
  }

  /// Creates Gen.set(elementGen)
  public static func set(_ elementGen: ExprSyntax) -> ExprSyntax {
    FunctionCallBuilder(type: "Gen", member: "set")
      .arg(elementGen)
      .buildExpr()
  }

  /// Creates Gen.dictionary(keyGen, valueGen)
  public static func dictionary(keys keyGen: ExprSyntax, values valueGen: ExprSyntax) -> ExprSyntax
  {
    FunctionCallBuilder(type: "Gen", member: "dictionary")
      .arg(keyGen)
      .arg(valueGen)
      .buildExpr()
  }

  /// Creates Gen.zip(gen1, gen2, ...)
  public static func zip(_ generators: [ExprSyntax]) -> ExprSyntax {
    FunctionCallBuilder.genZip(generators).buildExpr()
  }

  /// Creates gen.map { ... }
  public static func map(_ gen: ExprSyntax, closure: ClosureExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: SyntaxFactory.memberAccess(base: gen, member: "map"),
        leftParen: nil,
        arguments: [],
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  /// Creates Type.arbitrary reference
  public static func arbitraryRef(_ typeName: String) -> ExprSyntax {
    ExprSyntax(SyntaxFactory.memberAccess(type: typeName, member: "arbitrary"))
  }

  // MARK: - Type-Based Generator Inference

  /// Infers the generator expression for a given type
  public static func infer(for type: TypeSyntax) -> ExprSyntax {
    // Check for Optional<T>
    if let wrapped = TypeAnalyzer.unwrapOptional(type) {
      let innerGen = infer(for: wrapped)
      return optional(innerGen)
    }

    // Check for Array<T> or [T]
    if let element = TypeAnalyzer.arrayElementType(type) {
      let elementGen = infer(for: element)
      return array(elementGen)
    }

    // Check for Set<T>
    if TypeAnalyzer.isSet(type) {
      let args = TypeAnalyzer.genericArguments(type)
      if let element = args.first {
        let elementGen = infer(for: element)
        return set(elementGen)
      }
    }

    // Check for Dictionary<K, V>
    if TypeAnalyzer.isDictionary(type) {
      let args = TypeAnalyzer.genericArguments(type)
      if args.count == 2 {
        let keyGen = infer(for: args[0])
        let valueGen = infer(for: args[1])
        return dictionary(keys: keyGen, values: valueGen)
      }
    }

    // Check for primitive type
    let baseName = TypeAnalyzer.baseTypeName(from: type)
    if let primitiveGen = primitive(baseName) {
      return primitiveGen
    }

    // Fall back to Type.arbitrary
    return arbitraryRef(baseName)
  }
}
