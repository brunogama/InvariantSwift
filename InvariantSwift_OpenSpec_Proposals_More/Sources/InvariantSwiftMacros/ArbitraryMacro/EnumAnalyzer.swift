import SwiftSyntax
import SwiftSyntaxBuilder

struct AnalyzedEnumCase {
  let name: String
  let associatedValues: [AnalyzedAssociatedValue]

  var hasAssociatedValues: Bool {
    !associatedValues.isEmpty
  }
}

struct AnalyzedAssociatedValue {
  let label: String?
  let type: TypeSyntax
}

enum EnumAnalyzer {

  static func extractCases(from enumDecl: EnumDeclSyntax) -> [AnalyzedEnumCase] {
    var cases: [AnalyzedEnumCase] = []

    for member in enumDecl.memberBlock.members {
      guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
        continue
      }

      for element in caseDecl.elements {
        let caseName = element.name.text

        var associatedValues: [AnalyzedAssociatedValue] = []
        if let paramClause = element.parameterClause {
          for param in paramClause.parameters {
            associatedValues.append(
              AnalyzedAssociatedValue(
                label: param.firstName?.text,
                type: param.type
              )
            )
          }
        }

        cases.append(
          AnalyzedEnumCase(
            name: caseName,
            associatedValues: associatedValues
          )
        )
      }
    }

    return cases
  }
}
