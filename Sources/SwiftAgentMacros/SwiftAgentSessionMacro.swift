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

/// Member macro that synthesizes ModelSession implementation
public struct SwiftAgentSessionMacro: MemberMacro, ExtensionMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		// Validate that this is applied to a class
		guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
			throw MacroError.onlyApplicableToClass
		}

		// Extract provider from macro arguments
		guard let provider = try extractProvider(from: node) else {
			throw MacroError.missingProvider
		}

		// Extract all @ResolvableTool properties
		let resolvableTools = classDecl.memberBlock.members
			.compactMap { $0.decl.as(VariableDeclSyntax.self) }
			.filter { variable in
				variable.attributes.contains { attribute in
					attribute.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "ResolvableTool"
				}
			}

		// Generate member declarations
		var members: [DeclSyntax] = []

		// Add typealias declarations
		members.append(
			"""
			typealias Adapter = \(raw: provider.adapterTypeName)
			"""
		)
		members.append(
			"""
			typealias SessionType = \(raw: classDecl.name.text)
			"""
		)

		// Add adapter, transcript, tokenUsage properties if not already declared
		members.append(
			"""
			var adapter: \(raw: provider.adapterTypeName)
			"""
		)
		members.append(
			"""
			var transcript: SwiftAgent.Transcript
			"""
		)
		members.append(
			"""
			var tokenUsage: TokenUsage
			"""
		)
		members.append(
			"""
			nonisolated let tools: [any ResolvableTool<\(raw: classDecl.name.text)>]
			"""
		)

		// Generate initializers
		let initializers = try generateInitializers(
			for: resolvableTools,
			provider: provider,
			className: classDecl.name.text
		)
		members.append(contentsOf: initializers)

		// Generate ResolvedToolRun enum
		let resolvedEnum = generateResolvedToolRunEnum(for: resolvableTools)
		members.append(resolvedEnum)

		// Generate PartiallyResolvedToolRun enum
		let partiallyResolvedEnum = generatePartiallyResolvedToolRunEnum(for: resolvableTools)
		members.append(partiallyResolvedEnum)

		// Add Grounding enum with manual Codable implementation for empty enum
		members.append(
			"""
			enum Grounding: GroundingRepresentable {
			  init(from decoder: Decoder) throws {
			    let container = try decoder.singleValueContainer()
			    throw DecodingError.dataCorrupted(
			      DecodingError.Context(
			        codingPath: container.codingPath,
			        debugDescription: "No cases available for decoding"
			      )
			    )
			  }

			  func encode(to encoder: Encoder) throws {
			    var container = encoder.singleValueContainer()
			    try container.encodeNil()
			  }
			}
			"""
		)

		return members
	}

	private static func extractProvider(from attribute: AttributeSyntax) throws -> Provider? {
		// Extract provider argument from macro
		guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
		      let providerArg = arguments.first(where: { $0.label?.text == "provider" })
		else {
			return nil
		}

		// Extract the provider value
		guard let memberAccess = providerArg.expression.as(MemberAccessExprSyntax.self) else {
			throw MacroError.invalidProvider
		}

		let providerName = memberAccess.declName.baseName.text
		guard let provider = Provider(rawValue: providerName) else {
			throw MacroError.invalidProvider
		}

		return provider
	}

	private static func generateInitializers(
		for tools: [VariableDeclSyntax],
		provider: Provider,
		className: String
	) throws -> [DeclSyntax] {
		var initializers: [DeclSyntax] = []

		// Collect tool info for init parameters
		var toolParameters: [(name: String, type: String, hasInitializer: Bool)] = []

		for tool in tools {
			guard let binding = tool.bindings.first,
			      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
			      let typeAnnotation = binding.typeAnnotation
			else {
				continue
			}

			let toolName = identifier.text
			let toolType = typeAnnotation.type.trimmedDescription
			let hasInitializer = binding.initializer != nil

			toolParameters.append((name: toolName, type: toolType, hasInitializer: hasInitializer))
		}

		// Generate tools array initialization code
		let toolsArrayInit = toolParameters.map { param in
			let wrapperName = "Resolvable\(param.name.capitalizedFirstLetter())Tool"
			return "      \(wrapperName)(baseTool: \(param.name))"
		}.joined(separator: ",\n")

		let toolsArrayCode = toolsArrayInit.isEmpty ? "[]" : "[\n\(toolsArrayInit)\n    ]"

		// Generate init parameters (only for tools without initializers)
		let initParameters = toolParameters
			.filter { !$0.hasInitializer }
			.map { "    \($0.name): \($0.type)" }
			.joined(separator: ",\n")

		let allInitParameters = initParameters.isEmpty
			? "instructions: String,\n    apiKey: String"
			: "\(initParameters),\n    instructions: String,\n    apiKey: String"

		// Generate self assignments for all tools
		let selfAssignments = toolParameters.map { param in
			if param.hasInitializer {
				"" // Already initialized
			} else {
				"    self.\(param.name) = \(param.name)"
			}
		}
		.filter { !$0.isEmpty }
		.joined(separator: "\n")

		// First initializer with apiKey
		initializers.append(
			"""
			init(
			\(raw: allInitParameters)
			) {
			  let tools: [any ResolvableTool<\(raw: className)>] = \(raw: toolsArrayCode)

			\(raw: selfAssignments)
			  self.tools = tools

			  adapter = \(raw: provider.adapterTypeName)(
			    tools: tools,
			    instructions: instructions,
			    configuration: .direct(apiKey: apiKey)
			  )
			  transcript = Transcript()
			  tokenUsage = TokenUsage()
			}
			"""
		)

		// Second initializer with configuration
		let configInitParameters = initParameters.isEmpty
			? "instructions: String,\n    configuration: \(provider.configurationTypeName)"
			: "\(initParameters),\n    instructions: String,\n    configuration: \(provider.configurationTypeName)"

		initializers.append(
			"""
			init(
			\(raw: configInitParameters)
			) {
			  let tools: [any ResolvableTool<\(raw: className)>] = \(raw: toolsArrayCode)

			\(raw: selfAssignments)
			  self.tools = tools

			  adapter = \(raw: provider.adapterTypeName)(
			    tools: tools,
			    instructions: instructions,
			    configuration: configuration
			  )
			  transcript = Transcript()
			  tokenUsage = TokenUsage()
			}
			"""
		)

		return initializers
	}

	private static func generateResolvedToolRunEnum(for tools: [VariableDeclSyntax]) -> DeclSyntax {
		let cases = tools.compactMap { tool -> String? in
			guard let binding = tool.bindings.first,
			      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
			else {
				return nil
			}

			let toolName = identifier.text
			let wrapperName = "Resolvable\(toolName.capitalizedFirstLetter())Tool"
			return "    case \(toolName)(ToolRun<\(wrapperName)>)"
		}.joined(separator: "\n")

		let enumDecl: DeclSyntax =
			"""
			enum ResolvedToolRun: Equatable {
			\(raw: cases)
			}
			"""

		return enumDecl
	}

	private static func generatePartiallyResolvedToolRunEnum(for tools: [VariableDeclSyntax])
		-> DeclSyntax {
		let cases = tools.compactMap { tool -> String? in
			guard let binding = tool.bindings.first,
			      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier
			else {
				return nil
			}

			let toolName = identifier.text
			let wrapperName = "Resolvable\(toolName.capitalizedFirstLetter())Tool"
			return "    case \(toolName)(PartialToolRun<\(wrapperName)>)"
		}.joined(separator: "\n")

		let enumDecl: DeclSyntax =
			"""
			enum PartiallyResolvedToolRun: Equatable {
			\(raw: cases)
			}
			"""

		return enumDecl
	}

	// MARK: - ExtensionMacro Implementation

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext
	) throws -> [ExtensionDeclSyntax] {
		// Generate extension for ModelSession conformance
		let extensionDecl: DeclSyntax =
			"""
			extension \(type.trimmed): ModelSession {}
			"""

		guard let extensionDeclSyntax = extensionDecl.as(ExtensionDeclSyntax.self) else {
			return []
		}

		return [extensionDeclSyntax]
	}
}
