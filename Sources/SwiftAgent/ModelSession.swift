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
public final class ModelSession<Adapter: SwiftAgent.Adapter & SendableMetatype, Resolver: TranscriptResolvable> {
	/// The transcript type for this session, containing the conversation history.
	public typealias Transcript = SwiftAgent.Transcript

	/// The context type for this session, containing additional prompt context.
	public typealias Grounding = Resolver.Grounding

	/// The response type for this session, containing generated content and metadata.
	public typealias Response<Content: Generable> = AgentResponse<Content>

	public typealias Snapshot<Content: Generable> = AgentSnapshot< Content>

	/// The adapter instance that handles communication with the AI provider.
	package let adapter: Adapter

	/// The conversation transcript containing all prompts, responses, and tool calls.
	///
	/// The transcript maintains the complete history of interactions and can be used
	/// to access previous responses, analyze tool usage, or continue conversations.
	public var transcript: Transcript
	
	public var resolver: Resolver

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
	package init(adapter: Adapter, resolver: Resolver) {
		transcript = Transcript()
		self.adapter = adapter
		self.resolver = resolver
	}

	// MARK: - Private Response Helpers

	package func processResponse<Content>(
		from prompt: Transcript.Prompt,
		generating type: Content.Type,
		using model: Adapter.Model,
		options: Adapter.GenerationOptions?,
	) async throws -> Response<Content> where Content: Generable {
		let promptEntry = Transcript.Entry.prompt(prompt)
		transcript.append(promptEntry)

		let stream = adapter.respond(
			to: prompt,
			generating: type,
			using: model,
			including: transcript,
			options: options ?? .automatic(for: model),
		)

		var generatedTranscript = Transcript()
		var generatedUsage: TokenUsage?

		for try await update in stream {
			switch update {
			case let .transcript(entry):
				transcript.upsert(entry)
				generatedTranscript.upsert(entry)

				// Handle content extraction based on type
				if Content.self == String.self {
					// For String content, we accumulate all text segments and process at the end
					continue
				} else {
					// For structured content, return immediately when we find a structured segment
					if case let .response(response) = entry {
						for segment in response.segments {
							switch segment {
							case .text:
								// Not applicable for structured content
								break
							case let .structure(structuredSegment):
								// We can return here since a structured response can only happen once
								// TODO: Handle errors here in some way

								return try AgentResponse<Content>(
									content: Content(structuredSegment.content),
									transcript: generatedTranscript,
									tokenUsage: generatedUsage,
								)
							}
						}
					}
				}
			case let .tokenUsage(usage):
				// Update session token usage immediately for real-time tracking
				tokenUsage.merge(usage)

				if var current = generatedUsage {
					current.merge(usage)
					generatedUsage = current
				} else {
					generatedUsage = usage
				}
			}
		}

		// Handle final content extraction for String type
		if Content.self == String.self {
			let finalResponseSegments = generatedTranscript
				.compactMap { entry -> [String]? in
					guard case let .response(response) = entry else { return nil }

					return response.segments.compactMap { segment in
						if case let .text(textSegment) = segment {
							return textSegment.content
						}
						return nil
					}
				}
				.flatMap(\.self)

			return AgentResponse<Content>(
				content: finalResponseSegments.joined(separator: "\n") as! Content,
				transcript: generatedTranscript,
				tokenUsage: generatedUsage,
			)
		} else {
			// For structured content, if we reach here, no structured segment was found
			let errorContext = GenerationError.UnexpectedStructuredResponseContext()
			throw GenerationError.unexpectedStructuredResponse(errorContext)
		}
	}

