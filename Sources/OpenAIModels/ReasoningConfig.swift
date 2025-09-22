import Foundation

/// Configuration options for reasoning capable models.
public struct ReasoningConfig: Codable, Hashable, Sendable {
  public enum Effort: String, Codable, CaseIterable, Sendable {
    case minimal
    case low
    case medium
    case high
  }

  public enum SummaryConfig: String, Codable, CaseIterable, Sendable {
    case auto
    case concise
    case detailed
  }

  public var effort: Effort?
  public var summary: SummaryConfig?

  public init(effort: Effort? = nil, summary: SummaryConfig? = nil) {
    self.effort = effort
    self.summary = summary
  }

  private enum CodingKeys: String, CodingKey {
    case effort
    case summary
  }
}

/// The truncation strategy to apply when inputs exceed the context window.
public enum Truncation: String, Codable, CaseIterable, Sendable {
  case auto
  case disabled
}

/// The latency tier to use when processing a request.
public enum ServiceTier: String, Codable, CaseIterable, Sendable {
  case auto
  case `default`
  case flex
  case priority
}

/// Reference to a reusable prompt template stored on the OpenAI platform.
public struct Prompt: Codable, Hashable, Sendable {
  public var id: String
  public var version: String?
  public var variables: [String: String]?

  public init(id: String, version: String? = nil, variables: [String: String]? = nil) {
    self.id = id
    self.version = version
    self.variables = variables
  }
}
