// MARK: - TestCodeGenerator Scaffold Extension
// Renders `Generatable` scaffolds for types whose generators need a human.

import InvariantSwiftExpansionSupport

extension TestCodeGenerator {
  /// Renders a `Generatable` extension, including TODO placeholders when requested directly.
  public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
    generateArbitraryExtensionResult(for: type).code
  }

  /// Renders a `Generatable` extension and reports properties needing custom generators.
  public func generateArbitraryExtensionResult(
    for type: ExtractedTypeInfo
  ) -> ArbitraryGenerationResult {
    var todoProperties: [String] = []
    let arbitraryExtension = plannedArbitraryExtension(
      for: type,
      identity: GeneratedTypeIdentity(type: type),
      todoProperties: &todoProperties
    )

    return ArbitraryGenerationResult(
      code: GhostwriterExpansionRenderer.render(arbitraryExtension: arbitraryExtension),
      todoProperties: todoProperties
    )
  }

  /// Renders a `Generatable` scaffold for a type the generator cannot yet
  /// synthesize, carrying TODO guidance for the initializer or invariants
  /// the composed expression does not satisfy.
  public func generateGeneratorScaffold(for type: ExtractedTypeInfo) -> String {
    let scaffold = plannedScaffoldExtension(for: type)
    return GhostwriterExpansionRenderer.render(arbitraryExtension: scaffold)
  }

  /// Builds the scaffold plan: the composed extension plus TODO guidance.
  func plannedScaffoldExtension(
    for type: ExtractedTypeInfo
  ) -> GhostwriterGeneratedArbitraryExtension {
    var todoProperties: [String] = []
    return plannedArbitraryExtension(
      for: type,
      identity: GeneratedTypeIdentity(type: type),
      todoProperties: &todoProperties,
      todoComment: scaffoldGuidance(for: type)
    )
  }

  /// Explains why the composed generator cannot serve the type as-is.
  private func scaffoldGuidance(for type: ExtractedTypeInfo) -> String {
    let initializers = type.methods.filter { $0.name.hasPrefix("init") }
    let memberwiseMatch = initializers.contains { initializer in
      initializer.name == "init"
        && initializer.parameters.map(\.label) == type.properties.map(\.name)
    }
    if memberwiseMatch {
      return Self.todoCommentPrefix
        + "a stored property needs a generator this tool cannot synthesize;"
        + " replace the composed expression with one that produces valid values."
    }
    return Self.todoCommentPrefix
      + "`\(type.name)` does not expose a plain memberwise initializer"
      + " (its initializers are failable, throwing, or differently labelled);"
      + " replace the composed expression with one that constructs valid"
      + " values, for example by generating inputs and mapping through"
      + " the validating initializer."
  }

  /// Prefix placed on scaffold TODO guidance comments.
  private static let todoCommentPrefix = "TODO: Ghostwriter scaffold: "
}
