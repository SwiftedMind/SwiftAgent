// By Dennis Müller

/// Marks a property as a decodable tool within a `@TranscriptDecoder` tool group.
///
/// This attribute is used in conjunction with `@TranscriptDecoder` to identify which properties
/// should be wrapped as decodable tools. Generates a wrapper type prefixed with "Decoder".
///
/// Example:
/// ```swift
/// @TranscriptDecoder
/// struct ToolGroup {
///   @ToolDecoder var addMovie = AddMovieTool()
/// }
/// ```
@attached(peer, names: arbitrary)
public macro ToolDecoder() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ToolDecoderMacro",
)

/// Synthesizes a transcript decoder tool group with automatic wrapper generation.
///
/// This macro transforms a struct with `@ToolDecoder` properties into a complete
/// `TranscriptDecodable` implementation, including:
/// - Conformance to `TranscriptDecodable`
/// - An `allTools` property containing all wrapped tools
/// - `ResolvedToolRun` and `PartiallyResolvedToolRun` enums
/// - Nested wrapper types for each tool
///
/// Example:
/// ```swift
/// @TranscriptDecoder
/// fileprivate struct ToolGroup {
///   @ToolDecoder var addMovie = AddMovieTool()
/// }
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: TranscriptDecodable)
public macro TranscriptDecoder() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "TranscriptDecoderMacro",
)
