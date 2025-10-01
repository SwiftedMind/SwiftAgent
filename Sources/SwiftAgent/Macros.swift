// By Dennis Müller

/// Marks a property as a resolvable tool within a `@SwiftAgentSession`.
///
/// This attribute is used in conjunction with `@SwiftAgentSession` to identify which properties
/// should be wrapped as resolvable tools. Generates a wrapper type prefixed with "Resolvable".
///
/// Properties marked with `@ResolvableTool` must:
/// - Be declared with `let` (not `var`)
/// - Have an explicit type annotation
/// - Conform to the `Tool` protocol
///
/// Example:
/// ```swift
/// @SwiftAgentSession(provider: .openAI)
/// final class MySession {
///   @ResolvableTool let calculator: CalculatorTool
///   @ResolvableTool let weather: WeatherTool = WeatherTool()
/// }
/// ```
@attached(peer, names: arbitrary)
public macro ResolvableTool() = #externalMacro(
	module: "SwiftAgentMacros",
	type: "ResolvableToolMacro",
)

/// Synthesizes a complete ModelSession implementation with automatic wrapper generation.
///
/// This macro transforms a class with `@ResolvableTool` properties into a complete
/// `ModelSession` implementation, including:
/// - Protocol conformance to `ModelSession`
/// - Type aliases for `Adapter` and `SessionType`
/// - Required properties (`adapter`, `transcript`, `tokenUsage`, `tools`)
/// - Initializers for both direct API key and configuration-based setup
/// - `ResolvedToolRun` and `PartiallyResolvedToolRun` enums
/// - Nested wrapper types for each tool
///
/// Example:
/// ```swift
/// @SwiftAgentSession(provider: .openAI) @Observable
/// final class MySession {
///   @ResolvableTool let calculator: CalculatorTool
///   @ResolvableTool let weather: WeatherTool
/// }
/// ```
///
/// The macro generates two initializers:
/// 1. `init(calculator:weather:instructions:apiKey:)` - Direct API key setup
/// 2. `init(calculator:weather:instructions:configuration:)` - Configuration-based setup
///
/// Tools with default values (e.g., `= WeatherTool()`) don't require initialization parameters.
@attached(member, names: arbitrary)
@attached(extension, conformances: ModelSession)
public macro SwiftAgentSession(provider: Provider) = #externalMacro(
	module: "SwiftAgentMacros",
	type: "SwiftAgentSessionMacro",
)

/// Provider types supported by `@SwiftAgentSession`
public enum Provider {
	case openAI
}
