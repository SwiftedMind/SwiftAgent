// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// The core ModelSession class that provides AI agent functionality with Apple's FoundationModels design philosophy.
///
/// ``ModelSession`` is the main entry point for building autonomous AI agents. It handles agent loops, tool execution,
/// and adapter communication while maintaining a conversation transcript. The class is designed to be used with
/// different AI providers through the adapter pattern.
///
/// ## Basic Usage
///
/// ```swift
/// // Create a session with OpenAI
/// let session = ModelSession.openAI(
///   tools: [WeatherTool(), CalculatorTool()],
///   instructions: "You are a helpful assistant.",
///   apiKey: "sk-..."
/// )
///
/// // Get a response
/// let response = try await session.respond(to: "What's the weather like in San Francisco?")
/// print(response.content)
/// ```
///
/// ## Structured Generation
///
/// Generate strongly-typed responses using `@Generable` types:
///
/// ```swift
/// @Generable
/// struct TaskList {
///   let tasks: [Task]
///   let priority: String
/// }
///
/// let response = try await session.respond(
///   to: "Create a todo list for planning a vacation",
///   generating: TaskList.self
/// )
/// ```
///
/// ## Context Support
///
/// Provide additional context while keeping user input separate:
///
/// ```swift
/// let response = try await session.respond(
///   to: "What are the key features?",
///   supplying: [.documentContext("SwiftUI documentation...")]
/// ) { input, context in
///   PromptTag("context", items: context.sources)
///   input
/// }
/// ```
///
/// ## Token Usage Tracking
///
/// Monitor cumulative token usage across all responses in the session:
///
/// ```swift
/// // After multiple responses
/// print("Total tokens used: \(session.sessionTokenUsage.totalTokens ?? 0)")
/// print("Total input tokens: \(session.sessionTokenUsage.inputTokens ?? 0)")
/// print("Total output tokens: \(session.sessionTokenUsage.outputTokens ?? 0)")
/// ```
///
/// - Note: ModelSession is `@MainActor` isolated and `@Observable` for SwiftUI integration.
@Observable @MainActor
public final class ModelSession<Adapter: AgentAdapter, Context: PromptContextSource> {
  /// The transcript type for this session, containing the conversation history.
  public typealias Transcript = AgentTranscript<Context>

  /// The context type for this session, containing additional prompt context.
  public typealias Context = PromptContext<Context>

  /// The response type for this session, containing generated content and metadata.
  public typealias Response<Content: Generable> = AgentResponse<Adapter, Context, Content>

  /// The adapter instance that handles communication with the AI provider.
  package let adapter: Adapter

  /// The conversation transcript containing all prompts, responses, and tool calls.
  ///
  /// The transcript maintains the complete history of interactions and can be used
  /// to access previous responses, analyze tool usage, or continue conversations.
  public var transcript: Transcript

  /// Cumulative token usage across all responses in this session.
  ///
  /// This property tracks the total token consumption for the entire session,
  /// aggregating usage from all responses. It's updated automatically after
  /// each generation and can be observed for real-time usage monitoring.
  public var tokenUsage = TokenUsage()

  /// Provider for fetching URL metadata for link previews in prompts.
  private let metadataProvider = URLMetadataProvider()

  /// Creates a new ModelSession with the specified adapter.
  ///
  /// - Parameter adapter: The adapter instance that will handle AI provider communication.
  ///
  /// - Note: This is a package-internal initializer. Use the public factory methods like
  ///   `ModelSession.openAI(tools:instructions:apiKey:)` to create sessions.
  package init(adapter: Adapter) {
    transcript = Transcript()
    self.adapter = adapter
  }

  // MARK: - Private Response Helpers

