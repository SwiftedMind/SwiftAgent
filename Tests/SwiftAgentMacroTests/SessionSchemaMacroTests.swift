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

        internal nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]

        internal struct StructuredOutputs: @unchecked Sendable {
          let weatherReport = WeatherReport.self
        }

        internal static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
          [
              DecodableWeatherReport.self
          ]
        }

        internal init() {
          decodableTools = [
            DecodableCalculatorTool(baseTool: _calculator.wrappedValue),
            DecodableWeatherTool(baseTool: _weather.wrappedValue)
          ]
        }

        internal enum DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {
          case currentDate(Date)
        }

        internal enum DecodedToolRun: SwiftAgent.DecodedToolRun, @unchecked Sendable {
          case calculator(ToolRun<CalculatorTool>)
          case weather(ToolRun<WeatherTool>)
          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)
          internal static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
            .unknown(toolCall: toolCall)
          }
          internal var id: String {
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

        internal enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput, @unchecked Sendable {
          case weatherReport(SwiftAgent.StructuredOutputSnapshot<WeatherReport>)
          case unknown(SwiftAgent.Transcript.StructuredSegment)

          internal static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {
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

        private struct DecodableWeatherReport: SwiftAgent.DecodableStructuredOutput, @unchecked Sendable {
          typealias Base = WeatherReport

          static func decode(
            _ structuredOutput: SwiftAgent.StructuredOutputSnapshot<WeatherReport>
          ) -> DecodedStructuredOutput {
            .weatherReport(structuredOutput)
          }
        }

        @propertyWrapper
        struct Tool<ToolType: FoundationModels.Tool>
        where ToolType.Arguments: Generable, ToolType.Output: Generable {
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

        internal nonisolated let decodableTools: [any DecodableTool<DecodedToolRun>]

        internal struct StructuredOutputs: @unchecked Sendable {
        }

        internal static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
          []
        }

        internal init(
          calculator: CalculatorTool
        ) {
          _calculator = Tool(wrappedValue: calculator)

          decodableTools = [
            DecodableCalculatorTool(baseTool: _calculator.wrappedValue)
          ]
        }

        internal struct DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {
        }

        internal enum DecodedToolRun: SwiftAgent.DecodedToolRun, @unchecked Sendable {
          case calculator(ToolRun<CalculatorTool>)
          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)
          internal static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
            .unknown(toolCall: toolCall)
          }
          internal var id: String {
            switch self {
            case let .calculator(run):
              run.id
            case let .unknown(toolCall):
              toolCall.id
            }
          }
        }

        internal enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput, @unchecked Sendable {
          case unknown(SwiftAgent.Transcript.StructuredSegment)

          internal static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {
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
        where ToolType.Arguments: Generable, ToolType.Output: Generable {
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
