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

    var members: [DeclSyntax] = []

    // Property wrappers copied onto the session type so user code can declare tools/groundings/structured outputs.
    members.append(
      """
      @propertyWrapper
      struct Tool<ToolType: FoundationModels.Tool> where ToolType.Arguments: Generable, ToolType.Output: Generable {
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

    members.append(
      """
      typealias Adapter = \(raw: provider.adapterTypeName)
      """,
    )

    members.append(
      """
      typealias ProviderType = \(raw: classDeclaration.name.text)
      """,
    )

    // Store the chosen adapter and observation-aware state the macro manages.
    members.append(
      """
      let adapter: \(raw: provider.adapterTypeName)
      """,
    )

    members.append(contentsOf:
      generateObservableMembers(
        named: "transcript",
        type: "SwiftAgent.Transcript",
        initialValue: "Transcript()",
        actorAttribute: "@MainActor",
      ))

    members.append(contentsOf:
      generateObservableMembers(
        named: "tokenUsage",
        type: "TokenUsage",
        initialValue: "TokenUsage()",
        actorAttribute: "@MainActor",
      ))

    members.append(
      """
      let tools: [any SwiftAgentTool]
      """,
    )

    members.append(
      """
      let decodableTools: [any DecodableTool<ProviderType>]
      """,
    )

    members.append(
      generateStructuredOutputsProperty(for: structuredOutputProperties),
    )

    members.append(contentsOf: generateObservationSupportMembers())

    // Emit initializers, grounding source types, and tool wrappers derived from the user's declarations.
    try members.append(contentsOf:
      generateInitializers(
        for: toolProperties,
        provider: provider,
      ))

    members.append(generateDecodedGroundingEnum(for: groundingProperties))

    members.append(generateDecodedToolRunEnum(for: toolProperties))
    members.append(contentsOf: toolProperties.map(Self.generateDecodableWrapper))

    // Structured Output typing support
    members.append(generateDecodedStructuredOutputEnum(for: structuredOutputProperties))
    members.append(contentsOf: generateDecodableStructuredOutputTypes(for: structuredOutputProperties))

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

    if
      let classDeclaration = declaration.as(ClassDeclSyntax.self),
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
