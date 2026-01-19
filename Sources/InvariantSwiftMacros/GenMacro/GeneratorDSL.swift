import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Generator DSL Parser

/// Parses generator DSL expressions from @Gen attribute arguments.
///
/// Supported DSL patterns:
/// - `.int`, `.int(in: 0...100)`, `.int(.positive)`, `.int(.negative)`, `.int(.nonZero)`
/// - `.string`, `.string(length: 1...20)`, `.string(.ascii)`, `.string(.email)`, `.string(.uuid)`
/// - `.bool`
/// - `.double`, `.double(in: 0.0...1.0)`
/// - `.array(of: .int)`, `.array(of: .int, count: 5)`, `.array(of: .int, count: 1...10)`
/// - `.set(of: .int)`
/// - `.dictionary(keys: .string, values: .int)`
/// - `.optional(.string)`, `.some(.string)`, `.none`
/// - `.oneOf([...])`, `.frequency([...])`
/// - `.custom { rng, size in ... }`
///
/// Fake data generators (full path):
/// - `.fake.name.firstName`, `.fake.name.lastName`, `.fake.name.fullName`
/// - `.fake.address.city`, `.fake.address.streetAddress`, `.fake.address.zipCode`
/// - `.fake.internet.email`, `.fake.internet.username`, `.fake.internet.url`
/// - `.fake.company.name`, `.fake.company.catchPhrase`
/// - `.fake.commerce.productName`, `.fake.commerce.price`, `.fake.commerce.color`
/// - `.fake.lorem.word`, `.fake.lorem.sentence`, `.fake.lorem.paragraph`
///
/// Fake data generators (shorthand):
/// - `.firstName`, `.lastName`, `.fullName`, `.city`, `.zipCode`, `.email`, `.username`
/// - `.companyName`, `.productName`, `.price`, `.color`, `.word`, `.sentence`, `.paragraph`
// swiftlint:disable:next type_body_length
public enum GeneratorDSL {

  /// Parsed generator expression
  public indirect enum ParsedGenerator {
    // Primitives
    case int(IntModifier?)
    case uint
    case bool
    case double(DoubleModifier?)
    case float
    case string(StringModifier?)
    case character
    case uuid
    case date
    case data
    case url

    // Collections
    case array(element: Self, count: CountModifier?)
    case set(element: Self)
    case dictionary(key: Self, value: Self)

    // Optionals
    case optional(Self)
    case some(Self)
    case none

    // Combinators
    case oneOf([Self])
    case frequency([(Int, Self)])

    // Custom
    case custom(ExprSyntax)

    // Reference to type's arbitrary
    case arbitrary(String)

    // Fake data generators
    case fake(FakeGenerator)
  }

  public enum FakeGenerator {
    // Name generators
    case firstName
    case lastName
    case fullName
    case namePrefix
    case nameSuffix

    // Address generators
    case city
    case streetName
    case streetAddress
    case zipCode
    case state
    case country
    case latitude
    case longitude

    // Internet generators
    case email
    case username
    case domainName
    case url
    case ipV4Address
    case ipV6Address
    case password

    // Company generators
    case companyName
    case companySuffix
    case catchPhrase
    case bs

    // Commerce generators
    case productName
    case price
    case color
    case department

    // Lorem generators
    case word
    case sentence
    case paragraph

    var categoryAndMember: (String, String) {
      switch self {
      case .firstName: return ("name", "firstName")
      case .lastName: return ("name", "lastName")
      case .fullName: return ("name", "fullName")
      case .namePrefix: return ("name", "prefix")
      case .nameSuffix: return ("name", "suffix")
      case .city: return ("address", "city")
      case .streetName: return ("address", "streetName")
      case .streetAddress: return ("address", "streetAddress")
      case .zipCode: return ("address", "zipCode")
      case .state: return ("address", "state")
      case .country: return ("address", "country")
      case .latitude: return ("address", "latitude")
      case .longitude: return ("address", "longitude")
      case .email: return ("internet", "email")
      case .username: return ("internet", "username")
      case .domainName: return ("internet", "domainName")
      case .url: return ("internet", "url")
      case .ipV4Address: return ("internet", "ipV4Address")
      case .ipV6Address: return ("internet", "ipV6Address")
      case .password: return ("internet", "password")
      case .companyName: return ("company", "name")
      case .companySuffix: return ("company", "suffix")
      case .catchPhrase: return ("company", "catchPhrase")
      case .bs: return ("company", "bs")
      case .productName: return ("commerce", "productName")
      case .price: return ("commerce", "price")
      case .color: return ("commerce", "color")
      case .department: return ("commerce", "department")
      case .word: return ("lorem", "word")
      case .sentence: return ("lorem", "sentence")
      case .paragraph: return ("lorem", "paragraph")
      }
    }
  }

