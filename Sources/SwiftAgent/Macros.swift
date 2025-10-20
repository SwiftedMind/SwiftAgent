// By Dennis Müller

import Observation

/// Declares the tools, groundings, and structured outputs your session understands.
///
/// Annotate a struct with `@SessionSchema` to generate everything SwiftAgent needs to resolve
/// transcripts, provide typed streaming helpers, and register your tool and structured output
/// declarations. The macro exposes the property wrappers (`@Tool`, `@Grounding`, `@StructuredOutput`)
/// and synthesizes the glue code that powers `session.respond`, `streamResponse`, and
/// `schema.resolve`.
///
/// ```swift
/// struct WeatherTool: Tool { /* ... */ }
/// struct WeatherReport: StructuredOutput { /* ... */ }
///
/// @SessionSchema
/// struct SessionSchema {
///   @Tool var weatherTool = WeatherTool()
///   @Grounding(Date.self) var currentDate
///   @StructuredOutput(WeatherReport.self) var weatherReport
/// }
///
/// let schema = SessionSchema()
/// let session = OpenAISession(schema: schema, instructions: "You are a helpful assistant.", apiKey: "sk-...")
/// let response = try await session.respond(to: "Weather in Lisbon?", generating: \.weatherReport)
/// ```
@attached(member, names: arbitrary)
@attached(
  extension,
  conformances: LanguageModelSessionSchema, GroundingSupportingSchema,
  names: arbitrary
)
public macro SessionSchema() = #externalMacro(
  module: "SwiftAgentMacros",
  type: "SessionSchemaMacro",
)
