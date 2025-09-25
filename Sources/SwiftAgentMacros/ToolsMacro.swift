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

		let enumDecl = makeToolsEnum(for: toolDefinitions)

		return [enumDecl]
	}
}

private struct ToolDefinition {
	let baseTypeDescription: String
	let caseName: String
	let wrapperName: String
	let creationExpression: ExprSyntax
}

private func makeToolsEnum(for definitions: [ToolDefinition]) -> DeclSyntax {
	var lines: [String] = []
	lines.append("enum Tools: ResolvableToolGroup {")
	lines.append("  static let all: [any ResolvableTool<Tools>] = [")

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
	lines.append("  enum Partials {")

	for definition in definitions {
		lines.append("    case \(definition.caseName)(PartialToolRun<\(definition.wrapperName)>)")
	}

	lines.append("  }")

	for definition in definitions {
		lines.append("")
		lines.append("  struct \(definition.wrapperName): ResolvableTool {")
		lines.append("    typealias BaseTool = \(definition.baseTypeDescription)")
		lines.append("    typealias Arguments = BaseTool.Arguments")
		lines.append("    typealias Output = BaseTool.Output")
		lines.append("")
		lines.append("    private let baseTool: BaseTool")
		lines.append("")
		lines.append("    init() {")
		lines.append("      self.baseTool = \(definition.creationExpression.trimmed.description)")
		lines.append("    }")
		lines.append("")
		lines.append("    var name: String { baseTool.name }")
		lines.append("    var description: String { baseTool.description }")
		lines.append("    var parameters: GenerationSchema { baseTool.parameters }")
		lines.append("")
		lines.append("    func call(arguments: Arguments) async throws -> Output {")
		lines.append("      try await baseTool.call(arguments: arguments)")
		lines.append("    }")
		lines.append("")
		lines.append("    func resolve(_ run: ToolRun<\(definition.wrapperName)>) -> Tools {")
		lines.append("      .\(definition.caseName)(run)")
		lines.append("    }")
		lines.append("")
		lines.append("    func resolvePartially(_ run: PartialToolRun<\(definition.wrapperName)>) -> Tools.Partials {")
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
		}
	}

	var severity: DiagnosticSeverity { .error }
}
