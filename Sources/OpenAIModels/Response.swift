import Foundation

/// A response returned by the Responses API.
public struct Response: Codable, Identifiable, Sendable {
  public struct Usage: Codable, Hashable, Sendable {
    public struct InputTokensDetails: Codable, Hashable, Sendable {
      public var cachedTokens: UInt

      public init(cachedTokens: UInt) {
        self.cachedTokens = cachedTokens
      }

      private enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
      }
    }

    public struct OutputTokensDetails: Codable, Hashable, Sendable {
      public var reasoningTokens: UInt

      public init(reasoningTokens: UInt) {
        self.reasoningTokens = reasoningTokens
      }

      private enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
      }
    }

    public var inputTokens: UInt
    public var inputTokensDetails: InputTokensDetails
    public var outputTokens: UInt
    public var outputTokensDetails: OutputTokensDetails
    public var totalTokens: UInt

    public init(
      inputTokens: UInt,
      inputTokensDetails: InputTokensDetails,
      outputTokens: UInt,
      outputTokensDetails: OutputTokensDetails,
      totalTokens: UInt
    ) {
      self.inputTokens = inputTokens
      self.inputTokensDetails = inputTokensDetails
      self.outputTokens = outputTokens
      self.outputTokensDetails = outputTokensDetails
      self.totalTokens = totalTokens
    }

    private enum CodingKeys: String, CodingKey {
      case inputTokens = "input_tokens"
      case inputTokensDetails = "input_tokens_details"
      case outputTokens = "output_tokens"
      case outputTokensDetails = "output_tokens_details"
      case totalTokens = "total_tokens"
    }
  }

  public var id: String
  public var output: [Item.Output]
  public var usage: Usage?

  public init(id: String, output: [Item.Output], usage: Usage? = nil) {
    self.id = id
    self.output = output
    self.usage = usage
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case output
    case usage
  }
}