  /// Processes a streaming response from the adapter for String content generation.
  ///
  /// This method handles the complete agent loop: sending the prompt to the adapter,
  /// processing streaming updates, managing transcript entries, and aggregating token usage.
  /// It specifically handles text-based responses where the content is accumulated as strings.
  ///
  /// - Parameters:
  ///   - prompt: The prompt to send to the adapter, containing input and context.
  ///   - model: The model to use for generation.
  ///   - options: Optional generation parameters. Uses automatic options if nil.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated text,
  ///   transcript entries added during generation, and aggregated token usage.
  ///
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  private func processStringResponse(
    from prompt: Transcript.Prompt,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?
  ) async throws -> Response<String> {
    let promptEntry = Transcript.Entry.prompt(prompt)
    transcript.append(promptEntry)

    let stream = adapter.respond(
      to: prompt,
      generating: String.self,
      using: model,
      including: transcript,
      options: options ?? .automatic(for: model)
    )
    var responseContent: [String] = []
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        transcript.append(entry)
        addedEntities.append(entry)

        if case let .response(response) = entry {
          for segment in response.segments {
            switch segment {
            case let .text(textSegment):
              responseContent.append(textSegment.content)
            case .structure:
              // Not applicable here
              break
            }
          }
        }
      case let .tokenUsage(usage):
        // Update session token usage immediately for real-time tracking
        tokenUsage.merge(usage)

        if var current = aggregatedUsage {
          current.merge(usage)
          aggregatedUsage = current
        } else {
          aggregatedUsage = usage
        }
      }
    }

    return AgentResponse<Adapter, Context, String>(
      content: responseContent.joined(separator: "\n"),
      addedEntries: addedEntities,
      tokenUsage: aggregatedUsage
    )
  }

  /// Processes a streaming response from the adapter for structured content generation.
  ///
  /// This method handles structured output generation where the AI provider returns
  /// a specific `@Generable` type. It processes the stream until it encounters a
  /// structured segment, then constructs and returns the typed content.
  ///
  /// - Parameters:
  ///   - prompt: The prompt to send to the adapter, containing input and context.
  ///   - type: The `Generable` type to generate (e.g., `TaskList.self`).
  ///   - model: The model to use for generation.
  ///   - options: Optional generation parameters. Uses automatic options if nil.
  ///
  /// - Returns: An ``AgentResponse`` containing the generated
  ///   structured content, transcript entries, and token usage.
  ///
  /// - Throws: ``AgentGenerationError/unexpectedStructuredResponse(_:)`` if no structured
  ///   content is received, or other adapter-specific errors.
  private func processStructuredResponse<Content>(
    from prompt: Transcript.Prompt,
    generating type: Content.Type,
    using model: Adapter.Model,
    options: Adapter.GenerationOptions?
  ) async throws -> Response<Content> where Content: Generable {
    let promptEntry = Transcript.Entry.prompt(prompt)
    transcript.append(promptEntry)

    let stream = adapter.respond(
      to: prompt,
      generating: type,
      using: model,
      including: transcript,
      options: options ?? .automatic(for: model)
    )
    var addedEntities: [Transcript.Entry] = []
    var aggregatedUsage: TokenUsage?

    for try await update in stream {
      switch update {
      case let .transcript(entry):
        transcript.append(entry)
        addedEntities.append(entry)

        if case let .response(response) = entry {
          for segment in response.segments {
            switch segment {
            case .text:
              // Not applicable here
              break
            case let .structure(structuredSegment):
              // We can return here since a structured response can only happen once
              // TODO: Handle errors here in some way

              return try AgentResponse<Adapter, Context, Content>(
                content: Content(structuredSegment.content),
                addedEntries: addedEntities,
                tokenUsage: aggregatedUsage
              )
            }
          }
        }
      case let .tokenUsage(usage):
        // Update session token usage immediately for real-time tracking
        tokenUsage.merge(usage)

        if var current = aggregatedUsage {
          current.merge(usage)
          aggregatedUsage = current
        } else {
          aggregatedUsage = usage
        }
      }
    }

    let errorContext = AgentGenerationError.UnexpectedStructuredResponseContext()
    throw AgentGenerationError.unexpectedStructuredResponse(errorContext)
  }

  /// Fetches metadata for URLs found in the input text to create link previews.
  ///
  /// This method extracts URLs from the input string and fetches their metadata
  /// (title, description, etc.) to provide rich context in prompts. Link previews
  /// are automatically included in context-aware responses.
  ///
  /// - Parameter input: The text to scan for URLs.
  ///
  /// - Returns: An array of ``PromptContextLinkPreview`` objects containing metadata
  ///   for discovered URLs. Returns empty array if no URLs are found.
  private func fetchLinkPreviews(from input: String) async -> [PromptContextLinkPreview] {
    let urls = URLMetadataProvider.extractURLs(from: input)
    guard !urls.isEmpty else { return [] }

    let metadataList = await metadataProvider.fetchMetadata(for: urls)
    return metadataList.map { metadata in
      PromptContextLinkPreview(
        originalURL: metadata.originalURL,
        url: metadata.url,
        title: metadata.title
      )
    }
  }
}

// MARK: - String Response Methods

public extension ModelSession {
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    to prompt: String,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil
  ) async throws -> Response<String> {
    let prompt = Transcript.Prompt(input: prompt, embeddedPrompt: prompt)
    return try await processStringResponse(from: prompt, using: model, options: options)
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    to prompt: Prompt,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt
  ) async throws -> Response<String> {
    try await respond(to: prompt().formatted(), using: model, options: options)
  }
}

// MARK: - Structured Response Methods

public extension ModelSession {
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to prompt: String,
    generating type: Content.Type = Content.self,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil
  ) async throws -> Response<Content> where Content: Generable {
    let prompt = Transcript.Prompt(input: prompt, embeddedPrompt: prompt)
    return try await processStructuredResponse(from: prompt, generating: type, using: model, options: options)
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to prompt: Prompt,
    generating type: Content.Type = Content.self,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil
  ) async throws -> Response<Content> where Content: Generable {
    try await respond(
      to: prompt.formatted(),
      generating: type,
      using: model,
      options: options
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    generating type: Content.Type = Content.self,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder prompt: () throws -> Prompt
  ) async throws -> Response<Content> where Content: Generable {
    try await respond(
      to: prompt().formatted(),
      generating: type,
      using: model,
      options: options
    )
  }
}

