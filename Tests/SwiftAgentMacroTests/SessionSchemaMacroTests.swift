// By Dennis Müller

import MacroTesting
import SwiftAgentMacros
import SwiftSyntaxMacros
import Testing

@Suite("@SessionSchema expansion")
struct SessionSchemaMacroTests {
  @Test("Schema with defaulted tools")
  func expandSchemaWithDefaults() {
    assertMacro(["SessionSchema": SessionSchemaMacro.self], indentationWidth: .spaces(2)) {
      """
      @SessionSchema
      struct SessionSchema {
        @Tool var calculator = CalculatorTool()
        @Tool var weather = WeatherTool()
        @Grounding(Date.self) var currentDate
        @StructuredOutput(WeatherReport.self) var weatherReport
      }
      """
    } expansion: {
      """
      struct SessionSchema {
        @Tool var calculator = CalculatorTool()
        @Tool var weather = WeatherTool()
        @Grounding(Date.self) var currentDate
        @StructuredOutput(WeatherReport.self) var weatherReport

        nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]

        struct StructuredOutputs {
          let weatherReport = WeatherReport.self
        }

        static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
          [
              DecodableWeatherReport.self
          ]
        }

        init() {
          decodableTools = [
            DecodableCalculatorTool(baseTool: _calculator.wrappedValue),
            DecodableWeatherTool(baseTool: _weather.wrappedValue)
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
            _ run: ToolRun<CalculatorTool>
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
            _ run: ToolRun<WeatherTool>
          ) -> DecodedToolRun {
            .weather(run)
          }
        }

        private struct DecodableWeatherReport: SwiftAgent.DecodableStructuredOutput {
          typealias Base = WeatherReport

          static func decode(
            _ structuredOutput: SwiftAgent.StructuredOutputUpdate<WeatherReport>
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

      extension SessionSchema: LanguageModelSessionSchema {
      }

      extension SessionSchema: GroundingSupportingSchema {
      }
      """
    }
  }

  @Test("Schema with injected tool")
  func expandSchemaWithInjectedTool() {
    assertMacro(["SessionSchema": SessionSchemaMacro.self], indentationWidth: .spaces(2)) {
      """
      @SessionSchema
      struct SessionSchema {
        @Tool var calculator: CalculatorTool
      }
      """
    } expansion: {
      """
      struct SessionSchema {
        @Tool var calculator: CalculatorTool

        nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]

        struct StructuredOutputs {
        }

        static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
          []
        }

        init(
          calculator: CalculatorTool
        ) {
          _calculator = Tool(wrappedValue: calculator)

          decodableTools = [
            DecodableCalculatorTool(baseTool: _calculator.wrappedValue)
          ]
        }

        struct DecodedGrounding: SwiftAgent.DecodedGrounding {
        }

        enum DecodedToolRun: SwiftAgent.DecodedToolRun {
          case calculator(ToolRun<CalculatorTool>)
          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)
          static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
            .unknown(toolCall: toolCall)
          }
          var id: String {
            switch self {
            case let .calculator(run):
              run.id
            case let .unknown(toolCall):
              toolCall.id
            }
          }
        }

        enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
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
            _ run: ToolRun<CalculatorTool>
          ) -> DecodedToolRun {
            .calculator(run)
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

      extension SessionSchema: LanguageModelSessionSchema {
      }
      """
    }
  }
}
