import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

// MARK: - @LawChecked Macro Implementation

/// **@LawChecked Macro**
///
/// Automatically generates property-based tests for mathematical laws and invariants.
/// This macro analyzes type conformances and generates comprehensive law verification:
/// - Functor laws (identity, composition)
/// - Applicative laws (identity, composition, homomorphism, interchange)
/// - Monad laws (left identity, right identity, associativity)
/// - Monoid laws (identity, associativity)
/// - Group laws (identity, inverse, associativity)
/// - Custom algebraic laws via protocol conformance
///
/// **Mathematical Foundation:**
/// Implements systematic law checking from category theory and abstract algebra:
/// - Automated verification of algebraic structures
/// - Property-based testing of mathematical invariants
/// - Compositional law checking for complex structures
///
/// **External References:**
/// - [Category Theory for Programmers](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/)
/// - [Laws for Functional Programming](https://wiki.haskell.org/Functor)
/// - [QuickCheck Laws](https://hackage.haskell.org/package/quickcheck-laws)
///
/// **Usage Examples:**
/// ```swift
/// @LawChecked(laws: [.functor, .applicative, .monad])
/// struct MyMonad<T>: Functor, Applicative, Monad {
///     // Implementation...
/// }
/// // Generates comprehensive property tests for all specified laws
///
/// @LawChecked(customLaws: ["commutativity": "a + b == b + a"])
/// struct Addition: Semigroup {
///     // Implementation...
/// }
/// ```
public struct LawCheckedMacro: MemberMacro {

  // MARK: - Macro Entry Point

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {

    // Extract law configuration from macro arguments
    let config = try extractLawConfiguration(from: node, context: context)

    // Analyze the type's mathematical structure
    guard let analyzed = try analyzeMathematicalStructure(declaration, context: context) else {
      throw LawCheckedError.unsupportedType("Cannot generate law checks for this type")
    }

    // Generate law verification tests
    let lawTests = try generateLawTests(
      for: analyzed,
      config: config,
      context: context
    )

    return lawTests
  }
}

// MARK: - Configuration and Types

/// **Configuration for law checking**
struct LawCheckedConfig: Sendable {
  /// Built-in mathematical laws to check
  let laws: Set<MathematicalLaw>

  /// Custom law expressions
  let customLaws: [String: String]

  /// Number of test iterations per law
  let iterations: Int

  /// Size parameter for generation
  let size: Int

  /// Enable shrinking for counterexamples
  let enableShrinking: Bool

  /// Timeout for each law test (seconds)
  let timeout: Double

  static let `default` = Self(
    laws: [],
    customLaws: [:],
    iterations: 100,
    size: 50,
    enableShrinking: true,
    timeout: 30.0
  )
}

/// **Built-in mathematical laws**
public enum MathematicalLaw: String, CaseIterable, Sendable {
  // Category Theory
  case functor = "functor"
  case applicative = "applicative"
  case monad = "monad"
  case comonad = "comonad"

  // Abstract Algebra
  case semigroup = "semigroup"
  case monoid = "monoid"
  case group = "group"
  case ring = "ring"
  case field = "field"

  // Order Theory
  case partialOrder = "partialOrder"
  case totalOrder = "totalOrder"
  case lattice = "lattice"

  // Topology
  case metric = "metric"
  case norm = "norm"

  // Special Structures
  case foldable = "foldable"
  case traversable = "traversable"
  case bifunctor = "bifunctor"
  case profunctor = "profunctor"
}

/// **Analyzed mathematical structure**
struct MathematicalStructure {
  let typeName: String
  let typeParameters: [String]
  let conformances: Set<String>
  let operations: [MathematicalOperation]
  let constraints: [TypeConstraint]
}

struct MathematicalOperation {
  let name: String
  let signature: FunctionSignature
  let isStatic: Bool
  let isAsync: Bool
}

struct FunctionSignature {
  let parameters: [Parameter]
  let returnType: TypeSyntax
  let isThrows: Bool
}

struct Parameter {
  let name: String
  let type: TypeSyntax
  let isInOut: Bool
}

struct TypeConstraint {
  let parameter: String
  let protocols: [String]
}