// MARK: - Context-Aware Response Methods

public extension ModelSession {
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond(
    to input: String,
    supplying contextItems: [Context],
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ context: PromptContext<Context>) -> Prompt
  ) async throws -> Response<String> {
    let linkPreviews = await fetchLinkPreviews(from: input)
    let context = PromptContext(sources: contextItems, linkPreviews: linkPreviews)

    let prompt = Transcript.Prompt(
      input: input,
      context: context,
      embeddedPrompt: prompt(input, context).formatted()
    )
    return try await processStringResponse(from: prompt, using: model, options: options)
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
  /// - Throws: ``AgentGenerationError`` or adapter-specific errors if generation fails.
  @discardableResult
  func respond<Content>(
    to input: String,
    supplying contextItems: [Context],
    generating type: Content.Type = Content.self,
    using model: Adapter.Model = .default,
    options: Adapter.GenerationOptions? = nil,
    @PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ context: PromptContext<Context>) -> Prompt
  ) async throws -> Response<Content> where Content: Generable {
    let linkPreviews = await fetchLinkPreviews(from: input)
    let context = PromptContext(sources: contextItems, linkPreviews: linkPreviews)

    let prompt = Transcript.Prompt(
      input: input,
      context: context,
      embeddedPrompt: prompt(input, context).formatted()
    )
    return try await processStructuredResponse(from: prompt, generating: type, using: model, options: options)
  }
}

// MARK: - Session Management Methods

public extension ModelSession {
  /// Clears the entire conversation transcript.
  ///
  /// This method removes all entries from the transcript, including prompts, responses,
  /// tool calls, and tool outputs. This is useful for starting a fresh conversation
  /// while retaining the same ModelSession instance with its configuration and tools.
  ///
  /// - Note: This method does not affect token usage tracking. Use `resetTokenUsage()`
  ///   if you also want to reset the cumulative token counter.
  func clearTranscript() {
    transcript = Transcript()
  }

  /// Resets the cumulative token usage counter to zero.
  ///
  /// This method resets all token usage statistics for the session, including
  /// total tokens, input tokens, output tokens, cached tokens, and reasoning tokens.
  /// This is useful when you want to track token usage for a specific period
  /// or after clearing the transcript.
  ///
  /// - Note: This method only affects the session's cumulative token tracking.
  ///   Individual response token usage is not affected.
  func resetTokenUsage() {
    tokenUsage = TokenUsage()
  }
}

// MARK: - AgentResponse

/// The response returned by ModelSession methods, containing generated content and metadata.
///
/// ``AgentResponse`` encapsulates the result of an AI generation request, providing access to
/// the generated content, transcript entries that were added during generation, and token usage statistics.
///
/// ## Properties
///
/// - **content**: The generated content, which can be a `String` for text responses or any
///   `@Generable` type for structured responses.
/// - **addedEntries**: The transcript entries that were created during this generation,
///   including reasoning steps, tool calls, and the final response.
/// - **tokenUsage**: Aggregated token consumption across all internal steps (optional).
///
/// ## Example Usage
///
/// ```swift
/// let response = try await session.respond(to: "What is 2 + 2?")
/// print("Answer: \(response.content)")
/// print("Used \(response.tokenUsage?.totalTokens ?? 0) tokens")
/// print("Added \(response.addedEntries.count) transcript entries")
/// ```
public struct AgentResponse<Adapter: AgentAdapter, Context: PromptContextSource, Content> where Content: Generable {
  /// The generated content from the AI model.
  ///
  /// For text responses, this will be a `String`. For structured responses,
  /// this will be an instance of the requested `@Generable` type.
  public var content: Content

  /// The transcript entries that were added to the conversation during this generation.
  ///
  /// This includes all intermediate steps such as reasoning, tool calls, tool outputs,
  /// and the final response. These entries are automatically added to the session's
  /// transcript and can be used for debugging or UI display.
  public var addedEntries: [ModelSession<Adapter, Context>.Transcript.Entry]

  /// Token usage statistics aggregated across all internal generation steps.
  ///
  /// Provides information about input tokens, output tokens, cached tokens, and reasoning tokens
  /// used during the generation. May be `nil` if the adapter doesn't provide token usage information.
  public var tokenUsage: TokenUsage?

  package init(
    content: Content,
    addedEntries: [ModelSession<Adapter, Context>.Transcript.Entry],
    tokenUsage: TokenUsage?
  ) {
    self.content = content
    self.addedEntries = addedEntries
    self.tokenUsage = tokenUsage
  }
}
