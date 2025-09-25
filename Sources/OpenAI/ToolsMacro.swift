@resultBuilder
public enum ToolTypesBuilder {
	public static func buildBlock(_ components: Any.Type...) -> [Any.Type] { components }
}


/// Synthesizes a resolvable tool group and conformances for the provided tool initializers.
@freestanding(declaration, names: named(Tools))
public macro tools(@ToolTypesBuilder _ build: () -> Void) = #externalMacro(module: "SwiftAgentMacros", type: "ToolsMacro")
