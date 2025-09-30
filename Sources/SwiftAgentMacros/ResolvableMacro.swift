// By Dennis Müller

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - ToolDecoderMacro

/// Peer macro that generates a wrapper type for a tool property marked with @ToolDecoder.
///
/// For a property like `@ToolDecoder var addMovie = AddMovieTool()`, this generates
/// a `DecoderAddMovieTool` wrapper struct that conforms to `ToolDecodable`.
public struct ToolDecoderMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		// Validate that the macro is applied to a property declaration
		guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
			context.diagnose(node, message: .toolDecoderOnlyOnProperties)
			return []
		}

		// Extract the property name
		guard let binding = varDecl.bindings.first,
		      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
		else {
			context.diagnose(node, message: .toolDecoderInvalidProperty)
			return []
		}

		// Extract the tool type from the initializer (e.g., "AddMovieTool" from "AddMovieTool()")
		guard let initializer = binding.initializer?.value,
		      let toolType = extractToolType(from: initializer)
		else {
			context.diagnose(node, message: .toolDecoderMissingInitializer)
			return []
		}

		let wrapperName = "Decoder\(toolType)"
		let accessLevel = extractAccessLevel(from: varDecl.modifiers)

		return [
			makeWrapperType(
				wrapperName: wrapperName,
				toolTypeName: toolType,
				propertyName: identifier,
				accessLevel: accessLevel,
			),
		]
	}
}

// MARK: - TranscriptDecoderMacro

/// Member and extension macro that synthesizes a complete `TranscriptDecodable` implementation.
///
/// This macro:
/// 1. Generates an `allTools` property containing all wrapped tools
/// 2. Creates `ResolvedToolRun` and `PartiallyResolvedToolRun` enums
/// 3. Adds the `ToolGroupType` typealias
/// 4. Adds conformance to `TranscriptDecodable`
public struct TranscriptDecoderMacro: MemberMacro, ExtensionMacro {
	// MARK: Member Expansion

	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		// Validate that the macro is applied to a struct
		guard let structDecl = declaration.as(StructDeclSyntax.self) else {
			context.diagnose(node, message: .onlyApplicableToStructs)
			return []
		}

		let accessLevel = extractAccessLevel(from: structDecl.modifiers)
		let toolProperties = extractToolProperties(from: structDecl, in: context)

		// Ensure at least one @ToolDecoder property exists
		guard !toolProperties.isEmpty else {
			context.diagnose(node, message: .noToolDecodersFound)
			return []
		}

		// Generate all required members for TranscriptDecodable conformance
		return [
			makeAllToolsProperty(for: toolProperties, accessLevel: accessLevel),
			makeResolvedToolRunEnum(for: toolProperties, accessLevel: accessLevel),
			makePartiallyResolvedToolRunEnum(for: toolProperties, accessLevel: accessLevel),
			makeToolGroupTypeAlias(accessLevel: accessLevel),
		]
	}

	// MARK: Extension Expansion

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext,
	) throws -> [ExtensionDeclSyntax] {
		let conformance: DeclSyntax = "extension \(type): TranscriptDecodable {}"
		return [conformance.cast(ExtensionDeclSyntax.self)]
	}
}

// MARK: - Helper Types

/// Represents metadata about a tool property marked with @ToolDecoder.
private struct ToolProperty {
	let propertyName: String
	let toolTypeName: String
	let wrapperTypeName: String
	let caseName: String
}

// MARK: - Syntax Analysis Helpers

/// Extracts the access level modifier from a declaration.
/// Returns "internal" if no access level is explicitly specified.
private func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> String {
	for modifier in modifiers {
		let name = modifier.name.text
		if ["public", "package", "internal", "fileprivate", "private"].contains(name) {
			return name
		}
	}
	return "internal"
}

