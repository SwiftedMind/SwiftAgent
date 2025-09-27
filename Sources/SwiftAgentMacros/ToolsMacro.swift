// By Dennis Müller

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct SwiftAgentMacroPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		ToolsMacro.self,
	]
}

public struct ToolsMacro: DeclarationMacro {
	public static func expansion(
		of node: some FreestandingMacroExpansionSyntax,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		guard let accessLevel = resolveAccessLevel(for: node, in: context) else {
			return []
		}
		guard let closure = node.trailingClosure else {
			context.diagnose(node, message: .missingToolDefinitions)
			return []
		}

		let toolExpressions: [ExprSyntax] = closure.statements.compactMap { statement in
			if let expression = statement.item.as(ExprSyntax.self) {
				return expression
			}

			context.diagnose(Syntax(statement), message: .onlyToolExpressionsAllowed)
			return nil
		}

		if toolExpressions.isEmpty {
			context.diagnose(node, message: .missingToolDefinitions)
			return []
		}

		var toolDefinitions: [ToolDefinition] = []
		var recordedCaseNames: Set<String> = []

		for expression in toolExpressions {
			guard let callExpression = expression.as(FunctionCallExprSyntax.self) else {
				context.diagnose(Syntax(expression), message: .invalidToolExpression)
				continue
			}
			guard let simpleTypeName = simpleTypeName(from: callExpression.calledExpression) else {
				context.diagnose(Syntax(expression), message: .invalidToolExpression)
				continue
			}

			let caseName = makeCaseName(from: simpleTypeName)
			let wrapperName = makeWrapperName(from: simpleTypeName)

			if !recordedCaseNames.insert(caseName).inserted {
				context.diagnose(Syntax(expression), message: .duplicateCaseName(caseName))
				continue
			}

			toolDefinitions.append(
				ToolDefinition(
					baseTypeDescription: callExpression.calledExpression.trimmed.description,
					caseName: caseName,
					wrapperName: wrapperName,
					creationExpression: ExprSyntax(callExpression),
				),
			)
		}

		if toolDefinitions.isEmpty {
			return []
		}

		let enumDecl = makeToolsEnum(for: toolDefinitions, accessLevel: accessLevel)

		return [enumDecl]
	}
}

private struct ToolDefinition {
	let baseTypeDescription: String
	let caseName: String
	let wrapperName: String
	let creationExpression: ExprSyntax
}

private func resolveAccessLevel(
	for node: some FreestandingMacroExpansionSyntax,
	in context: some MacroExpansionContext,
) -> AccessLevel? {
	let arguments = node.arguments
	if arguments.isEmpty {
		return .public
	}

	var selectedLevel: AccessLevel?

	for argument in arguments {
		if argument.expression.is(ClosureExprSyntax.self) {
			continue
		}

		guard let label = argument.label?.text else {
			context.diagnose(argument, message: .missingAccessLevelLabel)
			return nil
		}
		guard label == "accessLevel" else {
			context.diagnose(argument, message: .unsupportedArgumentLabel(label))
			return nil
		}

		if selectedLevel != nil {
			context.diagnose(argument, message: .duplicateAccessLevelArgument)
			return nil
		}

		guard let level = AccessLevel(expression: argument.expression) else {
			context.diagnose(argument, message: .invalidAccessLevelValue)
			return nil
		}

		selectedLevel = level
	}

	return selectedLevel ?? .public
}

private enum AccessLevel: String {
	case `private`
	case `internal`
	case package
	case `public`

	init?(expression: ExprSyntax) {
		if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
			self.init(rawValue: memberAccess.declName.baseName.text)
			return
		}

		if let reference = expression.as(DeclReferenceExprSyntax.self) {
			self.init(rawValue: reference.baseName.text)
			return
		}

		return nil
	}

	var keyword: String { rawValue }
}

private func makeToolsEnum(for definitions: [ToolDefinition], accessLevel: AccessLevel) -> DeclSyntax {
	var lines: [String] = []
	let accessModifier = accessLevel.keyword
	lines.append("\(accessModifier) enum Tools: ResolvableToolGroup {")
	lines.append("  \(accessModifier) static let all: [any ResolvableTool<Tools>] = [")

	let lastIndex = definitions.count - 1

	for (index, definition) in definitions.enumerated() {
		let separator = index < lastIndex ? "," : ""
		lines.append("    \(definition.wrapperName)()\(separator)")
	}

	lines.append("  ]")
	lines.append("")

	for definition in definitions {
		lines.append("  case \(definition.caseName)(ToolRun<\(definition.wrapperName)>)")
	}

	lines.append("")
	lines.append("  \(accessModifier) enum Partials {")

	for definition in definitions {
		lines.append("    case \(definition.caseName)(PartialToolRun<\(definition.wrapperName)>)")
	}

	lines.append("  }")

	for definition in definitions {
		lines.append("")
		lines.append("  \(accessModifier) struct \(definition.wrapperName): ResolvableTool {")
		lines.append("    \(accessModifier) typealias BaseTool = \(definition.baseTypeDescription)")
		lines.append("    \(accessModifier) typealias Arguments = BaseTool.Arguments")
		lines.append("    \(accessModifier) typealias Output = BaseTool.Output")
		lines.append("")
		lines.append("    private let baseTool: BaseTool")
		lines.append("")
		lines.append("    \(accessModifier) init() {")
		lines.append("      self.baseTool = \(definition.creationExpression.trimmed.description)")
		lines.append("    }")
		lines.append("")
		lines.append("    \(accessModifier) var name: String { baseTool.name }")
		lines.append("    \(accessModifier) var description: String { baseTool.description }")
		lines.append("    \(accessModifier) var parameters: GenerationSchema { baseTool.parameters }")
		lines.append("")
		lines.append("    \(accessModifier) func call(arguments: Arguments) async throws -> Output {")
		lines.append("      try await baseTool.call(arguments: arguments)")
		lines.append("    }")
		lines.append("")
		lines.append("    \(accessModifier) func resolve(_ run: ToolRun<\(definition.wrapperName)>) -> Tools {")
		lines.append("      .\(definition.caseName)(run)")
		lines.append("    }")
		lines.append("")
		let resolvePartiallyLine =
			"    \(accessModifier) func resolvePartially(_ run: PartialToolRun<\(definition.wrapperName)>) -> Tools.Partials {"
		lines.append(resolvePartiallyLine)
		lines.append("      .\(definition.caseName)(run)")
		lines.append("    }")
		lines.append("  }")
	}

	lines.append("}")

	return DeclSyntax(stringLiteral: lines.joined(separator: "\n"))
}