  public enum IntModifier {
    case range(ExprSyntax)  // ClosedRange or Range
    case positive
    case negative
    case nonZero
  }

  public enum DoubleModifier {
    case range(ExprSyntax)
  }

  public enum StringModifier {
    case length(ExprSyntax)  // Int or Range
    case ascii
    case alphanumeric
    case email
    case uuidFormat
  }

  public enum CountModifier {
    case fixed(Int)
    case range(ExprSyntax)
  }

  // MARK: - Parsing

  /// Parse a @Gen attribute expression into a ParsedGenerator
  public static func parse(from attribute: AttributeSyntax) -> ParsedGenerator? {
    guard case .argumentList(let args) = attribute.arguments,
      let firstArg = args.first
    else {
      return nil
    }

    return parseExpression(firstArg.expression)
  }

  /// Parse an expression into a ParsedGenerator
  public static func parseExpression(_ expr: ExprSyntax) -> ParsedGenerator? {
    // Check for member access: .int, .string, etc.
    if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
      return parseMemberAccess(memberAccess)
    }

    // Check for function call: .int(in: 0...100), .array(of: .int)
    if let funcCall = expr.as(FunctionCallExprSyntax.self) {
      return parseFunctionCall(funcCall)
    }

    return nil
  }

  // MARK: - Member Access Parsing

  // swiftlint:disable:next cyclomatic_complexity
  private static func parseMemberAccess(_ expr: MemberAccessExprSyntax) -> ParsedGenerator? {
    if let fakeGen = parseFakeChain(expr) {
      return .fake(fakeGen)
    }

    let name = expr.declName.baseName.text

    switch name {
    // Primitives without arguments
    case "int": return .int(nil)
    case "uint": return .uint
    case "bool": return .bool
    case "double": return .double(nil)
    case "float": return .float
    case "string": return .string(nil)
    case "character": return .character
    case "uuid": return .uuid
    case "date": return .date
    case "data": return .data
    case "url": return .url
    case "none": return ParsedGenerator.none

    // Int modifiers
    case "positive": return .int(.positive)
    case "negative": return .int(.negative)
    case "nonZero": return .int(.nonZero)

    // String modifiers
    case "ascii": return .string(.ascii)
    case "alphanumeric": return .string(.alphanumeric)
    case "email": return .string(.email)

    default:
      if let fakeGen = parseFakeShorthand(name) {
        return .fake(fakeGen)
      }
      return nil
    }
  }

  private static func parseFakeChain(_ expr: MemberAccessExprSyntax) -> FakeGenerator? {
    let member = expr.declName.baseName.text

    guard let categoryAccess = expr.base?.as(MemberAccessExprSyntax.self) else {
      return nil
    }

    let category = categoryAccess.declName.baseName.text

    guard let fakeAccess = categoryAccess.base?.as(MemberAccessExprSyntax.self),
      fakeAccess.declName.baseName.text == "fake"
    else {
      return nil
    }

    return fakeGeneratorFromCategoryAndMember(category: category, member: member)
  }

  // swiftlint:disable:next cyclomatic_complexity
  private static func fakeGeneratorFromCategoryAndMember(
    category: String,
    member: String
  ) -> FakeGenerator? {
    switch (category, member) {
    case ("name", "firstName"): return .firstName
    case ("name", "lastName"): return .lastName
    case ("name", "fullName"): return .fullName
    case ("name", "prefix"): return .namePrefix
    case ("name", "suffix"): return .nameSuffix
    case ("address", "city"): return .city
    case ("address", "streetName"): return .streetName
    case ("address", "streetAddress"): return .streetAddress
    case ("address", "zipCode"): return .zipCode
    case ("address", "state"): return .state
    case ("address", "country"): return .country
    case ("address", "latitude"): return .latitude
    case ("address", "longitude"): return .longitude
    case ("internet", "email"): return .email
    case ("internet", "username"): return .username
    case ("internet", "domainName"): return .domainName
    case ("internet", "url"): return .url
    case ("internet", "ipV4Address"): return .ipV4Address
    case ("internet", "ipV6Address"): return .ipV6Address
    case ("internet", "password"): return .password
    case ("company", "name"): return .companyName
    case ("company", "suffix"): return .companySuffix
    case ("company", "catchPhrase"): return .catchPhrase
    case ("company", "bs"): return .bs
    case ("commerce", "productName"): return .productName
    case ("commerce", "price"): return .price
    case ("commerce", "color"): return .color
    case ("commerce", "department"): return .department
    case ("lorem", "word"): return .word
    case ("lorem", "sentence"): return .sentence
    case ("lorem", "paragraph"): return .paragraph
    default: return nil
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private static func parseFakeShorthand(_ name: String) -> FakeGenerator? {
    switch name {
    case "firstName": return .firstName
    case "lastName": return .lastName
    case "fullName": return .fullName
    case "namePrefix": return .namePrefix
    case "nameSuffix": return .nameSuffix
    case "city": return .city
    case "streetName": return .streetName
    case "streetAddress": return .streetAddress
    case "zipCode": return .zipCode
    case "state": return .state
    case "country": return .country
    case "latitude": return .latitude
    case "longitude": return .longitude
    case "username": return .username
    case "domainName": return .domainName
    case "ipV4Address": return .ipV4Address
    case "ipV6Address": return .ipV6Address
    case "password": return .password
    case "companyName": return .companyName
    case "companySuffix": return .companySuffix
    case "catchPhrase": return .catchPhrase
    case "bs": return .bs
    case "productName": return .productName
    case "price": return .price
    case "color": return .color
    case "department": return .department
    case "word": return .word
    case "sentence": return .sentence
    case "paragraph": return .paragraph
    default: return nil
    }
  }

  // MARK: - Function Call Parsing

  // swiftlint:disable:next cyclomatic_complexity
  private static func parseFunctionCall(_ expr: FunctionCallExprSyntax) -> ParsedGenerator? {
    guard let memberAccess = expr.calledExpression.as(MemberAccessExprSyntax.self) else {
      return nil
    }

    let name = memberAccess.declName.baseName.text
    let args = Array(expr.arguments)

    switch name {
    // Int with range: .int(in: 0...100)
    case "int":
      if let rangeArg = findArgument(labeled: "in", in: args) {
        return .int(.range(rangeArg))
      }
      // Check for modifier: .int(.positive)
      if let firstArg = args.first,
        firstArg.label == nil,
        let parsed = parseExpression(firstArg.expression),
        case .int(let mod) = parsed
      {
        return .int(mod)
      }
      return .int(nil)

    // Double with range: .double(in: 0.0...1.0)
    case "double":
      if let rangeArg = findArgument(labeled: "in", in: args) {
        return .double(.range(rangeArg))
      }
      return .double(nil)

    // String with modifiers
    case "string":
      if let lengthArg = findArgument(labeled: "length", in: args) {
        return .string(.length(lengthArg))
      }
      // Check for modifier: .string(.ascii)
      if let firstArg = args.first,
        firstArg.label == nil,
        let parsed = parseExpression(firstArg.expression),
        case .string(let mod) = parsed
      {
        return .string(mod)
      }
      return .string(nil)

    // Array: .array(of: .int), .array(of: .int, count: 5)
    case "array":
      guard let elementArg = findArgument(labeled: "of", in: args),
        let elementGen = parseExpression(elementArg)
      else {
        return nil
      }

      let countMod: CountModifier?
      if let countArg = findArgument(labeled: "count", in: args) {
        if let intLiteral = countArg.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          countMod = .fixed(value)
        } else {
          countMod = .range(countArg)
        }
      } else {
        countMod = nil
      }

      return .array(element: elementGen, count: countMod)

    // Set: .set(of: .int)
    case "set":
      guard let elementArg = findArgument(labeled: "of", in: args),
        let elementGen = parseExpression(elementArg)
      else {
        return nil
      }
      return .set(element: elementGen)

    // Dictionary: .dictionary(keys: .string, values: .int)
    case "dictionary":
      guard let keysArg = findArgument(labeled: "keys", in: args),
        let keyGen = parseExpression(keysArg),
        let valuesArg = findArgument(labeled: "values", in: args),
        let valueGen = parseExpression(valuesArg)
      else {
        return nil
      }
      return .dictionary(key: keyGen, value: valueGen)

    // Optional: .optional(.string)
    case "optional":
      guard let firstArg = args.first,
        let innerGen = parseExpression(firstArg.expression)
      else {
        return nil
      }
      return .optional(innerGen)

    // Some: .some(.string)
    case "some":
      guard let firstArg = args.first,
        let innerGen = parseExpression(firstArg.expression)
      else {
        return nil
      }
      return .some(innerGen)

    // OneOf: .oneOf([.int, .string])
    case "oneOf":
      guard let firstArg = args.first,
        let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self)
      else {
        return nil
      }

      var generators: [ParsedGenerator] = []
      for element in arrayExpr.elements {
        if let parsed = parseExpression(element.expression) {
          generators.append(parsed)
        }
      }

      return generators.isEmpty ? nil : .oneOf(generators)

    // Frequency: .frequency([(3, .int), (1, .string)])
    case "frequency":
      guard let firstArg = args.first,
        let arrayExpr = firstArg.expression.as(ArrayExprSyntax.self)
      else {
        return nil
      }

      var weighted: [(Int, ParsedGenerator)] = []
      for element in arrayExpr.elements {
        if let tuple = element.expression.as(TupleExprSyntax.self),
          tuple.elements.count == 2,
          let weightExpr = tuple.elements.first?.expression.as(IntegerLiteralExprSyntax.self),
          let weight = Int(weightExpr.literal.text),
          let genExpr = tuple.elements.dropFirst().first?.expression,
          let parsed = parseExpression(genExpr)
        {
          weighted.append((weight, parsed))
        }
      }

      return weighted.isEmpty ? nil : .frequency(weighted)

    // Custom: .custom { rng, size in ... }
    case "custom":
      if let closure = expr.trailingClosure {
        return .custom(ExprSyntax(closure))
      }
      return nil

    default:
      return nil
    }
  }

  // MARK: - Helper Methods

  private static func findArgument(
    labeled label: String,
    in args: [LabeledExprSyntax]
  ) -> ExprSyntax? {
    args.first { $0.label?.text == label }?.expression
  }
}

