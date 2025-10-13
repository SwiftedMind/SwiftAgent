// By Dennis Müller

import MacroTesting
import SwiftAgentMacros
import SwiftSyntaxMacros
import Testing

@Suite("@LanguageModelProvider expansion")
struct LanguageModelProviderMacroTests {
  @Test("Empty Class")
  func expandEmptyClass() {
    assertMacro(["LanguageModelProvider": LanguageModelProviderMacro.self], indentationWidth: .spaces(2)) {
      """
      @LanguageModelProvider(.openAI)
      private final class ExampleSession {}
      """
    } expansion: {
      """
      private final class ExampleSession {

        typealias Adapter = OpenAIAdapter

        typealias ProviderType = ExampleSession

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
          typealias Generating<EnclosingSelf: LanguageModelProvider> = GeneratingLanguageModelProvider<EnclosingSelf, Output>
          private var output: Output.Type

          init(_ wrappedValue: Output.Type) {
            output = wrappedValue
          }

          static subscript <EnclosingSelf>(
            _enclosingInstance observed: EnclosingSelf,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Generating<EnclosingSelf>>,
            storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, StructuredOutput<Output>>
          ) -> Generating<EnclosingSelf> where EnclosingSelf: LanguageModelProvider {
            get {
              let wrapper = observed[keyPath: storageKeyPath]
              return Generating(provider: observed, output: wrapper.output)
            }
            set {
              // Intentionally ignore external assignments to the wrapped value
            }
          }

          @available(*, unavailable, message: "This property wrapper can only be applied to classes")
          var wrappedValue: Generating<ProviderType> {
            get {
              fatalError()
            }
            set {
              fatalError()
            }
          }
        }

        @propertyWrapper
        struct Grounding<Source: Codable & Sendable & Equatable> {
          var wrappedValue: Source.Type
          init(_ wrappedValue: Source.Type) {
            self.wrappedValue = wrappedValue
          }
        }

        let adapter: OpenAIAdapter

        let tools: [any SwiftAgentTool]

        let decodableTools: [any DecodableTool<ProviderType>]

        static let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = []

        @MainActor @_LanguageModelProviderObserved(initialValue: Transcript())
        var transcript: SwiftAgent.Transcript

        @MainActor @_LanguageModelProviderObserved(initialValue: TokenUsage())
        var tokenUsage: TokenUsage

        private let _$observationRegistrar = Observation.ObservationRegistrar()

        nonisolated func access(
          keyPath: KeyPath<ProviderType, some Any>
        ) {
          _$observationRegistrar.access(self, keyPath: keyPath)
        }

        nonisolated func withMutation<A>(
          keyPath: KeyPath<ProviderType, some Any>,
          _ mutation: () throws -> A
        ) rethrows -> A {
          try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
        }

        private nonisolated func shouldNotifyObservers<A>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          true
        }

        private nonisolated func shouldNotifyObservers<A: Equatable>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs != rhs
        }

        private nonisolated func shouldNotifyObservers<A: AnyObject>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs !== rhs
        }

        private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs != rhs
        }

        init(
          instructions: String,
          apiKey: String
        ) {
          let decodableTools: [any DecodableTool<ProviderType>] = []
          let tools: [any SwiftAgentTool] = decodableTools.map {
            $0 as any SwiftAgentTool
          }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = OpenAIAdapter(
            tools: tools,
            instructions: instructions,
            configuration: .direct(apiKey: apiKey)
          )
        }

        init(
          instructions: String,
          configuration: OpenAIConfiguration
        ) {
          let decodableTools: [any DecodableTool<ProviderType>] = []
          let tools: [any SwiftAgentTool] = decodableTools.map {
            $0 as any SwiftAgentTool
          }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = OpenAIAdapter(
            tools: tools,
            instructions: instructions,
            configuration: configuration
          )
        }

        init<each Tool: FoundationModels.Tool>(
          tools: repeat each Tool,
          instructions: String,
          apiKey: String
        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
          self.decodableTools = []
          var wrappedTools: [any SwiftAgentTool] = []
          for tool in repeat each tools {
            wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
          }
          self.tools = wrappedTools

          adapter = OpenAIAdapter(
            tools: wrappedTools,
            instructions: instructions,
            configuration: .direct(apiKey: apiKey)
          )
        }

        init<each Tool: FoundationModels.Tool>(
          tools: repeat each Tool,
          instructions: String,
          configuration: OpenAIConfiguration
        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
          self.decodableTools = []
          var wrappedTools: [any SwiftAgentTool] = []
          for tool in repeat each tools {
            wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
          }
          self.tools = wrappedTools

          adapter = OpenAIAdapter(
            tools: wrappedTools,
            instructions: instructions,
            configuration: configuration
          )
        }

        struct DecodedGrounding: SwiftAgent.DecodedGrounding {
        }

        enum DecodedToolRun: SwiftAgent.DecodedToolRun {

          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

          static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
            .unknown(toolCall: toolCall)
          }

          var id: String {
            switch self {

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
        }}

      extension ExampleSession: LanguageModelProvider, @unchecked Sendable, nonisolated Observation.Observable, SwiftAgent.RawStructuredOutputSupport {
      }
      """
    }
  }

