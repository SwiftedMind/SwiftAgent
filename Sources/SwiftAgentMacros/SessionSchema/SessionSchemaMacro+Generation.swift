// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SessionSchemaMacro {
  // MARK: - Initializers

  static func generateInitializers(for tools: [ToolProperty]) -> [DeclSyntax] {
    let toolsWithoutDefaults = tools.filter { !$0.hasInitializer }

    let parameterLines = toolsWithoutDefaults
      .map { "  \($0.identifier.text): \($0.typeName)" }
      .joined(separator: ",\n")

    let signature = if parameterLines.isEmpty {
      "init()"
    } else {
      """
      init(
      \(parameterLines)
      )
      """
    }

    let wrapperAssignments = toolsWithoutDefaults
      .map { "  _\($0.identifier.text) = Tool(wrappedValue: \($0.identifier.text))" }
      .joined(separator: "\n")

    let decodableEntries = tools
      .map { tool -> String in
        let wrapperName = decodableWrapperName(for: tool)
        return "    \(wrapperName)(baseTool: _\(tool.identifier.text).wrappedValue)"
      }
      .joined(separator: ",\n")

    let decodableLiteral = if tools.isEmpty {
      "[]"
    } else {
      "[\n\(decodableEntries)\n  ]"
    }

    let initializerBodySections = [
      wrapperAssignments,
      "  decodableTools = \(decodableLiteral)",
    ]
    .filter { !$0.isEmpty }
    .joined(separator: "\n\n")

    let initializer: DeclSyntax =
      """
      \(raw: signature) {
      \(raw: initializerBodySections.isEmpty ? "  decodableTools = []" : initializerBodySections)
      }
      """

    return [initializer]
  }

  // MARK: - Tool decoding

  static func generateDecodedToolRunEnum(for tools: [ToolProperty]) -> DeclSyntax {
    let cases = tools
      .map { tool in
        "  case \(tool.identifier.text)(ToolRun<\(tool.typeName)>)"
      }
      .joined(separator: "\n")

    let idSwitchCases = tools
      .map { tool in
        "    case let .\(tool.identifier.text)(run):\n      run.id"
      }
      .joined(separator: "\n")

    let enumBodyComponents: [String] = [
      cases,
      "  case unknown(toolCall: SwiftAgent.Transcript.ToolCall)",
      "",
      "  static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {",
      "    .unknown(toolCall: toolCall)",
      "  }",
      "",
      "  var id: String {",
      "    switch self {",
      idSwitchCases,
      "    case let .unknown(toolCall):",
      "      toolCall.id",
      "    }",
      "  }",
    ]

    let body = enumBodyComponents
      .filter { !$0.isEmpty }
      .joined(separator: "\n")

    return
      """
      enum DecodedToolRun: SwiftAgent.DecodedToolRun, @unchecked Sendable {
      \(raw: body)
      }
      """
  }

  static func generateDecodableWrapper(for tool: ToolProperty) -> DeclSyntax {
    let wrapperName = decodableWrapperName(for: tool)

    return
      """
      private struct \(raw: wrapperName): DecodableTool {
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
          _ run: ToolRun<\(raw: tool.typeName)>
        ) -> DecodedToolRun {
          .\(raw: tool.identifier.text)(run)
        }
      }
      """
  }

  // MARK: - Grounding

  static func generateDecodedGroundingType(for groundings: [GroundingProperty]) -> DeclSyntax {
    guard !groundings.isEmpty else {
      return
        """
        struct DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {}
        """
    }

    let cases = groundings
      .map { grounding in
        "  case \(grounding.identifier.text)(\(grounding.typeName))"
      }
      .joined(separator: "\n")

    return
      """
      enum DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {
      \(raw: cases)
      }
      """
  }

  // MARK: - Structured Output

  static func generateStructuredOutputsType(
    for outputs: [StructuredOutputProperty],
  ) -> DeclSyntax {
    guard !outputs.isEmpty else {
      return
        """
        struct StructuredOutputs: @unchecked Sendable {}
        """
    }

    let properties = outputs
      .map { output in
        "  let \(output.identifier.text) = \(output.typeName).self"
      }
      .joined(separator: "\n")

    return
      """
      struct StructuredOutputs: @unchecked Sendable {
      \(raw: properties)
      }
      """
  }

  static func generateStructuredOutputsFunction(for outputs: [StructuredOutputProperty]) -> DeclSyntax {
    guard !outputs.isEmpty else {
      return
        """
        static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
          []
        }
        """
    }

    let entries = outputs
      .map { output in
        "      \(resolvableStructuredOutputTypeName(for: output)).self"
      }
      .joined(separator: ",\n")

    return
      """
      static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type] {
        [
      \(raw: entries)
        ]
      }
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
          return "  case \(caseName)(SwiftAgent.StructuredOutputUpdate<\(output.typeName)>)"
        }
        .joined(separator: "\n")
      sections.append(cases)
    }

    sections.append("  case unknown(SwiftAgent.Transcript.StructuredSegment)")
    sections.append("")
    sections.append("  static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {")
    sections.append("    .unknown(segment)")
    sections.append("  }")

    let body = sections.joined(separator: "\n")

    return
      """
      enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput, @unchecked Sendable {
      \(raw: body)
      }
      """
  }

  static func generateDecodableStructuredOutputTypes(
    for outputs: [StructuredOutputProperty],
  ) -> [DeclSyntax] {
    outputs.map { output -> DeclSyntax in
      let resolvableName = resolvableStructuredOutputTypeName(for: output)
      let schemaType = output.typeName
      let caseName = output.identifier.text

      return
        """
        private struct \(raw: resolvableName): SwiftAgent.DecodableStructuredOutput, @unchecked Sendable {
          typealias Base = \(raw: schemaType)

          static func decode(
            _ structuredOutput: SwiftAgent.StructuredOutputUpdate<\(raw: output.typeName)>
          ) -> DecodedStructuredOutput {
            .\(raw: caseName)(structuredOutput)
          }
        }
        """
    }
  }

  static func resolvableStructuredOutputTypeName(for output: StructuredOutputProperty) -> String {
    "Decodable\(output.typeName)"
  }

  static func decodableWrapperName(for tool: ToolProperty) -> String {
    "Decodable\(tool.typeName)"
  }
}
