// By Dennis Müller

import Foundation
import FoundationModels

// MARK: - String Response Methods

public extension LanguageModelProvider {
  /// Generates a text response to a string prompt.
  ///
  /// This is the most basic response method, taking a plain string prompt and returning
  /// generated text content. The response is automatically added to the conversation transcript.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let response = try await session.respond(to: "What is the capital of France?")
  /// print(response.content) // "The capital of France is Paris."
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: The text prompt to send to the AI model.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters (temperature, max tokens, etc.).
  ///     Uses automatic options for the model if not specified.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated text, transcript entries,
  ///   and token usage information.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
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

  /// Generates a text response to a structured prompt.
  ///
  /// This method accepts a `Prompt` object built using the `@PromptBuilder` DSL,
  /// allowing for more complex prompt structures with formatting and embedded content.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let prompt = Prompt {
  ///   "You are a helpful assistant."
  ///   PromptTag("user-input") { "What is the weather like?" }
  ///   "Please provide a detailed response."
  /// }
  /// let response = try await session.respond(to: prompt)
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: A structured prompt created with `@PromptBuilder`.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated text and metadata.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    to prompt: Prompt,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<String> {
    try await respond(to: prompt.formatted(), using: model, options: options)
  }

  /// Generates a text response using a prompt builder closure.
  ///
  /// This method allows you to build prompts inline using the `@PromptBuilder` DSL,
  /// providing a convenient way to create structured prompts without explicitly
  /// constructing a ``Prompt`` object.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let response = try await session.respond(using: .gpt4) {
  ///   "You are an expert in Swift programming."
  ///   "Please explain the following concept:"
  ///   PromptTag("topic") { "Protocol-Oriented Programming" }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///   - prompt: A closure that builds the prompt using `@PromptBuilder` syntax.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated text and metadata.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
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
  /// Generates a structured response of the specified type from a string prompt.
  ///
  /// This method enables structured output generation where the AI returns data conforming
  /// to a specific `@Generable` type. This is useful for extracting structured data,
  /// creating objects, or getting formatted responses.
  ///
  /// ## Example
  ///
  /// ```swift
  /// @Generable
  /// struct WeatherReport {
  ///   let temperature: Double
  ///   let condition: String
  ///   let humidity: Int
  /// }
  ///
  /// let response = try await session.respond(
  ///   to: "Get weather for San Francisco",
  ///   generating: WeatherReport.self
  /// )
  /// print(response.content.temperature) // Strongly-typed access
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: The text prompt to send to the AI model.
  ///   - type: The `Generable` type to generate. Can often be inferred from context.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated structured content.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to prompt: String,
    generating type: (some StructuredOutput<Content>).Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<Content> where Content: Generable, Self: RawStructuredOutputSupport {
    let sourcesData = try schema.encodeGrounding([SessionSchema.DecodedGrounding]())
    let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
    return try await processResponse(from: prompt, generating: type, using: model, options: options)
  }

  /// Generates a structured response of the specified type from a structured prompt.
  ///
  /// Combines the power of structured prompts with structured output generation.
  /// Use this when you need both complex prompt formatting and typed response data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let prompt = Prompt {
  ///   "Extract key information from the following text:"
  ///   PromptTag("document") { documentText }
  ///   "Format the response as structured data."
  /// }
  ///
  /// let response = try await session.respond(
  ///   to: prompt,
  ///   generating: DocumentSummary.self
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - prompt: A structured prompt created with `@PromptBuilder`.
  ///   - type: The `Generable` type to generate.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated structured content.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to prompt: Prompt,
    generating type: (some StructuredOutput<Content>).Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
  ) async throws -> Response<Content> where Content: Generable, Self: RawStructuredOutputSupport {
    try await respond(
      to: prompt.formatted(),
      generating: type,
      using: model,
      options: options,
    )
  }

  /// Generates a structured response using a prompt builder closure.
  ///
  /// Allows you to build prompts inline while generating structured output,
  /// combining the convenience of `@PromptBuilder` with typed responses.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let response = try await session.respond(generating: TaskList.self) {
  ///   "Create a task list based on the following requirements:"
  ///   PromptTag("requirements") { userRequirements }
  ///   "Include priority levels and estimated completion times."
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - type: The `Generable` type to generate.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///   - prompt: A closure that builds the prompt using `@PromptBuilder` syntax.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated structured content.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    generating type: (some StructuredOutput<Content>).Type,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt,
  ) async throws -> Response<Content> where Content: Generable, Self: RawStructuredOutputSupport {
    try await respond(
      to: prompt().formatted(),
      generating: type,
      using: model,
      options: options,
    )
  }
}

