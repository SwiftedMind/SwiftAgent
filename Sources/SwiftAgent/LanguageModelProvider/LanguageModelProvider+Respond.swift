// By Dennis Müller

import Foundation
import FoundationModels

// MARK: - String Response Methods

public extension LanguageModelProvider {
  /// Generates a text response to a plain string prompt.
  ///
  /// SwiftAgent stores each turn in the transcript so you can revisit prompts, tool runs, and
  /// responses later.
  ///
  /// ## Example
  /// ```swift
  /// import OpenAISession
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let response = try await session.respond(to: "Weather in Lisbon today?")
  /// print(response.content)
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: A ``AgentResponse`` containing the final text and transcript metadata.
  @discardableResult
  func respond(
    to prompt: String,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<String> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())

    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return try await processResponse(
      from: prompt,
      using: model,
      options: options,
    )
  }

  /// Generates a text response from a structured ``Prompt``.
  ///
  /// Build prompts ahead of time when you need tags or metadata alongside prose.
  ///
  /// ## Example
  /// ```swift
  /// import OpenAISession
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let prompt = Prompt {
  ///   "You are a concise assistant."
  ///   PromptTag("question") { "List three Swift 6 features." }
  /// }
  /// let response = try await session.respond(to: prompt)
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: A ``AgentResponse`` containing the final text and transcript metadata.
  @discardableResult
  func respond(
    to prompt: Prompt,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<String> {
    try await respond(to: prompt.formatted(), using: model, options: options)
  }

  /// Generates a text response while constructing the prompt inline with ``PromptBuilder``.
  ///
  /// ## Example
  /// ```swift
  /// import OpenAISession
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let response = try await session.respond {
  ///   "You are a travel assistant."
  ///   PromptTag("request") { "Suggest a weekend itinerary for Lisbon." }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  ///   - prompt: Closure building the prompt content.
  @discardableResult
  func respond(
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt,
  ) async throws -> Response<String> {
    try await respond(to: prompt().formatted(), using: model, options: options)
  }
}

// MARK: - Structured Response Methods

public extension LanguageModelProvider {
  /// Generates a structured response from a plain string prompt.
  ///
  /// Pass a ``StructuredOutput`` type to receive validated, strongly typed data.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let report = try await session.respond(
  ///   to: "Summarize today's forecast",
  ///   generating: WeatherReport.self
  /// ).content
  /// print(report.condition)
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: A response whose ``AgentResponse/content`` matches the schema of
  ///   `type`.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<StructuredOutput> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return try await processResponse(from: prompt, generating: type, using: model, options: options)
  }

  /// Generates a structured response from a plain string prompt.
  ///
  /// Pass a ``StructuredOutput`` type to receive validated, strongly typed data.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(WeatherReport.self) var weatherReport
  /// }
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// let schema = SessionSchema()
  /// let session = OpenAISession(
  ///   schema: schema,
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let report = try await session.respond(
  ///   to: "Summarize today's forecast",
  ///   generating: \.weatherReport
  /// ).content
  /// print(report.condition)
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: A response whose ``AgentResponse/content`` matches the schema of
  ///   `type`.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<StructuredOutput> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return try await processResponse(
      from: prompt,
      generating: StructuredOutput.self,
      using: model,
      options: options,
    )
  }

  /// Generates a structured response from a prebuilt structured ``Prompt``.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// let article = "..."
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let prompt = Prompt {
  ///   "Summarize the highlights"
  ///   PromptTag("document") { article }
  /// }
  /// let summary = try await session.respond(
  ///   to: prompt,
  ///   generating: WeatherReport.self
  /// ).content
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  /// - Returns: A response whose ``AgentResponse/content`` matches the schema of
  ///   `type`.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<StructuredOutput> {
    try await respond(
      to: prompt.formatted(),
      generating: type,
      using: model,
      options: options,
    )
  }

  /// Generates a structured response using a key-path registration and a prebuilt ``Prompt``.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(WeatherReport.self) var weatherReport
  ///   @StructuredOutput(CustomerInsights.self) var customerInsights
  /// }
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// struct CustomerInsights: StructuredOutput {
  ///   static let name = "customerInsights"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let highlights: [String]
  ///   }
  /// }
  ///
  /// let schema = SessionSchema()
  /// let session = OpenAISession(
  ///   schema: schema,
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let prompt = Prompt {
  ///   "Extract customer insights"
  ///   PromptTag("transcript") { callNotes }
  /// }
  /// let insights = try await session.respond(
  ///   to: prompt,
  ///   generating: \.customerInsights
  /// ).content
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  /// - Returns: A response whose content matches the schema referenced by `type`.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<StructuredOutput> {
    try await respond(
      to: prompt.formatted(),
      generating: StructuredOutput.self,
      using: model,
      options: options,
    )
  }

  /// Generates a structured response while building the prompt inline with ``PromptBuilder``.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let report = try await session.respond(generating: WeatherReport.self) {
  ///   "Summarize the extended forecast"
  ///   PromptTag("city") { "Lisbon" }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Closure building the prompt content.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt,
  ) async throws -> Response<StructuredOutput> {
    try await respond(
      to: prompt().formatted(),
      generating: type,
      using: model,
      options: options,
    )
  }

  /// Generates a structured response using a key-path registration while building the prompt inline.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(WeatherReport.self) var weatherReport
  ///   @StructuredOutput(MeetingSummary.self) var meetingSummary
  /// }
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// struct MeetingSummary: StructuredOutput {
  ///   static let name = "meetingSummary"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let actionItems: [String]
  ///     let decisions: [String]
  ///   }
  /// }
  ///
  /// let schema = SessionSchema()
  /// let session = OpenAISession(
  ///   schema: schema,
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let summary = try await session.respond(generating: \.meetingSummary) {
  ///   "Summarize the call transcript"
  ///   PromptTag("transcript") { callNotes }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Closure building the prompt content.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt,
  ) async throws -> Response<StructuredOutput> {
    try await respond(
      to: prompt().formatted(),
      generating: StructuredOutput.self,
      using: model,
      options: options,
    )
  }
}

