// By Dennis Müller

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

extension SessionSchemaMacro {
  // MARK: - Initializers

  static func generateInitializers(
    for tools: [ToolProperty],
    accessModifier: String,
  ) -> [DeclSyntax] {
    let toolsWithoutDefaults = tools.filter { !$0.hasInitializer }

    let parameterLines = toolsWithoutDefaults
      .map { "  \($0.identifier.text): \($0.typeName)" }
      .joined(separator: ",\n")

    let signature = if parameterLines.isEmpty {
      "\(accessModifier) init()"
    } else {
      """
      \(accessModifier) init(
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

  static func generateDecodedToolRunEnum(
    for tools: [ToolProperty],
    accessModifier: String,
  ) -> DeclSyntax {
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

    let makeUnknownDeclaration =
      "  " + accessModifier + " static func makeUnknown(toolCall: SwiftAgent.Transcript.ToolCall) -> Self {"
    let idPropertyDeclaration = "  " + accessModifier + " var id: String {"

    let enumBodyComponents: [String] = [
      cases,
      "  case unknown(toolCall: SwiftAgent.Transcript.ToolCall)",
      "",
      makeUnknownDeclaration,
      "    .unknown(toolCall: toolCall)",
      "  }",
      "",
      idPropertyDeclaration,
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

    let declaration =
      accessModifier + " enum DecodedToolRun: SwiftAgent.DecodedToolRun, @unchecked Sendable {"

    return
      """
      \(raw: declaration)
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

  static func generateDecodedGroundingType(
    for groundings: [GroundingProperty],
    accessModifier: String,
  ) -> DeclSyntax {
    guard !groundings.isEmpty else {
      let declaration =
        accessModifier + " struct DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {}"

      return
        """
        \(raw: declaration)
        """
    }

    let cases = groundings
      .map { grounding in
        "  case \(grounding.identifier.text)(\(grounding.typeName))"
      }
      .joined(separator: "\n")

    let declaration =
      accessModifier + " enum DecodedGrounding: SwiftAgent.DecodedGrounding, @unchecked Sendable {"

    return
      """
      \(raw: declaration)
      \(raw: cases)
      }
      """
  }

  // MARK: - Structured Output

  static func generateStructuredOutputsType(
    for outputs: [StructuredOutputProperty],
    accessModifier: String,
  ) -> DeclSyntax {
    guard !outputs.isEmpty else {
      let declaration =
        accessModifier + " struct StructuredOutputs: @unchecked Sendable {}"

      return
        """
        \(raw: declaration)
        """
    }

    let properties = outputs
      .map { output in
        "  let \(output.identifier.text) = \(output.typeName).self"
      }
      .joined(separator: "\n")

    let declaration =
      accessModifier + " struct StructuredOutputs: @unchecked Sendable {"

    return
      """
      \(raw: declaration)
      \(raw: properties)
      }
      """
  }

  static func generateStructuredOutputsFunction(
    for outputs: [StructuredOutputProperty],
    accessModifier: String,
  ) -> DeclSyntax {
    let signature =
      accessModifier
        + " static func structuredOutputs() -> [any (SwiftAgent.DecodableStructuredOutput<DecodedStructuredOutput>).Type]"

    guard !outputs.isEmpty else {
      return
        """
        \(raw: signature) {
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
      \(raw: signature) {
        [
      \(raw: entries)
        ]
      }
      """
  }

  static func generateDecodedStructuredOutputEnum(
    for outputs: [StructuredOutputProperty],
    accessModifier: String,
  ) -> DeclSyntax {
    var sections: [String] = []

    if !outputs.isEmpty {
      let cases = outputs
        .map { output in
          let caseName = output.identifier.text
          return "  case \(caseName)(SwiftAgent.StructuredOutputSnapshot<\(output.typeName)>)"
        }
        .joined(separator: "\n")
      sections.append(cases)
    }

    sections.append("  case unknown(SwiftAgent.Transcript.StructuredSegment)")
    sections.append("")
    let makeUnknownDeclaration =
      "  " + accessModifier + " static func makeUnknown(segment: SwiftAgent.Transcript.StructuredSegment) -> Self {"
    sections.append(makeUnknownDeclaration)
    sections.append("    .unknown(segment)")
    sections.append("  }")

    let body = sections.joined(separator: "\n")

    let declaration =
      accessModifier + " enum DecodedStructuredOutput: SwiftAgent.DecodedStructuredOutput, @unchecked Sendable {"

    return
      """
      \(raw: declaration)
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
            _ structuredOutput: SwiftAgent.StructuredOutputSnapshot<\(raw: output.typeName)>
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
