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
		ResolvableToolMacro.self,
		ResolvableMacro.self,
	]
}

public struct ToolsMacro: DeclarationMacro {
	public static func expansion(
		of node: some FreestandingMacroExpansionSyntax,
		in context: some MacroExpansionContext,
	) throws -> [DeclSyntax] {
		guard let arguments = resolveArguments(for: node, in: context) else {
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

		let enumDecl = makeToolsEnum(
			for: toolDefinitions,
			enumName: arguments.name,
			accessLevel: arguments.accessLevel,
		)

		return [enumDecl]
	}
}

private struct ToolDefinition {
	let baseTypeDescription: String
	let caseName: String
	let wrapperName: String
	let creationExpression: ExprSyntax
}

private struct MacroArguments {
	let name: String
	let accessLevel: AccessLevel
}

private func resolveArguments(
	for node: some FreestandingMacroExpansionSyntax,
	in context: some MacroExpansionContext,
) -> MacroArguments? {
	let arguments = node.arguments
	if arguments.isEmpty {
		return MacroArguments(name: "Tools", accessLevel: .internal)
	}

	var selectedName: String?
	var selectedLevel: AccessLevel?

	for argument in arguments {
		if argument.expression.is(ClosureExprSyntax.self) {
			continue
		}

		guard let label = argument.label?.text else {
			context.diagnose(argument, message: .missingArgumentLabel)
			return nil
		}

		switch label {
		case "name":
			if selectedName != nil {
				context.diagnose(argument, message: .duplicateNameArgument)
				return nil
			}
			guard let name = extractStringLiteral(from: argument.expression) else {
				context.diagnose(argument, message: .invalidNameValue)
				return nil
			}

			selectedName = name

		case "accessLevel":
			if selectedLevel != nil {
				context.diagnose(argument, message: .duplicateAccessLevelArgument)
				return nil
			}
			guard let level = AccessLevel(expression: argument.expression) else {
				context.diagnose(argument, message: .invalidAccessLevelValue)
				return nil
			}

			selectedLevel = level

		default:
			context.diagnose(argument, message: .unsupportedArgumentLabel(label))
			return nil
		}
	}

	return MacroArguments(
		name: selectedName ?? "Tools",
		accessLevel: selectedLevel ?? .internal,
	)
}

private func extractStringLiteral(from expression: ExprSyntax) -> String? {
	guard let stringLiteral = expression.as(StringLiteralExprSyntax.self) else {
		return nil
	}
	guard let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self) else {
		return nil
	}

	return segment.content.text
}

private enum AccessLevel: String {
	case `fileprivate`
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

private func makeToolsEnum(
	for definitions: [ToolDefinition],
	enumName: String,
	accessLevel: AccessLevel,
) -> DeclSyntax {
	var lines: [String] = []
	let accessModifier = accessLevel.keyword
	lines.appendMultilineString(
		"""
		\(accessModifier) enum \(enumName): ResolvableToolGroup {
		  static let all: [any ResolvableTool<\(enumName)>] = [
		""",
	)

	let lastIndex = definitions.count - 1

	for (index, definition) in definitions.enumerated() {
		let separator = index < lastIndex ? "," : ""
		lines.append("    \(definition.wrapperName)()\(separator)")
	}

	lines.appendMultilineString(
		"""
		  ]

		""",
	)

	for definition in definitions {
		lines.append("  case \(definition.caseName)(ToolRun<\(definition.wrapperName)>)")
	}

	lines.appendMultilineString(
		"""

		  \(accessModifier) enum PartiallyGenerated: Equatable {
		""",
	)

	for definition in definitions {
		lines.append("    case \(definition.caseName)(PartialToolRun<\(definition.wrapperName)>)")
	}

	lines.append("  }")

	for definition in definitions {
		lines.appendMultilineString(
			"""

			  \(accessModifier) struct \(definition.wrapperName): ResolvableTool {
			    \(accessModifier) typealias BaseTool = \(definition.baseTypeDescription)
			    \(accessModifier) typealias Arguments = BaseTool.Arguments
			    \(accessModifier) typealias Output = BaseTool.Output

					private let baseTool: BaseTool

			    \(accessModifier) init() {
			      self.baseTool = \(definition.creationExpression.trimmed.description)
			    }

			    \(accessModifier) var name: String { baseTool.name }
			    \(accessModifier) var description: String { baseTool.description }
			    \(accessModifier) var parameters: GenerationSchema { baseTool.parameters }

			    \(accessModifier) func call(arguments: Arguments) async throws -> Output {
			      try await baseTool.call(arguments: arguments)
			    }

			    \(accessModifier) func resolve(_ run: ToolRun<\(definition.wrapperName)>) -> \(enumName) {
			      .\(definition.caseName)(run)
			    }

			    \(accessModifier) func resolvePartially(_ run: PartialToolRun<\(definition
				.wrapperName)>) -> \(enumName).PartiallyGenerated {
			      .\(definition.caseName)(run)
			    }
			  }
			""",
		)
	}

	lines.append("}")

	return DeclSyntax(stringLiteral: lines.joined(separator: "\n"))
}

private extension [String] {
	mutating func appendMultilineString(_ multiline: String) {
		let contents = Substring(multiline)
		let newLines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
		append(contentsOf: newLines)
	}
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
	case missingArgumentLabel
	case unsupportedArgumentLabel(String)
	case duplicateNameArgument
	case invalidNameValue
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
		case .missingArgumentLabel:
			"Arguments must have a label (name or accessLevel)."
		case let .unsupportedArgumentLabel(label):
			"Unsupported argument label \"\(label)\". Only name and accessLevel are allowed."
		case .duplicateNameArgument:
			"The name argument can only be provided once."
		case .invalidNameValue:
			"The name argument must be a string literal."
		case .duplicateAccessLevelArgument:
			"The accessLevel argument can only be provided once."
		case .invalidAccessLevelValue:
			"The accessLevel argument must be one of .fileprivate, .internal, .package, or .public."
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
		case .missingArgumentLabel:
			"missingArgumentLabel"
		case .unsupportedArgumentLabel:
			"unsupportedArgumentLabel"
		case .duplicateNameArgument:
			"duplicateNameArgument"
		case .invalidNameValue:
			"invalidNameValue"
		case .duplicateAccessLevelArgument:
			"duplicateAccessLevelArgument"
		case .invalidAccessLevelValue:
			"invalidAccessLevelValue"
		}
	}

	var severity: DiagnosticSeverity { .error }
}