	package func processResponseStream<Content: Generable>(
		from prompt: Transcript.Prompt,
		generating type: Content.Type,
		using model: Adapter.Model,
		options: Adapter.GenerationOptions?,
	) -> AsyncThrowingStream<Snapshot<Content>, any Error> {
		let setup = AsyncThrowingStream<Snapshot<Content>, any Error>.makeStream()

		let task = Task<Void, Never> {
			do {
				let promptEntry = Transcript.Entry.prompt(prompt)
				transcript.append(promptEntry)

				let stream = adapter.streamResponse(
					to: prompt,
					generating: type,
					using: model,
					including: transcript,
					options: options ?? .automatic(for: model),
				)

				var generatedTranscript = Transcript()
				var generatedUsage: TokenUsage = .zero
				for try await update in stream {
					switch update {
					case let .transcript(entry):
						generatedTranscript.upsert(entry)

					case let .tokenUsage(usage):
						generatedUsage.merge(usage)
					}
				}

				// Update the transcript and token usage when the stream is finished
				transcript.append(contentsOf: generatedTranscript.entries)
				tokenUsage.merge(generatedUsage)
			} catch {
				setup.continuation.finish(throwing: error)
			}
		}

		setup.continuation.onTermination = { _ in
			task.cancel()
		}

		return setup.stream
	}
}

// MARK: - Authorization

public extension ModelSession {
	/// Executes the provided work with a temporary authorization context for this session.
	///
	/// Use this helper to attach an access token to all network requests that happen during a single
	/// "agent turn" — that is, every request the agent performs until it finishes producing the
	/// next message (reasoning steps, tool calls and their outputs, and the final response).
	///
	/// The token is stored in an internal task‑local value and is automatically picked up by adapter
	/// configurations that support proxy authorization (for example, ``OpenAIConfiguration/proxy(through:)``).
	/// This keeps credentials out of your app bundle and enables secure, backend‑issued, short‑lived
	/// tokens that you can rotate per turn.
	///
	/// You can also provide an optional `refresh` closure. If the proxy responds with `401 Unauthorized`,
	/// the SDK will invoke this closure to obtain a new token and retry the failed request once.
	///
	/// - Parameters:
	///   - token: The access token to authorize requests for this agent turn.
	///   - refresh: Optional closure that returns a freshly issued token when a request is unauthorized.
	///   - perform: The asynchronous work to run while the authorization context is active.
	/// - Returns: The result of the `perform` closure.
	///
	/// ## Example: Per‑Turn Token
	///
	/// ```swift
	/// // 1) Configure the session to use your proxy backend
	/// let configuration = OpenAIConfiguration.proxy(through: URL(string: "https://api.your‑backend.com")!)
	/// let session = ModelSession.openAI(
	///   tools: [WeatherTool(), CalculatorTool()],
	///   instructions: "You are a helpful assistant.",
	///   configuration: configuration
	/// )
	///
	/// // 2) Ask your backend for a short‑lived token that is valid for a single agent turn
	/// let token = try await backend.issueTurnToken(for: userId)
	///
	/// // 3) Run all requests for this turn with that token
	/// let response = try await session.withAuthorization(token: token) {
	///   try await session.respond(to: "What's the weather in San Francisco?")
	/// }
	/// print(response.content)
	/// ```
	///
	/// ## Example: Automatic Refresh
	///
	/// ```swift
	/// let initial = try await backend.issueTurnToken(for: userId)
	///
	/// let response = try await session.withAuthorization(
	///   token: initial,
	///   refresh: { try await backend.refreshTurnToken(for: userId) }
	/// ) {
	///   try await session.respond(to: "Plan a 3‑day trip to Kyoto.")
	/// }
	/// ```
	@discardableResult
	func withAuthorization<T>(
		token: String,
		refresh: (@Sendable () async throws -> String)? = nil,
		perform: () async throws -> T,
	) async rethrows -> T {
		precondition(!token.isEmpty, "Authorization token must not be empty.")
		let context = AuthorizationContext(bearerToken: token, refreshToken: refresh)
		return try await AuthorizationContext.$current.withValue(context) {
			try await perform()
		}
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
	
	// TODO: Does this need an instance, or is type enough?
	// TODO: Instance is needed because the tools are initialized!
	// TODO: So I need a default Decoder that does nothing
	// TODO: Decoder to Coder?
	// TODO: "Resolve" to "decode"
	func toolResolver() -> ToolResolver<Resolver> {
		ToolResolver(for: resolver, in: transcript)
	}
}
