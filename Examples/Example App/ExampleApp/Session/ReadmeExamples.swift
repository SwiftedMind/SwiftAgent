// By Dennis Müller

import Foundation
import FoundationModels
import Observation
import OpenAISession

@Observable
final class NewOpenAISession<SessionSchema: LanguageModelSessionSchema>: LanguageModelProvider, @unchecked Sendable {
  typealias Adapter = OpenAIAdapter
  typealias ProviderType = NewOpenAISession

  /// Adapter used by this provider to communicate with the underlying model API.
  @ObservationIgnored let adapter: OpenAIAdapter

  @ObservationIgnored var schema: SessionSchema

  /// Registered tools available to the model during a session.
  @ObservationIgnored var tools: [any SwiftAgentTool] {
    adapter.tools
  }

  /// Transcript of the session, including prompts, tool calls, and model outputs.
  var transcript: SwiftAgent.Transcript = Transcript()
  var tokenUsage: TokenUsage = .init()

  init(
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

  init(
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

  init(
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

  init(
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

/*

 @SessionSchema
 struct SessionSchema: LanguageModelSessionSchema {
   @Tool var calculator = CalculatorTool()
   @Tool var weather = WeatherTool()
   @Grounding(Date.self) var currentDate
   @StructuredOutput(WeatherReport.self) var weatherReport
 }

 expands into:

 */

struct SessionSchema: LanguageModelSessionSchema {
  @Tool var calculator = CalculatorTool()
  @Tool var weather = WeatherTool()
  @Grounding(Date.self) var currentDate
  @StructuredOutput(WeatherReport.self) var weatherReport

  /// Internal decodable wrappers for tool results used by the macro.
  let decodableTools: [any DecodableTool<DecodedToolRun>]

  static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
    [
      DecodableWeatherReport.self,
    ]
  }

  /// NOTE: As before, macro should generate overloads with tool parameters, if they don't have default values above.
  init() {
    decodableTools = [
      DecodableCalculatorTool(baseTool: _calculator.wrappedValue),
      DecodableWeatherTool(baseTool: _weather.wrappedValue),
    ]
  }

  enum DecodedGrounding: SwiftAgent.DecodedGrounding {
    case currentDate(Date)
  }

  enum DecodedToolRun: SwiftAgent.DecodedToolRun {
    case calculator(ToolRun<CalculatorTool>)
    case weather(ToolRun<WeatherTool>)
    case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

    static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
      .unknown(toolCall: toolCall)
    }

    var id: String {
      switch self {
      case let .calculator(run):
        run.id
      case let .weather(run):
        run.id
      case let .unknown(toolCall):
        toolCall.id
      }
    }
  }

  enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
    case weatherReport(SwiftAgent.StructuredOutputUpdate<WeatherReport>)
    case unknown(SwiftAgent.Transcript.StructuredSegment)

    static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {
      .unknown(segment)
    }
  }

  private struct DecodableCalculatorTool: DecodableTool {
    typealias BaseTool = CalculatorTool
    typealias Arguments = BaseTool.Arguments
    typealias Output = BaseTool.Output

    private let baseTool: BaseTool

    init(baseTool: CalculatorTool) {
      self.baseTool = baseTool
    }

    var name: String {
      baseTool.name
    }

    var description: String {
      baseTool.description
    }

    var parameters: GenerationSchema {
      baseTool.parameters
    }

    func call(arguments: Arguments) async throws -> Output {
      try await baseTool.call(arguments: arguments)
    }

    func decode(
      _ run: ToolRun<CalculatorTool>,
    ) -> DecodedToolRun {
      .calculator(run)
    }
  }

  private struct DecodableWeatherTool: DecodableTool {
    typealias BaseTool = WeatherTool
    typealias Arguments = BaseTool.Arguments
    typealias Output = BaseTool.Output

    private let baseTool: BaseTool

    init(baseTool: WeatherTool) {
      self.baseTool = baseTool
    }

    var name: String {
      baseTool.name
    }

    var description: String {
      baseTool.description
    }

    var parameters: GenerationSchema {
      baseTool.parameters
    }

    func call(arguments: Arguments) async throws -> Output {
      try await baseTool.call(arguments: arguments)
    }

    func decode(
      _ run: ToolRun<WeatherTool>,
    ) -> DecodedToolRun {
      .weather(run)
    }
  }

  private struct DecodableWeatherReport: SwiftAgent.DecodableStructuredOutput {
    typealias Base = WeatherReport

    static func decode(
      _ structuredOutput: SwiftAgent.StructuredOutputUpdate<WeatherReport>,
    ) -> DecodedStructuredOutput {
      .weatherReport(structuredOutput)
    }
  }

  @propertyWrapper
  struct Tool<ToolType: FoundationModels.Tool>
    where ToolType.Arguments: Generable & Sendable, ToolType.Output: Generable & Sendable {
    var wrappedValue: ToolType
    init(wrappedValue: ToolType) {
      self.wrappedValue = wrappedValue
    }
  }

  @propertyWrapper
  struct StructuredOutput<Output: SwiftAgent.StructuredOutput> {
    var wrappedValue: Output.Type
    init(_ wrappedValue: Output.Type) {
      self.wrappedValue = wrappedValue
    }
  }

  @propertyWrapper
  struct Grounding<Source: Codable & Sendable & Equatable> {
    var wrappedValue: Source.Type
    init(_ wrappedValue: Source.Type) {
      self.wrappedValue = wrappedValue
    }
  }
}
