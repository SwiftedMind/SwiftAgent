// By Dennis Müller

/// Marks a property as a decodable tool within a `@TranscriptResolver` tool group.
///
/// This attribute is used in conjunction with `@TranscriptResolver` to identify which properties
/// should be wrapped as decodable tools. Generates a wrapper type prefixed with "Resolvable".
///
/// Example:
/// ```swift
/// @TranscriptResolver
/// struct Resolver {
///   @ResolvableTool var addMovie = AddMovieTool()
/// }
/// ```
@attached(peer, names: arbitrary)
public macro ResolvableTool() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ResolvableToolMacro",
)

/// Synthesizes a transcript decoder tool group with automatic wrapper generation.
///
/// This macro transforms a struct with `@ResolvableTool` properties into a complete
/// `TranscriptResolvable` implementation, including:
/// - Conformance to `TranscriptResolvable`
/// - An `allTools` property containing all wrapped tools
/// - `ResolvedToolRun` and `PartiallyResolvedToolRun` enums
/// - Nested wrapper types for each tool
///
/// Example:
/// ```swift
/// @TranscriptResolver
/// fileprivate struct Resolver {
///   @ResolvableTool var addMovie = AddMovieTool()
/// }
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: ModelSession)
public macro TranscriptResolver() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "SwiftAgentSessionMacro",
)
