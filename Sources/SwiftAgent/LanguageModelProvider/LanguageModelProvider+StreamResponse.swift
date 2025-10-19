// By Dennis Müller

import Foundation
import FoundationModels

// MARK: - String Response Methods

public extension LanguageModelProvider {
  /// Streams a text response to a plain string prompt.
  ///
  /// Each emitted ``Snapshot`` includes the current response fragment and the full transcript so you
  /// can update UI incrementally while the model thinks.
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
  /// let stream = try session.streamResponse(to: "What's the weather like in San Francisco?")
  ///
  /// for try await snapshot in stream {
  ///   if let message = snapshot.content {
  ///     print(message)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: An ``AsyncThrowingStream`` that yields response snapshots as they arrive.
  func streamResponse(
    to prompt: String,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, using: model, options: options)
  }

  /// Streams a text response from a structured ``Prompt``.
  ///
  /// Precompose prompts when you need tags or metadata alongside user text while still receiving
  /// incremental updates.
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
  ///
  /// let stream = try session.streamResponse(to: prompt)
  ///
  /// for try await snapshot in stream {
  ///   if let text = snapshot.content {
  ///     print(text)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: An ``AsyncThrowingStream`` that yields response snapshots as they arrive.
  func streamResponse(
    to prompt: Prompt,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    try streamResponse(to: prompt.formatted(), using: model, options: options)
  }

  /// Streams a text response while constructing the prompt inline with ``PromptBuilder``.
  ///
  /// This is convenient for single-use prompts that mix prose and structured tags without creating
  /// a separate ``Prompt`` variable.
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
  /// let stream = try session.streamResponse {
  ///   "You are a travel assistant."
  ///   PromptTag("request") { "Suggest a weekend itinerary for Lisbon." }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let answer = snapshot.content {
  ///     print(answer)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  ///   - prompt: Builder describing the prompt content.
  /// - Returns: An ``AsyncThrowingStream`` that yields response snapshots as they arrive.
  func streamResponse(
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    try streamResponse(to: prompt().formatted(), using: model, options: options)
  }
}

// MARK: - Structured Response Methods

public extension LanguageModelProvider {
  /// Streams a structured response from a plain string prompt.
  ///
  /// Provide a ``StructuredOutput`` type to receive strongly typed snapshots where partial values
  /// fill in as tokens arrive.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
  ///   }
  /// }
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let stream = try session.streamResponse(
  ///   to: "What's the weather like in San Francisco?",
  ///   generating: WeatherReport.self
  /// )
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.condition ?? "pending")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, generating: type, using: model, options: options)
  }

  /// Streams a structured response using a key-path registration.
  ///
  /// Use the session schema’s key path helpers to reuse registrations without referencing the type
  /// directly.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
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
  /// let stream = try session.streamResponse(
  ///   to: "What's the weather like in San Francisco?",
  ///   generating: \.weatherReport
  /// )
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.temperature ?? 0)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Raw text sent to the model.
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return processResponseStream(from: prompt, generating: StructuredOutput.self, using: model, options: options)
  }

  /// Streams a structured response from a prebuilt ``Prompt``.
  ///
  /// Useful when you want to inject metadata or context tags alongside the main request while still
  /// observing the output incrementally.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
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
  ///
  /// let stream = try session.streamResponse(
  ///   to: prompt,
  ///   generating: WeatherReport.self
  /// )
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.condition ?? "pending")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    try streamResponse(to: prompt.formatted(), generating: type, using: model, options: options)
  }

  /// Streams a structured response using a key-path registration and a prebuilt ``Prompt``.
  ///
  /// Combine schema registrations with a composed prompt when you need reusable structured outputs
  /// and rich context tagging.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(CustomerInsights.self) var customerInsights
  /// }
  ///
  /// struct CustomerInsights: StructuredOutput {
  ///   static let name = "customerInsights"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let highlights: [String]?
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
  ///
  /// let stream = try session.streamResponse(
  ///   to: prompt,
  ///   generating: \.customerInsights
  /// )
  ///
  /// for try await snapshot in stream {
  ///   if let insights = snapshot.content {
  ///     print(insights.highlights ?? [])
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: Structured prompt built with ``PromptBuilder``.
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to prompt: Prompt,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    try streamResponse(to: prompt.formatted(), generating: StructuredOutput.self, using: model, options: options)
  }

  /// Streams a structured response while building the prompt inline with ``PromptBuilder``.
  ///
  /// Ideal for single-turn prompts that need structured output but do not warrant a dedicated
  /// ``Prompt`` definition.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
  ///   }
  /// }
  ///
  /// let session = OpenAISession(
  ///   instructions: "You are a helpful assistant.",
  ///   apiKey: "sk-..."
  /// )
  ///
  /// let stream = try session.streamResponse(generating: WeatherReport.self) {
  ///   "Summarize the extended forecast"
  ///   PromptTag("city") { "Lisbon" }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.temperature ?? 0)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: Structured output declaration describing the expected schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Builder describing the prompt content.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: StructuredOutput.Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    try streamResponse(to: prompt().formatted(), generating: type, using: model, options: options)
  }

  /// Streams a structured response using a key-path registration while building the prompt inline.
  ///
  /// Combine schema registrations with a lightweight inline prompt to observe structured content
  /// as it streams in.
  ///
  /// ## Example
  /// ```swift
  /// import FoundationModels
  /// import OpenAISession
  ///
  /// @SessionSchema
  /// struct SessionSchema {
  ///   @StructuredOutput(MeetingSummary.self) var meetingSummary
  /// }
  ///
  /// struct MeetingSummary: StructuredOutput {
  ///   static let name = "meetingSummary"
  ///
  ///   @Generable
  ///   struct Schema {
  ///     let actionItems: [String]?
  ///     let decisions: [String]?
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
  /// let stream = try session.streamResponse(generating: \.meetingSummary) {
  ///   "Summarize the call transcript"
  ///   PromptTag("transcript") { callNotes }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let summary = snapshot.content {
  ///     print(summary.actionItems ?? [])
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Builder describing the prompt content.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots until generation completes.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: @Sendable () throws -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    try streamResponse(to: prompt().formatted(), generating: StructuredOutput.self, using: model, options: options)
  }
}