  @Test("Tool, Grounding and Structured Output")
  func expandSingleToolWithDefaultInitializer() {
    assertMacro(["LanguageModelProvider": LanguageModelProviderMacro.self], indentationWidth: .spaces(2)) {
      """
      @LanguageModelProvider(.openAI)
      private final class ExampleSession {
        @Tool var weatherTool = WeatherTool()
        @Grounding(Date.self) var currentDate
        @StructuredOutput(WeatherReport.self) var weatherReport
      }
      """
    } expansion: {
      """
      private final class ExampleSession {
        @Tool var weatherTool = WeatherTool()
        @Grounding(Date.self) var currentDate
        @StructuredOutput(WeatherReport.self) var weatherReport

        typealias Adapter = OpenAIAdapter

        typealias ProviderType = ExampleSession

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
          typealias Generating<EnclosingSelf: LanguageModelProvider> = GeneratingLanguageModelProvider<EnclosingSelf, Output>
          private var output: Output.Type

          init(_ wrappedValue: Output.Type) {
            output = wrappedValue
          }

          static subscript <EnclosingSelf>(
            _enclosingInstance observed: EnclosingSelf,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Generating<EnclosingSelf>>,
            storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, StructuredOutput<Output>>
          ) -> Generating<EnclosingSelf> where EnclosingSelf: LanguageModelProvider {
            get {
              let wrapper = observed[keyPath: storageKeyPath]
              return Generating(provider: observed, output: wrapper.output)
            }
            set {
              // Intentionally ignore external assignments to the wrapped value
            }
          }

          @available(*, unavailable, message: "This property wrapper can only be applied to classes")
          var wrappedValue: Generating<ProviderType> {
            get {
              fatalError()
            }
            set {
              fatalError()
            }
          }
        }

        @propertyWrapper
        struct Grounding<Source: Codable & Sendable & Equatable> {
          var wrappedValue: Source.Type
          init(_ wrappedValue: Source.Type) {
            self.wrappedValue = wrappedValue
          }
        }

        let adapter: OpenAIAdapter

        let tools: [any SwiftAgentTool]

        let decodableTools: [any DecodableTool<ProviderType>]

        static let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = [
            DecodableWeatherReport.self
        ]

        @MainActor @_LanguageModelProviderObserved(initialValue: Transcript())
        var transcript: SwiftAgent.Transcript

        @MainActor @_LanguageModelProviderObserved(initialValue: TokenUsage())
        var tokenUsage: TokenUsage

        private let _$observationRegistrar = Observation.ObservationRegistrar()

        nonisolated func access(
          keyPath: KeyPath<ProviderType, some Any>
        ) {
          _$observationRegistrar.access(self, keyPath: keyPath)
        }

        nonisolated func withMutation<A>(
          keyPath: KeyPath<ProviderType, some Any>,
          _ mutation: () throws -> A
        ) rethrows -> A {
          try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
        }

        private nonisolated func shouldNotifyObservers<A>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          true
        }

        private nonisolated func shouldNotifyObservers<A: Equatable>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs != rhs
        }

        private nonisolated func shouldNotifyObservers<A: AnyObject>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs !== rhs
        }

        private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
          _ lhs: A,
          _ rhs: A
        ) -> Bool {
          lhs != rhs
        }

        init(
          instructions: String,
          apiKey: String
        ) {
          let decodableTools: [any DecodableTool<ProviderType>] = [
            DecodableWeatherTool(baseTool: _weatherTool.wrappedValue)
          ]
          let tools: [any SwiftAgentTool] = decodableTools.map {
            $0 as any SwiftAgentTool
          }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = OpenAIAdapter(
            tools: tools,
            instructions: instructions,
            configuration: .direct(apiKey: apiKey)
          )
        }

        init(
          instructions: String,
          configuration: OpenAIConfiguration
        ) {
          let decodableTools: [any DecodableTool<ProviderType>] = [
            DecodableWeatherTool(baseTool: _weatherTool.wrappedValue)
          ]
          let tools: [any SwiftAgentTool] = decodableTools.map {
            $0 as any SwiftAgentTool
          }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = OpenAIAdapter(
            tools: tools,
            instructions: instructions,
            configuration: configuration
          )
        }

        enum DecodedGrounding: SwiftAgent.DecodedGrounding {
          case currentDate(Date)
        }

        enum DecodedToolRun: SwiftAgent.DecodedToolRun {
          case weatherTool(ToolRun<WeatherTool>)
          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

          static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
            .unknown(toolCall: toolCall)
          }

          var id: String {
            switch self {
            case let .weatherTool(run):
            run.id
            case let .unknown(toolCall):
              toolCall.id
            }
          }
        }

        struct DecodableWeatherTool: DecodableTool {
          typealias Provider = ProviderType
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
          ) -> Provider.DecodedToolRun {
            .weatherTool(run)
          }
        }

        enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
          case weatherReport(SwiftAgent.StructuredOutputUpdate<WeatherReport>)
          case unknown(SwiftAgent.Transcript.StructuredSegment)

          static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {
              .unknown(segment)
          }
        }

        struct DecodableWeatherReport: SwiftAgent.DecodableStructuredOutput {
          typealias Base = WeatherReport
          typealias Provider = ProviderType

          static func decode(
            _ structuredOutput: SwiftAgent.StructuredOutputUpdate<WeatherReport>
          ) -> Provider.DecodedStructuredOutput {
            .weatherReport(structuredOutput)
          }
        }
      }

      extension ExampleSession: LanguageModelProvider, @unchecked Sendable, nonisolated Observation.Observable {
      }
      """
    }
  }
}