public extension LanguageModelProvider {
  /// Generates a text response while injecting grounding data into the prompt.
  ///
  /// Groundings represent supplemental context—such as the current date or search results—and are
  /// stored alongside the user input.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @Grounding(Date.self) var currentDate
  /// }
  ///
  /// let schema = SessionSchema()
  /// let session = OpenAISession(
  ///   schema: schema,
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let response = try await session.respond(
  ///   to: "What's happening in the city today?",
  ///   groundingWith: [.currentDate(Date())]
  /// ) { input, sources in
  ///   PromptTag("context") {
  ///     if case let .currentDate(date) = sources.first { "Today is \(date)" }
  ///   }
  ///   PromptTag("user-question") { input }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - model: Optional override for the model identifier.
  ///   - sources: Grounding items to attach to this turn.
  ///   - options: Optional generation overrides.
  ///   - prompt: Prompt builder combining the input text with the supplied groundings.
  @discardableResult
  func respond(
    to input: String,
    using model: Adapter.Model = .default,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) async throws -> Response<String> where SessionSchema: GroundingSupportingSchema {
    let sourcesData = try schema.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await processResponse(from: prompt, using: model, options: options)
  }

  /// Generates a structured response while injecting grounding data into the prompt.
  ///
  /// The transcript keeps the grounding values next to the user input and validates the structured
  /// result against the provided schema.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(WeatherReport.self) var weatherReport
  ///   @Grounding(Date.self) var currentDate
  /// }
  ///
  /// struct WeatherReport: StructuredOutput {
  ///   static let name = "weatherReport"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let temperature: Double
  ///     let condition: String
  ///     let humidity: Int
  ///   }
  /// }
  ///
  /// let schema = SessionSchema()
  /// let session = OpenAISession(
  ///   schema: schema,
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let report = try await session.respond(
  ///   to: "What's the weather like in San Francisco?",
  ///   generating: WeatherReport.self,
  ///   groundingWith: [.currentDate(Date())]
  /// ) { input, sources in
  ///   PromptTag("context") {
  ///     for source in sources {
  ///       if case let .currentDate(date) = source {
  ///         "Today is \(date)."
  ///       }
  ///     }
  ///   }
  ///
  ///   PromptTag("user-query") {
  ///     input
  ///   }
  /// }
  ///
  /// print(report.content.temperature)
  /// ```
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - sources: Grounding items to attach to this turn.
  ///   - options: Optional generation overrides.
  ///   - prompt: Prompt builder combining the input text with the supplied groundings.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) async throws -> Response<StructuredOutput> where SessionSchema: GroundingSupportingSchema {
    let sourcesData = try schema.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await processResponse(from: prompt, generating: type, using: model, options: options)
  }

  /// Generates a structured response while injecting grounding data into the prompt.
  ///
  /// The transcript keeps the grounding values next to the user input and validates the structured
  /// result against the provided schema.
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - sources: Grounding items to attach to this turn.
  ///   - options: Optional generation overrides.
  ///   - prompt: Prompt builder combining the input text with the supplied groundings.
  @discardableResult
  func respond<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) async throws -> Response<StructuredOutput> where SessionSchema: GroundingSupportingSchema {
    let sourcesData = try schema.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await processResponse(
      from: prompt,
      generating: StructuredOutput.self,
      using: model,
      options: options,
    )
  }
}
