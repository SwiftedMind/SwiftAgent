// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// The response returned by LanguageModelProvider methods, containing generated content and metadata.
///
/// ``AgentResponse`` encapsulates the result of an AI generation request, providing access to
/// the generated content, transcript entries that were added during generation, and token usage statistics.
///
/// ## Properties
///
/// - **content**: The generated content, which can be a `String` for text responses or any
///   `@Generable` type for structured responses.
/// - **transcript**: The transcript entries that were created during this generation,
///   including reasoning steps, tool calls, and the final response.
/// - **tokenUsage**: Aggregated token consumption across all internal steps (optional).
///
/// ## Example Usage
///
/// ```swift
/// let response = try await session.respond(to: "What is 2 + 2?")
/// print("Answer: \(response.content)")
/// print("Used \(response.tokenUsage?.totalTokens ?? 0) tokens")
/// print("Added \(response.transcript.count) transcript entries")
/// ```
public struct AgentResponse<Content: Generable> {
	/// The generated content from the AI model.
	///
	/// For text responses, this will be a `String`. For structured responses,
	/// this will be an instance of the requested `@Generable` type.
	public var content: Content

	/// The transcript of the generation.
	///
	/// This includes all the entries that were added during the generation,
	/// including reasoning steps, tool calls, and the final response.
	public var transcript: Transcript

	/// Token usage statistics aggregated across all internal generation steps.
	///
	/// Provides information about input tokens, output tokens, cached tokens, and reasoning tokens
	/// used during the generation. May be `nil` if the adapter doesn't provide token usage information.
	public var tokenUsage: TokenUsage?

	package init(
		content: Content,
		transcript: Transcript,
		tokenUsage: TokenUsage?,
	) {
		self.content = content
		self.transcript = transcript
		self.tokenUsage = tokenUsage
	}
}

extension AgentResponse: Sendable where Content: Sendable {}
