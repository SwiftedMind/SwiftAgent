import Foundation

/// Identifiers for models that can be used with the OpenAI Responses API.
public enum Model: Hashable, Sendable {
  case o1
  case o1Pro
  case o1Mini
  case o3
  case o3Pro
  case o3Mini
  case o3DeepResearch
  case o4Mini
  case o4MiniDeepResearch
  case codexMini
  case gpt4
  case gpt4Turbo
  case gpt4o
  case gpt4oMini
  case gpt4_1
  case gpt4_1Mini
  case gpt4_1Nano
  case gpt4_5Preview
  case gpt3_5Turbo
  case chatGPT4o
  case computerUsePreview
  case gpt5
  case gpt5_mini
  case gpt5_nano
  case other(String)

  public init(_ rawValue: String) {
    switch rawValue {
    case "o1": self = .o1
    case "o1-pro": self = .o1Pro
    case "o1-mini": self = .o1Mini
    case "o3": self = .o3
    case "o3-pro": self = .o3Pro
    case "o3-mini": self = .o3Mini
    case "o3-deep-research": self = .o3DeepResearch
    case "o4-mini": self = .o4Mini
    case "o4-mini-deep-research": self = .o4MiniDeepResearch
    case "codex-mini": self = .codexMini
    case "gpt-4": self = .gpt4
    case "gpt-4o": self = .gpt4o
    case "gpt-4o-mini": self = .gpt4oMini
    case "gpt-4o-turbo": self = .gpt4Turbo
    case "gpt-4.1": self = .gpt4_1
    case "gpt-4.1-mini": self = .gpt4_1Mini
    case "gpt-4.1-nano": self = .gpt4_1Nano
    case "gpt-4.5-preview": self = .gpt4_5Preview
    case "gpt-3.5-turbo": self = .gpt3_5Turbo
    case "chatgpt-4o": self = .chatGPT4o
    case "computer-use-preview": self = .computerUsePreview
    case "gpt-5": self = .gpt5
    case "gpt-5-mini": self = .gpt5_mini
    case "gpt-5-nano": self = .gpt5_nano
    default: self = .other(rawValue)
    }
  }

  public var rawValue: String {
    switch self {
    case .o1: "o1"
    case .o1Pro: "o1-pro"
    case .o1Mini: "o1-mini"
    case .o3: "o3"
    case .o3Pro: "o3-pro"
    case .o3Mini: "o3-mini"
    case .o3DeepResearch: "o3-deep-research"
    case .o4Mini: "o4-mini"
    case .o4MiniDeepResearch: "o4-mini-deep-research"
    case .codexMini: "codex-mini"
    case .gpt4: "gpt-4"
    case .gpt4Turbo: "gpt-4o-turbo"
    case .gpt4o: "gpt-4o"
    case .gpt4oMini: "gpt-4o-mini"
    case .gpt4_1: "gpt-4.1"
    case .gpt4_1Mini: "gpt-4.1-mini"
    case .gpt4_1Nano: "gpt-4.1-nano"
    case .gpt4_5Preview: "gpt-4.5-preview"
    case .gpt3_5Turbo: "gpt-3.5-turbo"
    case .chatGPT4o: "chatgpt-4o"
    case .computerUsePreview: "computer-use-preview"
    case .gpt5: "gpt-5"
    case .gpt5_mini: "gpt-5-mini"
    case .gpt5_nano: "gpt-5-nano"
    case let .other(value): value
    }
  }
}

extension Model: RawRepresentable {
  public init?(rawValue: String) {
    self.init(rawValue)
  }
}

extension Model: Codable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let value = try container.decode(String.self)
    self.init(value)
  }
}
