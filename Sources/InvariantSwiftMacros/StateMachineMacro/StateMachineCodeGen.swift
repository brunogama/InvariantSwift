import SwiftSyntax
import SwiftSyntaxBuilder

// swiftlint:disable:next type_body_length
enum StateMachineCodeGen {

  static func generateMembers(
    typeName: String,
    analysis: StateMachineAnalysis
  ) -> [DeclSyntax] {

    var members: [DeclSyntax] = []

    let commandEnum = buildCommandEnum(
      modelTypeName: typeName,
      commandMethods: analysis.commandMethods
    )
    members.append(DeclSyntax(commandEnum))

    let initialStateProperty = buildInitialStateProperty(
      stateFields: analysis.stateFields
    )
    members.append(DeclSyntax(initialStateProperty))

    let generateCommandFunc = buildGenerateCommandFunc(
      modelTypeName: typeName,
      commandMethods: analysis.commandMethods
    )
    members.append(DeclSyntax(generateCommandFunc))

    let invariantFunc = buildInvariantFunc()
    members.append(DeclSyntax(invariantFunc))

    return members
  }

  static func generateExtensions(
    typeName: String,
    type: some TypeSyntaxProtocol,
    analysis: StateMachineAnalysis
  ) -> [ExtensionDeclSyntax] {

    let commandEnumName = "\(typeName)Command"

    let stateMachineExtension = ExtensionDeclSyntax(
      extensionKeyword: .keyword(.extension),
      extendedType: TypeSyntax(type),
      inheritanceClause: InheritanceClauseSyntax(
        inheritedTypes: InheritedTypeListSyntax {
          InheritedTypeSyntax(
            type: IdentifierTypeSyntax(name: .identifier("StateMachine"))
          )
        }
      ),
      memberBlock: MemberBlockSyntax(
        leftBrace: .leftBraceToken(),
        members: MemberBlockItemListSyntax {},
        rightBrace: .rightBraceToken()
      )
    )

    let commandExtension = buildCommandEnumExtension(
      modelTypeName: typeName,
      commandEnumName: commandEnumName,
      analysis: analysis
    )

    return [stateMachineExtension, commandExtension]
  }

