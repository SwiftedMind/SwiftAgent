// By Dennis Müller

import FoundationModels
import Observation
import SwiftAgent
import SwiftUI

@Observable
public final class OpenAISession<
  SessionSchema: LanguageModelSessionSchema,
>: LanguageModelProvider, @unchecked Sendable {
  public typealias Adapter = OpenAIAdapter

  /// Adapter used by this provider to communicate with the underlying model API.
  @ObservationIgnored public let adapter: OpenAIAdapter

  @ObservationIgnored public var schema: SessionSchema

  /// Registered tools available to the model during a session.
  @ObservationIgnored public var tools: [any SwiftAgentTool] {
    adapter.tools
  }

  /// Transcript of the session, including prompts, tool calls, and model outputs.
  public var transcript: SwiftAgent.Transcript = Transcript()
  public var tokenUsage: TokenUsage = .init()

  public init(
    tools: [any SwiftAgentTool] = [],
    instructions: String = "",
    apiKey: String,
  ) where SessionSchema == NoSchema {
    schema = NoSchema()
    adapter = OpenAIAdapter(
      tools: tools,
      instructions: instructions,
      configuration: .direct(apiKey: apiKey),
    )
  }

  public init(
    schema: SessionSchema,
    instructions: String,
    apiKey: String,
  ) {
    self.schema = schema
    adapter = OpenAIAdapter(
      tools: schema.decodableTools,
      instructions: instructions,
      configuration: .direct(apiKey: apiKey),
    )
  }

  public init(
    schema: SessionSchema,
    instructions: String,
    configuration: OpenAIConfiguration,
  ) {
    self.schema = schema
    adapter = OpenAIAdapter(
      tools: schema.decodableTools,
      instructions: instructions,
      configuration: configuration,
    )
  }

  public init(
    tools: [any SwiftAgentTool] = [],
    instructions: String = "",
    configuration: OpenAIConfiguration,
  ) where SessionSchema == NoSchema {
    schema = NoSchema()
    adapter = OpenAIAdapter(
      tools: tools,
      instructions: instructions,
      configuration: configuration,
    )
  }
}