// MARK: - Context-Aware Response Methods

public extension LanguageModelProvider {
  /// Streams a text response while injecting grounding data into the prompt.
  ///
  /// Groundings attach supplemental context—like the current date or search results—to each
  /// streamed snapshot so you can correlate emitted tokens with the source material.
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
  /// let stream = try session.streamResponse(
  ///   to: "What's happening in the city today?",
  ///   groundingWith: [.currentDate(Date())]
  /// ) { input, sources in
  ///   PromptTag("context") {
  ///     if case let .currentDate(date) = sources.first {
  ///       "Today is \(date)"
  ///     }
  ///   }
  ///
  ///   PromptTag("user-question") { input }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let content = snapshot.content {
  ///     print(content)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - sources: Grounding items to attach to this turn.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides such as temperature.
  ///   - prompt: Builder combining the input text with the supplied groundings.
  /// - Returns: An ``AsyncThrowingStream`` yielding response snapshots with transcript context.
  func streamResponse(
    to input: String,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<String>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, using: model, options: options)
  }

  /// Streams a structured response while injecting grounding data into the prompt.
  ///
  /// The transcript stores grounding values alongside the prompt, and each snapshot surfaces the
  /// partially generated structured output so UIs can highlight progress.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
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
  /// let stream = try session.streamResponse(
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
  ///   PromptTag("user-query") { input }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.temperature ?? 0)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - type: Structured output declaration describing the expected schema.
  ///   - sources: Grounding items to attach to this turn.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Builder combining the input text with the supplied groundings.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots with transcript context.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: StructuredOutput.Type,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, generating: type, using: model, options: options)
  }

  /// Streams a structured response using a key-path registration while injecting grounding data.
  ///
  /// Use this overload when your schema already registers the structured output you need and you
  /// want to attach per-turn context.
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
  ///     let temperature: Double?
  ///     let condition: String?
  ///     let humidity: Int?
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
  /// let stream = try session.streamResponse(
  ///   to: "What's the weather like in San Francisco?",
  ///   generating: \.weatherReport,
  ///   groundingWith: [.currentDate(Date())]
  /// ) { input, sources in
  ///   PromptTag("context") {
  ///     if let date = sources.first(where: { if case .currentDate = $0 { return true } else { return false } }) {
  ///       if case let .currentDate(value) = date {
  ///         "Today is \(value)"
  ///       }
  ///     }
  ///   }
  ///
  ///   PromptTag("user-query") { input }
  /// }
  ///
  /// for try await snapshot in stream {
  ///   if let report = snapshot.content {
  ///     print(report.condition ?? "pending")
  ///   }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: User-provided text.
  ///   - type: Key path pointing to a structured output registered on your schema.
  ///   - sources: Grounding items to attach to this turn.
  ///   - model: Optional override for the model identifier.
  ///   - options: Optional generation overrides.
  ///   - prompt: Builder combining the input text with the supplied groundings.
  /// - Returns: An ``AsyncThrowingStream`` yielding structured snapshots with transcript context.
  func streamResponse<StructuredOutput: SwiftAgent.StructuredOutput>(
    to input: String,
    generating type: KeyPath<SessionSchema.StructuredOutputs, StructuredOutput.Type>,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) throws -> AsyncThrowingStream<Snapshot<StructuredOutput>, any Error> {
    let sourcesData = try schema.encodeGrounding(sources)
    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return processResponseStream(from: prompt, generating: StructuredOutput.self, using: model, options: options)
  }
}
