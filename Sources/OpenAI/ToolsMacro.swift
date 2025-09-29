// By Dennis Müller

import SwiftAgent

/// Synthesizes a resolvable tool group and conformances for the provided tool initializers.
///
/// - Parameters:
///   - name: The name of the generated enum. Defaults to "Tools".
///   - accessLevel: The access level for the generated types. Defaults to `.internal`.
///   - build: A closure that returns the tool instances to include.
@freestanding(declaration, names: prefixed(Resolvable), named(Tools))
public macro tools(
	name: String = "Tools",
	accessLevel: ToolsAccessLevel = .internal,
	@ToolsMacroBuilder _ build: () -> [any SwiftAgentTool],
) = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ToolsMacro",
)

/// Access level for generated tool wrapper types.
public enum ToolsAccessLevel {
	case `fileprivate`
	case `internal`
	case package
	case `public`
}

/// Aggregates tool definitions from the macro body without emitting unused result warnings.
@resultBuilder
public enum ToolsMacroBuilder {
	public static func buildExpression(_ expression: some SwiftAgentTool) -> [any SwiftAgentTool] {
		[expression]
	}

	public static func buildBlock(_ components: [any SwiftAgentTool]...) -> [any SwiftAgentTool] {
		components.flatMap(\.self)
	}

	public static func buildOptional(_ component: [any SwiftAgentTool]?) -> [any SwiftAgentTool] {
		component ?? []
	}

	public static func buildEither(first component: [any SwiftAgentTool]) -> [any SwiftAgentTool] {
		component
	}

	public static func buildEither(second component: [any SwiftAgentTool]) -> [any SwiftAgentTool] {
		component
	}

	public static func buildArray(_ components: [[any SwiftAgentTool]]) -> [any SwiftAgentTool] {
		components.flatMap(\.self)
	}

	public static func buildLimitedAvailability(_ component: [any SwiftAgentTool]) -> [any SwiftAgentTool] {
		component
	}
}