// MARK: - Context-Aware Response Methods

public extension LanguageModelProvider {
  /// Generates a text response with additional context while keeping user input separate.
  ///
  /// The method automatically extracts URLs from the input and fetches link previews,
  /// which are included in the context alongside the provided context items.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let response = try await session.respond(
  ///   to: "What are the key features of SwiftUI?",
  ///   supplying: [
  ///     .documentContext("SwiftUI is a declarative framework..."),
  ///     .searchResult("SwiftUI provides state management...")
  ///   ]
  /// ) { input, context in
  ///   "You are a helpful assistant. Use the following context to answer questions."
  ///   PromptTag("context") {
  ///     for source in context.sources {
  ///       source
  ///     }
  ///   }
  ///   PromptTag("user-question") { input }
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: The user's input/question as a plain string.
  ///   - contextItems: Array of context sources that implement ``PromptContextSource``.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///   - prompt: A closure that builds the final prompt by combining input and context.
  ///     Receives the input string and a `PromptContext` containing sources and link previews.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated text and metadata.
  ///   The transcript entry will maintain separation between input and context.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    to input: String,
    using model: Adapter.Model = .default,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) async throws -> Response<String> {
    let sourcesData = try schema.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await processResponse(from: prompt, using: model, options: options)
  }

  /// Generates a structured response with additional context while keeping user input separate.
  ///
  /// Combines context-aware generation with structured output, allowing you to provide
  /// supplementary information while getting back strongly-typed data. This is particularly
  /// useful for structured data extraction from contextual information.
  ///
  /// Like the text variant, this method automatically handles URL extraction and link preview
  /// generation from the input text.
  ///
  /// ## Example
  ///
  /// ```swift
  /// @Generable
  /// struct ProductSummary {
  ///   let name: String
  ///   let features: [String]
  ///   let price: Double
  /// }
  ///
  /// let response = try await session.respond(
  ///   to: "Summarize this product",
  ///   supplying: [.productDescription(productData)],
  ///   generating: ProductSummary.self
  /// ) { input, context in
  ///   "Extract product information from the context below:"
  ///   PromptTag("context", items: context.sources)
  ///   "User request: \(input)"
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - input: The user's input/question as a plain string.
  ///   - contextItems: Array of context sources that implement ``PromptContextSource``.
  ///   - type: The `Generable` type to generate.
  ///   - model: The model to use for generation. Defaults to the adapter's default model.
  ///   - options: Optional generation parameters.
  ///   - prompt: A closure that builds the final prompt by combining input and context.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated structured content and metadata.
  ///
  /// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to input: String,
    generating type: (some StructuredOutput<Content>).Type,
    using model: Adapter.Model = .default,
    groundingWith sources: [SessionSchema.DecodedGrounding],
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [SessionSchema.DecodedGrounding])
      -> Prompt,
  ) async throws -> Response<Content> where Content: Generable, Self: RawStructuredOutputSupport {
    let sourcesData = try schema.encodeGrounding(sources)

    let prompt = Transcript.Prompt(
      input: input,
      sources: sourcesData,
      prompt: prompt(input, sources).formatted(),
    )
    return try await processResponse(from: prompt, generating: type, using: model, options: options)
  }
}
