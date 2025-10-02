// By Dennis Müller

import Foundation
import FoundationModels

// MARK: - String Response Methods

public extension LanguageModelProvider {
	/// Generates a streaming text response to a string prompt.
	///
	/// This method provides real-time streaming of text generation, allowing you to
	/// process and display content as it's being generated rather than waiting for
	/// the complete response. Each snapshot contains the current state of the response.
	///
	/// ## Example
	///
	/// ```swift
	/// for try await snapshot in session.streamResponse(to: "Tell me a story") {
	///   print("Current content: \(snapshot.content)")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - prompt: The text prompt to send to the AI model.
	///   - model: The model to use for generation. Defaults to the adapter's default model.
	///   - options: Optional generation parameters (temperature, max tokens, etc.).
	///     Uses automatic options for the model if not specified.
	///
	/// - Returns: An `AsyncThrowingStream` of ``AgentSnapshot`` objects containing
	///   the current state of the response as it's being generated.
	///
	/// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
	func streamResponse(
		to prompt: String,
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
	) throws -> AsyncThrowingStream<AgentSnapshot<String>, any Error> {
		let sourcesData = try encodeGrounding([GroundingSource]())
		let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
		return processResponseStream(from: prompt, generating: String.self, using: model, options: options)
	}

	/// Generates a streaming text response to a structured prompt.
	///
	/// This method provides real-time streaming of text generation from a structured prompt,
	/// allowing you to process and display content as it's being generated. Each snapshot
	/// contains the current state of the response.
	///
	/// ## Example
	///
	/// ```swift
	/// let prompt = Prompt {
	///   "You are a helpful assistant."
	///   PromptTag("user-input") { "Tell me a story" }
	/// }
	/// for try await snapshot in session.streamResponse(to: prompt) {
	///   print("Current content: \(snapshot.content)")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - prompt: A structured prompt created with `@PromptBuilder`.
	///   - model: The model to use for generation. Defaults to the adapter's default model.
	///   - options: Optional generation parameters.
	///
	/// - Returns: An `AsyncThrowingStream` of ``AgentAgentSnapshot`` objects containing
	///   the current state of the response as it's being generated.
	///
	/// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
	func streamResponse(
		to prompt: Prompt,
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
	) throws -> AsyncThrowingStream<AgentSnapshot<String>, any Error> {
		try streamResponse(to: prompt.formatted(), using: model, options: options)
	}

	func streamResponse(
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
		@PromptBuilder prompt: @Sendable () throws -> Prompt,
	) throws -> AsyncThrowingStream<AgentSnapshot<String>, any Error> {
		try streamResponse(to: prompt().formatted(), using: model, options: options)
	}
}

// MARK: - Structured Response Methods

public extension LanguageModelProvider {
	/// Generates a streaming structured response of the specified type from a string prompt.
	///
	/// This method provides real-time streaming of structured output generation where the AI
	/// returns data conforming to a specific `@Generable` type. Each snapshot contains the
	/// current state of the structured response as it's being generated.
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
	/// for try await snapshot in session.streamResponse(
	///   to: "Get weather for San Francisco",
	///   generating: WeatherReport.self
	/// ) {
	///   print("Current content: \(snapshot.content)")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - prompt: The text prompt to send to the AI model.
	///   - type: The `Generable` type to generate. Can often be inferred from context.
	///   - model: The model to use for generation. Defaults to the adapter's default model.
	///   - options: Optional generation parameters.
	///
	/// - Returns: An `AsyncThrowingStream` of ``AgentAgentSnapshot`` objects containing
	///   the current state of the structured response as it's being generated.
	///
	/// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
	func streamResponse<Content>(
		to prompt: String,
		generating type: Content.Type = Content.self,
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
	) throws -> AsyncThrowingStream<AgentSnapshot<Content>, any Error> where Content: Generable {
		let sourcesData = try encodeGrounding([GroundingSource]())
		let prompt = Transcript.Prompt(input: prompt, sources: sourcesData, prompt: prompt)
		return processResponseStream(from: prompt, generating: type, using: model, options: options)
	}

