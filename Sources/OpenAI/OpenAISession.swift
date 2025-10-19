// By Dennis Müller

import FoundationModels
import Observation
import SwiftAgent
import SwiftUI

/// High-level client for working with OpenAI's Responses API using SwiftAgent.
///
/// `OpenAISession` pairs an ``OpenAIAdapter`` with your tools or schema so you can request
/// completions, stream updates, and inspect transcripts without wiring adapters by hand. Supply a
/// ``SessionSchema`` when you need typed transcripts, or pass tools directly for quick prototypes.
@Observable
public final class OpenAISession<
  SessionSchema: LanguageModelSessionSchema,
>: LanguageModelProvider, @unchecked Sendable {
  public typealias Adapter = OpenAIAdapter

  /// Adapter that performs network requests against OpenAI's Responses API.
  @ObservationIgnored public let adapter: OpenAIAdapter

  @ObservationIgnored public var schema: SessionSchema

  /// Registered tools available to the model during a session.
  @ObservationIgnored public var tools: [any SwiftAgentTool] {
    adapter.tools
  }

  /// Transcript of the session, including prompts, tool calls, and model outputs.
  public var transcript: SwiftAgent.Transcript = Transcript()

  /// Aggregated token accounting reported by OpenAI for the active session.
  public var tokenUsage: TokenUsage = .init()

  /// Creates a session that exposes the provided tools without defining a schema.
  ///
  /// - Parameters:
  ///   - tools: Variadic list of tools available to the model.
  ///   - instructions: Default instructions applied to every turn.
  ///   - apiKey: OpenAI API key used for direct authentication.
  public init<each ToolType>(
    tools: repeat each ToolType,
    instructions: String = "",
    apiKey: String,
  ) where
    SessionSchema == NoSchema,
    repeat (each ToolType): FoundationModels.Tool,
    repeat (each ToolType).Arguments: Generable,
    repeat (each ToolType).Output: Generable {
      var wrappedTools: [any SwiftAgentTool] = []
      _ = (repeat wrappedTools.append(_SwiftAgentToolWrapper(tool: each tools)))

      schema = NoSchema()
      adapter = OpenAIAdapter(
        tools: wrappedTools,
        instructions: instructions,
        configuration: .direct(apiKey: apiKey),
      )
    }

  /// Creates a schema-backed session using a direct API key.
  ///
  /// - Parameters:
  ///   - schema: The schema that enumerates tools, structured outputs, and groundings.
  ///   - instructions: Default instructions applied to every turn.
  ///   - apiKey: OpenAI API key used for direct authentication.
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

  /// Creates a schema-backed session with a custom configuration (for proxies or advanced options).
  ///
  /// - Parameters:
  ///   - schema: The schema that enumerates tools, structured outputs, and groundings.
  ///   - instructions: Default instructions applied to every turn.
  ///   - configuration: OpenAI configuration describing routing and authentication.
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

  /// Creates a tool-only session backed by a custom configuration.
  ///
  /// - Parameters:
  ///   - tools: Variadic list of tools available to the model.
  ///   - instructions: Default instructions applied to every turn.
  ///   - configuration: OpenAI configuration describing routing and authentication.
  public init<each ToolType>(
    tools: repeat each ToolType,
    instructions: String = "",
    configuration: OpenAIConfiguration,
  ) where SessionSchema == NoSchema,
    repeat (each ToolType): FoundationModels.Tool,
    repeat (each ToolType).Arguments: Generable,
    repeat (each ToolType).Output: Generable {
      var wrappedTools: [any SwiftAgentTool] = []
      _ = (repeat wrappedTools.append(_SwiftAgentToolWrapper(tool: each tools)))

      schema = NoSchema()
      adapter = OpenAIAdapter(
        tools: wrappedTools,
        instructions: instructions,
        configuration: configuration,
      )
    }
}