// MARK: - Code Generation

extension GeneratorDSL {

  /// Generate SwiftSyntax expression for a parsed generator
  // swiftlint:disable:next cyclomatic_complexity
  public static func generateCode(for parsed: ParsedGenerator) -> ExprSyntax {
    switch parsed {
    // Primitives
    case .int(let modifier):
      return generateIntGenerator(modifier)

    case .uint:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<UInt>", member: "uint"))

    case .bool:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Bool>", member: "bool"))

    case .double(let modifier):
      return generateDoubleGenerator(modifier)

    case .float:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Float>", member: "float"))

    case .string(let modifier):
      return generateStringGenerator(modifier)

    case .character:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Character>", member: "letter"))

    case .uuid:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<UUID>", member: "uuid"))

    case .date:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Date>", member: "date"))

    case .data:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Data>", member: "data"))

    case .url:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<URL>", member: "url"))

    // Collections
    case .array(let element, let count):
      return generateArrayGenerator(element: element, count: count)

    case .set(let element):
      return generateSetGenerator(element: element)

    case .dictionary(let key, let value):
      return generateDictionaryGenerator(key: key, value: value)

    // Optionals
    case .optional(let inner):
      let innerCode = generateCode(for: inner)
      return FunctionCallBuilder(type: "Gen", member: "optional")
        .arg(innerCode)
        .buildExpr()

    case .some(let inner):
      let innerCode = generateCode(for: inner)
      return FunctionCallBuilder(type: "Gen", member: "some")
        .arg(innerCode)
        .buildExpr()

    case .none:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen", member: "none"))

    // Combinators
    case .oneOf(let generators):
      let genExprs = generators.map { generateCode(for: $0) }
      let arrayExpr = ArrayExprSyntax(
        elements: ArrayElementListSyntax {
          for expr in genExprs {
            ArrayElementSyntax(expression: expr)
          }
        }
      )
      return FunctionCallBuilder(type: "Gen", member: "oneOf")
        .arg(ExprSyntax(arrayExpr))
        .buildExpr()

    case .frequency(let weighted):
      let tupleExprs = weighted.map { weight, gen -> ExprSyntax in
        let genCode = generateCode(for: gen)
        return ExprSyntax(
          TupleExprSyntax(
            elements: LabeledExprListSyntax {
              LabeledExprSyntax(expression: SyntaxFactory.intLiteral(weight))
              LabeledExprSyntax(expression: genCode)
            }
          )
        )
      }
      let arrayExpr = ArrayExprSyntax(
        elements: ArrayElementListSyntax {
          for expr in tupleExprs {
            ArrayElementSyntax(expression: expr)
          }
        }
      )
      return FunctionCallBuilder(type: "Gen", member: "frequency")
        .arg(ExprSyntax(arrayExpr))
        .buildExpr()

    case .custom(let expr):
      return FunctionCallBuilder("Gen")
        .arg(expr)
        .buildExpr()

    case .arbitrary(let typeName):
      return ExprSyntax(SyntaxFactory.memberAccess(type: typeName, member: "arbitrary"))

    case .fake(let fakeGen):
      return generateFakeGenerator(fakeGen)
    }
  }

