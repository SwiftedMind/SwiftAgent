// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension LanguageModelProviderMacro {
  // MARK: - Initializers

  static func generateInitializers(
    for tools: [ToolProperty],
    provider: Provider,
  ) throws -> [DeclSyntax] {
    var initializers: [DeclSyntax] = []

    // Capture parameter metadata so we can drive wrapper creation and initializer signatures.
    let toolParameters = tools.map { tool in
      (
        name: tool.identifier.text,
        type: tool.typeName,
        hasInitializer: tool.hasInitializer,
      )
    }

    // Populate stored wrappers for tools that must be injected by the initializer.
    let wrapperAssignments = toolParameters
      .compactMap { parameter in
        guard !parameter.hasInitializer else {
          return nil
        }

        return "    _\(parameter.name) = Tool(wrappedValue: \(parameter.name))"
      }
      .joined(separator: "\n")

    let initializerPrologueBlock = wrapperAssignments.isEmpty
      ? ""
      : "\(wrapperAssignments)\n\n"

    let decodableToolsArrayInit = toolParameters.map { parameter in
      let wrapperName = "Decodable\(parameter.name.capitalizedFirstLetter())Tool"
      let baseToolExpression = parameter.hasInitializer
        ? "_\(parameter.name).wrappedValue"
        : parameter.name
      // Wrap each declared tool so we can hand it to the adapter as a `DecodableTool`.
      return "      \(wrapperName)(baseTool: \(baseToolExpression))"
    }
    .joined(separator: ",\n")

    // Construct the literal array so the adapter receives every tool in declaration order.
    let decodableToolsArrayCode = decodableToolsArrayInit.isEmpty ? "[]" : "[\n\(decodableToolsArrayInit)\n    ]"

    let initParameters = toolParameters
      .filter { !$0.hasInitializer }
      .map { "    \($0.name): \($0.type)" }
      .joined(separator: ",\n")

    let allInitParameters = initParameters.isEmpty
      ? "instructions: String,\n    apiKey: String"
      : "\(initParameters),\n    instructions: String,\n    apiKey: String"

    // Base initializer wires direct API key authentication through the generated adapter.
    initializers.append(
      """
        init(
          \(raw: allInitParameters)
        ) {
        \(raw: initializerPrologueBlock)    let decodableTools: [any DecodableTool<ProviderType>] = \(
          raw: decodableToolsArrayCode
        )
          let tools: [any SwiftAgentTool] = decodableTools.map { $0 as any SwiftAgentTool }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = \(raw: provider.adapterTypeName)(
            tools: tools,
            instructions: instructions,
            configuration: .direct(apiKey: apiKey)
          )
        }
      """,
    )

    let configurationInitParameters = initParameters.isEmpty
      ? "instructions: String,\n    configuration: \(provider.configurationTypeName)"
      : "\(initParameters),\n    instructions: String,\n    configuration: \(provider.configurationTypeName)"

    // Overload initializer accepts a fully-formed provider configuration instead.
    initializers.append(
      """
        init(
          \(raw: configurationInitParameters)
        ) {
        \(raw: initializerPrologueBlock)    let decodableTools: [any DecodableTool<ProviderType>] = \(
          raw: decodableToolsArrayCode
        )
          let tools: [any SwiftAgentTool] = decodableTools.map { $0 as any SwiftAgentTool }
          self.decodableTools = decodableTools
          self.tools = tools

          adapter = \(raw: provider.adapterTypeName)(
            tools: tools,
            instructions: instructions,
            configuration: configuration
          )
        }
      """,
    )

    if toolParameters.isEmpty {
      initializers.append(
        """
          init<each Tool: FoundationModels.Tool>(
            tools: repeat each Tool,
            instructions: String,
            apiKey: String
          ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
        \(raw: initializerPrologueBlock)    self.decodableTools = []
            var wrappedTools: [any SwiftAgentTool] = []
            for tool in repeat each tools {
              wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
            }
            self.tools = wrappedTools

            adapter = \(raw: provider.adapterTypeName)(
              tools: wrappedTools,
              instructions: instructions,
              configuration: .direct(apiKey: apiKey)
            )
          }
        """,
      )

      initializers.append(
        """
          init<each Tool: FoundationModels.Tool>(
            tools: repeat each Tool,
            instructions: String,
            configuration: \(raw: provider.configurationTypeName)
          ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
        \(raw: initializerPrologueBlock)    self.decodableTools = []
            var wrappedTools: [any SwiftAgentTool] = []
            for tool in repeat each tools {
              wrappedTools.append(SwiftAgentToolWrapper(tool: tool))
            }
            self.tools = wrappedTools

            adapter = \(raw: provider.adapterTypeName)(
              tools: wrappedTools,
              instructions: instructions,
              configuration: configuration
            )
          }
        """,
      )
    }

    return initializers
  }

  // MARK: - Tool decoding

  static func generateDecodedToolRunEnum(for tools: [ToolProperty]) -> DeclSyntax {
    let cases = tools.map { tool -> String in
      let wrapperName = "Decodable\(tool.identifier.text.capitalizedFirstLetter())Tool"
      return "    case \(tool.identifier.text)(ToolRun<\(wrapperName)>)"
    }
    .joined(separator: "\n")

    let idSwitchCases = tools.map { tool -> String in
      return "        case let .\(tool.identifier.text)(run):\n            run.id"
    }
    .joined(separator: "\n")

    return
      """
      enum DecodedToolRun: SwiftAgent.DecodedToolRun {
      \(raw: cases)
      case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

      static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
        .unknown(toolCall: toolCall)
      }

      var id: String {
        switch self {
      \(raw: idSwitchCases)
        case let .unknown(toolCall):
            toolCall.id
        }
      }
      }
      """
  }

  static func generateDecodableWrapper(for tool: ToolProperty) -> DeclSyntax {
    let wrapperName = "Decodable\(tool.identifier.text.capitalizedFirstLetter())Tool"

    return
      """
      struct \(raw: wrapperName): DecodableTool {
        typealias Provider = ProviderType
        typealias BaseTool = \(raw: tool.typeName)
        typealias Arguments = BaseTool.Arguments
        typealias Output = BaseTool.Output

        private let baseTool: BaseTool

        init(baseTool: \(raw: tool.typeName)) {
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
          _ run: ToolRun<\(raw: wrapperName)>
        ) -> Provider.DecodedToolRun {
          .\(raw: tool.identifier.text)(run)
        }
      }
      """
  }

  // MARK: - Grounding

  static func generateDecodedGroundingEnum(for groundings: [GroundingProperty]) -> DeclSyntax {
    guard !groundings.isEmpty else {
      return
        """
        enum DecodedGrounding: SwiftAgent.DecodedGrounding {
          init(from decoder: Decoder) throws {
            let context = DecodingError.Context(
              codingPath: decoder.codingPath,
              debugDescription: "No @Grounding properties are defined, so no DecodedGrounding can be decoded."
            )
            throw DecodingError.dataCorrupted(context)
          }

          func encode(to encoder: Encoder) throws {
            let context = EncodingError.Context(
              codingPath: encoder.codingPath,
              debugDescription: "No @Grounding properties are defined, so no DecodedGrounding can be encoded."
            )
            throw EncodingError.invalidValue(self, context)
          }
        }
        """
    }

    let cases = groundings.map { grounding -> String in
      "    case \(grounding.identifier.text)(\(grounding.typeName))"
    }
    .joined(separator: "\n")

    return
      """
      enum DecodedGrounding: SwiftAgent.DecodedGrounding {
      \(raw: cases)
      }
      """
  }

  // MARK: - Structured Output generation

  static func generateStructuredOutputsProperty(
    for outputs: [StructuredOutputProperty],
  ) -> DeclSyntax {
    guard !outputs.isEmpty else {
      return """
      static let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = []
      """
    }

    let entries = outputs
      .map { output in
        "    \(resolvableStructuredOutputTypeName(for: output)).self"
      }
      .joined(separator: "\n")

    return """
    static let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = [
    \(raw: entries)
    ]
    """
  }

  static func generateDecodedStructuredOutputEnum(
    for outputs: [StructuredOutputProperty],
  ) -> DeclSyntax {
    var sections: [String] = []

    if !outputs.isEmpty {
      let cases = outputs
        .map { output in
          let caseName = output.identifier.text
          let resolvableTypeName = resolvableStructuredOutputTypeName(for: output)
          return "    case \(caseName)(SwiftAgent.DecodedGeneratedContent<\(resolvableTypeName)>)"
        }
        .joined(separator: "\n")
      sections.append(cases)
    }

    sections.append("    case unknown(SwiftAgent.Transcript.StructuredSegment)")
    sections.append("")
    sections.append("    static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {")
    sections.append("        .unknown(segment)")
    sections.append("    }")

    let body = sections.joined(separator: "\n")

    return """
    enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
    \(raw: body)
    }
    """
  }

  static func generateDecodableStructuredOutputTypes(
    for outputs: [StructuredOutputProperty],
  ) -> [DeclSyntax] {
    outputs.map { output in
      let resolvableName = resolvableStructuredOutputTypeName(for: output)
      let schemaType = output.typeName
      let caseName = output.identifier.text

      return """
      struct \(raw: resolvableName): SwiftAgent.DecodableStructuredOutput {
        typealias Base = \(raw: schemaType)
        typealias Provider = ProviderType

        static func decode(
          _ structuredOutput: SwiftAgent.DecodedGeneratedContent<\(raw: resolvableName)>
        ) -> Provider.DecodedStructuredOutput {
          .\(raw: caseName)(structuredOutput)
        }
      }
      """
    }
  }

  static func resolvableStructuredOutputTypeName(for output: StructuredOutputProperty) -> String {
    "Decodable\(output.identifier.text.capitalizedFirstLetter())"
  }
}
