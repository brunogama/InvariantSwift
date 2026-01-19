import SwiftSyntax
import SwiftSyntaxBuilder

// swiftlint:disable:next type_body_length
enum ArbitraryCodeGen {

  static func buildStructArbitraryProperty(
    typeName: String,
    fields: [AnalyzedField],
    config: ArbitraryConfig
  ) -> VariableDeclSyntax {

    let generatorExpr = buildStructGenerator(typeName: typeName, fields: fields, config: config)

    return VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("arbitrary")),
          typeAnnotation: TypeAnnotationSyntax(
            type: buildGenType(for: typeName)
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(generatorExpr))
              }
            )
          )
        )
      }
    )
  }

  static func buildStructShrinkProperty(
    typeName: String,
    fields: [AnalyzedField],
    config: ArbitraryConfig
  ) -> VariableDeclSyntax {

    let shrinkExpr = buildStructShrinker(typeName: typeName, fields: fields, config: config)

    return VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("shrink")),
          typeAnnotation: TypeAnnotationSyntax(
            type: buildShrinkType(for: typeName)
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(shrinkExpr))
              }
            )
          )
        )
      }
    )
  }

  static func buildEnumArbitraryProperty(
    typeName: String,
    cases: [AnalyzedEnumCase],
    config: ArbitraryConfig
  ) -> VariableDeclSyntax {

    let generatorExpr = buildEnumGenerator(typeName: typeName, cases: cases, config: config)

    return VariableDeclSyntax(
      modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
        DeclModifierSyntax(name: .keyword(.static))
      },
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax {
        PatternBindingSyntax(
          pattern: IdentifierPatternSyntax(identifier: .identifier("arbitrary")),
          typeAnnotation: TypeAnnotationSyntax(
            type: buildGenType(for: typeName)
          ),
          accessorBlock: AccessorBlockSyntax(
            accessors: .getter(
              CodeBlockItemListSyntax {
                CodeBlockItemSyntax(item: .expr(generatorExpr))
              }
            )
          )
        )
      }
    )
  }

  private static func buildGenType(for typeName: String) -> TypeSyntax {
    TypeSyntax(
      IdentifierTypeSyntax(
        name: .identifier("Gen"),
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(
            argument: IdentifierTypeSyntax(name: .identifier(typeName))
          )
        }
      )
    )
  }

  private static func buildShrinkType(for typeName: String) -> TypeSyntax {
    TypeSyntax(
      IdentifierTypeSyntax(
        name: .identifier("Shrink"),
        genericArgumentClause: GenericArgumentClauseSyntax {
          GenericArgumentSyntax(
            argument: IdentifierTypeSyntax(name: .identifier(typeName))
          )
        }
      )
    )
  }

  private static func buildStructGenerator(
    typeName: String,
    fields: [AnalyzedField],
    config: ArbitraryConfig
  ) -> ExprSyntax {

    let fieldGenerators = fields.map { field -> ExprSyntax in
      if let constraint = config.constraints[field.name] {
        return buildConstrainedGenerator(constraint: constraint)
      }
      return GeneratorInference.infer(for: field.type)
    }

    if fieldGenerators.count == 1 {
      let mapClosure = buildSingleFieldMapClosure(typeName: typeName, field: fields[0])
      return buildMapCall(generator: fieldGenerators[0], closure: mapClosure)
    }

    let zipCall = buildZipCall(generators: fieldGenerators)
    let mapClosure = buildMultiFieldMapClosure(typeName: typeName, fields: fields)
    return buildMapCall(generator: ExprSyntax(zipCall), closure: mapClosure)
  }

  private static func buildEnumGenerator(
    typeName: String,
    cases: [AnalyzedEnumCase],
    config: ArbitraryConfig
  ) -> ExprSyntax {

    let caseGenerators = cases.map { enumCase -> ExprSyntax in
      if enumCase.hasAssociatedValues {
        return buildEnumCaseWithValuesGenerator(typeName: typeName, enumCase: enumCase)
      }
      return buildPureCaseGenerator(typeName: typeName, caseName: enumCase.name)
    }

    return buildOneOfCall(generators: caseGenerators)
  }

  private static func buildPureCaseGenerator(typeName: String, caseName: String) -> ExprSyntax {
    let caseAccess = MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      declName: DeclReferenceExprSyntax(baseName: .identifier(caseName))
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("pure"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: ExprSyntax(caseAccess))
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func buildEnumCaseWithValuesGenerator(
    typeName: String,
    enumCase: AnalyzedEnumCase
  ) -> ExprSyntax {

    let valueGenerators = enumCase.associatedValues.map { value -> ExprSyntax in
      GeneratorInference.infer(for: value.type)
    }

    if valueGenerators.count == 1 {
      let mapClosure = buildSingleValueEnumClosure(
        typeName: typeName,
        caseName: enumCase.name,
        value: enumCase.associatedValues[0]
      )
      return buildMapCall(generator: valueGenerators[0], closure: mapClosure)
    }

    let zipCall = buildZipCall(generators: valueGenerators)
    let mapClosure = buildMultiValueEnumClosure(
      typeName: typeName,
      caseName: enumCase.name,
      values: enumCase.associatedValues
    )
    return buildMapCall(generator: ExprSyntax(zipCall), closure: mapClosure)
  }

  private static func buildZipCall(generators: [ExprSyntax]) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("zip"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        for gen in generators {
          LabeledExprSyntax(expression: gen)
        }
      },
      rightParen: .rightParenToken()
    )
  }

  private static func buildOneOfCall(generators: [ExprSyntax]) -> ExprSyntax {
    let arrayExpr = ArrayExprSyntax(
      elements: ArrayElementListSyntax {
        for gen in generators {
          ArrayElementSyntax(expression: gen)
        }
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
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
    )
  }

  private static func buildMapCall(generator: ExprSyntax, closure: ClosureExprSyntax) -> ExprSyntax
  {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: generator,
          declName: DeclReferenceExprSyntax(baseName: .identifier("map"))
        ),
        leftParen: nil,
        arguments: LabeledExprListSyntax {},
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  private static func buildSingleFieldMapClosure(
    typeName: String,
    field: AnalyzedField
  ) -> ClosureExprSyntax {

    let initCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          label: .identifier(field.name),
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
        )
      },
      rightParen: .rightParenToken()
    )

    return ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(ExprSyntax(initCall)))
      }
    )
  }

  private static func buildMultiFieldMapClosure(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ClosureExprSyntax {

    let initCall = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        for (index, field) in fields.enumerated() {
          LabeledExprSyntax(
            label: .identifier(field.name),
            colon: .colonToken(),
            expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$\(index)"))
          )
        }
      },
      rightParen: .rightParenToken()
    )

    return ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(ExprSyntax(initCall)))
      }
    )
  }

  private static func buildSingleValueEnumClosure(
    typeName: String,
    caseName: String,
    value: AnalyzedAssociatedValue
  ) -> ClosureExprSyntax {

    let caseCall: ExprSyntax
    if let label = value.label {
      caseCall = ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(caseName))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              label: .identifier(label),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
            )
          },
          rightParen: .rightParenToken()
        )
      )
    } else {
      caseCall = ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(caseName))
          ),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(
              expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$0"))
            )
          },
          rightParen: .rightParenToken()
        )
      )
    }

    return ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(caseCall))
      }
    )
  }

  private static func buildMultiValueEnumClosure(
    typeName: String,
    caseName: String,
    values: [AnalyzedAssociatedValue]
  ) -> ClosureExprSyntax {

    let caseCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
        declName: DeclReferenceExprSyntax(baseName: .identifier(caseName))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        for (index, value) in values.enumerated() {
          if let label = value.label {
            LabeledExprSyntax(
              label: .identifier(label),
              colon: .colonToken(),
              expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$\(index)"))
            )
          } else {
            LabeledExprSyntax(
              expression: DeclReferenceExprSyntax(baseName: .dollarIdentifier("$\(index)"))
            )
          }
        }
      },
      rightParen: .rightParenToken()
    )

    return ClosureExprSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(ExprSyntax(caseCall)))
      }
    )
  }

  private static func buildStructShrinker(
    typeName: String,
    fields: [AnalyzedField],
    config: ArbitraryConfig
  ) -> ExprSyntax {

    switch config.shrinkStrategy {
    case .towards(let expr):
      return buildTowardsShrink(targetExpr: expr)

    case .toEmpty:
      return buildToEmptyShrink(typeName: typeName, fields: fields)

    case .dropFields:
      return buildDropFieldsShrink(typeName: typeName, fields: fields)

    case .custom(let expr):
      return buildCustomShrink(closure: expr)

    case .automatic, .none:
      return buildAutomaticShrink(typeName: typeName, fields: fields)
    }
  }

  private static func buildTowardsShrink(targetExpr: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("Shrink")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("towards"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: targetExpr)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func buildAutomaticShrink(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ExprSyntax {
    let fieldsWithDefaults = fields.filter { $0.hasDefaultValue }

    if !fieldsWithDefaults.isEmpty {
      let defaultInstance = buildDefaultInstance(typeName: typeName, fields: fields)
      return buildTowardsShrink(targetExpr: defaultInstance)
    }

    return buildPerFieldShrink(typeName: typeName, fields: fields)
  }

  private static func buildToEmptyShrink(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ExprSyntax {
    let emptyValues = fields.map { field -> LabeledExprSyntax in
      let emptyExpr = buildEmptyValue(for: field.type)
      return LabeledExprSyntax(
        label: .identifier(field.name),
        colon: .colonToken(),
        expression: emptyExpr
      )
    }

    let emptyInstance = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(emptyValues),
      rightParen: .rightParenToken()
    )

    return buildTowardsShrink(targetExpr: ExprSyntax(emptyInstance))
  }

  private static func buildEmptyValue(for type: TypeSyntax) -> ExprSyntax {
    let typeName = type.trimmedDescription

    if typeName.contains("Int") || typeName.contains("Double") || typeName.contains("Float") {
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("0")))
    }
    if typeName == "String" {
      return ExprSyntax(StringLiteralExprSyntax(content: ""))
    }
    if typeName == "Bool" {
      return ExprSyntax(BooleanLiteralExprSyntax(booleanLiteral: false))
    }
    if typeName.hasPrefix("[") || typeName.hasPrefix("Array") {
      return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax {}))
    }
    if typeName.hasPrefix("Set") {
      return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax {}))
    }
    if typeName.hasSuffix("?") || typeName.hasPrefix("Optional") {
      return ExprSyntax(NilLiteralExprSyntax())
    }
    return ExprSyntax(NilLiteralExprSyntax())
  }

  private static func buildDropFieldsShrink(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ExprSyntax {
    let optionalFields = fields.filter { field in
      let typeName = field.type.trimmedDescription
      return typeName.hasSuffix("?") || typeName.hasPrefix("Optional")
    }

    if optionalFields.isEmpty {
      return buildAutomaticShrink(typeName: typeName, fields: fields)
    }

    return buildPerFieldShrink(typeName: typeName, fields: fields)
  }

  private static func buildCustomShrink(closure: ExprSyntax) -> ExprSyntax {
    ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Shrink")),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: closure)
        },
        rightParen: .rightParenToken()
      )
    )
  }

  // swiftlint:disable:next function_body_length
  private static func buildPerFieldShrink(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ExprSyntax {
    let valueParam = "value"

    let shrinkClosureStatements = CodeBlockItemListSyntax {
      CodeBlockItemSyntax(
        item: .decl(
          DeclSyntax(
            VariableDeclSyntax(
              bindingSpecifier: .keyword(.var),
              bindings: PatternBindingListSyntax {
                PatternBindingSyntax(
                  pattern: IdentifierPatternSyntax(identifier: .identifier("results")),
                  typeAnnotation: TypeAnnotationSyntax(
                    type: ArrayTypeSyntax(
                      element: IdentifierTypeSyntax(name: .identifier(typeName))
                    )
                  ),
                  initializer: InitializerClauseSyntax(
                    value: ArrayExprSyntax(elements: ArrayElementListSyntax {})
                  )
                )
              }
            )
          )
        )
      )

      for field in fields {
        CodeBlockItemSyntax(
          item: .stmt(
            StmtSyntax(
              buildFieldShrinkLoop(typeName: typeName, field: field, fields: fields)
            )
          )
        )
      }

      CodeBlockItemSyntax(
        item: .stmt(
          StmtSyntax(
            ReturnStmtSyntax(
              expression: DeclReferenceExprSyntax(baseName: .identifier("results"))
            )
          )
        )
      )
    }

    let shrinkClosure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            ClosureShorthandParameterSyntax(name: .identifier(valueParam))
          }
        )
      ),
      statements: shrinkClosureStatements
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Shrink")),
        leftParen: nil,
        arguments: LabeledExprListSyntax {},
        rightParen: nil,
        trailingClosure: shrinkClosure
      )
    )
  }

  // swiftlint:disable:next function_body_length
  private static func buildFieldShrinkLoop(
    typeName: String,
    field: AnalyzedField,
    fields: [AnalyzedField]
  ) -> ForStmtSyntax {
    let shrunkVar = "shrunk\(field.name.capitalized)"
    let shrinkExpr = GeneratorInference.inferShrink(for: field.type)

    let shrinkCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: shrinkExpr,
        declName: DeclReferenceExprSyntax(baseName: .identifier("shrink"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("value")),
            declName: DeclReferenceExprSyntax(baseName: .identifier(field.name))
          )
        )
      },
      rightParen: .rightParenToken()
    )

    let argumentList = LabeledExprListSyntax(
      fields.enumerated().map { index, f in
        let valueExpr: ExprSyntax
        if f.name == field.name {
          valueExpr = ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(shrunkVar)))
        } else {
          valueExpr = ExprSyntax(
            MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: .identifier("value")),
              declName: DeclReferenceExprSyntax(baseName: .identifier(f.name))
            )
          )
        }
        let isLast = index == fields.count - 1
        return LabeledExprSyntax(
          label: .identifier(f.name),
          colon: .colonToken(),
          expression: valueExpr,
          trailingComma: isLast ? nil : .commaToken()
        )
      }
    )

    let newInstanceExpr = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      leftParen: .leftParenToken(),
      arguments: argumentList,
      rightParen: .rightParenToken()
    )

    let appendCall = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("results")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("append"))
      ),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax {
        LabeledExprSyntax(expression: ExprSyntax(newInstanceExpr))
      },
      rightParen: .rightParenToken()
    )

    return ForStmtSyntax(
      forKeyword: .keyword(.for),
      pattern: IdentifierPatternSyntax(identifier: .identifier(shrunkVar)),
      inKeyword: .keyword(.in),
      sequence: ExprSyntax(shrinkCall),
      body: CodeBlockSyntax(
        statements: CodeBlockItemListSyntax {
          CodeBlockItemSyntax(item: .expr(ExprSyntax(appendCall)))
        }
      )
    )
  }

  private static func buildDefaultInstance(
    typeName: String,
    fields: [AnalyzedField]
  ) -> ExprSyntax {
    let allFieldsHaveDefaults = fields.allSatisfy { $0.hasDefaultValue }

    if allFieldsHaveDefaults {
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {},
          rightParen: .rightParenToken()
        )
      )
    }

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          for field in fields {
            if let defaultValue = field.defaultValue {
              LabeledExprSyntax(
                label: .identifier(field.name),
                colon: .colonToken(),
                expression: defaultValue
              )
            } else {
              LabeledExprSyntax(
                label: .identifier(field.name),
                colon: .colonToken(),
                expression: buildDefaultValueForType(field.type)
              )
            }
          }
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func buildDefaultValueForType(_ type: TypeSyntax) -> ExprSyntax {
    let typeName = extractBaseTypeName(type)

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
      if type.is(OptionalTypeSyntax.self)
        || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
      {
        return ExprSyntax(NilLiteralExprSyntax())
      }
      if type.is(ArrayTypeSyntax.self) || typeName == "Array" {
        return ExprSyntax(ArrayExprSyntax(elements: ArrayElementListSyntax {}))
      }
      return ExprSyntax(
        MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
          declName: DeclReferenceExprSyntax(baseName: .identifier("default"))
        )
      )
    }
  }

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
    if let member = type.as(MemberTypeSyntax.self) {
      return member.name.text
    }
    return type.trimmedDescription
  }

  private static func buildConstrainedGenerator(constraint: String) -> ExprSyntax {
    let trimmed = constraint.trimmingCharacters(in: .whitespaces)

    if trimmed == "nonEmpty" {
      return buildNonEmptyGenerator()
    }

    if let range = parseClosedRange(trimmed) {
      return buildRangedIntGenerator(lower: range.lower, upper: range.upper)
    }

    if let range = parseHalfOpenRange(trimmed) {
      return buildRangedIntGenerator(lower: range.lower, upper: range.upper, isClosed: false)
    }

    return ExprSyntax(
      MemberAccessExprSyntax(
        base: GenericSpecializationExprSyntax(
          expression: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          genericArgumentClause: GenericArgumentClauseSyntax {
            GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("Int")))
          }
        ),
        declName: DeclReferenceExprSyntax(baseName: .identifier("int"))
      )
    )
  }

  private static func parseClosedRange(_ str: String) -> (lower: String, upper: String)? {
    let parts = str.components(separatedBy: "...")
    guard parts.count == 2 else { return nil }
    let lower = parts[0].trimmingCharacters(in: .whitespaces)
    let upper = parts[1].trimmingCharacters(in: .whitespaces)
    guard !lower.isEmpty, !upper.isEmpty else { return nil }
    return (lower, upper)
  }

  private static func parseHalfOpenRange(_ str: String) -> (lower: String, upper: String)? {
    let parts = str.components(separatedBy: "..<")
    guard parts.count == 2 else { return nil }
    let lower = parts[0].trimmingCharacters(in: .whitespaces)
    let upper = parts[1].trimmingCharacters(in: .whitespaces)
    guard !lower.isEmpty, !upper.isEmpty else { return nil }
    return (lower, upper)
  }

  private static func buildRangedIntGenerator(
    lower: String,
    upper: String,
    isClosed: Bool = true
  ) -> ExprSyntax {
    let rangeOperator = isClosed ? "..." : "..<"
    let rangeExpr = SequenceExprSyntax {
      IntegerLiteralExprSyntax(literal: .integerLiteral(lower))
      BinaryOperatorExprSyntax(operator: .binaryOperator(rangeOperator))
      IntegerLiteralExprSyntax(literal: .integerLiteral(upper))
    }

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: GenericSpecializationExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
            genericArgumentClause: GenericArgumentClauseSyntax {
              GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("Int")))
            }
          ),
          declName: DeclReferenceExprSyntax(baseName: .identifier("int"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("in"),
            colon: .colonToken(),
            expression: ExprSyntax(rangeExpr)
          )
        },
        rightParen: .rightParenToken()
      )
    )
  }

  private static func buildNonEmptyGenerator() -> ExprSyntax {
    let baseGen = ExprSyntax(
      MemberAccessExprSyntax(
        base: GenericSpecializationExprSyntax(
          expression: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
          genericArgumentClause: GenericArgumentClauseSyntax {
            GenericArgumentSyntax(argument: IdentifierTypeSyntax(name: .identifier("String")))
          }
        ),
        declName: DeclReferenceExprSyntax(baseName: .identifier("string"))
      )
    )

    let predicateClosure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            ClosureShorthandParameterSyntax(name: .identifier("s"))
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        PrefixOperatorExprSyntax(
          operator: .prefixOperator("!"),
          expression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("s")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("isEmpty"))
          )
        )
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: baseGen,
          declName: DeclReferenceExprSyntax(baseName: .identifier("suchThat"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: ExprSyntax(predicateClosure))
        },
        rightParen: .rightParenToken()
      )
    )
  }
// swiftlint:disable:next file_length
}
