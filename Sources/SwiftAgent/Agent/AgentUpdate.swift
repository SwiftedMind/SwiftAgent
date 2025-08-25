// By Dennis Müller

import Foundation

/// Internal stream updates emitted by adapters while generating.
///
/// These updates are translated by `ModelSession` into public-facing state
/// (e.g., transcript updates and responses). While public for type exposure,
/// they are considered an SDK-internal mechanism.
public enum AgentUpdate<Context: PromptContextSource>: Sendable, Equatable {
  /// A transcript entry produced during generation (reasoning, tool calls, outputs, responses...).
  case transcript(AgentTranscript<Context>.Entry)

  /// Token usage information for a request/step. Optional today; may be provided by adapters.
  case tokenUsage(TokenUsage)
}
