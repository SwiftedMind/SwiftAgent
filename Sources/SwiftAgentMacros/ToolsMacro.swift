// By Dennis Müller

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

@main
struct SwiftAgentMacroPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = []
}
