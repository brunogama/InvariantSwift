/// An import needed by a generated test file.
public struct GhostwriterImport: Sendable {
  /// The declaration kinds supported by selective imports.
  public enum DeclarationKind: String, Sendable {
    case `class`
    case `enum`
    case `struct`
  }

  /// The module containing the imported declaration.
  public let moduleName: String
  /// Whether the whole module needs testable access.
  public let isTestable: Bool
  /// The kind to import when selecting one declaration.
  public let declarationKind: DeclarationKind?
  /// The declaration to import when a whole-module import would be ambiguous.
  public let declarationName: String?

  /// Creates a whole-module import.
  public init(moduleName: String, isTestable: Bool = false) {
    self.moduleName = moduleName
    self.isTestable = isTestable
    declarationKind = nil
    declarationName = nil
  }

  /// Creates an import for one named declaration.
  public init(
    moduleName: String,
    declarationKind: DeclarationKind,
    declarationName: String
  ) {
    self.moduleName = moduleName
    isTestable = false
    self.declarationKind = declarationKind
    self.declarationName = declarationName
  }
}

/// A complete source file planned for Ghostwriter rendering.
public struct GhostwriterGeneratedFile: Sendable {
  /// The project-relative source path shown in the generated header.
  public let sourceFile: String
  /// The command to reproduce this generated file.
  public let regenerationCommand: String
  /// Imports required to compile the generated tests.
  public let imports: [GhostwriterImport]
  /// Generator conformances emitted before the test suite.
  public let arbitraryExtensions: [GhostwriterGeneratedArbitraryExtension]
  /// The human-readable Swift Testing suite title.
  public let suiteTitle: String
  /// The unique Swift identifier for this file's suite type.
  public let suiteTypeName: String
  /// Groups of generated tests within the suite.
  public let sections: [GhostwriterGeneratedSection]

  /// Creates a generated file plan ready for rendering.
  public init(
    sourceFile: String,
    regenerationCommand: String = "swift package ghostwrite",
    imports: [GhostwriterImport],
    arbitraryExtensions: [GhostwriterGeneratedArbitraryExtension],
    suiteTitle: String,
    suiteTypeName: String,
    sections: [GhostwriterGeneratedSection]
  ) {
    self.sourceFile = sourceFile
    self.regenerationCommand = regenerationCommand
    self.imports = imports
    self.arbitraryExtensions = arbitraryExtensions
    self.suiteTitle = suiteTitle
    self.suiteTypeName = suiteTypeName
    self.sections = sections
  }
}

/// A named group of property tests for one source declaration.
public struct GhostwriterGeneratedSection: Sendable {
  /// The section heading written into the generated file.
  public let title: String
  /// The tests rendered below the heading.
  public let tests: [GhostwriterGeneratedTest]

  /// Creates a section and its tests.
  public init(title: String, tests: [GhostwriterGeneratedTest]) {
    self.title = title
    self.tests = tests
  }
}

/// A planned `Generatable` conformance for a concrete type.
public struct GhostwriterGeneratedArbitraryExtension: Sendable {
  /// The type receiving the conformance.
  public let typeName: String
  /// Generators for its stored properties.
  public let propertyGenerators: [GhostwriterPropertyGenerator]
  /// Cases used when the type is a finite enum.
  public let enumCases: [String]

  /// Creates a conformance plan for a struct or enum.
  public init(
    typeName: String,
    propertyGenerators: [GhostwriterPropertyGenerator],
    enumCases: [String] = []
  ) {
    self.typeName = typeName
    self.propertyGenerators = propertyGenerators
    self.enumCases = enumCases
  }
}

/// A generator expression for one stored property.
public struct GhostwriterPropertyGenerator: Sendable {
  /// The stored property's initializer label.
  public let name: String
  /// The expression that produces its values.
  public let expression: ExpansionExpr
  /// A reminder when this expression needs a custom generator.
  public let todoComment: String?

  /// Creates a property generator plan.
  public init(name: String, expression: ExpansionExpr, todoComment: String?) {
    self.name = name
    self.expression = expression
    self.todoComment = todoComment
  }
}

