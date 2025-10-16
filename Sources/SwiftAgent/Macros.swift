// By Dennis Müller

import Observation

/// Synthesizes the helper types required by `LanguageModelSessionSchema`, including tool wrappers,
/// decoding enums, and structured output registrations.
///
/// Applying this macro to a struct performs the following:
/// - Exposes the nested `@Tool`, `@StructuredOutput`, and `@Grounding` property wrappers.
/// - Generates the stored `decodableTools` collection used by the transcript decoder.
/// - Synthesizes `DecodedGrounding`, `DecodedToolRun`, and `DecodedStructuredOutput` enums.
/// - Emits `Decodable<Name>` helper types for tools and structured outputs.
///
/// Example:
/// ```swift
/// @SessionSchema
/// struct SessionSchema: LanguageModelSessionSchema {
///   @Tool var calculator = CalculatorTool()
///   @Tool var weather = WeatherTool()
///   @Grounding(Date.self) var currentDate
///   @StructuredOutput(WeatherReport.self) var weatherReport
/// }
/// ```
@attached(member, names: arbitrary)
public macro SessionSchema() = #externalMacro(
  module: "SwiftAgentMacros",
  type: "SessionSchemaMacro",
)

/// Marks a property synthesized by `@LanguageModelProvider` as observable and inserts the associated storage.
@attached(peer, names: prefixed(_))
@attached(accessor)
public macro _LanguageModelProviderObserved(initialValue: Any) = #externalMacro(
  module: "SwiftAgentMacros",
  type: "LanguageModelProviderObservedMacro",
)