private func simpleTypeName(from expression: ExprSyntax) -> String? {
	if let reference = expression.as(DeclReferenceExprSyntax.self) {
		return reference.baseName.text
	}

	if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
		return memberAccess.declName.baseName.text
	}

	return nil
}

private func makeCaseName(from typeName: String) -> String {
	let trimmed = typeName.hasSuffix("Tool") ? String(typeName.dropLast(4)) : typeName
	guard !trimmed.isEmpty else { return "tool" }

	let characters = Array(trimmed)
	guard !characters.isEmpty else { return "tool" }

	var words: [String] = []
	var currentWord = ""

	for index in characters.indices {
		let character = characters[index]
		let previousCharacter: Character? = index > characters.startIndex ? characters[index - 1] : nil
		let nextCharacter: Character? = index < characters.index(before: characters.endIndex) ? characters[index + 1] : nil

		if index != characters.startIndex {
			let startsNewWord: Bool

			if character.isNumber {
				let previousWasNumber = previousCharacter?.isNumber == true
				startsNewWord = !previousWasNumber
			} else if character.isUppercase {
				let previousWasLowercase = previousCharacter?.isLowercase == true
				let nextIsLowercase = nextCharacter?.isLowercase == true
				startsNewWord = previousWasLowercase || nextIsLowercase
			} else {
				startsNewWord = false
			}

			if startsNewWord, !currentWord.isEmpty {
				words.append(currentWord)
				currentWord = ""
			}
		}

		currentWord.append(character)
	}

	if !currentWord.isEmpty {
		words.append(currentWord)
	}

	guard !words.isEmpty else {
		return trimmed.lowercased()
	}

	var components: [String] = []
	if let first = words.first {
		components.append(first.lowercased())
	}

	for word in words.dropFirst() {
		let lowercased = word.lowercased()
		let capitalized = lowercased.prefix(1).uppercased() + lowercased.dropFirst()
		components.append(capitalized)
	}

	return components.joined()
}

private func makeWrapperName(from typeName: String) -> String {
	"Resolvable\(typeName)"
}

private extension MacroExpansionContext {
	func diagnose(_ syntax: some SyntaxProtocol, message: ToolsMacroDiagnostic) {
		diagnose(Diagnostic(node: Syntax(syntax), message: message))
	}
}

private enum ToolsMacroDiagnostic: DiagnosticMessage {
	case missingToolDefinitions
	case onlyToolExpressionsAllowed
	case invalidToolExpression
	case duplicateCaseName(String)
	case missingAccessLevelLabel
	case unsupportedArgumentLabel(String)
	case duplicateAccessLevelArgument
	case invalidAccessLevelValue

	var message: String {
		switch self {
		case .missingToolDefinitions:
			"#tools requires at least one tool expression inside the macro body."
		case .onlyToolExpressionsAllowed:
			"Only tool creation expressions are allowed inside the #tools macro body."
		case .invalidToolExpression:
			"Each statement inside #tools must be a tool initializer expression."
		case let .duplicateCaseName(caseName):
			"The generated case name \"\(caseName)\" would be duplicated. Provide distinct tool types."
		case .missingAccessLevelLabel:
			"The access level argument must use the label accessLevel."
		case let .unsupportedArgumentLabel(label):
			"Unsupported argument label \"\(label)\". Only accessLevel is allowed."
		case .duplicateAccessLevelArgument:
			"The accessLevel argument can only be provided once."
		case .invalidAccessLevelValue:
			"The accessLevel argument must be one of .private, .internal, .package, or .public."
		}
	}

	var diagnosticID: MessageID {
		MessageID(domain: "SwiftAgentMacros", id: identifier)
	}

	private var identifier: String {
		switch self {
		case .missingToolDefinitions:
			"missingToolDefinitions"
		case .onlyToolExpressionsAllowed:
			"onlyToolExpressionsAllowed"
		case .invalidToolExpression:
			"invalidToolExpression"
		case .duplicateCaseName:
			"duplicateCaseName"
		case .missingAccessLevelLabel:
			"missingAccessLevelLabel"
		case .unsupportedArgumentLabel:
			"unsupportedArgumentLabel"
		case .duplicateAccessLevelArgument:
			"duplicateAccessLevelArgument"
		case .invalidAccessLevelValue:
			"invalidAccessLevelValue"
		}
	}

	var severity: DiagnosticSeverity { .error }
}