/// A property test planned as a function within a generated suite.
public struct GhostwriterGeneratedTest: Sendable {
  /// The documentation placed above the test function.
  public let docComment: String
  /// The collision-safe Swift function identifier.
  public let functionName: String
  /// Inputs sampled by the property runner.
  public let parameters: [ExpansionParameter]
  /// Whether the test body can throw.
  public let isThrowing: Bool
  /// Statements rendered into the test body.
  public let bodyStatements: [ExpansionStatement]

  /// Creates a generated property test plan.
  public init(
    docComment: String,
    functionName: String,
    parameters: [ExpansionParameter],
    isThrowing: Bool = false,
    bodyStatements: [ExpansionStatement]
  ) {
    self.docComment = docComment
    self.functionName = functionName
    self.parameters = parameters
    self.isThrowing = isThrowing
    self.bodyStatements = bodyStatements
  }
}

/// A named parameter of a generated test function.
public struct ExpansionParameter: Sendable {
  /// The Swift parameter name.
  public let name: String
  /// The source spelling of the parameter type.
  public let type: String

  /// Creates a test parameter.
  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

/// An argument in a generated call expression.
public struct ExpansionArgument: Sendable {
  /// The argument label, or nil for an unlabeled argument.
  public let label: String?
  /// The argument value.
  public let expression: ExpansionExpr

  /// Creates a labeled or unlabeled argument.
  public init(label: String?, expression: ExpansionExpr) {
    self.label = label
    self.expression = expression
  }

  /// Wraps an expression as an unlabeled argument.
  public static func unlabeled(_ expression: ExpansionExpr) -> Self {
    Self(label: nil, expression: expression)
  }

  /// Wraps an expression with a call-site label.
  public static func labeled(_ label: String, _ expression: ExpansionExpr) -> Self {
    Self(label: label, expression: expression)
  }
}

/// A closure used inside a generated expression.
public struct ExpansionClosure: Sendable {
  /// Names bound by the closure signature.
  public let parameters: [String]
  /// Statements evaluated by the closure.
  public let bodyStatements: [ExpansionStatement]

  /// Creates a closure plan.
  public init(parameters: [String], bodyStatements: [ExpansionStatement]) {
    self.parameters = parameters
    self.bodyStatements = bodyStatements
  }
}

/// The expression forms supported by Ghostwriter's typed rendering plan.
public indirect enum ExpansionExpr: Sendable {
  case identifier(String)
  case member(base: Self, name: String)
  case call(
    callee: Self,
    arguments: [ExpansionArgument],
    trailingClosure: ExpansionClosure?
  )
  case tryExpr(Self)
  case binary(lhs: Self, op: String, rhs: Self)
  case prefix(op: String, expression: Self)
  case array([Self])
  case tuple([Self])
  case exactlyOneTrue([Self])
}

/// The statement forms supported in a generated property test body.
public indirect enum ExpansionStatement: Sendable {
  case letBinding(name: String, initializer: ExpansionExpr)
  case varBinding(name: String, initializer: ExpansionExpr)
  case assignment(target: ExpansionExpr, value: ExpansionExpr)
  case ifStatement(condition: ExpansionExpr, body: [Self])
  case expression(ExpansionExpr)
  case expect(condition: ExpansionExpr, message: String)
}

public extension ExpansionExpr {
  static func variable(_ name: String) -> Self {
    .identifier(name)
  }

  static func call(_ name: String, arguments: [ExpansionArgument] = []) -> Self {
    .call(callee: .identifier(name), arguments: arguments, trailingClosure: nil)
  }

  static func property(_ name: String, on base: String) -> Self {
    .member(base: .identifier(base), name: name)
  }

  static func property(_ name: String, on base: Self) -> Self {
    .member(base: base, name: name)
  }

  static func operation(_ lhs: Self, _ op: String, _ rhs: Self) -> Self {
    .binary(lhs: lhs, op: op, rhs: rhs)
  }

  func method(
    _ name: String,
    arguments: [ExpansionArgument] = [],
    trailingClosure: ExpansionClosure? = nil
  ) -> Self {
    .call(
      callee: .member(base: self, name: name),
      arguments: arguments,
      trailingClosure: trailingClosure
    )
  }

  func trying() -> Self {
    .tryExpr(self)
  }
}
