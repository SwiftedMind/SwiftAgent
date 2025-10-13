// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Member macro that synthesizes the boilerplate required by `LanguageModelProvider`-conformant
/// sessions, including adapters, tool registries, observation plumbing, and grounding support.
public struct LanguageModelProviderMacro: MemberMacro, ExtensionMacro {
  /// Generates stored properties, type aliases, wrappers, and helper types for the annotated class.
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    // Macro only supports class declarations so we can synthesize stored members safely.
    guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
      throw MacroError.onlyApplicableToClass(node: Syntax(node)).asDiagnosticsError()
    }

    // Provider argument decides which adapter and configuration types get emitted.
    let provider = try extractProvider(from: node)

    // Surface diagnostics when the user adds conflicting observation attributes manually.
    if let observableAttribute = attribute(named: "Observable", in: classDeclaration.attributes) {
      MacroError.manualObservable(node: Syntax(observableAttribute), typeName: classDeclaration.name.text)
        .diagnose(in: context)
    }
    diagnoseObservationIgnored(in: classDeclaration, context: context)

    // Gather the declared tools and grounding sources up front so generation can reference them.
    let toolProperties = try extractToolProperties(from: classDeclaration)
    let groundingProperties = try extractGroundingProperties(from: classDeclaration)
    let structuredOutputProperties = try extractStructuredOutputProperties(from: classDeclaration)
    let accessModifier = Self.accessModifier(for: classDeclaration)
    let accessKeyword: (String) -> String = { baseKeyword in
      guard let accessModifier else {
        return baseKeyword
      }

      return "\(accessModifier) \(baseKeyword)"
    }

    var members: [DeclSyntax] = []

    // Type aliases
    members.append(
      """
      \(raw: accessKeyword("typealias")) Adapter = \(raw: provider.adapterTypeName)
      """,
    )

    members.append(
      """
      \(raw: accessKeyword("typealias")) ProviderType = \(raw: classDeclaration.name.text)
      """,
    )

    // Property wrappers copied onto the session type so user code can declare tools/groundings/structured outputs.
    members.append(
      """
      @propertyWrapper
      struct Tool<ToolType: FoundationModels.Tool>
      where ToolType.Arguments: Generable & Sendable, ToolType.Output: Generable & Sendable {
        var wrappedValue: ToolType
        init(wrappedValue: ToolType) { self.wrappedValue = wrappedValue }
      }
      """,
    )

    members.append(
      """
      @propertyWrapper
      struct StructuredOutput<Output: SwiftAgent.StructuredOutput> {
        typealias Generating<EnclosingSelf: LanguageModelProvider> = GeneratingLanguageModelProvider<EnclosingSelf, Output>
        private var output: Output.Type

        init(_ wrappedValue: Output.Type) {
          output = wrappedValue
        }

        static subscript<EnclosingSelf>(
          _enclosingInstance observed: EnclosingSelf,
          wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Generating<EnclosingSelf>>,
          storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, StructuredOutput<Output>>
        ) -> Generating<EnclosingSelf> where EnclosingSelf: LanguageModelProvider {
          get {
            let wrapper = observed[keyPath: storageKeyPath]
            return Generating(provider: observed, output: wrapper.output)
          }
          set {
            // Intentionally ignore external assignments to the wrapped value
          }
        }

        @available(*, unavailable, message: "This property wrapper can only be applied to classes")
        var wrappedValue: Generating<ProviderType> {
          get { fatalError() }
          set { fatalError() }
        }
      }
      """,
    )

    members.append(
      """
      @propertyWrapper
      struct Grounding<Source: Codable & Sendable & Equatable> {
        var wrappedValue: Source.Type
        init(_ wrappedValue: Source.Type) { self.wrappedValue = wrappedValue }
      }
      """,
    )

    // Stored properties
    members.append(
      """
      \(raw: accessKeyword("let")) adapter: \(raw: provider.adapterTypeName)
      """,
    )

    members.append(
      """
      \(raw: accessKeyword("let")) tools: [any SwiftAgentTool]
      """,
    )

    members.append(
      """
      \(raw: accessKeyword("let")) decodableTools: [any DecodableTool<ProviderType>]
      """,
    )

    members.append(
      generateStructuredOutputsProperty(for: structuredOutputProperties, accessModifier: accessModifier),
    )

    // Observable state
    members.append(
      """
      @MainActor @_LanguageModelProviderObserved(initialValue: Transcript())
      \(raw: accessKeyword("var")) transcript: SwiftAgent.Transcript
      """,
    )

    members.append(
      """
      @MainActor @_LanguageModelProviderObserved(initialValue: TokenUsage())
      \(raw: accessKeyword("var")) tokenUsage: TokenUsage
      """,
    )

    // Observation support members
    members.append(contentsOf: generateObservationSupportMembers())

    // Initializers
    try members.append(contentsOf:
      generateInitializers(
        for: toolProperties,
        provider: provider,
        accessModifier: accessModifier,
      ))

    // Supporting nested types
    members.append(generateDecodedGroundingType(for: groundingProperties, accessModifier: accessModifier))

    members.append(generateDecodedToolRunEnum(for: toolProperties, accessModifier: accessModifier))
    members.append(contentsOf: toolProperties.map { Self.generateDecodableWrapper(
      for: $0,
      accessModifier: accessModifier,
    ) })

    members.append(generateDecodedStructuredOutputEnum(for: structuredOutputProperties, accessModifier: accessModifier))
    members.append(contentsOf: generateDecodableStructuredOutputTypes(
      for: structuredOutputProperties,
      accessModifier: accessModifier,
    ))

    return members
  }

  /// Extends the annotated class to add the required protocol conformances produced by the macro.
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext,
  ) throws -> [ExtensionDeclSyntax] {
    var conformances = ["LanguageModelProvider", "@unchecked Sendable", "nonisolated Observation.Observable"]

    let classDeclaration = declaration.as(ClassDeclSyntax.self)
    if
      let classDeclaration,
      try extractStructuredOutputProperties(from: classDeclaration).isEmpty {
      conformances.append("SwiftAgent.RawStructuredOutputSupport")
    }

    let extensionDecl: DeclSyntax =
      """
      extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {}
      """

    guard let baseExtensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    return [baseExtensionDecl]
  }
}

extension LanguageModelProviderMacro {
  static func accessModifier(for classDeclaration: ClassDeclSyntax) -> String? {
    for modifier in classDeclaration.modifiers {
      switch modifier.name.tokenKind {
      case .keyword(.public), .keyword(.open):
        return "public"
      case .keyword(.package):
        return "package"
      default:
        continue
      }
    }

    return nil
  }
}