  private static func buildCommandEnum(
    modelTypeName: String,
    commandMethods: [CommandMethod]
  ) -> EnumDeclSyntax {

    let commandEnumName = "\(modelTypeName)Command"

    let enumCases = MemberBlockItemListSyntax {
      for method in commandMethods {
        MemberBlockItemSyntax(
          decl: buildEnumCase(method: method)
        )
      }
    }

    return EnumDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier(commandEnumName),
      memberBlock: MemberBlockSyntax(
        leftBrace: .leftBraceToken(),
        members: enumCases,
        rightBrace: .rightBraceToken()
      )
    )
  }

  private static func buildEnumCase(method: CommandMethod) -> EnumCaseDeclSyntax {
    if method.parameters.isEmpty {
      return EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax {
          EnumCaseElementSyntax(name: .identifier(method.name))
        }
      )
    }

    let parameterClause = EnumCaseParameterClauseSyntax(
      parameters: EnumCaseParameterListSyntax {
        for (index, param) in method.parameters.enumerated() {
          EnumCaseParameterSyntax(
            firstName: .identifier(param.name),
            colon: .colonToken(),
            type: param.type,
            trailingComma: index < method.parameters.count - 1 ? .commaToken() : nil
          )
        }
      }
    )

    return EnumCaseDeclSyntax(
      elements: EnumCaseElementListSyntax {
        EnumCaseElementSyntax(
          name: .identifier(method.name),
          parameterClause: parameterClause
        )
      }
    )
  }

  private static func buildInitialStateProperty(
    stateFields: [StateField]
  ) -> VariableDeclSyntax {

    var tupleElementsArray: [LabeledExprSyntax] = []
    for (index, field) in stateFields.enumerated() {
      let value: ExprSyntax
      if let defaultValue = field.defaultValue {
        value = defaultValue
      } else {
        value = buildDefaultValue(for: field.type)
      }

      tupleElementsArray.append(
        LabeledExprSyntax(
          label: .identifier(field.name),
          colon: .colonToken(),
          expression: value,
          trailingComma: index < stateFields.count - 1 ? .commaToken() : nil
        )
      )
    }
    let tupleElements = LabeledExprListSyntax(tupleElementsArray)

    let stateType = buildStateTupleType(fields: stateFields)

    let returnExpr: ExprSyntax
    if stateFields.count == 1 {
      returnExpr = tupleElementsArray.first?.expression ?? ExprSyntax(NilLiteralExprSyntax())
    } else {
      returnExpr = ExprSyntax(TupleExprSyntax(elements: tupleElements))
    }

    let getterBody = CodeBlockItemListSyntax([
      CodeBlockItemSyntax(item: .expr(returnExpr))
    ])

    return VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("initialState")),
          typeAnnotation: TypeAnnotationSyntax(type: stateType),
          accessorBlock: AccessorBlockSyntax(accessors: .getter(getterBody))
        )
      }
    )
  }

  private static func buildStateTupleType(fields: [StateField]) -> TypeSyntax {
    if fields.count == 1, let field = fields.first {
      return field.type
    }

    let tupleElements = TupleTypeElementListSyntax {
      for (index, field) in fields.enumerated() {
        TupleTypeElementSyntax(
          firstName: .identifier(field.name),
          colon: .colonToken(),
          type: field.type,
          trailingComma: index < fields.count - 1 ? .commaToken() : nil
        )
      }
    }

    return TypeSyntax(TupleTypeSyntax(elements: tupleElements))
  }

  // swiftlint:disable:next function_body_length
  private static func buildGenerateCommandFunc(
    modelTypeName: String,
    commandMethods: [CommandMethod]
  ) -> FunctionDeclSyntax {

    let commandEnumName = "\(modelTypeName)Command"
    let stateParam = "state"

    let generatorCalls = commandMethods.map { method -> ExprSyntax in
      if method.parameters.isEmpty {
        return ExprSyntax(
          FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
              declName: DeclReferenceExprSyntax(baseName: .identifier("pure"))
            ),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax {
              LabeledExprSyntax(
                expression: MemberAccessExprSyntax(
                  base: DeclReferenceExprSyntax(baseName: .identifier(commandEnumName)),
                  declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
                )
              )
            },
            rightParen: .rightParenToken()
          )
        )
      }

      return buildParameterizedCommandGenerator(
        commandEnumName: commandEnumName,
        method: method
      )
    }

    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax {
        for (index, genCall) in generatorCalls.enumerated() {
          ArrayElementSyntax(
            expression: genCall,
            trailingComma: index < generatorCalls.count - 1 ? .commaToken() : nil
          )
        }
      }
    )

    let oneOfCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("oneOf"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: ExprSyntax(arrayExpr))
      },
      rightParen: .rightParenToken()
    )

    return FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("generateCommand"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: .identifier(stateParam),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("State"))
            )
          }
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(
            name: .identifier("Gen"),
            genericArgumentClause: GenericArgumentClauseSyntax(
              arguments: GenericArgumentListSyntax {
                GenericArgumentSyntax(
                  argument: .type(
                    TypeSyntax(IdentifierTypeSyntax(name: .identifier(commandEnumName)))
                  )
                )
              }
            )
          )
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(item: .expr(ExprSyntax(oneOfCall)))
        }
      )
    )
  }

  // swiftlint:disable:next function_body_length
  private static func buildParameterizedCommandGenerator(
    commandEnumName: String,
    method: CommandMethod
  ) -> ExprSyntax {

    guard let firstParam = method.parameters.first else {
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("pure"))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              expression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier(commandEnumName)),
                declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
              )
            )
          },
          rightParen: .rightParenToken()
        )
      )
    }

    let paramGen = GeneratorInference.infer(for: firstParam.type)

    let closureParam = "$0"
    let commandConstruction: ExprSyntax

    if method.parameters.count == 1 {
      commandConstruction = ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(commandEnumName)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier(firstParam.name),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier(closureParam))
            )
          },
          rightParen: .rightParenToken()
        )
      )
    } else {
      commandConstruction = ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(commandEnumName)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier(firstParam.name),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .identifier(closureParam))
            )
          },
          rightParen: .rightParenToken()
        )
      )
    }

    let mapClosure = ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(commandConstruction))
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: paramGen,
          declName: DeclReferenceExprSyntax(baseName: .identifier("map"))
        ),
        leftParen: nil,
        arguments: LabeledExprListSyntax {},
        rightParen: nil,
        trailingClosure: mapClosure
      )
    )
  }

  private static func buildInvariantFunc() -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("invariant"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: .identifier("state"),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("State"))
            )
          }
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(name: .identifier("Bool"))
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(
            item: .expr(ExprSyntax(BooleanLiteralExprSyntax(booleanLiteral: true)))
          )
        }
      )
    )
  }

  private static func buildCommandEnumExtension(
    modelTypeName: String,
    commandEnumName: String,
    analysis: StateMachineAnalysis
  ) -> ExtensionDeclSyntax {

    let stateType = buildStateTupleType(fields: analysis.stateFields)

    let members = MemberBlockItemListSyntax {
      MemberBlockItemSyntax(
        decl: buildCommandTypealiases(stateType: stateType)
      )

      MemberBlockItemSyntax(
        decl: buildPreconditionFunc(
          commandMethods: analysis.commandMethods,
          stateFields: analysis.stateFields
        )
      )

      MemberBlockItemSyntax(
        decl: buildExecuteFunc(commandMethods: analysis.commandMethods)
      )

      MemberBlockItemSyntax(
        decl: buildApplyFunc(
          modelTypeName: modelTypeName,
          commandMethods: analysis.commandMethods,
          stateFields: analysis.stateFields
        )
      )

      MemberBlockItemSyntax(
        decl: buildPostconditionFunc(commandMethods: analysis.commandMethods)
      )
    }

    let fullyQualifiedCommandType = MemberTypeSyntax(
      baseType: IdentifierTypeSyntax(name: .identifier(modelTypeName)),
      name: .identifier(commandEnumName)
    )

    return ExtensionDeclSyntax(
      extensionKeyword: .keyword(.extension),
      extendedType: TypeSyntax(fullyQualifiedCommandType),
      inheritanceClause: InheritanceClauseSyntax(
        inheritedTypes: InheritedTypeListSyntax {
          InheritedTypeSyntax(
            type: IdentifierTypeSyntax(name: .identifier("Command"))
          )
        }
      ),
      memberBlock: MemberBlockSyntax(
        leftBrace: .leftBraceToken(),
        members: members,
        rightBrace: .rightBraceToken()
      )
    )
  }

  private static func buildCommandTypealiases(stateType: TypeSyntax) -> TypeAliasDeclSyntax {
    TypeAliasDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("State"),
      initializer: TypeInitializerClauseSyntax(value: stateType)
    )
  }

  private static func buildPreconditionFunc(
    commandMethods: [CommandMethod],
    stateFields: [StateField]
  ) -> FunctionDeclSyntax {

    let switchCases = SwitchCaseListSyntax {
      for method in commandMethods {
        SwitchCaseSyntax(
          label: .case(
            SwitchCaseLabelSyntax(
              caseItems: SwitchCaseItemListSyntax {
                SwitchCaseItemSyntax(
                  pattern: buildCasePattern(method: method)
                )
              }
            )
          ),
          statements: CodeBlockItemListSyntax {
            if let precondition = method.preconditionExpr {
              CodeBlockItemSyntax(
                item: .stmt(StmtSyntax(ReturnStmtSyntax(expression: precondition)))
              )
            } else {
              CodeBlockItemSyntax(
                item: .stmt(
                  StmtSyntax(
                    ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: true))
                  )
                )
              )
            }
          }
        )
      }
    }

    let switchExpr = SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: .keyword(.self)),
      cases: switchCases
    )

    return FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("precondition"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: .identifier("state"),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("State"))
            )
          }
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(name: .identifier("Bool"))
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(item: .expr(ExprSyntax(switchExpr)))
        }
      )
    )
  }

  private static func buildExecuteFunc(
    commandMethods: [CommandMethod]
  ) -> FunctionDeclSyntax {

    FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("execute"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {}
        ),
        effectSpecifiers: FunctionEffectSpecifiersSyntax(
          asyncSpecifier: .keyword(.async),
          throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(name: .identifier("Void"))
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {}
      )
    )
  }

  private static func buildApplyFunc(
    modelTypeName: String,
    commandMethods: [CommandMethod],
    stateFields: [StateField]
  ) -> FunctionDeclSyntax {

    let switchCases = SwitchCaseListSyntax {
      for method in commandMethods {
        SwitchCaseSyntax(
          label: .case(
            SwitchCaseLabelSyntax(
              caseItems: SwitchCaseItemListSyntax {
                SwitchCaseItemSyntax(
                  pattern: buildCasePattern(method: method)
                )
              }
            )
          ),
          statements: buildApplyCaseBody(
            method: method,
            stateFields: stateFields
          )
        )
      }
    }

    let switchExpr = SwitchExprSyntax(
      subject: DeclReferenceExprSyntax(baseName: .keyword(.self)),
      cases: switchCases
    )

    return FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("apply"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: .identifier("state"),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("State"))
            )
          }
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(name: .identifier("State"))
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(item: .expr(ExprSyntax(switchExpr)))
        }
      )
    )
  }

  private static func buildApplyCaseBody(
    method: CommandMethod,
    stateFields: [StateField]
  ) -> CodeBlockItemListSyntax {

    CodeBlockItemListSyntax {
      CodeBlockItemSyntax(
        item: .decl(
          DeclSyntax(
            VariableDeclSyntax(
              bindingSpecifier: .keyword(.let),
              bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                  pattern: IdentifierPatternSyntax(identifier: .identifier("newState")),
                  initializer: InitializerClauseSyntax(
                    value: DeclReferenceExprSyntax(baseName: .identifier("state"))
                  )
                )
              }
            )
          )
        )
      )

      for stmt in method.body.statements {
        if let exprStmt = stmt.item.as(ExpressionStmtSyntax.self) {
          CodeBlockItemSyntax(
            item: .expr(transformStateAccess(expr: exprStmt.expression, stateFields: stateFields))
          )
        }
      }

      CodeBlockItemSyntax(
        item: .stmt(
          StmtSyntax(
            ReturnStmtSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("newState")))
          )
        )
      )
    }
  }

  private static func transformStateAccess(
    expr: ExprSyntax,
    stateFields: [StateField]
  ) -> ExprSyntax {
    expr
  }

  private static func buildPostconditionFunc(
    commandMethods: [CommandMethod]
  ) -> FunctionDeclSyntax {

    FunctionDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
      },
      name: .identifier("postcondition"),
      signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax {
            FunctionParameterSyntax(
              firstName: .identifier("state"),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("State")),
              trailingComma: .commaToken()
            )
            FunctionParameterSyntax(
              firstName: .identifier("result"),
              colon: .colonToken(),
              type: IdentifierTypeSyntax(name: .identifier("Void"))
            )
          }
        ),
        returnClause: ReturnClauseSyntax(
          type: IdentifierTypeSyntax(name: .identifier("Bool"))
        )
      ),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(
            item: .expr(ExprSyntax(BooleanLiteralExprSyntax(booleanLiteral: true)))
          )
        }
      )
    )
  }

  private static func buildCasePattern(method: CommandMethod) -> PatternSyntax {
    if method.parameters.isEmpty {
      return PatternSyntax(
        ExpressionPatternSyntax(
          expression: MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
          )
        )
      )
    }

    return PatternSyntax(
      ExpressionPatternSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            declName: DeclReferenceExprSyntax(baseName: .identifier(method.name))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for (index, param) in method.parameters.enumerated() {
              LabeledExprSyntax(
                label: .identifier(param.name),
                colon: .colonToken(),
                expression: DeclReferenceExprSyntax(baseName: .identifier("_")),
                trailingComma: index < method.parameters.count - 1 ? .commaToken() : nil
              )
            }
          },
          rightParen: .rightParenToken()
        )
      )
    )
  }

  private static func buildDefaultValue(for type: TypeSyntax) -> ExprSyntax {
    let typeName = type.trimmedDescription

    switch typeName {
    case "Int", "Int8", "Int16", "Int32", "Int64",
      "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))

    case "Double", "Float":
      return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral("0.0")))

    case "Bool":
      return ExprSyntax(BooleanLiteralExprSyntax(booleanLiteral: false))

    case "String":
      return ExprSyntax(StringLiteralExprSyntax(content: ""))

    default:
      if type.is(OptionalTypeSyntax.self) {
        return ExprSyntax(NilLiteralExprSyntax())
      }
      if type.is(ArrayTypeSyntax.self) {
        return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax {}))
      }
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
    }
  }
  // swiftlint:disable:next file_length
}