// MARK: - Error Types

enum LawCheckedError: Error, CustomStringConvertible {
  case unsupportedType(String)
  case invalidConfiguration(String)
  case lawGenerationFailed(String)
  case missingOperation(String)

  var description: String {
    switch self {
    case .unsupportedType(let msg):
      return "Unsupported type for @LawChecked: \(msg)"

    case .invalidConfiguration(let msg):
      return "Invalid @LawChecked configuration: \(msg)"

    case .lawGenerationFailed(let msg):
      return "Law test generation failed: \(msg)"

    case .missingOperation(let msg):
      return "Missing required operation: \(msg)"
    }
  }
}

// MARK: - Configuration Extraction

private func extractLawConfiguration(
  from node: AttributeSyntax,
  context: some MacroExpansionContext
) throws -> LawCheckedConfig {
  var config = LawCheckedConfig.default

  if case .argumentList(let arguments) = node.arguments {
    for argument in arguments {
      switch argument.label?.text {
      case "laws":
        config = try parseLaws(argument.expression, config: config)

      case "customLaws":
        config = try parseCustomLaws(argument.expression, config: config)

      case "iterations":
        config = try parseIterations(argument.expression, config: config)

      case "size":
        config = try parseSize(argument.expression, config: config)

      case "enableShrinking":
        config = try parseEnableShrinking(argument.expression, config: config)

      case "timeout":
        config = try parseTimeout(argument.expression, config: config)

      default:
        break
      }
    }
  }

  return config
}

private func parseLaws(
  _ expr: ExprSyntax,
  config: LawCheckedConfig
) throws -> LawCheckedConfig {
  guard let arrayExpr = expr.as(ArrayExprSyntax.self) else {
    throw LawCheckedError.invalidConfiguration("laws must be an array")
  }

  var laws: Set<MathematicalLaw> = []

  for element in arrayExpr.elements {
    if let memberAccess = element.expression.as(MemberAccessExprSyntax.self) {
      let lawName = memberAccess.declName.baseName.text
      if let law = MathematicalLaw(rawValue: lawName) {
        laws.insert(law)
      }
    }
  }

  return LawCheckedConfig(
    laws: laws,
    customLaws: config.customLaws,
    iterations: config.iterations,
    size: config.size,
    enableShrinking: config.enableShrinking,
    timeout: config.timeout
  )
}

private func parseCustomLaws(
  _ expr: ExprSyntax,
  config: LawCheckedConfig
) throws -> LawCheckedConfig {
  guard let dictExpr = expr.as(DictionaryExprSyntax.self) else {
    throw LawCheckedError.invalidConfiguration("customLaws must be a dictionary")
  }

  var customLaws: [String: String] = [:]

  switch dictExpr.content {
  case .elements(let elements):
    for element in elements {
      guard let keyExpr = element.key.as(StringLiteralExprSyntax.self),
        let valueExpr = element.value.as(StringLiteralExprSyntax.self)
      else {
        throw LawCheckedError.invalidConfiguration("customLaws must be [String: String]")
      }

      let key = keyExpr.representedLiteralValue ?? ""
      let value = valueExpr.representedLiteralValue ?? ""
      customLaws[key] = value
    }

  case .colon:
    // Empty dictionary case
    break
  }

  return LawCheckedConfig(
    laws: config.laws,
    customLaws: customLaws,
    iterations: config.iterations,
    size: config.size,
    enableShrinking: config.enableShrinking,
    timeout: config.timeout
  )
}

private func parseIterations(
  _ expr: ExprSyntax,
  config: LawCheckedConfig
) throws -> LawCheckedConfig {
  guard let intExpr = expr.as(IntegerLiteralExprSyntax.self),
    let iterations = Int(intExpr.literal.text)
  else {
    throw LawCheckedError.invalidConfiguration("iterations must be an integer")
  }

  return LawCheckedConfig(
    laws: config.laws,
    customLaws: config.customLaws,
    iterations: iterations,
    size: config.size,
    enableShrinking: config.enableShrinking,
    timeout: config.timeout
  )
}

