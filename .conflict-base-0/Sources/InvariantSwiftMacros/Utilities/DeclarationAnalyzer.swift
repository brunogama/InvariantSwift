import SwiftSyntax

public enum DeclarationAnalyzer {

  public static func requireFunction(
    from declaration: some DeclSyntaxProtocol,
    context: MacroContext,
    macroName: String
  ) -> FunctionDeclSyntax? {
    if let funcDecl = declaration as? FunctionDeclSyntax {
      return funcDecl
    }

    if let declSyntax = declaration as? DeclSyntax,
      let funcDecl = declSyntax.as(FunctionDeclSyntax.self)
    {
      return funcDecl
    }

    context.error("@\(macroName) can only be applied to functions", at: Syntax(declaration))
    return nil
  }

  public static func requireStruct(
    from declaration: some DeclGroupSyntax,
    context: MacroContext,
    macroName: String
  ) -> StructDeclSyntax? {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return structDecl
    }

    context.error("@\(macroName) can only be applied to structs", at: Syntax(declaration))
    return nil
  }

  public static func requireEnum(
    from declaration: some DeclGroupSyntax,
    context: MacroContext,
    macroName: String
  ) -> EnumDeclSyntax? {
    if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return enumDecl
    }

    context.error("@\(macroName) can only be applied to enums", at: Syntax(declaration))
    return nil
  }

  public static func requireStructOrEnum(
    from declaration: some DeclGroupSyntax,
    context: MacroContext,
    macroName: String
  ) -> StructOrEnum? {
    if let structDecl = declaration.as(StructDeclSyntax.self) {
      return .struct(structDecl)
    }

    if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      return .enum(enumDecl)
    }

    context.error("@\(macroName) can only be applied to structs or enums", at: Syntax(declaration))
    return nil
  }

  public static func requireClass(
    from declaration: some DeclGroupSyntax,
    context: MacroContext,
    macroName: String
  ) -> ClassDeclSyntax? {
    if let classDecl = declaration.as(ClassDeclSyntax.self) {
      return classDecl
    }

    context.error("@\(macroName) can only be applied to classes", at: Syntax(declaration))
    return nil
  }
}

public enum StructOrEnum {
  case `struct`(StructDeclSyntax)
  case `enum`(EnumDeclSyntax)

  public var name: TokenSyntax {
    switch self {
    case .struct(let s): return s.name
    case .enum(let e): return e.name
    }
  }

  public var nameText: String {
    name.text
  }

  public var memberBlock: MemberBlockSyntax {
    switch self {
    case .struct(let s): return s.memberBlock
    case .enum(let e): return e.memberBlock
    }
  }
}
