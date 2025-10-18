// By Dennis Müller

import Foundation
import FoundationModels
import Observation
@_exported import SwiftAgent

@Observable
public final class SimulatedSession<
  SessionSchema: LanguageModelSessionSchema,
>: LanguageModelProvider, @unchecked Sendable {
  public typealias Adapter = SimulationAdapter

  @ObservationIgnored public let adapter: SimulationAdapter
  @ObservationIgnored public var schema: SessionSchema

  @ObservationIgnored public var tools: [any SwiftAgentTool] {
    adapter.tools
  }

  public var transcript: SwiftAgent.Transcript = Transcript()
  public var tokenUsage: TokenUsage = .init()

  private var defaultGenerations: [SimulatedGeneration] {
    adapter.configuration.defaultGenerations
  }

  private var defaultTokenUsage: TokenUsage? {
    adapter.configuration.tokenUsage
  }

  public init<each ToolType>(
    tools: repeat each ToolType,
    instructions: String = "",
    configuration: SimulationAdapter.Configuration,
  ) where
    SessionSchema == NoSchema,
    repeat (each ToolType): FoundationModels.Tool,
    repeat (each ToolType).Arguments: Generable,
    repeat (each ToolType).Output: Generable {
      var wrappedTools: [any SwiftAgentTool] = []
      _ = (repeat wrappedTools.append(_SwiftAgentToolWrapper(tool: each tools)))

      schema = NoSchema()
      adapter = SimulationAdapter(
        tools: wrappedTools,
        instructions: instructions,
        configuration: configuration,
      )
    }

  public init(
    schema: SessionSchema,
    instructions: String,
    configuration: SimulationAdapter.Configuration,
  ) {
    self.schema = schema
    adapter = SimulationAdapter(
      tools: schema.decodableTools,
      instructions: instructions,
      configuration: configuration,
    )
  }
}
