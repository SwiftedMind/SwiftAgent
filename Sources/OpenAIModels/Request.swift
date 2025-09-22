import Foundation

/// Request payload for the Responses API.
public struct Request: Codable, Sendable {
  public enum Include: String, Codable, CaseIterable, Sendable {
    case codeInterpreterOutputs = "code_interpreter_call.outputs"
    case computerCallImageURLs = "computer_call_output.output.image_url"
    case fileSearchResults = "file_search_call.results"
    case inputImageURLs = "message.input_image.image_url"
    case outputLogprobs = "message.output_text.logprobs"
    case encryptedReasoning = "reasoning.encrypted_content"
  }

  public var model: Model
  public var input: Input
  public var background: Bool?
  public var include: [Include]?
  public var instructions: String?
  public var maxOutputTokens: UInt?
  public var maxToolCalls: UInt?
  public var metadata: [String: String]?
  public var parallelToolCalls: Bool?
  public var previousResponseId: String?
  public var prompt: Prompt?
  public var promptCacheKey: String?
  public var reasoning: ReasoningConfig?
  public var safetyIdentifier: String?
  public var serviceTier: ServiceTier?
  public var store: Bool?
  public var stream: Bool?
  public var temperature: Double?
  public var text: TextConfig?
  public var toolChoice: Tool.Choice?
  public var tools: [Tool]?
  public var topLogprobs: UInt?
  public var topP: Double?
  public var truncation: Truncation?
  public var user: String?

  public init(
    model: Model,
    input: Input,
    background: Bool? = nil,
    include: [Include]? = nil,
    instructions: String? = nil,
    maxOutputTokens: UInt? = nil,
    maxToolCalls: UInt? = nil,
    metadata: [String: String]? = nil,
    parallelToolCalls: Bool? = nil,
    previousResponseId: String? = nil,
    prompt: Prompt? = nil,
    promptCacheKey: String? = nil,
    reasoning: ReasoningConfig? = nil,
    safetyIdentifier: String? = nil,
    serviceTier: ServiceTier? = nil,
    store: Bool? = nil,
    stream: Bool? = nil,
    temperature: Double? = nil,
    text: TextConfig? = nil,
    toolChoice: Tool.Choice? = nil,
    tools: [Tool]? = nil,
    topLogprobs: UInt? = nil,
    topP: Double? = nil,
    truncation: Truncation? = nil,
    user: String? = nil
  ) {
    self.model = model
    self.input = input
    self.background = background
    self.include = include
    self.instructions = instructions
    self.maxOutputTokens = maxOutputTokens
    self.maxToolCalls = maxToolCalls
    self.metadata = metadata
    self.parallelToolCalls = parallelToolCalls
    self.previousResponseId = previousResponseId
    self.prompt = prompt
    self.promptCacheKey = promptCacheKey
    self.reasoning = reasoning
    self.safetyIdentifier = safetyIdentifier
    self.serviceTier = serviceTier
    self.store = store
    self.stream = stream
    self.temperature = temperature
    self.text = text
    self.toolChoice = toolChoice
    self.tools = tools
    self.topLogprobs = topLogprobs
    self.topP = topP
    self.truncation = truncation
    self.user = user
  }

  private enum CodingKeys: String, CodingKey {
    case model
    case input
    case background
    case include
    case instructions
    case maxOutputTokens = "max_output_tokens"
    case maxToolCalls = "max_tool_calls"
    case metadata
    case parallelToolCalls = "parallel_tool_calls"
    case previousResponseId = "previous_response_id"
    case prompt
    case promptCacheKey = "prompt_cache_key"
    case reasoning
    case safetyIdentifier = "safety_identifier"
    case serviceTier = "service_tier"
    case store
    case stream
    case temperature
    case text
    case toolChoice = "tool_choice"
    case tools
    case topLogprobs = "top_logprobs"
    case topP = "top_p"
    case truncation
    case user
  }
}
