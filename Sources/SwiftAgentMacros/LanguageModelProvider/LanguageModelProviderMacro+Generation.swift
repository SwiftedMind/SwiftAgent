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
    accessModifier: String?,
  ) throws -> [DeclSyntax] {
    var initializers: [DeclSyntax] = []
    let initKeyword = accessModifier.map { "\($0) init" } ?? "init"

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
      // Generate wrapper name based on the base tool type name
      let wrapperName = "Decodable\(parameter.type)"
      let baseToolExpression = parameter.hasInitializer
        ? "_\(parameter.name).wrappedValue"
        : parameter.name
      // Wrap each declared tool so we can hand it to the adapter as a `DecodableTool`.
      return "    \(wrapperName)(baseTool: \(baseToolExpression))"
    }
    .joined(separator: ",\n")

    // Construct the literal array so the adapter receives every tool in declaration order.
    let decodableToolsArrayCode = decodableToolsArrayInit.isEmpty ? "[]" : "[\n\(decodableToolsArrayInit)\n  ]"

    let initParameters = toolParameters
      .filter { !$0.hasInitializer }
      .map { "    \($0.name): \($0.type)" }
      .joined(separator: ",\n")

    let allInitParameters = initParameters.isEmpty
      ? "instructions: String,\n  apiKey: String"
      : "\(initParameters),\n  instructions: String,\n  apiKey: String"

    // Base initializer wires direct API key authentication through the generated adapter.
    initializers.append(
      """
      \(raw: initKeyword)(
        \(raw: allInitParameters)
      ) {
      \(raw: initializerPrologueBlock)  let decodableTools: [any DecodableTool<ProviderType>] = \(
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
      ? "instructions: String,\n  configuration: \(provider.configurationTypeName)"
      : "\(initParameters),\n  instructions: String,\n  configuration: \(provider.configurationTypeName)"

    // Overload initializer accepts a fully-formed provider configuration instead.
    initializers.append(
      """
      \(raw: initKeyword)(
        \(raw: configurationInitParameters)
      ) {
      \(raw: initializerPrologueBlock)  let decodableTools: [any DecodableTool<ProviderType>] = \(
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
        \(raw: initKeyword)<each Tool: FoundationModels.Tool>(
          tools: repeat each Tool,
          instructions: String,
          apiKey: String
        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
        \(raw: initializerPrologueBlock)  self.decodableTools = []
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
        \(raw: initKeyword)<each Tool: FoundationModels.Tool>(
          tools: repeat each Tool,
          instructions: String,
          configuration: \(raw: provider.configurationTypeName)
        ) where repeat (each Tool).Arguments: Generable, repeat (each Tool).Output: Generable {
        \(raw: initializerPrologueBlock)  self.decodableTools = []
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

  static func generateDecodedToolRunEnum(
    for tools: [ToolProperty],
    accessModifier: String?,
  ) -> DeclSyntax {
    let enumKeyword = accessModifier.map { "\($0) enum" } ?? "enum"
    let staticFunctionKeyword = accessModifier.map { "\($0) static func" } ?? "static func"
    let propertyKeyword = accessModifier.map { "\($0) var" } ?? "var"
    let cases = tools.map { tool -> String in
      return "  case \(tool.identifier.text)(ToolRun<\(tool.typeName).Arguments, \(tool.typeName).Output>)"
    }
    .joined(separator: "\n")

    let idSwitchCases = tools.map { tool -> String in
      return "case let .\(tool.identifier.text)(run):\n  run.id"
    }
    .joined(separator: "\n")

    return
      """
      \(raw: enumKeyword) DecodedToolRun: SwiftAgent.DecodedToolRun {
      \(raw: cases)
      case unknown(toolCall: SwiftAgent.Transcript.ToolCall)

      \(raw: staticFunctionKeyword) makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {
        .unknown(toolCall: toolCall)
      }

      \(raw: propertyKeyword) id: String {
        switch self {
        \(raw: idSwitchCases)
        case let .unknown(toolCall):
          toolCall.id
        }
      }
      }
      """
  }

  static func generateDecodableWrapper(
    for tool: ToolProperty,
    accessModifier: String?,
  ) -> DeclSyntax {
    let wrapperName = decodableWrapperName(for: tool)
    let structKeyword = accessModifier.map { "\($0) struct" } ?? "struct"
    let typeDeclaration = "\(structKeyword) \(wrapperName)"
    let initKeyword = accessModifier.map { "\($0) init" } ?? "init"
    let propertyKeyword = accessModifier.map { "\($0) var" } ?? "var"
    let functionKeyword = accessModifier.map { "\($0) func" } ?? "func"
    let typealiasKeyword = accessModifier.map { "\($0) typealias" } ?? "typealias"

    return
      """
      \(raw: typeDeclaration): DecodableTool {
        \(raw: typealiasKeyword) Provider = ProviderType
        \(raw: typealiasKeyword) BaseTool = \(raw: tool.typeName)
        \(raw: typealiasKeyword) Arguments = BaseTool.Arguments
        \(raw: typealiasKeyword) Output = BaseTool.Output

        private let baseTool: BaseTool

        \(raw: initKeyword)(baseTool: \(raw: tool.typeName)) {
          self.baseTool = baseTool
        }

        \(raw: propertyKeyword) name: String {
          baseTool.name
        }

        \(raw: propertyKeyword) description: String {
          baseTool.description
        }

        \(raw: propertyKeyword) parameters: GenerationSchema {
          baseTool.parameters
        }

        \(raw: functionKeyword) call(arguments: Arguments) async throws -> Output {
          try await baseTool.call(arguments: arguments)
        }

        \(raw: functionKeyword) decode(
          _ run: ToolRun<\(raw: tool.typeName).Arguments, \(raw: tool.typeName).Output>
        ) -> Provider.DecodedToolRun {
          .\(raw: tool.identifier.text)(run)
        }
      }
      """
  }

  // MARK: - Grounding

  static func generateDecodedGroundingType(
    for groundings: [GroundingProperty],
    accessModifier: String?,
  ) -> DeclSyntax {
    let enumKeyword = accessModifier.map { "\($0) enum" } ?? "enum"
    let structKeyword = accessModifier.map { "\($0) struct" } ?? "struct"
    guard !groundings.isEmpty else {
      return
        """
        \(raw: structKeyword) DecodedGrounding: SwiftAgent.DecodedGrounding {}
        """
    }

    let cases = groundings.map { grounding -> String in
      "  case \(grounding.identifier.text)(\(grounding.typeName))"
    }
    .joined(separator: "\n")

    return
      """
      \(raw: enumKeyword) DecodedGrounding: SwiftAgent.DecodedGrounding {
      \(raw: cases)
      }
      """
  }

  // MARK: - Structured Output generation

  static func generateStructuredOutputsProperty(
    for outputs: [StructuredOutputProperty],
    accessModifier: String?,
  ) -> DeclSyntax {
    let staticKeyword = accessModifier.map { "\($0) static" } ?? "static"
    guard !outputs.isEmpty else {
      return """
      \(raw: staticKeyword) let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = []
      """
    }

    let entries = outputs
      .map { output in
        "    \(resolvableStructuredOutputTypeName(for: output)).self"
      }
      .joined(separator: "\n")

    return """
    \(raw: staticKeyword) let structuredOutputs: [any (SwiftAgent.DecodableStructuredOutput<ProviderType>).Type] = [
    \(raw: entries)
    ]
    """
  }

  static func generateDecodedStructuredOutputEnum(
    for outputs: [StructuredOutputProperty],
    accessModifier: String?,
  ) -> DeclSyntax {
    let enumKeyword = accessModifier.map { "\($0) enum" } ?? "enum"
    let staticFunctionKeyword = accessModifier.map { "\($0) static func" } ?? "static func"
    var sections: [String] = []

    if !outputs.isEmpty {
      let cases = outputs
        .map { output in
          let caseName = output.identifier.text
          let resolvableTypeName = resolvableStructuredOutputTypeName(for: output)
          return "  case \(caseName)(SwiftAgent.StructuredOutputUpdate<\(resolvableTypeName)>)"
        }
        .joined(separator: "\n")
      sections.append(cases)
    }

    sections.append("  case unknown(SwiftAgent.Transcript.StructuredSegment)")
    sections.append("")
    sections
      .append("  \(staticFunctionKeyword) makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {")
    sections.append("      .unknown(segment)")
    sections.append("  }")

    let body = sections.joined(separator: "\n")

    return """
    \(raw: enumKeyword) DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput {
    \(raw: body)
    }
    """
  }

  static func generateDecodableStructuredOutputTypes(
    for outputs: [StructuredOutputProperty],
    accessModifier: String?,
  ) -> [DeclSyntax] {
    let structKeyword = accessModifier.map { "\($0) struct" } ?? "struct"
    let staticFunctionKeyword = accessModifier.map { "\($0) static func" } ?? "static func"
    let typealiasKeyword = accessModifier.map { "\($0) typealias" } ?? "typealias"
    return outputs.map { output -> DeclSyntax in
      let resolvableName = resolvableStructuredOutputTypeName(for: output)
      let schemaType = output.typeName
      let caseName = output.identifier.text
      let typeDeclaration = "\(structKeyword) \(resolvableName)"

      return """
      \(raw: typeDeclaration): SwiftAgent.DecodableStructuredOutput {
        \(raw: typealiasKeyword) Base = \(raw: schemaType)
        \(raw: typealiasKeyword) Provider = ProviderType

        \(raw: staticFunctionKeyword) decode(
          _ structuredOutput: SwiftAgent.StructuredOutputUpdate<\(raw: resolvableName)>
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

  static func decodableWrapperName(for tool: ToolProperty) -> String {
    "Decodable\(tool.typeName)"
  }
}
