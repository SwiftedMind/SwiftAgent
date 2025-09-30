// By Dennis Müller

/// Marks a property as a resolvable tool within a `@Resolvable` tool group.
///
/// This attribute is used in conjunction with `@Resolvable` to identify which properties
/// should be wrapped as resolvable tools. Generates a wrapper type prefixed with "Resolvable".
///
/// Example:
/// ```swift
/// @Resolvable
/// struct ToolGroup {
///   @ResolvableTool var addMovie = AddMovieTool()
/// }
/// ```
@attached(peer, names: arbitrary)
public macro ResolvableTool() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ResolvableToolMacro",
)

/// Synthesizes a resolvable tool group with automatic wrapper generation.
///
/// This macro transforms a struct with `@ResolvableTool` properties into a complete
/// `ResolvableToolGroup` implementation, including:
/// - Conformance to `ResolvableToolGroup`
/// - An `allTools` property containing all wrapped tools
/// - `ResolvedToolRun` and `PartiallyResolvedToolRun` enums
/// - Nested wrapper types for each tool
///
/// Example:
/// ```swift
/// @Resolvable
/// fileprivate struct ToolGroup {
///   @ResolvableTool var addMovie = AddMovieTool()
/// }
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: ResolvableToolGroup)
public macro Resolvable() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ResolvableMacro",
)