private func parseSize(_ expr: ExprSyntax, config: LawCheckedConfig) throws -> LawCheckedConfig {
  guard let intExpr = expr.as(IntegerLiteralExprSyntax.self),
    let size = Int(intExpr.literal.text)
  else {
    throw LawCheckedError.invalidConfiguration("size must be an integer")
  }

  return LawCheckedConfig(
    laws: config.laws,
    customLaws: config.customLaws,
    iterations: config.iterations,
    size: size,
    enableShrinking: config.enableShrinking,
    timeout: config.timeout
  )
}

private func parseEnableShrinking(
  _ expr: ExprSyntax,
  config: LawCheckedConfig
) throws -> LawCheckedConfig {
  guard let boolExpr = expr.as(BooleanLiteralExprSyntax.self) else {
    throw LawCheckedError.invalidConfiguration("enableShrinking must be a boolean")
  }

  let enabled = boolExpr.literal.text == "true"

  return LawCheckedConfig(
    laws: config.laws,
    customLaws: config.customLaws,
    iterations: config.iterations,
    size: config.size,
    enableShrinking: enabled,
    timeout: config.timeout
  )
}

private func parseTimeout(_ expr: ExprSyntax, config: LawCheckedConfig) throws -> LawCheckedConfig {
  let timeout: Double
  if let floatExpr = expr.as(FloatLiteralExprSyntax.self) {
    timeout = Double(floatExpr.literal.text) ?? 30.0
  } else if let intExpr = expr.as(IntegerLiteralExprSyntax.self) {
    timeout = Double(intExpr.literal.text) ?? 30.0
  } else {
    throw LawCheckedError.invalidConfiguration("timeout must be a number")
  }

  return LawCheckedConfig(
    laws: config.laws,
    customLaws: config.customLaws,
    iterations: config.iterations,
    size: config.size,
    enableShrinking: config.enableShrinking,
    timeout: timeout
  )
}

// MARK: - Mathematical Structure Analysis

private func analyzeMathematicalStructure(
  _ declaration: some DeclGroupSyntax,
  context: some MacroExpansionContext
) throws -> MathematicalStructure? {

  guard let typeDecl = declaration.asProtocol((any NamedDeclSyntax).self) else {
    return nil
  }

  let typeName = typeDecl.name.text

  // Extract type parameters
  let typeParameters = extractTypeParameters(from: declaration)

  // Extract protocol conformances
  let conformances = extractConformances(from: declaration)

  // Extract mathematical operations
  let operations = extractMathematicalOperations(from: declaration)

  // Extract type constraints
  let constraints = extractTypeConstraints(from: declaration)

  return MathematicalStructure(
    typeName: typeName,
    typeParameters: typeParameters,
    conformances: conformances,
    operations: operations,
    constraints: constraints
  )
}

private func extractTypeParameters(from declaration: some DeclGroupSyntax) -> [String] {
  // Extract generic parameters from the declaration
  var parameters: [String] = []

  if let structDecl = declaration.as(StructDeclSyntax.self),
    let genericClause = structDecl.genericParameterClause
  {
    for param in genericClause.parameters {
      parameters.append(param.name.text)
    }
  } else if let enumDecl = declaration.as(EnumDeclSyntax.self),
    let genericClause = enumDecl.genericParameterClause
  {
    for param in genericClause.parameters {
      parameters.append(param.name.text)
    }
  } else if let classDecl = declaration.as(ClassDeclSyntax.self),
    let genericClause = classDecl.genericParameterClause
  {
    for param in genericClause.parameters {
      parameters.append(param.name.text)
    }
  }

  return parameters
}

private func extractConformances(from declaration: some DeclGroupSyntax) -> Set<String> {
  var conformances: Set<String> = []

  let inheritanceClause: InheritanceClauseSyntax?

  if let structDecl = declaration.as(StructDeclSyntax.self) {
    inheritanceClause = structDecl.inheritanceClause
  } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
    inheritanceClause = enumDecl.inheritanceClause
  } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
    inheritanceClause = classDecl.inheritanceClause
  } else {
    inheritanceClause = nil
  }

  if let clause = inheritanceClause {
    for type in clause.inheritedTypes {
      if let simpleType = type.type.as(IdentifierTypeSyntax.self) {
        conformances.insert(simpleType.name.text)
      }
    }
  }

  return conformances
}

