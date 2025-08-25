// By Dennis Müller

import Foundation
import Internal
import OpenAI

public struct OpenAIGenerationOptions: AdapterGenerationOptions {
  public typealias Model = OpenAI.Model
  public typealias GenerationOptionsError = OpenAIGenerationOptionsError
  public typealias Include = OpenAI.Request.Include
  public typealias ReasoningConfig = OpenAI.ReasoningConfig
  public typealias ToolChoice = OpenAI.Tool.Choice
  public typealias Truncation = OpenAI.Truncation
  
  public static func automatic(for model: Model) -> OpenAIGenerationOptions {
    var options = OpenAIGenerationOptions()
    
    if model.isReasoning {
      options.include = [.encryptedReasoning]
    }
    
    return options
  }
  
  /// Specifies additional outputs to include with the response, such as code interpreter results, search outputs, or logprobs.
  public var include: [Include]?

  /// The maximum number of tokens that the model can generate in its response.
  public var maxOutputTokens: UInt?

  /// Controls whether multiple tool calls can be executed in parallel during generation.
  public var allowParallelToolCalls: Bool?
  
  /// Used by OpenAI to cache responses for similar requests to optimize your cache hit rates.
  public var promptCacheKey: String?
  
  /// Configuration for reasoning-capable models, including effort level and summary formatting options.
  public var reasoning: ReasoningConfig?

  /// A stable identifier used by OpenAI to help detect potential misuse patterns across requests.
  public var safetyIdentifier: String?

  /// The service tier to use, which affects request priority, throughput limits, and cost.
  public var serviceTier: ServiceTier?

  /// Controls the randomness of the output. Values range from 0 to 2, where higher values produce more random results.
  public var temperature: Double?

  /// Specifies how the model should choose which tools to call, if any. Options include automatic, none, required, or a specific tool.
  public var toolChoice: ToolChoice?

  /// The number of most likely tokens to return at each token position, along with their log probabilities. Must be between 0 and 20.
  public var topLogProbs: UInt?

  /// An alternative to temperature sampling. Only tokens with cumulative probability up to this threshold are considered.
  public var topP: Double?

  /// Defines how the model should handle inputs that exceed the context window limits.
  public var truncation: Truncation?

  public init() {}

  public init(
    include: [Include]? = nil,
    maxOutputTokens: UInt? = nil,
    allowParallelToolCalls: Bool? = nil,
    promptCacheKey: String?,
    reasoning: ReasoningConfig? = nil,
    safetyIdentifier: String? = nil,
    serviceTier: ServiceTier? = nil,
    temperature: Double? = nil,
    toolChoice: ToolChoice? = nil,
    topLogProbs: UInt? = nil,
    topP: Double? = nil,
    truncation: Truncation? = nil
  ) {
    self.include = include
    self.maxOutputTokens = maxOutputTokens
    self.allowParallelToolCalls = allowParallelToolCalls
    self.promptCacheKey = promptCacheKey
    self.reasoning = reasoning
    self.safetyIdentifier = safetyIdentifier
    self.serviceTier = serviceTier
    self.temperature = temperature
    self.toolChoice = toolChoice
    self.topLogProbs = topLogProbs
    self.topP = topP
    self.truncation = truncation
  }

  public func validate(for model: Model) throws(OpenAIGenerationOptionsError) {
    if model.isReasoning, include?.contains(.encryptedReasoning) != true {
      throw GenerationOptionsError.missingEncryptedReasoningForReasoningModel
    }

    // TODO: Check for other common combinations of options that cause problems
  }
}