/// Extracts all tool properties marked with @ToolDecoder from a struct declaration.
/// Validates access levels and diagnoses errors for invalid configurations.
private func extractToolProperties(
	from structDecl: StructDeclSyntax,
	in context: some MacroExpansionContext,
) -> [ToolProperty] {
	var properties: [ToolProperty] = []
	let structAccessLevel = extractAccessLevel(from: structDecl.modifiers)

	for member in structDecl.memberBlock.members {
		// Only process variable declarations
		guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
			continue
		}

		// Check if the property has the @ToolDecoder attribute
		let hasToolDecoderAttribute = varDecl.attributes.contains { attribute in
			guard let attributeSyntax = attribute.as(AttributeSyntax.self) else {
				return false
			}

			return attributeSyntax.attributeName.trimmedDescription == "ToolDecoder"
		}

		guard hasToolDecoderAttribute else {
			continue
		}

		// Extract the property name
		guard let binding = varDecl.bindings.first,
		      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
		else {
			continue
		}

		// Validate that the property's access level is at least as accessible as the struct
		let propertyAccessLevel = extractAccessLevel(from: varDecl.modifiers)
		if !isAccessLevelCompatible(property: propertyAccessLevel, with: structAccessLevel) {
			context.diagnose(
				varDecl,
				message: .propertyAccessLevelTooRestrictive(
					property: identifier,
					propertyLevel: propertyAccessLevel,
					structLevel: structAccessLevel,
				),
			)
			continue
		}

		// Extract the tool type from the initializer
		guard let initializer = binding.initializer?.value,
		      let toolType = extractToolType(from: initializer)
		else {
			context.diagnose(varDecl, message: .missingToolInitializer)
			continue
		}

		let wrapperName = "Decoder\(toolType)"
		let caseName = identifier // Use property name directly as the case name

		properties.append(
			ToolProperty(
				propertyName: identifier,
				toolTypeName: toolType,
				wrapperTypeName: wrapperName,
				caseName: caseName,
			),
		)
	}

	return properties
}

/// Extracts the tool type name from an initializer expression.
/// Supports both direct calls like `AddMovieTool()` and member access like `ToolType.init()`.
private func extractToolType(from expression: ExprSyntax) -> String? {
	if let functionCall = expression.as(FunctionCallExprSyntax.self) {
		// Handle direct reference: `AddMovieTool()`
		if let reference = functionCall.calledExpression.as(DeclReferenceExprSyntax.self) {
			return reference.baseName.text
		}
		// Handle member access: `SomeType.init()`
		if let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) {
			return memberAccess.declName.baseName.text
		}
	}
	return nil
}

/// Validates that a property's access level is compatible with its containing struct.
/// A property must be at least as accessible as the struct to satisfy protocol requirements.
private func isAccessLevelCompatible(property: String, with structLevel: String) -> Bool {
	let levels = ["private", "fileprivate", "internal", "package", "public"]
	guard let structIndex = levels.firstIndex(of: structLevel),
	      let propertyIndex = levels.firstIndex(of: property)
	else {
		// If we can't determine the access level, allow it (shouldn't happen in practice)
		return true
	}

	// Property must be at least as accessible as the struct
	return propertyIndex >= structIndex
}

// MARK: - Code Generation

/// Generates the `allTools` property that returns an array of all wrapped tools.
private func makeAllToolsProperty(
	for properties: [ToolProperty],
	accessLevel: String,
) -> DeclSyntax {
	let toolsList = properties
		.map { "    \($0.wrapperTypeName)(baseTool: \($0.propertyName))" }
		.joined(separator: ",\n")

	return DeclSyntax(
		stringLiteral: """
		\(accessLevel) var allTools: [any ToolDecodable<Self>] {
		  [
		\(toolsList)
		  ]
		}
		""",
	)
}

/// Generates the `ResolvedToolRun` enum with cases for each tool.
/// Each case wraps a fully resolved tool run with complete arguments.
private func makeResolvedToolRunEnum(
	for properties: [ToolProperty],
	accessLevel: String,
) -> DeclSyntax {
	let cases = properties
		.map { "  case \($0.caseName)(ToolRun<\($0.wrapperTypeName)>)" }
		.joined(separator: "\n")

	return DeclSyntax(
		stringLiteral: """
		\(accessLevel) enum ResolvedToolRun: Equatable {
		\(cases)
		}
		""",
	)
}

/// Generates the `PartiallyResolvedToolRun` enum with cases for each tool.
/// Each case wraps a partially resolved tool run with incomplete or streaming arguments.
private func makePartiallyResolvedToolRunEnum(
	for properties: [ToolProperty],
	accessLevel: String,
) -> DeclSyntax {
	let cases = properties
		.map { "  case \($0.caseName)(PartialToolRun<\($0.wrapperTypeName)>)" }
		.joined(separator: "\n")

	return DeclSyntax(
		stringLiteral: """
		\(accessLevel) enum PartiallyResolvedToolRun: Equatable {
		\(cases)
		}
		""",
	)
}

/// Generates a typealias for `ToolGroupType` pointing to `Self`.
/// This is required for the wrapper types to reference their containing tool group.
private func makeToolGroupTypeAlias(accessLevel: String) -> DeclSyntax {
	DeclSyntax(stringLiteral: "\(accessLevel) typealias ToolGroupType = Self")
}

