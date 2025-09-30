// By Dennis Müller

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ResolvableToolMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
			context.diagnose(node, message: .resolvableToolOnlyOnProperties)
			return []
		}
		guard let binding = varDecl.bindings.first,
		      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
		else {
			context.diagnose(node, message: .resolvableToolInvalidProperty)
			return []
		}
		guard let initializer = binding.initializer?.value,
		      let toolType = extractToolType(from: initializer)
		else {
			context.diagnose(node, message: .resolvableToolMissingInitializer)
			return []
		}

		let wrapperName = "Resolvable\(toolType)"
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

public struct ResolvableMacro: MemberMacro, ExtensionMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		guard let structDecl = declaration.as(StructDeclSyntax.self) else {
			context.diagnose(node, message: .onlyApplicableToStructs)
			return []
		}

		let accessLevel = extractAccessLevel(from: structDecl.modifiers)
		let toolProperties = extractToolProperties(from: structDecl, in: context)

		guard !toolProperties.isEmpty else {
			context.diagnose(node, message: .noResolvableToolsFound)
			return []
		}

		var members: [DeclSyntax] = []

		// Generate allTools property
		members.append(makeAllToolsProperty(for: toolProperties, accessLevel: accessLevel))

		// Generate ResolvedToolRun enum
		members.append(makeResolvedToolRunEnum(for: toolProperties, accessLevel: accessLevel))

		// Generate PartiallyResolvedToolRun enum
		members.append(
			makePartiallyResolvedToolRunEnum(for: toolProperties, accessLevel: accessLevel),
		)

		// Generate ToolGroupType typealias
		members.append(makeToolGroupTypeAlias(accessLevel: accessLevel))

		return members
	}

	public static func expansion(
		of node: AttributeSyntax,
		attachedTo declaration: some DeclGroupSyntax,
		providingExtensionsOf type: some TypeSyntaxProtocol,
		conformingTo protocols: [TypeSyntax],
		in context: some MacroExpansionContext,
	) throws -> [ExtensionDeclSyntax] {
		let conformance: DeclSyntax = "extension \(type): ResolvableToolGroup {}"
		return [conformance.cast(ExtensionDeclSyntax.self)]
	}
}

private struct ToolProperty {
	let propertyName: String
	let toolTypeName: String
	let wrapperTypeName: String
	let caseName: String
}

private func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> String {
	for modifier in modifiers {
		let name = modifier.name.text
		if ["public", "package", "internal", "fileprivate", "private"].contains(name) {
			return name
		}
	}
	return "internal"
}

private func extractToolProperties(
	from structDecl: StructDeclSyntax,
	in context: some MacroExpansionContext,
) -> [ToolProperty] {
	var properties: [ToolProperty] = []
	let structAccessLevel = extractAccessLevel(from: structDecl.modifiers)

	for member in structDecl.memberBlock.members {
		guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
			continue
		}

		let hasResolvableToolAttribute = varDecl.attributes.contains { attribute in
			guard let attributeSyntax = attribute.as(AttributeSyntax.self) else {
				return false
			}

			return attributeSyntax.attributeName.trimmedDescription == "ResolvableTool"
		}

		guard hasResolvableToolAttribute else {
			continue
		}
		guard let binding = varDecl.bindings.first,
		      let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
		else {
			continue
		}

		// Check access level compatibility
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

		let wrapperName = "Resolvable\(toolType)"
		let caseName = makeCaseName(from: identifier)

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

private func extractToolType(from expression: ExprSyntax) -> String? {
	if let functionCall = expression.as(FunctionCallExprSyntax.self) {
		if let reference = functionCall.calledExpression.as(DeclReferenceExprSyntax.self) {
			return reference.baseName.text
		}
		if let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) {
			return memberAccess.declName.baseName.text
		}
	}
	return nil
}

private func makeCaseName(from propertyName: String) -> String {
	// Convert property name to camelCase (it should already be camelCase)
	propertyName
}

private func isAccessLevelCompatible(property: String, with structLevel: String) -> Bool {
	let levels = ["private", "fileprivate", "internal", "package", "public"]
	guard let structIndex = levels.firstIndex(of: structLevel),
	      let propertyIndex = levels.firstIndex(of: property)
	else {
		return true // If we can't determine, allow it (shouldn't happen)
	}

	// Property must be at least as accessible as the struct
	return propertyIndex >= structIndex
}

private func makeAllToolsProperty(
	for properties: [ToolProperty],
	accessLevel: String,
) -> DeclSyntax {
	let toolsList = properties
		.map { "    \($0.wrapperTypeName)(baseTool: \($0.propertyName))" }
		.joined(separator: ",\n")

	return DeclSyntax(
		stringLiteral: """
		\(accessLevel) var allTools: [any ResolvableTool<Self>] {
		  [
		\(toolsList)
		  ]
		}
		""",
	)
}

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

private func makeToolGroupTypeAlias(accessLevel: String) -> DeclSyntax {
	DeclSyntax(stringLiteral: "\(accessLevel) typealias ToolGroupType = Self")
}

private func makeWrapperType(
	wrapperName: String,
	toolTypeName: String,
	propertyName: String,
	accessLevel: String,
) -> DeclSyntax {
	DeclSyntax(
		stringLiteral: """
		\(accessLevel) struct \(wrapperName): ResolvableTool {
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

private extension MacroExpansionContext {
	func diagnose(_ syntax: some SyntaxProtocol, message: ResolvableMacroDiagnostic) {
		diagnose(Diagnostic(node: Syntax(syntax), message: message))
	}
}

private enum ResolvableMacroDiagnostic: DiagnosticMessage {
	case onlyApplicableToStructs
	case noResolvableToolsFound
	case missingToolInitializer
	case resolvableToolOnlyOnProperties
	case resolvableToolInvalidProperty
	case resolvableToolMissingInitializer
	case propertyAccessLevelTooRestrictive(property: String, propertyLevel: String, structLevel: String)

	var message: String {
		switch self {
		case .onlyApplicableToStructs:
			"@Resolvable can only be applied to struct declarations."
		case .noResolvableToolsFound:
			"@Resolvable requires at least one property marked with @ResolvableTool."
		case .missingToolInitializer:
			"@ResolvableTool property must be initialized with a tool instance."
		case .resolvableToolOnlyOnProperties:
			"@ResolvableTool can only be applied to property declarations."
		case .resolvableToolInvalidProperty:
			"@ResolvableTool property must have a valid identifier."
		case .resolvableToolMissingInitializer:
			"@ResolvableTool property must be initialized with a tool instance."
		case let .propertyAccessLevelTooRestrictive(property, propertyLevel, structLevel):
			"@ResolvableTool property '\(property)' has access level '\(propertyLevel)' which is less accessible than the struct's '\(structLevel)' access level. The property must be '\(structLevel)' or more accessible."
		}
	}

	var diagnosticID: MessageID {
		MessageID(domain: "SwiftAgentMacros", id: identifier)
	}

	private var identifier: String {
		switch self {
		case .onlyApplicableToStructs:
			"onlyApplicableToStructs"
		case .noResolvableToolsFound:
			"noResolvableToolsFound"
		case .missingToolInitializer:
			"missingToolInitializer"
		case .resolvableToolOnlyOnProperties:
			"resolvableToolOnlyOnProperties"
		case .resolvableToolInvalidProperty:
			"resolvableToolInvalidProperty"
		case .resolvableToolMissingInitializer:
			"resolvableToolMissingInitializer"
		case .propertyAccessLevelTooRestrictive:
			"propertyAccessLevelTooRestrictive"
		}
	}

	var severity: DiagnosticSeverity { .error }
}
