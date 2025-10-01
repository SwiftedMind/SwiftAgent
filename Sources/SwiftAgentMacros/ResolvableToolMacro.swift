// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Peer macro that generates a ResolvableTool wrapper for a tool property
public struct ResolvableToolMacro: PeerMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingPeersOf declaration: some DeclSyntaxProtocol,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		// @ResolvableTool can only be applied to stored properties
		guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
			throw MacroError.notAProperty
		}

		// Ensure it's a `let` property
		guard variableDecl.bindingSpecifier.tokenKind == .keyword(.let) else {
			throw MacroError.mustBeLet
		}

		// Get the first binding (property)
		guard let binding = variableDecl.bindings.first else {
			throw MacroError.noBinding
		}

		// Get the property name
		guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier else {
			throw MacroError.invalidPattern
		}

		// Get the type annotation or infer from initializer
		let toolTypeName: String
		if let typeAnnotation = binding.typeAnnotation {
			// Use explicit type annotation
			toolTypeName = typeAnnotation.type.trimmedDescription
		} else if let initializer = binding.initializer {
			// Infer type from initializer expression
			if let functionCall = initializer.value.as(FunctionCallExprSyntax.self) {
				// Extract type from function call like `CalculatorTool()`
				toolTypeName = functionCall.calledExpression.trimmedDescription
			} else {
				throw MacroError.cannotInferType
			}
		} else {
			throw MacroError.missingTypeAnnotation
		}

		// Generate the wrapper struct name
		let wrapperName = "Resolvable\(identifier.text.capitalizedFirstLetter())Tool"

		// Generate the wrapper struct
		let wrapperStruct: DeclSyntax =
			"""
			struct \(raw: wrapperName): ResolvableTool {
			  typealias Session = SessionType
			  typealias BaseTool = \(raw: toolTypeName)
			  typealias Arguments = BaseTool.Arguments
			  typealias Output = BaseTool.Output

			  private let baseTool: BaseTool

			  init(baseTool: \(raw: toolTypeName)) {
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
			    .\(identifier)(run)
			  }

			  func resolvePartially(
			    _ run: PartialToolRun<\(raw: wrapperName)>
			  ) -> Session.PartiallyResolvedToolRun {
			    .\(identifier)(run)
			  }
			}
			"""

		return [wrapperStruct]
	}
}
