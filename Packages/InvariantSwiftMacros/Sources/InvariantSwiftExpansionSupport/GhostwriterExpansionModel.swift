public struct GhostwriterImport: Sendable {
  public let moduleName: String
  public let isTestable: Bool

  public init(moduleName: String, isTestable: Bool = false) {
    self.moduleName = moduleName
    self.isTestable = isTestable
  }
}

public struct GhostwriterGeneratedFile: Sendable {
  public let sourceFile: String
  public let generatedAt: String
  public let imports: [GhostwriterImport]
  public let arbitraryExtensions: [GhostwriterGeneratedArbitraryExtension]
  public let suiteTitle: String
  public let sections: [GhostwriterGeneratedSection]

  public init(
    sourceFile: String,
    generatedAt: String,
    imports: [GhostwriterImport],
    arbitraryExtensions: [GhostwriterGeneratedArbitraryExtension],
    suiteTitle: String,
    sections: [GhostwriterGeneratedSection]
  ) {
    self.sourceFile = sourceFile
    self.generatedAt = generatedAt
    self.imports = imports
    self.arbitraryExtensions = arbitraryExtensions
    self.suiteTitle = suiteTitle
    self.sections = sections
  }
}

public struct GhostwriterGeneratedSection: Sendable {
  public let title: String
  public let tests: [GhostwriterGeneratedTest]

  public init(title: String, tests: [GhostwriterGeneratedTest]) {
    self.title = title
    self.tests = tests
  }
}

public struct GhostwriterGeneratedArbitraryExtension: Sendable {
  public let typeName: String
  public let propertyGenerators: [GhostwriterPropertyGenerator]

  public init(typeName: String, propertyGenerators: [GhostwriterPropertyGenerator]) {
    self.typeName = typeName
    self.propertyGenerators = propertyGenerators
  }
}

public struct GhostwriterPropertyGenerator: Sendable {
  public let name: String
  public let expression: ExpansionExpr
  public let todoComment: String?

  public init(name: String, expression: ExpansionExpr, todoComment: String?) {
    self.name = name
    self.expression = expression
    self.todoComment = todoComment
  }
}

public struct GhostwriterGeneratedTest: Sendable {
  public let docComment: String
  public let functionName: String
  public let parameters: [ExpansionParameter]
  public let isThrowing: Bool
  public let bodyStatements: [ExpansionStatement]

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

public struct ExpansionParameter: Sendable {
  public let name: String
  public let type: String

  public init(name: String, type: String) {
    self.name = name
    self.type = type
  }
}

public struct ExpansionArgument: Sendable {
  public let label: String?
  public let expression: ExpansionExpr

  public init(label: String?, expression: ExpansionExpr) {
    self.label = label
    self.expression = expression
  }

  public static func unlabeled(_ expression: ExpansionExpr) -> Self {
    Self(label: nil, expression: expression)
  }

  public static func labeled(_ label: String, _ expression: ExpansionExpr) -> Self {
    Self(label: label, expression: expression)
  }
}

public struct ExpansionClosure: Sendable {
  public let parameters: [String]
  public let bodyStatements: [ExpansionStatement]

  public init(parameters: [String], bodyStatements: [ExpansionStatement]) {
    self.parameters = parameters
    self.bodyStatements = bodyStatements
  }
}

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

public indirect enum ExpansionStatement: Sendable {
  case letBinding(name: String, initializer: ExpansionExpr)
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
