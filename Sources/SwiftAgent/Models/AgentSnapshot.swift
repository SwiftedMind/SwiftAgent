// By Dennis Müller

import Foundation
import FoundationModels

/// A snapshot of the agent's current state during streamed generation.
///
/// ## Example Usage
///
/// ```swift
/// for try await snapshot in session.streamResponse(to: "What is 2 + 2?") {
///   print("Current transcript entries: \(snapshot.transcript.count)")
///   if let usage = snapshot.tokenUsage {
///     print("Tokens used so far: \(usage.totalTokens ?? 0)")
///   }
/// }
/// ```
public struct AgentSnapshot<StructuredOutput: SwiftAgent.StructuredOutput> {
  /// The current partially generated response from the AI model.
  ///
  /// This will be `nil` if the content is not available yet.
  ///
  /// For text responses, this will be a `String`. For structured responses,
  /// this will be the `PartiallyGenerated` variant of the requested `@Generable` type.
  public var content: StructuredOutput.Schema.PartiallyGenerated?

  /// The current conversation transcript.
  ///
  /// This includes all transcript entries that have been added during the current generation,
  /// including the initial prompt, reasoning steps, tool calls, and partially generated responses.
  public let transcript: Transcript

  /// Current token usage statistics.
  ///
  /// Provides information about input tokens, output tokens, cached tokens, and reasoning tokens
  /// used so far during the generation. May be `nil` if the adapter doesn't provide token usage
  /// information or if no usage data has been received yet.
  public let tokenUsage: TokenUsage?

  /// Creates a new agent snapshot with the specified transcript and token usage.
  ///
  /// - Parameters:
  ///   - content: The current partially generated response from the AI model
  ///   - transcript: The current conversation transcript
  ///   - tokenUsage: Current token usage statistics, if available
  package init(
    content: StructuredOutput.Schema.PartiallyGenerated? = nil,
    transcript: Transcript,
    tokenUsage: TokenUsage? = nil,
  ) {
    self.content = content
    self.transcript = transcript
    self.tokenUsage = tokenUsage
  }
}

extension AgentSnapshot: Sendable where StructuredOutput.Schema.PartiallyGenerated: Sendable {}