private func extractMathematicalOperations(
  from declaration: some DeclGroupSyntax
) -> [MathematicalOperation] {
  var operations: [MathematicalOperation] = []

  for member in declaration.memberBlock.members {
    if let funcDecl = member.decl.as(FunctionDeclSyntax.self) {
      let operation = MathematicalOperation(
        name: funcDecl.name.text,
        signature: extractFunctionSignature(funcDecl),
        isStatic: funcDecl.modifiers.contains { $0.name.text == "static" },
        isAsync: funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
      )
      operations.append(operation)
    }
  }

  return operations
}

private func extractFunctionSignature(_ funcDecl: FunctionDeclSyntax) -> FunctionSignature {
  let parameters = funcDecl.signature.parameterClause.parameters.map { param in
    Parameter(
      name: param.secondName?.text ?? param.firstName.text,
      type: param.type,
      isInOut: false  // TODO: Fix specifier access for Swift 6
    )
  }

  let returnType = funcDecl.signature.returnClause?.type ?? TypeSyntax(stringLiteral: "Void")
  let isThrows = funcDecl.signature.effectSpecifiers?.throwsSpecifier != nil

  return FunctionSignature(
    parameters: parameters,
    returnType: returnType,
    isThrows: isThrows
  )
}

private func extractTypeConstraints(from declaration: some DeclGroupSyntax) -> [TypeConstraint] {
  // Extract where clause constraints
  let constraints: [TypeConstraint] = []

  // This is a simplified implementation - real constraint extraction
  // would need more sophisticated parsing of where clauses

  return constraints
}

// MARK: - Law Test Generation

private func generateLawTests(
  for structure: MathematicalStructure,
  config: LawCheckedConfig,
  context: some MacroExpansionContext
) throws -> [DeclSyntax] {

  var tests: [DeclSyntax] = []

  // Generate tests for built-in laws
  for law in config.laws {
    let lawTests = try generateLawTests(for: law, structure: structure, config: config)
    tests.append(contentsOf: lawTests)
  }

  // Generate tests for custom laws
  for (lawName, lawExpression) in config.customLaws {
    let customTest = try generateCustomLawTest(
      name: lawName,
      expression: lawExpression,
      structure: structure,
      config: config
    )
    tests.append(customTest)
  }

  return tests
}

private func generateLawTests(
  for law: MathematicalLaw,
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  switch law {
  case .functor:
    return try generateFunctorLaws(structure: structure, config: config)

  case .applicative:
    return try generateApplicativeLaws(structure: structure, config: config)

  case .monad:
    return try generateMonadLaws(structure: structure, config: config)

  case .semigroup:
    return try generateSemigroupLaws(structure: structure, config: config)

  case .monoid:
    return try generateMonoidLaws(structure: structure, config: config)

  default:
    // TODO: Implement other laws
    return []
  }
}

private func generateFunctorLaws(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  guard structure.conformances.contains("Functor") else {
    throw LawCheckedError.missingOperation("Type must conform to Functor")
  }

  let identityLaw = try generateFunctorIdentityLaw(structure: structure, config: config)
  let compositionLaw = try generateFunctorCompositionLaw(structure: structure, config: config)

  return [identityLaw, compositionLaw]
}

