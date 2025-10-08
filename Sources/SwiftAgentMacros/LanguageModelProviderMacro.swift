// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Provider type enumeration for different AI providers
enum Provider: String {
  case openAI

  var adapterTypeName: String {
    switch self {
    case .openAI: "OpenAIAdapter"
    }
  }

  var configurationTypeName: String {
    switch self {
    case .openAI: "OpenAIConfiguration"
    }
  }
}

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
    if let observableAttribute = attribute(
      named: "Observable",
      in: classDeclaration.attributes,
    ) {
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
      struct StructuredOutput<Schema: Generable> {
        var wrappedValue: Schema.Type
        init(_ wrappedValue: Schema.Type) { self.wrappedValue = wrappedValue }
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
      let tools: [any ResolvableTool<ProviderType>]
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

    members.append(generateGroundingRepresentationEnum(for: groundingProperties))

    members.append(generateResolvedToolRunEnum(for: toolProperties))
    members.append(contentsOf: toolProperties.map(Self.generateResolvableWrapper))

    // Structured Output typing support
    members.append(generateResolvedStructuredOutputEnum(for: structuredOutputProperties))
    members.append(contentsOf: generateResolvableStructuredOutputTypes(for: structuredOutputProperties))

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
    var structuredOutputProperties: [StructuredOutputProperty] = []

    if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
      structuredOutputProperties = try extractStructuredOutputProperties(from: classDeclaration)
      if !structuredOutputProperties.isEmpty {
        conformances.append("SupportsStructuredOutputs")
      }
    }

    let extensionDecl: DeclSyntax =
      """
      extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {}
      """

    guard let baseExtensionDecl = extensionDecl.as(ExtensionDeclSyntax.self) else {
      return []
    }

    var extensions: [ExtensionDeclSyntax] = [baseExtensionDecl]

    if let classDeclaration = declaration.as(ClassDeclSyntax.self) {
      extensions.append(
        contentsOf: generateStructuredOutputRepresentationExtensions(
          for: classDeclaration.name.text,
          outputs: structuredOutputProperties,
        ),
      )
    }

    return extensions
  }

  /// Captures information about a `@Tool` property declared on the session type.
  private struct ToolProperty {
    let identifier: TokenSyntax
    let typeName: String
    let hasInitializer: Bool
  }

  /// Captures information about a `@Grounding` property declared on the session type.
  private struct GroundingProperty {
    let identifier: TokenSyntax
    let typeName: String
  }

  /// Captures information about a `@StructuredOutput` property declared on the session type.
  private struct StructuredOutputProperty {
    let identifier: TokenSyntax
    let typeName: String
  }

  /// Checks whether an attribute list already contains an attribute with the provided base name.
  private static func attributeList(
    _ attributes: AttributeListSyntax?,
    containsAttributeNamed name: String,
  ) -> Bool {
    guard let attributes else {
      return false
    }

    return attributes.contains { attribute in
      guard let attributeSyntax = attribute.as(AttributeSyntax.self) else {
        return false
      }

      return attributeBaseName(attributeSyntax) == name
    }
  }

  /// Finds every `@Tool` property on the session declaration and records essential metadata.
  private static func extractToolProperties(from classDeclaration: ClassDeclSyntax) throws -> [ToolProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }

      let hasToolAttribute = attributeList(
        variableDecl.attributes,
        containsAttributeNamed: "Tool",
      )

      guard hasToolAttribute else {
        return nil
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName: String
      if let typeAnnotation = binding.typeAnnotation {
        typeName = typeAnnotation.type.trimmedDescription
      } else if let initializer = binding.initializer {
        if let functionCall = initializer.value.as(FunctionCallExprSyntax.self) {
          typeName = functionCall.calledExpression.trimmedDescription
        } else {
          throw MacroError.cannotInferType(node: Syntax(initializer.value)).asDiagnosticsError()
        }
      } else {
        throw MacroError.missingTypeAnnotation(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      return ToolProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
        hasInitializer: binding.initializer != nil,
      )
    }
  }

  /// Collects `@Grounding` declarations to drive `GroundingRepresentation` synthesis.
  private static func extractGroundingProperties(from classDeclaration: ClassDeclSyntax) throws -> [GroundingProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard let groundingAttribute = attribute(named: "Grounding", in: variableDecl.attributes) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName = try extractGroundingTypeName(from: groundingAttribute)

      return GroundingProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
      )
    }
  }

  /// Collects `@StructuredOutput` declarations to drive typed response synthesis.
  private static func extractStructuredOutputProperties(from classDeclaration: ClassDeclSyntax) throws
    -> [StructuredOutputProperty] {
    try classDeclaration.memberBlock.members.compactMap { member in
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
        return nil
      }
      guard let structuredOutputAttribute = attribute(named: "StructuredOutput", in: variableDecl.attributes) else {
        return nil
      }
      guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
        throw MacroError.mustBeVar(node: Syntax(variableDecl.bindingSpecifier)).asDiagnosticsError()
      }
      guard let binding = variableDecl.bindings.first else {
        throw MacroError.noBinding(node: Syntax(variableDecl)).asDiagnosticsError()
      }
      guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        throw MacroError.invalidPattern(node: Syntax(binding.pattern)).asDiagnosticsError()
      }

      let typeName = try extractGroundingTypeName(from: structuredOutputAttribute)

      return StructuredOutputProperty(
        identifier: identifierPattern.identifier,
        typeName: typeName,
      )
    }
  }

  /// Reads the provider argument from the macro attribute, if one was supplied.
  private static func extractProvider(from attribute: AttributeSyntax) throws -> Provider {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
          let providerArgument = arguments.first
    else {
      throw MacroError.missingProvider(node: Syntax(attribute)).asDiagnosticsError()
    }

    if let label = providerArgument.label, label.text != "for" {
      throw MacroError.invalidProvider(node: Syntax(providerArgument)).asDiagnosticsError()
    }
    guard let memberAccess = providerArgument.expression.as(MemberAccessExprSyntax.self) else {
      throw MacroError.invalidProvider(node: Syntax(providerArgument.expression)).asDiagnosticsError()
    }

    let providerName = memberAccess.declName.baseName.text

    guard let provider = Provider(rawValue: providerName) else {
      throw MacroError.invalidProvider(node: Syntax(memberAccess)).asDiagnosticsError()
    }

    return provider
  }

  /// Returns the first attribute with the given name from an attribute list, if present.
  private static func attribute(
    named name: String,
    in attributes: AttributeListSyntax?,
  ) -> AttributeSyntax? {
    attributes?
      .compactMap { $0.as(AttributeSyntax.self) }
      .first(where: { attributeBaseName($0) == name })
  }

  /// Extracts the last path component of an attribute name, stripping generic arguments and parens.
  private static func attributeBaseName(_ attribute: AttributeSyntax) -> String {
    baseName(from: attribute.attributeName)
  }

  /// Extracts the simple base name from a potentially qualified type or attribute.
  private static func baseName(from type: TypeSyntax) -> String {
    let description = type.trimmedDescription
    guard !description.isEmpty else {
      return description
    }

    let components = description.split(separator: ".")
    guard let lastComponent = components.last else {
      return description
    }

    let sanitizedComponent = lastComponent
      .split(separator: "(")
      .first?
      .split(separator: "<")
      .first

    return String(sanitizedComponent ?? lastComponent)
  }

  /// Pulls the concrete type referenced by a `@Grounding` attribute argument.
  private static func extractGroundingTypeName(from attribute: AttributeSyntax) throws -> String {
    guard let arguments = attribute.arguments else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard case let .argumentList(argumentList) = arguments else {
      throw MacroError.invalidGroundingAttribute(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard argumentList.count == 1, let argument = argumentList.first else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }
    guard argument.label == nil else {
      throw MacroError.invalidGroundingAttribute(node: Syntax(attribute)).asDiagnosticsError()
    }

    let content = argument.expression.trimmedDescription

    guard content.hasSuffix(".self") else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }

    let typeName = content.dropLast(".self".count)

    guard !typeName.isEmpty else {
      throw MacroError.missingGroundingType(node: Syntax(attribute)).asDiagnosticsError()
    }

    return String(typeName)
  }

  /// Builds the `init` overloads that wire tools into the adapter and configure credentials.
  private static func generateInitializers(
    for tools: [ToolProperty],
    provider: Provider,
  ) throws -> [DeclSyntax] {
    var initializers: [DeclSyntax] = []

    // Capture parameter metadata so we can drive wrapper creation and initializer signatures.
    let toolParameters = tools.map { tool in
      (
        name: tool.identifier.text,
        type: tool.typeName,
        hasInitializer: tool.hasInitializer,
      )
    }

    // Populate stored wrappers for tools that must be injected by the initializer.
    let wrapperAssignments = toolParameters
      .compactMap { parameter in
        guard !parameter.hasInitializer else {
          return nil
        }

        return "  _\(parameter.name) = Tool(wrappedValue: \(parameter.name))"
      }
      .joined(separator: "\n")

    let initializerPrologueBlock = wrapperAssignments.isEmpty
      ? ""
      : "\(wrapperAssignments)\n\n"

    let toolsArrayInit = toolParameters.map { parameter in
      let wrapperName = "Resolvable\(parameter.name.capitalizedFirstLetter())Tool"
      let baseToolExpression = parameter.hasInitializer
        ? "_\(parameter.name).wrappedValue"
        : parameter.name
      // Wrap each declared tool so we can hand it to the adapter as a `ResolvableTool`.
      return "      \(wrapperName)(baseTool: \(baseToolExpression))"
    }
    .joined(separator: ",\n")

    // Construct the literal array so the adapter receives every tool in declaration order.
    let toolsArrayCode = toolsArrayInit.isEmpty ? "[]" : "[\n\(toolsArrayInit)\n    ]"

    let initParameters = toolParameters
      .filter { !$0.hasInitializer }
      .map { "    \($0.name): \($0.type)" }
      .joined(separator: ",\n")

    let allInitParameters = initParameters.isEmpty
      ? "instructions: String,\n    apiKey: String"
      : "\(initParameters),\n    instructions: String,\n    apiKey: String"

    // Base initializer wires direct API key authentication through the generated adapter.
    initializers.append(
      """
      	init(
      	\(raw: allInitParameters)
      	) {
        \(raw: initializerPrologueBlock)  let tools: [any ResolvableTool<ProviderType>] = \(raw: toolsArrayCode)
        self.tools = tools

        adapter = \(raw: provider.adapterTypeName)(
      		tools: tools,
      		instructions: instructions,
      		configuration: .direct(apiKey: apiKey)
      	)
      }
      """,
    )

    let configurationInitParameters = initParameters.isEmpty
      ? "instructions: String,\n    configuration: \(provider.configurationTypeName)"
      : "\(initParameters),\n    instructions: String,\n    configuration: \(provider.configurationTypeName)"

    // Overload initializer accepts a fully-formed provider configuration instead.
    initializers.append(
      """
      	init(
      	\(raw: configurationInitParameters)
      	) {
        \(raw: initializerPrologueBlock)  let tools: [any ResolvableTool<ProviderType>] = \(raw: toolsArrayCode)
        self.tools = tools

        adapter = \(raw: provider.adapterTypeName)(
      		tools: tools,
      		instructions: instructions,
      		configuration: configuration
      	)
      }
      """,
    )

    return initializers
  }

  /// Produces the `ResolvedToolRun` enum mapping each tool wrapper to a case.
  private static func generateResolvedToolRunEnum(for tools: [ToolProperty]) -> DeclSyntax {
    let cases = tools.map { tool -> String in
      let wrapperName = "Resolvable\(tool.identifier.text.capitalizedFirstLetter())Tool"
      return "    case \(tool.identifier.text)(ToolRun<\(wrapperName)>)"
    }
    .joined(separator: "\n")

    let idSwitchCases = tools.map { tool -> String in
      return "        case let .\(tool.identifier.text)(run):\n            run.id"
    }
    .joined(separator: "\n")

    return
      """
      enum ResolvedToolRun: SwiftAgent.ResolvedToolRun {
      \(raw: cases)
      case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

      static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
      	.unknown(toolCall: toolCall)
      }

      var id: String {
      	switch self {
      \(raw: idSwitchCases)
      	case let .unknown(toolCall):
      		toolCall.id
      	}
      }
      }
      """
  }

  /// Emits the `GroundingRepresentation` enum used to send and receive grounding payloads.
  private static func generateGroundingRepresentationEnum(for groundings: [GroundingProperty]) -> DeclSyntax {
    guard !groundings.isEmpty else {
      return
        """
        enum GroundingRepresentation: GroundingRepresentable {
          init(from decoder: Decoder) throws {
            let context = DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "No @Grounding properties are defined, so no GroundingRepresentation can be decoded."
            )
            throw DecodingError.dataCorrupted(context)
          }

          func encode(to encoder: Encoder) throws {
            let context = EncodingError.Context(
              codingPath: encoder.codingPath,
              debugDescription: "No @Grounding properties are defined, so no GroundingRepresentation can be encoded."
            )
            throw EncodingError.invalidValue(self, context)
          }
        }
        """
    }

    let cases = groundings.map { grounding -> String in
      "    case \(grounding.identifier.text)(\(grounding.typeName))"
    }
    .joined(separator: "\n")

    return
      """
      enum GroundingRepresentation: GroundingRepresentable {
      \(raw: cases)
      }
      """
  }

  /// Wraps a user-declared tool so it can integrate with the provider's resolution APIs.
  private static func generateResolvableWrapper(for tool: ToolProperty) -> DeclSyntax {
    let wrapperName = "Resolvable\(tool.identifier.text.capitalizedFirstLetter())Tool"

    return
      """
      struct \(raw: wrapperName): ResolvableTool {
        typealias Provider = ProviderType
        typealias BaseTool = \(raw: tool.typeName)
        typealias Arguments = BaseTool.Arguments
        typealias Output = BaseTool.Output

        private let baseTool: BaseTool

        init(baseTool: \(raw: tool.typeName)) {
          self.baseTool = baseTool
        }

        var name: String {
          baseTool.name
        }

        var description: String {
          baseTool.description
        }

        var parameters: GenerationSchema {
          baseTool.parameters
        }

        func call(arguments: Arguments) async throws -> Output {
          try await baseTool.call(arguments: arguments)
        }

        func resolve(
          _ run: ToolRun<\(raw: wrapperName)>
        ) -> Provider.ResolvedToolRun {
          .\(raw: tool.identifier.text)(run)
        }
      }
      """
  }

  /// Emits a diagnostic when the user tries to opt out of observation for a property the macro manages.
  private static func diagnoseObservationIgnored(
    in classDeclaration: ClassDeclSyntax,
    context: some MacroExpansionContext,
  ) {
    for member in classDeclaration.memberBlock.members {
      guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
            let ignoredAttribute = attribute(
              named: "ObservationIgnored",
              in: variableDecl.attributes,
            )
      else {
        continue
      }

      MacroError.observationIgnored(node: Syntax(ignoredAttribute)).diagnose(in: context)
    }
  }

  /// Synthesizes stored and computed properties that bridge Observation to macro-managed members.
  private static func generateObservableMembers(
    named name: String,
    type: String,
    initialValue: String,
    actorAttribute: String,
  ) -> [DeclSyntax] {
    let storedProperty: DeclSyntax =
      """
      	\(raw: actorAttribute) private var _\(raw: name): \(raw: type) = \(raw: initialValue)
      """

    let keyPath = "\\.\(name)"
    let computedProperty: DeclSyntax =
      """
      \(raw: actorAttribute) var \(raw: name): \(raw: type) {
        @storageRestrictions(initializes: _\(raw: name))
        init(initialValue) {
          _\(raw: name) = initialValue
        }
        get {
          access(keyPath: \(raw: keyPath))
          return _\(raw: name)
        }
        set {
          guard shouldNotifyObservers(_\(raw: name), newValue) else {
            _\(raw: name) = newValue
            return
          }

          withMutation(keyPath: \(raw: keyPath)) {
            _\(raw: name) = newValue
          }
        }
        _modify {
          access(keyPath: \(raw: keyPath))
          _$observationRegistrar.willSet(self, keyPath: \(raw: keyPath))
          defer {
            _$observationRegistrar.didSet(self, keyPath: \(raw: keyPath))
          }
          yield &_\(raw: name)
        }
      }
      """

    return [storedProperty, computedProperty]
  }

  /// Adds the reusable observation registrar helpers shared by all generated sessions.
  private static func generateObservationSupportMembers() -> [DeclSyntax] {
    [
      """
      private let _$observationRegistrar = Observation.ObservationRegistrar()
      """,
      """
      nonisolated func access(
        keyPath: KeyPath<ProviderType, some Any>
      ) {
        _$observationRegistrar.access(self, keyPath: keyPath)
      }
      """,
      """
      nonisolated func withMutation<A>(
        keyPath: KeyPath<ProviderType, some Any>,
        _ mutation: () throws -> A
      ) rethrows -> A {
        try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        true
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: Equatable>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs != rhs
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: AnyObject>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs !== rhs
      }
      """,
      """
      private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
        _ lhs: A,
        _ rhs: A
      ) -> Bool {
        lhs != rhs
      }
      """,
    ]
  }

  // MARK: - Structured Output generation

  private static func generateStructuredOutputsProperty(
    for outputs: [StructuredOutputProperty],
  ) -> DeclSyntax {
    guard !outputs.isEmpty else {
      return """
      static let structuredOutputs: [any (SwiftAgent.ResolvableStructuredOutput<ProviderType>).Type] = []
      """
    }

    let entries = outputs
      .map { output in
        "    \(resolvableStructuredOutputTypeName(for: output)).self"
      }
      .joined(separator: "\n")

    return """
    static let structuredOutputs: [any (SwiftAgent.ResolvableStructuredOutput<ProviderType>).Type] = [
    \(raw: entries)
    ]
    """
  }

  private static func generateResolvedStructuredOutputEnum(
    for outputs: [StructuredOutputProperty],
  ) -> DeclSyntax {
    var sections: [String] = []

    if !outputs.isEmpty {
      let cases = outputs
        .map { output in
          let caseName = output.identifier.text
          let resolvableTypeName = resolvableStructuredOutputTypeName(for: output)
          return "    case \(caseName)(SwiftAgent.StructuredOutput<\(resolvableTypeName)>)"
        }
        .joined(separator: "\n")
      sections.append(cases)
    }

    sections.append("    case unknown(SwiftAgent.Transcript.StructuredSegment)")
    sections.append("")
    sections.append("    static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {")
    sections.append("        .unknown(segment)")
    sections.append("    }")

    let body = sections.joined(separator: "\n")

    return """
    enum ResolvedStructuredOutput: SwiftAgent.ResolvedStructuredOutput {
    \(raw: body)
    }
    """
  }

  private static func generateResolvableStructuredOutputTypes(
    for outputs: [StructuredOutputProperty],
  ) -> [DeclSyntax] {
    outputs.map { output in
      let resolvableName = resolvableStructuredOutputTypeName(for: output)
      let schemaType = output.typeName
      let caseName = output.identifier.text

      return """
      struct \(raw: resolvableName): SwiftAgent.ResolvableStructuredOutput {
        typealias Schema = \(raw: schemaType)
        typealias Provider = ProviderType
        static let name = "\(raw: caseName)"

        static func resolve(
          _ structuredOutput: SwiftAgent.StructuredOutput<\(raw: resolvableName)>
        ) -> ResolvedStructuredOutput {
          .\(raw: caseName)(structuredOutput)
        }
      }
      """
    }
  }

  /// Provides strongly-typed accessors for each structured output scoped to the provider.
  private static func generateStructuredOutputRepresentationExtensions(
    for providerTypeName: String,
    outputs: [StructuredOutputProperty],
  ) -> [ExtensionDeclSyntax] {
    outputs.compactMap { output in
      let schemaType = output.typeName
      let caseName = output.identifier.text
      let providerScopedResolvableName =
        "\(providerTypeName).\(resolvableStructuredOutputTypeName(for: output))"

      let extensionDecl: DeclSyntax =
        """
        extension SwiftAgent.StructuredOutputRepresentation where Provider == \(raw: providerTypeName),
          Schema == \(raw: schemaType) {
          static var \(raw: caseName): Self { .init(\(raw: providerScopedResolvableName).name) }
        }
        """

      return extensionDecl.as(ExtensionDeclSyntax.self)
    }
  }

  private static func resolvableStructuredOutputTypeName(for output: StructuredOutputProperty) -> String {
    "Resolvable\(output.identifier.text.capitalizedFirstLetter())"
  }
}
