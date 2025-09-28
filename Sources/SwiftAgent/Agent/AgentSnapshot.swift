// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A snapshot of the agent's current state during response streaming.
///
/// ## Properties
///
/// - **transcript**: The current conversation transcript, including all entries added during generation
/// - **tokenUsage**: Current token usage statistics (optional, may be nil if not available)
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
public struct AgentSnapshot<
  Adapter: SwiftAgent.Adapter & SendableMetatype,
  Context: PromptContextSource,
  Content: Generable,
> {
  /// The generated content from the AI model.
  ///
  /// This will be `nil` if the content is not available yet.
  ///
  /// For text responses, this will be a `String`. For structured responses,
  /// this will be an instance of the requested `@Generable` type.
  public var content: Content?
  /// The current conversation transcript.
  ///
  /// This includes all entries that have been added during the current generation,
  /// including reasoning steps, tool calls, and partial responses.
  public let transcript: ModelSession<Adapter, Context>.Transcript

  /// Current token usage statistics.
  ///
  /// Provides information about input tokens, output tokens, cached tokens, and reasoning tokens
  /// used so far during the generation. May be `nil` if the adapter doesn't provide token usage
  /// information or if no usage data has been received yet.
  public let tokenUsage: TokenUsage?

  /// Creates a new agent snapshot with the specified transcript and token usage.
  ///
  /// - Parameters:
  ///   - transcript: The current conversation transcript
  ///   - tokenUsage: Current token usage statistics, if available
  public init(
    content: Content? = nil,
    transcript: ModelSession<Adapter, Context>.Transcript,
    tokenUsage: TokenUsage? = nil,
  ) {
    self.content = content
    self.transcript = transcript
    self.tokenUsage = tokenUsage
  }
}