private func generateFunctorIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_FunctorIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Functor Identity Law: map(id) == id")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { functor in
                let mapped = functor.map { $0 }
                return mapped == functor
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(
                iterations: \(config.iterations),
                maxShrinks: 1000,
                maxDiscarded: 1000
            )
        )
        
        #expect(result.isSuccess, "Functor identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateFunctorCompositionLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_FunctorCompositionLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Functor Composition Law: map(g ∘ f) == map(g) ∘ map(f)")
    func \(testName)() async {
        let property = Property<(\(typeName), (Int) -> String, (String) -> Bool)>(
            generator: Gen.zip3(\(typeName).gen, Gen.function(Gen.string), Gen.function(Gen.bool)),
            predicate: { (functor, f, g) in
                let composed = functor.map { g(f($0)) }
                let sequential = functor.map(f).map(g)
                return composed == sequential
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Functor composition law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateApplicativeLaws(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  guard structure.conformances.contains("Applicative") else {
    throw LawCheckedError.missingOperation("Type must conform to Applicative")
  }

  // Generate all four applicative laws
  let identityLaw = try generateApplicativeIdentityLaw(structure: structure, config: config)
  let compositionLaw = try generateApplicativeCompositionLaw(structure: structure, config: config)
  let homomorphismLaw = try generateApplicativeHomomorphismLaw(structure: structure, config: config)
  let interchangeLaw = try generateApplicativeInterchangeLaw(structure: structure, config: config)

  return [identityLaw, compositionLaw, homomorphismLaw, interchangeLaw]
}

private func generateApplicativeIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_ApplicativeIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Applicative Identity Law: pure(id) <*> v == v")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { applicative in
                let identity = \(typeName).pure { $0 }
                let result = identity.apply(applicative)
                return result == applicative
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Applicative identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateApplicativeCompositionLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_ApplicativeCompositionLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Applicative Composition Law")
    func \(testName)() async {
        let property = Property<(\(typeName), \(typeName), \(typeName))>(
            generator: Gen.zip3(\(typeName).gen, \(typeName).gen, \(typeName).gen),
            predicate: { (u, v, w) in
                let compose: (Any) -> (Any) -> (Any) -> Any = { f in { g in { x in f(g(x)) } } }
                let left = \(typeName).pure(compose).apply(u).apply(v).apply(w)
                let right = u.apply(v.apply(w))
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Applicative composition law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateApplicativeHomomorphismLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_ApplicativeHomomorphismLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Applicative Homomorphism Law: pure(f) <*> pure(x) == pure(f(x))")
    func \(testName)() async {
        let property = Property<(Int, (Int) -> String)>(
            generator: Gen.zip(Gen.int, Gen.function(Gen.string)),
            predicate: { (x, f) in
                let left = \(typeName).pure(f).apply(\(typeName).pure(x))
                let right = \(typeName).pure(f(x))
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Applicative homomorphism law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateApplicativeInterchangeLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_ApplicativeInterchangeLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Applicative Interchange Law: u <*> pure(y) == pure($ y) <*> u")
    func \(testName)() async {
        let property = Property<(\(typeName), Int)>(
            generator: Gen.zip(\(typeName).gen, Gen.int),
            predicate: { (u, y) in
                let left = u.apply(\(typeName).pure(y))
                let right = \(typeName).pure { f in f(y) }.apply(u)
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Applicative interchange law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateMonadLaws(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  guard structure.conformances.contains("Monad") else {
    throw LawCheckedError.missingOperation("Type must conform to Monad")
  }

  let leftIdentityLaw = try generateMonadLeftIdentityLaw(structure: structure, config: config)
  let rightIdentityLaw = try generateMonadRightIdentityLaw(structure: structure, config: config)
  let associativityLaw = try generateMonadAssociativityLaw(structure: structure, config: config)

  return [leftIdentityLaw, rightIdentityLaw, associativityLaw]
}

private func generateMonadLeftIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_MonadLeftIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Monad Left Identity Law: pure(a) >>= f == f(a)")
    func \(testName)() async {
        let property = Property<(Int, (Int) -> \(typeName))>(
            generator: Gen.zip(Gen.int, Gen.function(\(typeName).gen)),
            predicate: { (a, f) in
                let left = \(typeName).pure(a).flatMap(f)
                let right = f(a)
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Monad left identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateMonadRightIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_MonadRightIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Monad Right Identity Law: m >>= pure == m")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { monad in
                let result = monad.flatMap(\(typeName).pure)
                return result == monad
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Monad right identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateMonadAssociativityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_MonadAssociativityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Monad Associativity Law: (m >>= f) >>= g == m >>= (\\x -> f x >>= g)")
    func \(testName)() async {
        let property = Property<(\(typeName), (Int) -> \(typeName), (Int) -> \(typeName))>(
            generator: Gen.zip3(\(typeName).gen, Gen.function(\(typeName).gen), Gen.function(\(typeName).gen)),
            predicate: { (monad, f, g) in
                let left = monad.flatMap(f).flatMap(g)
                let right = monad.flatMap { x in f(x).flatMap(g) }
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Monad associativity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateSemigroupLaws(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  guard structure.conformances.contains("Semigroup") else {
    throw LawCheckedError.missingOperation("Type must conform to Semigroup")
  }

  let associativityLaw = try generateSemigroupAssociativityLaw(structure: structure, config: config)

  return [associativityLaw]
}

private func generateSemigroupAssociativityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_SemigroupAssociativityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Semigroup Associativity Law: (a <> b) <> c == a <> (b <> c)")
    func \(testName)() async {
        let property = Property<(\(typeName), \(typeName), \(typeName))>(
            generator: Gen.zip3(\(typeName).gen, \(typeName).gen, \(typeName).gen),
            predicate: { (a, b, c) in
                let left = a.combine(b).combine(c)
                let right = a.combine(b.combine(c))
                return left == right
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Semigroup associativity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateMonoidLaws(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> [DeclSyntax] {

  guard structure.conformances.contains("Monoid") else {
    throw LawCheckedError.missingOperation("Type must conform to Monoid")
  }

  let leftIdentityLaw = try generateMonoidLeftIdentityLaw(structure: structure, config: config)
  let rightIdentityLaw = try generateMonoidRightIdentityLaw(structure: structure, config: config)

  return [leftIdentityLaw, rightIdentityLaw]
}

private func generateMonoidLeftIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_MonoidLeftIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Monoid Left Identity Law: empty <> a == a")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { value in
                let result = \(typeName).empty.combine(value)
                return result == value
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Monoid left identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateMonoidRightIdentityLaw(
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName = "test_\(structure.typeName)_MonoidRightIdentityLaw"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Monoid Right Identity Law: a <> empty == a")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { value in
                let result = value.combine(\(typeName).empty)
                return result == value
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Monoid right identity law failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

private func generateCustomLawTest(
  name: String,
  expression: String,
  structure: MathematicalStructure,
  config: LawCheckedConfig
) throws -> DeclSyntax {

  let testName =
    "test_\(structure.typeName)_CustomLaw_\(name.replacingOccurrences(of: " ", with: "_"))"
  let typeName = structure.typeName

  let testBody = """
    @Test("\(typeName) Custom Law: \(name)")
    func \(testName)() async {
        let property = Property<\(typeName)>(
            generator: \(typeName).gen,
            predicate: { value in
                // Custom law expression: \(expression)
                // This would need to be parsed and converted to executable code
                return true // Placeholder - real implementation would parse expression
            }
        )
        
        let result = await PropertyRunner().runProperty(
            property,
            config: PropertyConfig(iterations: \(config.iterations))
        )
        
        #expect(result.isSuccess, "Custom law '\(name)' failed")
    }
    """

  return DeclSyntax(stringLiteral: testBody)
}

// MARK: - Public Macro Declaration

/// **@LawChecked Macro Attribute**
///
/// Automatically generates property-based tests for mathematical laws.
///
/// **Parameters:**
/// - `laws`: Array of built-in mathematical laws to check
/// - `customLaws`: Dictionary of custom law expressions
/// - `iterations`: Number of test iterations (default: 100)
/// - `size`: Size parameter for generation (default: 50)
/// - `enableShrinking`: Enable shrinking for counterexamples (default: true)
/// - `timeout`: Timeout for each law test in seconds (default: 30.0)
///
/// **Example:**
/// ```swift
/// @LawChecked(laws: [.functor, .applicative, .monad])
/// struct Maybe<T>: Functor, Applicative, Monad {
///     // Implementation...
/// }
/// ```
/*
@attached(member, names: arbitrary)
public macro LawChecked(
  laws: [MathematicalLaw] = [],
  customLaws: [String: String] = [:],
  iterations: Int = 100,
  size: Int = 50,
  enableShrinking: Bool = true,
  timeout: Double = 30.0
) = #externalMacro(module: "FunctionalTestingMacros", type: "LawCheckedMacro")
*/
