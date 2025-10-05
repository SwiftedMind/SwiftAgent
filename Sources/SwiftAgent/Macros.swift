// By Dennis Müller

import Observation

/// Synthesizes a complete `LanguageModelProvider` implementation, including tool wrappers and
/// support infrastructure for interacting with Foundation Models.
///
/// Applying this macro to a class performs the following:
/// - Generates the nested `@Tool` property wrapper used to mark stored tool properties.
/// - Adds type aliases, storage, and initializers required by `LanguageModelProvider`.
/// - Synthesizes `ResolvedToolRun` and `StreamingToolRun` enums.
/// - Emits resolver wrapper types (`Resolvable<Name>Tool`) for each `@Tool` property.
///
/// Example:
/// ```swift
/// @LanguageModelProvider(.openAI)
/// final class MySession {
///   @Tool var calculator: CalculatorTool
///   @Tool var weather = WeatherTool()
/// }
/// ```
///
/// Two convenience initializers are generated:
/// 1. `init(calculator:weather:instructions:apiKey:)`
/// 2. `init(calculator:weather:instructions:configuration:)`
///
/// Tool parameters are omitted automatically when the corresponding properties have default values.
@attached(member, names: arbitrary)
@attached(extension, conformances: LanguageModelProvider, Sendable, Observation.Observable)
public macro LanguageModelProvider(_ provider: Provider) = #externalMacro(
	module: "SwiftAgentMacros",
	type: "LanguageModelProviderMacro",
)

/// Provider types supported by `@LanguageModelProvider`.
public enum Provider {
	case openAI
}