/// Generates a wrapper struct for a tool that conforms to `ToolDecodable`.
/// The wrapper forwards all tool methods to the base tool and provides resolve methods
/// that map tool runs to the appropriate enum cases in the tool group.
private func makeWrapperType(
	wrapperName: String,
	toolTypeName: String,
	propertyName: String,
	accessLevel: String,
) -> DeclSyntax {
	DeclSyntax(
		stringLiteral: """
		\(accessLevel) struct \(wrapperName): ToolDecodable {
		  \(accessLevel) typealias ToolGroup = ToolGroupType
		  \(accessLevel) typealias BaseTool = \(toolTypeName)
		  \(accessLevel) typealias Arguments = BaseTool.Arguments
		  \(accessLevel) typealias Output = BaseTool.Output

		  private let baseTool: BaseTool

		  \(accessLevel) init(baseTool: \(toolTypeName)) {
		    self.baseTool = baseTool
		  }

		  \(accessLevel) var name: String {
		    baseTool.name
		  }

		  \(accessLevel) var description: String {
		    baseTool.description
		  }

		  \(accessLevel) var parameters: GenerationSchema {
		    baseTool.parameters
		  }

		  \(accessLevel) func call(arguments: Arguments) async throws -> Output {
		    try await baseTool.call(arguments: arguments)
		  }

		  \(accessLevel) func resolve(
		    _ run: ToolRun<\(wrapperName)>
		  ) -> ToolGroup.ResolvedToolRun {
		    .\(propertyName)(run)
		  }

		  \(accessLevel) func resolvePartially(
		    _ run: PartialToolRun<\(wrapperName)>
		  ) -> ToolGroup.PartiallyResolvedToolRun {
		    .\(propertyName)(run)
		  }
		}
		""",
	)
}

// MARK: - Diagnostics

/// Convenience extension for diagnosing macro errors.
private extension MacroExpansionContext {
	func diagnose(_ syntax: some SyntaxProtocol, message: ResolvableMacroDiagnostic) {
		diagnose(Diagnostic(node: Syntax(syntax), message: message))
	}
}

/// Diagnostic messages for @TranscriptDecoder and @ToolDecoder macro errors.
private enum ResolvableMacroDiagnostic: DiagnosticMessage {
	case onlyApplicableToStructs
	case noToolDecodersFound
	case missingToolInitializer
	case toolDecoderOnlyOnProperties
	case toolDecoderInvalidProperty
	case toolDecoderMissingInitializer
	case propertyAccessLevelTooRestrictive(property: String, propertyLevel: String, structLevel: String)

	var message: String {
		switch self {
		case .onlyApplicableToStructs:
			"@TranscriptDecoder can only be applied to struct declarations."
		case .noToolDecodersFound:
			"@TranscriptDecoder requires at least one property marked with @ToolDecoder."
		case .missingToolInitializer:
			"@ToolDecoder property must be initialized with a tool instance."
		case .toolDecoderOnlyOnProperties:
			"@ToolDecoder can only be applied to property declarations."
		case .toolDecoderInvalidProperty:
			"@ToolDecoder property must have a valid identifier."
		case .toolDecoderMissingInitializer:
			"@ToolDecoder property must be initialized with a tool instance."
		case let .propertyAccessLevelTooRestrictive(property, propertyLevel, structLevel):
			"@ToolDecoder property '\(property)' has access level '\(propertyLevel)' which is less accessible than the struct's '\(structLevel)' access level. The property must be '\(structLevel)' or more accessible."
		}
	}

	var diagnosticID: MessageID {
		MessageID(domain: "SwiftAgentMacros", id: identifier)
	}

	private var identifier: String {
		switch self {
		case .onlyApplicableToStructs:
			"onlyApplicableToStructs"
		case .noToolDecodersFound:
			"noToolDecodersFound"
		case .missingToolInitializer:
			"missingToolInitializer"
		case .toolDecoderOnlyOnProperties:
			"toolDecoderOnlyOnProperties"
		case .toolDecoderInvalidProperty:
			"toolDecoderInvalidProperty"
		case .toolDecoderMissingInitializer:
			"toolDecoderMissingInitializer"
		case .propertyAccessLevelTooRestrictive:
			"propertyAccessLevelTooRestrictive"
		}
	}

	var severity: DiagnosticSeverity { .error }
}
