// By Dennis Müller

import Foundation

/// Public token usage metrics for a generation.
///
/// ModelSession aggregates these across internal steps and exposes them on `AgentResponse`.
public struct TokenUsage: Sendable, Equatable {
  /// The number of input tokens.
  public var inputTokens: Int?

  /// The number of output tokens.
  public var outputTokens: Int?

  /// The total number of tokens used.
  public var totalTokens: Int?

  /// The number of cached input tokens (prompt caching).
  public var cachedTokens: Int?

  /// The number of reasoning tokens used in the output.
  public var reasoningTokens: Int?

  /// Creates a new TokenUsage instance.
  public init(
    inputTokens: Int? = nil,
    outputTokens: Int? = nil,
    totalTokens: Int? = nil,
    cachedTokens: Int? = nil,
    reasoningTokens: Int? = nil
  ) {
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.totalTokens = totalTokens
    self.cachedTokens = cachedTokens
    self.reasoningTokens = reasoningTokens
  }

  /// Merges another usage into this one by summing available counters.
  public mutating func merge(_ other: TokenUsage) {
    inputTokens = Self.sum(inputTokens, other.inputTokens)
    outputTokens = Self.sum(outputTokens, other.outputTokens)
    totalTokens = Self.sum(totalTokens, other.totalTokens)
    cachedTokens = Self.sum(cachedTokens, other.cachedTokens)
    reasoningTokens = Self.sum(reasoningTokens, other.reasoningTokens)
  }

  private static func sum(_ a: Int?, _ b: Int?) -> Int? {
    switch (a, b) {
    case let (x?, y?): return x + y
    case (nil, let y?): return y
    case (let x?, nil): return x
    default: return nil
    }
  }
}
