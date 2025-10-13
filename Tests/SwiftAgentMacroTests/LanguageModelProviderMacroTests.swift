// By Dennis Müller

import MacroTesting
import SwiftAgentMacros
import SwiftSyntaxMacros
import Testing

@Suite(.macros([LanguageModelProviderMacro.self]))
struct LanguageModelProviderMacroTests {
  @Test
  func expansion_matches_expected_output() {
    assertMacro {
      """
      @LanguageModelProvider(.openAI)
      private final class ExampleSession {}
      """
    } expansion: {
      #"""
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

          @MainActor private var _transcript: SwiftAgent.Transcript = Transcript()

          @MainActor var transcript: SwiftAgent.Transcript {
            @storageRestrictions(initializes: _transcript)
            init(initialValue) {
              _transcript = initialValue
            }
            get {
              access(keyPath: \.transcript)
              return _transcript
            }
            set {
              guard shouldNotifyObservers(_transcript, newValue) else {
                _transcript = newValue
                return
              }

              withMutation(keyPath: \.transcript) {
                _transcript = newValue
              }
            }
            _modify {
              access(keyPath: \.transcript)
              _$observationRegistrar.willSet(self, keyPath: \.transcript)
              defer {
                _$observationRegistrar.didSet(self, keyPath: \.transcript)
              }
              yield &_transcript
            }
          }

          @MainActor private var _tokenUsage: TokenUsage = TokenUsage()

          @MainActor var tokenUsage: TokenUsage {
            @storageRestrictions(initializes: _tokenUsage)
            init(initialValue) {
              _tokenUsage = initialValue
            }
            get {
              access(keyPath: \.tokenUsage)
              return _tokenUsage
            }
            set {
              guard shouldNotifyObservers(_tokenUsage, newValue) else {
                _tokenUsage = newValue
                return
              }

              withMutation(keyPath: \.tokenUsage) {
                _tokenUsage = newValue
              }
            }
            _modify {
              access(keyPath: \.tokenUsage)
              _$observationRegistrar.willSet(self, keyPath: \.tokenUsage)
              defer {
                _$observationRegistrar.didSet(self, keyPath: \.tokenUsage)
              }
              yield &_tokenUsage
            }
          }

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
      """#
    }

//    assertMacro(
//      """
//      @LanguageModelProvider(.openAI)
//      private final class ExampleSession {}
//      """,
//      expansion: #"""
//      private final class ExampleSession {
//        typealias Adapter = OpenAIAdapter
//
//        typealias ProviderType = ExampleSession
//
//        @propertyWrapper
//        struct Tool<ToolType: FoundationModels.Tool>
//        where ToolType.Arguments: Generable & Sendable, ToolType.Output: Generable & Sendable {
//          var wrappedValue: ToolType
//          init(wrappedValue: ToolType) {
//            self.wrappedValue = wrappedValue
//          }
//        }
//
//        @propertyWrapper
//        struct StructuredOutput<Output: SwiftAgent.StructuredOutput> {
//          typealias Generating<EnclosingSelf: LanguageModelProvider> = GeneratingLanguageModelProvider<EnclosingSelf,
//          Output>
//          private var output: Output.Type
//
//          init(_ wrappedValue: Output.Type) {
//            output = wrappedValue
//          }
//
//          static subscript<EnclosingSelf>(
//            _enclosingInstance observed: EnclosingSelf,
//            wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Generating<EnclosingSelf>>,
//            storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, StructuredOutput<Output>>,
//          ) -> Generating<EnclosingSelf> where EnclosingSelf: LanguageModelProvider {
//            get {
//              let wrapper = observed[keyPath: storageKeyPath]
//              return Generating(provider: observed, output: wrapper.output)
//            }
//            set {
//              // Intentionally ignore external assignments to the wrapped value
//            }
//          }
//
//          @available(*, unavailable, message: "This property wrapper can only be applied to classes")
//          var wrappedValue: Generating<ProviderType> {
//            get {
//              fatalError()
//            }
//            set {
//              fatalError()
//            }
//          }
//        }
//
//        @propertyWrapper
//        struct Grounding<Source: Codable & Sendable & Equatable> {
//          var wrappedValue: Source.Type
//          init(_ wrappedValue: Source.Type) {
//            self.wrappedValue = wrappedValue
//          }
//        }
//
//        let adapter: OpenAIAdapter
//
//        let tools: [any SwiftAgentTool]
//
//        let decodableTools: [any DecodableTool<ProviderType>]
//
//        static let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = []
//
//        @MainActor private var _transcript: SwiftAgent.Transcript = Transcript()
//
//        @MainActor var transcript: SwiftAgent.Transcript {
//          @storageRestrictions(initializes: _transcript)
//          init(initialValue) {
//            _transcript = initialValue
//          }
//          get {
//            access(keyPath: \.transcript)
//            return _transcript
//          }
//          set {
//            guard shouldNotifyObservers(_transcript, newValue) else {
//              _transcript = newValue
//              return
//            }
//
//            withMutation(keyPath: \.transcript) {
//              _transcript = newValue
//            }
//          }
//          _modify {
//            access(keyPath: \.transcript)
//            _$observationRegistrar.willSet(self, keyPath: \.transcript)
//            defer {
//              _$observationRegistrar.didSet(self, keyPath: \.transcript)
//            }
//            yield &_transcript
//          }
//        }
//
//        @MainActor private var _tokenUsage: TokenUsage = .init()
//
//        @MainActor var tokenUsage: TokenUsage {
//          @storageRestrictions(initializes: _tokenUsage)
//          init(initialValue) {
//            _tokenUsage = initialValue
//          }
//          get {
//            access(keyPath: \.tokenUsage)
//            return _tokenUsage
//          }
//          set {
//            guard shouldNotifyObservers(_tokenUsage, newValue) else {
//              _tokenUsage = newValue
//              return
//            }
//
//            withMutation(keyPath: \.tokenUsage) {
//              _tokenUsage = newValue
//            }
//          }
//          _modify {
//            access(keyPath: \.tokenUsage)
//            _$observationRegistrar.willSet(self, keyPath: \.tokenUsage)
//            defer {
//              _$observationRegistrar.didSet(self, keyPath: \.tokenUsage)
//            }
//            yield &_tokenUsage
//          }
//        }
//
//        private let _$observationRegistrar = Observation.ObservationRegistrar()
//
//        nonisolated func access(
//          keyPath: KeyPath<ProviderType, some Any>,
//        ) {
//          _$observationRegistrar.access(self, keyPath: keyPath)
//        }
//
//        nonisolated func withMutation<A>(
//          keyPath: KeyPath<ProviderType, some Any>,
//          _ mutation: () throws -> A,
//        ) rethrows -> A {
//          try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
//        }
//
//        private nonisolated func shouldNotifyObservers<A>(
//          _ lhs: A,
//          _ rhs: A,
//        ) -> Bool {
//          true
//        }
//
//        private nonisolated func shouldNotifyObservers<A: Equatable>(
//          _ lhs: A,
//          _ rhs: A,
//        ) -> Bool {
//          lhs != rhs
//        }
//
//        private nonisolated func shouldNotifyObservers<A: AnyObject>(
//          _ lhs: A,
//          _ rhs: A,
//        ) -> Bool {
//          lhs !== rhs
//        }
//
//        private nonisolated func shouldNotifyObservers<A: Equatable & AnyObject>(
//          _ lhs: A,
//          _ rhs: A,
//        ) -> Bool {
//          lhs != rhs
//        }
//
//        init(
//          instructions: String,
//          apiKey: String,
//        ) {
//          let decodableTools: [any DecodableTool<ProviderType>] = []
//          let tools: [any SwiftAgentTool] = decodableTools.map {
//            $0 as any SwiftAgentTool
//          }
//          self.decodableTools = decodableTools
//          self.tools = tools
//
//          adapter = OpenAIAdapter(
//            tools: tools,
//            instructions: instructions,
//            configuration: .direct(apiKey: apiKey),
//          )
//        }
//
//        init(
//          instructions: String,
//          configuration: OpenAIConfiguration,
//        ) {
//          let decodableTools: [any DecodableTool<ProviderType>] = []
//          let tools: [any SwiftAgentTool] = decodableTools.map {
//            $0 as any SwiftAgentTool
//          }
//          self.decodableTools = decodableTools
//          self.tools = tools
//
//          adapter = OpenAIAdapter(
//            tools: tools,
//            instructions: instructions,
//            configuration: configuration,
//          )
//        }
//
//        init<each Tool: FoundationModels.Tool>(
//          tools: repeat each Tool,
//          instructions: String,
//          apiKey: String,
//        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
//          decodableTools = []
//          var wrappedTools: [any SwiftAgentTool] = []
//          for tool in repeat each tools {
//            wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
//          }
//          self.tools = wrappedTools
//
//          adapter = OpenAIAdapter(
//            tools: wrappedTools,
//            instructions: instructions,
//            configuration: .direct(apiKey: apiKey),
//          )
//        }
//
//        init<each Tool: FoundationModels.Tool>(
//          tools: repeat each Tool,
//          instructions: String,
//          configuration: OpenAIConfiguration,
//        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
//          decodableTools = []
//          var wrappedTools: [any SwiftAgentTool] = []
//          for tool in repeat each tools {
//            wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
//          }
//          self.tools = wrappedTools
//
//          adapter = OpenAIAdapter(
//            tools: wrappedTools,
//            instructions: instructions,
//            configuration: configuration,
//          )
//        }
//
//        struct DecodedGrounding: SwiftAgent.DecodedGrounding {}
//
//        enum DecodedToolRun: SwiftAgent.DecodedToolRun {
//          case unknown(toolCall: SwiftAgent.Transcript.ToolCall)
//
//          static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
//            .unknown(toolCall: toolCall)
//          }
//
//          var id: String {
//            switch self {
//            case let .unknown(toolCall):
//              toolCall.id
//            }
//          }
//        }
//
//        enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
//          case unknown(SwiftAgent.Transcript.StructuredSegment)
//
//          static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {
//            .unknown(segment)
//          }
//        }
//      }
//
//      extension ExampleSession: LanguageModelProvider, @unchecked Sendable, nonisolated Observation.Observable,
//        SwiftAgent.RawStructuredOutputSupport {}
//      """#
//    )
  }
}