  private static func generateFakeGenerator(_ fakeGen: FakeGenerator) -> ExprSyntax {
    let (category, member) = fakeGen.categoryAndMember
    return ExprSyntax(
      MemberAccessExprSyntax(
        base: MemberAccessExprSyntax(
          base: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("Gen")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("fake"))
          ),
          declName: DeclReferenceExprSyntax(baseName: .identifier(category))
        ),
        declName: DeclReferenceExprSyntax(baseName: .identifier(member))
      )
    )
  }

  // MARK: - Specific Generator Builders

  private static func generateIntGenerator(_ modifier: IntModifier?) -> ExprSyntax {
    guard let modifier = modifier else {
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Int>", member: "int"))
    }

    switch modifier {
    case .range(let rangeExpr):
      return FunctionCallBuilder(type: "Gen<Int>", member: "int")
        .arg("in", rangeExpr)
        .buildExpr()

    case .positive:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Int>", member: "positiveInt"))

    case .negative:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Int>", member: "negativeInt"))

    case .nonZero:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Int>", member: "nonZeroInt"))
    }
  }

  private static func generateDoubleGenerator(_ modifier: DoubleModifier?) -> ExprSyntax {
    guard let modifier = modifier else {
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<Double>", member: "double"))
    }

    switch modifier {
    case .range(let rangeExpr):
      return FunctionCallBuilder(type: "Gen<Double>", member: "double")
        .arg("in", rangeExpr)
        .buildExpr()
    }
  }

  private static func generateStringGenerator(_ modifier: StringModifier?) -> ExprSyntax {
    guard let modifier = modifier else {
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<String>", member: "string"))
    }

    switch modifier {
    case .length(let lengthExpr):
      return FunctionCallBuilder(type: "Gen<String>", member: "string")
        .arg("length", lengthExpr)
        .buildExpr()

    case .ascii:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<String>", member: "asciiString"))

    case .alphanumeric:
      return ExprSyntax(
        SyntaxFactory.memberAccess(type: "Gen<String>", member: "alphanumericString")
      )

    case .email:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<String>", member: "email"))

    case .uuidFormat:
      return ExprSyntax(SyntaxFactory.memberAccess(type: "Gen<String>", member: "uuidString"))
    }
  }

  private static func generateArrayGenerator(
    element: ParsedGenerator,
    count: CountModifier?
  ) -> ExprSyntax {
    let elementCode = generateCode(for: element)

    var builder = FunctionCallBuilder(type: "Gen", member: "array")
      .arg(elementCode)

    if let count = count {
      switch count {
      case .fixed(let value):
        builder = builder.arg("count", int: value)

      case .range(let rangeExpr):
        builder = builder.arg("count", rangeExpr)
      }
    }

    return builder.buildExpr()
  }

  private static func generateSetGenerator(element: ParsedGenerator) -> ExprSyntax {
    let elementCode = generateCode(for: element)
    return FunctionCallBuilder(type: "Gen", member: "set")
      .arg(elementCode)
      .buildExpr()
  }

  private static func generateDictionaryGenerator(
    key: ParsedGenerator,
    value: ParsedGenerator
  ) -> ExprSyntax {
    let keyCode = generateCode(for: key)
    let valueCode = generateCode(for: value)
    return FunctionCallBuilder(type: "Gen", member: "dictionary")
      .arg(keyCode)
      .arg(valueCode)
      .buildExpr()
  }
  // swiftlint:disable:next file_length
}
