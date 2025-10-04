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

/// Member macro that synthesizes LanguageModelProvider implementation
public struct LanguageModelProviderMacro: MemberMacro, ExtensionMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let classDeclaration = declaration.as(ClassDeclSyntax.self) else {
			throw MacroError.onlyApplicableToClass
		}
		guard let provider = try extractProvider(from: node) else {
			throw MacroError.missingProvider
		}

		if let observableAttribute = attribute(
			named: "Observable",
			in: classDeclaration.attributes
		) {
			diagnoseManualObservable(on: observableAttribute, typeName: classDeclaration.name.text, in: context)
		}
		diagnoseObservationIgnored(in: classDeclaration, context: context)

		let toolProperties = try extractToolProperties(from: classDeclaration)
		let groundingProperties = try extractGroundingProperties(from: classDeclaration)

		var members: [DeclSyntax] = []

		members.append(
			"""
			@propertyWrapper
			struct Tool<ToolType: SwiftAgentTool> {
			  var wrappedValue: ToolType
			  init(wrappedValue: ToolType) { self.wrappedValue = wrappedValue }
			}
			"""
		)

		members.append(
			"""
			@propertyWrapper
			struct Grounding<Source: Codable & Sendable & Equatable> {
			  var wrappedValue: Source.Type
			  init(_ wrappedValue: Source.Type) { self.wrappedValue = wrappedValue }
			}
			"""
		)

		members.append(
			"""
			typealias Adapter = \(raw: provider.adapterTypeName)
			"""
		)
		members.append(
			"""
			typealias SessionType = \(raw: classDeclaration.name.text)
			"""
		)

		members.append(
			"""
			let adapter: \(raw: provider.adapterTypeName)
			"""
		)
		members.append(contentsOf:
			generateObservableMembers(
				named: "transcript",
				type: "SwiftAgent.Transcript",
				initialValue: "Transcript()",
				actorAttribute: "@MainActor"
			))
		members.append(contentsOf:
			generateObservableMembers(
				named: "tokenUsage",
				type: "TokenUsage",
				initialValue: "TokenUsage()",
				actorAttribute: "@MainActor"
			))
		members.append(
			"""
			let tools: [any ResolvableTool<SessionType>]
			"""
		)

		members.append(contentsOf: generateObservationSupportMembers())

		try members.append(contentsOf:
			generateInitializers(
				for: toolProperties,
				provider: provider
			))

		members.append(generateGroundingSourceEnum(for: groundingProperties))

		members.append(generateResolvedToolRunEnum(for: toolProperties))
		members.append(generatePartiallyResolvedToolRunEnum(for: toolProperties))
		members.append(contentsOf: toolProperties.map(Self.generateResolvableWrapper))

		return members
	}

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		let conformances = ["LanguageModelProvider", "@unchecked Sendable", "nonisolated Observation.Observable"]

		let extensionDecl: DeclSyntax =
			"""
			extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {}
			"""

		guard let extensionDeclSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
			return []
		}

		return [extensionDeclSyntax]
	}

	private struct ToolProperty {
		let identifier: TokenSyntax
		let typeName: String
		let hasInitializer: Bool
	}

	private struct GroundingProperty {
		let identifier: TokenSyntax
		let typeName: String
	}

	private static func attributeList(
		_ attributes: AttributeListSyntax?,
		containsAttributeNamed name: String
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

	private static func extractToolProperties(from classDeclaration: ClassDeclSyntax) throws -> [ToolProperty] {
		try classDeclaration.memberBlock.members.compactMap { member in
			guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
				return nil
			}
			guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
				throw MacroError.mustBeVar
			}

			let hasToolAttribute = attributeList(
				variableDecl.attributes,
				containsAttributeNamed: "Tool"
			)

			guard hasToolAttribute else {
				return nil
			}
			guard let binding = variableDecl.bindings.first else {
				throw MacroError.noBinding
			}
			guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
				throw MacroError.invalidPattern
			}

			let typeName: String
			if let typeAnnotation = binding.typeAnnotation {
				typeName = typeAnnotation.type.trimmedDescription
			} else if let initializer = binding.initializer {
				if let functionCall = initializer.value.as(FunctionCallExprSyntax.self) {
					typeName = functionCall.calledExpression.trimmedDescription
				} else {
					throw MacroError.cannotInferType
				}
			} else {
				throw MacroError.missingTypeAnnotation
			}

			return ToolProperty(
				identifier: identifierPattern.identifier,
				typeName: typeName,
				hasInitializer: binding.initializer != nil
			)
		}
	}

	private static func extractGroundingProperties(from classDeclaration: ClassDeclSyntax) throws -> [GroundingProperty] {
		try classDeclaration.memberBlock.members.compactMap { member in
			guard let variableDecl = member.decl.as(VariableDeclSyntax.self) else {
				return nil
			}
			guard let groundingAttribute = attribute(named: "Grounding", in: variableDecl.attributes) else {
				return nil
			}
			guard variableDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
				throw MacroError.mustBeVar
			}
			guard let binding = variableDecl.bindings.first else {
				throw MacroError.noBinding
			}
			guard let identifierPattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
				throw MacroError.invalidPattern
			}

			let typeName = try extractGroundingTypeName(from: groundingAttribute)

			return GroundingProperty(
				identifier: identifierPattern.identifier,
				typeName: typeName
			)
		}
	}

	private static func extractProvider(from attribute: AttributeSyntax) throws -> Provider? {
		guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
		      let providerArgument = arguments.first
		else {
			return nil
		}
		guard let memberAccess = providerArgument.expression.as(MemberAccessExprSyntax.self) else {
			throw MacroError.invalidProvider
		}

		let providerName = memberAccess.declName.baseName.text

		guard let provider = Provider(rawValue: providerName) else {
			throw MacroError.invalidProvider
		}

		return provider
	}

	private static func attribute(
		named name: String,
		in attributes: AttributeListSyntax?
	) -> AttributeSyntax? {
		attributes?
			.compactMap { $0.as(AttributeSyntax.self) }
			.first(where: { attributeBaseName($0) == name })
	}

	private static func attributeBaseName(_ attribute: AttributeSyntax) -> String {
		baseName(from: attribute.attributeName)
	}

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

	private static func extractGroundingTypeName(from attribute: AttributeSyntax) throws -> String {
		guard let arguments = attribute.arguments else {
			throw MacroError.missingGroundingType
		}
		guard case let .argumentList(argumentList) = arguments else {
			throw MacroError.invalidGroundingAttribute
		}
		guard argumentList.count == 1, let argument = argumentList.first else {
			throw MacroError.missingGroundingType
		}
		guard argument.label == nil else {
			throw MacroError.invalidGroundingAttribute
		}

		let content = argument.expression.trimmedDescription

		guard content.hasSuffix(".self") else {
			throw MacroError.missingGroundingType
		}

		let typeName = content.dropLast(".self".count)

		guard !typeName.isEmpty else {
			throw MacroError.missingGroundingType
		}

		return String(typeName)
	}

	private static func generateInitializers(
		for tools: [ToolProperty],
		provider: Provider
	) throws -> [DeclSyntax] {
		var initializers: [DeclSyntax] = []

		let toolParameters = tools.map { tool in
			(
				name: tool.identifier.text,
				type: tool.typeName,
				hasInitializer: tool.hasInitializer
			)
		}

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
			return "      \(wrapperName)(baseTool: \(baseToolExpression))"
		}
		.joined(separator: ",\n")

		let toolsArrayCode = toolsArrayInit.isEmpty ? "[]" : "[\n\(toolsArrayInit)\n    ]"

		let initParameters = toolParameters
			.filter { !$0.hasInitializer }
			.map { "    \($0.name): \($0.type)" }
			.joined(separator: ",\n")

		let allInitParameters = initParameters.isEmpty
			? "instructions: String,\n    apiKey: String"
			: "\(initParameters),\n    instructions: String,\n    apiKey: String"

		initializers.append(
			"""
			init(
			\(raw: allInitParameters)
			) {
			  \(raw: initializerPrologueBlock)  let tools: [any ResolvableTool<SessionType>] = \(raw: toolsArrayCode)
			  self.tools = tools

			  adapter = \(raw: provider.adapterTypeName)(
					tools: tools,
					instructions: instructions,
					configuration: .direct(apiKey: apiKey)
				)
			}
			"""
		)

		let configurationInitParameters = initParameters.isEmpty
			? "instructions: String,\n    configuration: \(provider.configurationTypeName)"
			: "\(initParameters),\n    instructions: String,\n    configuration: \(provider.configurationTypeName)"

		initializers.append(
			"""
			init(
			\(raw: configurationInitParameters)
			) {
			  \(raw: initializerPrologueBlock)  let tools: [any ResolvableTool<SessionType>] = \(raw: toolsArrayCode)
			  self.tools = tools

			  adapter = \(raw: provider.adapterTypeName)(
					tools: tools,
					instructions: instructions,
					configuration: configuration
				)
			}
			"""
		)

		return initializers
	}

	private static func generateResolvedToolRunEnum(for tools: [ToolProperty]) -> DeclSyntax {
		let cases = tools.map { tool -> String in
			let wrapperName = "Resolvable\(tool.identifier.text.capitalizedFirstLetter())Tool"
			return "    case \(tool.identifier.text)(ToolRun<\(wrapperName)>)"
		}
		.joined(separator: "\n")

		return
			"""
			enum ResolvedToolRun: Equatable {
			\(raw: cases)
			}
			"""
	}

	private static func generatePartiallyResolvedToolRunEnum(for tools: [ToolProperty]) -> DeclSyntax {
		let cases = tools.map { tool -> String in
			let wrapperName = "Resolvable\(tool.identifier.text.capitalizedFirstLetter())Tool"
			return "    case \(tool.identifier.text)(PartialToolRun<\(wrapperName)>)"
		}
		.joined(separator: "\n")

		return
			"""
			enum PartiallyResolvedToolRun: Equatable {
			\(raw: cases)
			}
			"""
	}

	private static func generateGroundingSourceEnum(for groundings: [GroundingProperty]) -> DeclSyntax {
		guard !groundings.isEmpty else {
			return
				"""
				enum GroundingSource: GroundingRepresentable {
				  init(from decoder: Decoder) throws {
				    let context = DecodingError.Context(
				      codingPath: decoder.codingPath,
				      debugDescription: "No @Grounding properties are defined, so no GroundingSource can be decoded."
				    )
				    throw DecodingError.dataCorrupted(context)
				  }

				  func encode(to encoder: Encoder) throws {
				    let context = EncodingError.Context(
				      codingPath: encoder.codingPath,
				      debugDescription: "No @Grounding properties are defined, so no GroundingSource can be encoded."
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
			enum GroundingSource: GroundingRepresentable {
			\(raw: cases)
			}
			"""
	}

	private static func generateResolvableWrapper(for tool: ToolProperty) -> DeclSyntax {
		let wrapperName = "Resolvable\(tool.identifier.text.capitalizedFirstLetter())Tool"

		return
			"""
			struct \(raw: wrapperName): ResolvableTool {
			  typealias Session = SessionType
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
			  ) -> Session.ResolvedToolRun {
			    .\(raw: tool.identifier.text)(run)
			  }

			  func resolvePartially(
			    _ run: PartialToolRun<\(raw: wrapperName)>
			  ) -> Session.PartiallyResolvedToolRun {
			    .\(raw: tool.identifier.text)(run)
			  }
			}
			"""
	}

	private static func diagnoseManualObservable(
		on attribute: AttributeSyntax,
		typeName: String,
		in context: some MacroExpansionContext
	) {
		context.diagnose(
			Diagnostic(
				node: Syntax(attribute),
				message: Diagnostics.manualObservable(typeName: typeName)
			)
		)
	}

	private static func diagnoseObservationIgnored(
		in classDeclaration: ClassDeclSyntax,
		context: some MacroExpansionContext
	) {
		for member in classDeclaration.memberBlock.members {
			guard let variableDecl = member.decl.as(VariableDeclSyntax.self),
			      let ignoredAttribute = attribute(
			      	named: "ObservationIgnored",
			      	in: variableDecl.attributes
			      )
			else {
				continue
			}

			context.diagnose(
				Diagnostic(
					node: Syntax(ignoredAttribute),
					message: Diagnostics.observationIgnored()
				)
			)
		}
	}

	private static func generateObservableMembers(
		named name: String,
		type: String,
		initialValue: String,
		actorAttribute: String
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

	private static func generateObservationSupportMembers() -> [DeclSyntax] {
		[
			"""
			private let _$observationRegistrar = Observation.ObservationRegistrar()
			""",
			"""
			nonisolated func access(
			  keyPath: KeyPath<SessionType, some Any>
			) {
			  _$observationRegistrar.access(self, keyPath: keyPath)
			}
			""",
			"""
			nonisolated func withMutation<A>(
			  keyPath: KeyPath<SessionType, some Any>,
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

	private enum Diagnostics {
		private static let domain = "LanguageModelProviderMacro"

		static func manualObservable(typeName: String) -> SimpleDiagnosticMessage {
			SimpleDiagnosticMessage(
				message: "LanguageModelProvider already adds @Observable; remove it from \(typeName)",
				diagnosticID: MessageID(domain: domain, id: "manual-observable"),
				severity: .error
			)
		}

		static func observationIgnored() -> SimpleDiagnosticMessage {
			SimpleDiagnosticMessage(
				message: "@ObservationIgnored isn't supported here; LanguageModelProvider manages observation automatically",
				diagnosticID: MessageID(domain: domain, id: "observation-ignored"),
				severity: .error
			)
		}
	}
}

private struct SimpleDiagnosticMessage: DiagnosticMessage {
	let message: String
	let diagnosticID: MessageID
	let severity: DiagnosticSeverity
}