	/// Generates a streaming structured response of the specified type from a structured prompt.
	///
	/// This method provides real-time streaming of structured output generation from a structured
	/// prompt, combining the power of structured prompts with structured output generation.
	/// Each snapshot contains the current state of the structured response as it's being generated.
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
	/// for try await snapshot in session.streamResponse(
	///   to: prompt,
	///   generating: DocumentSummary.self
	/// ) {
	///   print("Current content: \(snapshot.content)")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - prompt: A structured prompt created with `@PromptBuilder`.
	///   - type: The `Generable` type to generate.
	///   - model: The model to use for generation. Defaults to the adapter's default model.
	///   - options: Optional generation parameters.
	///
	/// - Returns: An `AsyncThrowingStream` of ``AgentAgentSnapshot`` objects containing
	///   the current state of the structured response as it's being generated.
	///
	/// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
	func streamResponse<Content>(
		to prompt: Prompt,
		generating type: Content.Type = Content.self,
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
	) throws -> AsyncThrowingStream<AgentSnapshot<Content>, any Error> where Content: Generable {
		try streamResponse(to: prompt.formatted(), generating: type, using: model, options: options)
	}

	/// Generates a streaming structured response using a prompt builder closure.
	///
	/// This method provides real-time streaming of structured output generation from a prompt
	/// built inline using the `@PromptBuilder` DSL, combining the convenience of `@PromptBuilder`
	/// with typed responses. Each snapshot contains the current state of the structured response
	/// as it's being generated.
	///
	/// ## Example
	///
	/// ```swift
	/// for try await snapshot in session.streamResponse(generating: TaskList.self) {
	///   "Create a task list based on the following requirements:"
	///   PromptTag("requirements") { userRequirements }
	///   "Include priority levels and estimated completion times."
	/// } {
	///   print("Current content: \(snapshot.content)")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - type: The `Generable` type to generate.
	///   - model: The model to use for generation. Defaults to the adapter's default model.
	///   - options: Optional generation parameters.
	///   - prompt: A closure that builds the prompt using `@PromptBuilder` syntax. Must be `@Sendable`.
	///
	/// - Returns: An `AsyncThrowingStream` of ``AgentAgentSnapshot`` objects containing
	///   the current state of the structured response as it's being generated.
	///
	/// - Throws: ``GenerationError`` or adapter-specific errors if generation fails.
	func streamResponse<Content>(
		generating type: Content.Type = Content.self,
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
		@PromptBuilder prompt: @Sendable () throws -> Prompt,
	) throws -> AsyncThrowingStream<AgentSnapshot<Content>, any Error> where Content: Generable {
		try streamResponse(to: prompt().formatted(), generating: type, using: model, options: options)
	}
}

// MARK: - Context-Aware Response Methods

public extension LanguageModelProvider {
	func streamResponse(
		to input: String,
		using model: Adapter.Model = .default,
		groundingWith sources: [GroundingSource],
		options: Adapter.GenerationOptions? = nil,
		@PromptBuilder embeddingInto prompt: @Sendable (_ input: String, _ sources: [GroundingSource]) -> Prompt,
	) throws -> AsyncThrowingStream<AgentSnapshot<String>, any Error> {
		let sourcesData = try encodeGrounding(sources)

		let prompt = Transcript.Prompt(
			input: input,
			sources: sourcesData,
			prompt: prompt(input, sources).formatted(),
		)
		return processResponseStream(from: prompt, generating: String.self, using: model, options: options)
	}

	@discardableResult
	func streamResponse<Content: Generable>(
		to input: String,
		generating type: Content.Type = Content.self,
		groundingWith sources: [GroundingSource],
		using model: Adapter.Model = .default,
		options: Adapter.GenerationOptions? = nil,
		@PromptBuilder embeddingInto prompt: @Sendable (_ prompt: String, _ sources: [GroundingSource]) -> Prompt,
	) throws -> AsyncThrowingStream<AgentSnapshot<Content>, any Error> {
		let sourcesData = try encodeGrounding(sources)

		let prompt = Transcript.Prompt(
			input: input,
			sources: sourcesData,
			prompt: prompt(input, sources).formatted(),
		)
		return processResponseStream(from: prompt, generating: type, using: model, options: options)
	}
}
