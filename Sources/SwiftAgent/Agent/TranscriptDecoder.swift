// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

public struct TranscriptDecoder<Provider: LanguageModelProvider> {
  /// The tool call type from the associated transcript.
  public typealias ToolCall = Transcript.ToolCall

  /// Dictionary mapping tool names to their implementations for fast lookup.
  private let toolsByName: [String: any DecodableTool<Provider>]

  /// All tool outputs extracted from the conversation transcript.
  private let transcriptToolOutputs: [Transcript.ToolOutput]

  /// Creates a new tool decoder for the given tools and transcript.
  ///
  /// - Parameters:
  ///   - tools: The tools that can be decoded, all sharing the same `Resolution` type
  ///   - transcript: The conversation transcript containing tool calls and outputs
  init(for provider: Provider, transcript: Transcript) {
    toolsByName = Dictionary(uniqueKeysWithValues: provider.tools.map { ($0.name, $0) })
    transcriptToolOutputs = transcript.compactMap { entry in
      switch entry {
      case let .toolOutput(toolOutput):
        toolOutput
      default:
        nil
      }
    }
  }

  public func decode(_ call: ToolCall) -> Provider.DecodedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
      let error = TranscriptDecodingError.ToolRunResolution.unknownTool(name: call.toolName)
      AgentLog.error(
        error,
        context: "Tool resolution failed. Available tools: \(availableTools)",
      )
      return Provider.DecodedToolRun.makeUnknown(toolCall: call)
    }

    let rawOutput = findOutput(for: call)

    do {
      switch call.status {
      case .inProgress:
        return try tool.decodeInProgress(id: call.id, rawContent: call.arguments, rawOutput: rawOutput)
      case .completed:
        return try tool.decodeCompleted(id: call.id, rawContent: call.arguments, rawOutput: rawOutput)
      default:
        return Provider.DecodedToolRun.makeUnknown(toolCall: call)
      }
    } catch {
      AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
      return Provider.DecodedToolRun.makeUnknown(toolCall: call)
    }
  }

  private func findOutput(for call: ToolCall) -> GeneratedContent? {
    guard let toolOutput = transcriptToolOutputs.first(where: { $0.callId == call.callId }) else {
      return nil
    }

    switch toolOutput.segment {
    case let .text(text):
      return GeneratedContent(text.content)
    case let .structure(structure):
      return structure.content
    }
  }

  // MARK: - Structured Outputs

  public func decode(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
  ) -> Provider.DecodedStructuredOutput {
    let structuredOutputs = Provider.structuredOutputs

    guard let structuredOutput = structuredOutputs.first(where: { $0.name == structuredSegment.typeName }) else {
      return Provider.DecodedStructuredOutput.makeUnknown(segment: structuredSegment)
    }

    return decode(structuredSegment, status: status, with: structuredOutput)
  }

  private func decode<DecodableType: DecodableStructuredOutput>(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
    with resolvableType: DecodableType.Type,
  ) -> Provider.DecodedStructuredOutput where DecodableType.Provider == Provider {
    var decodedContent: ContentGeneration<DecodableType>.State

    do {
      switch status {
      case .completed:
        decodedContent = try .completed(resolvableType.Base.Schema(structuredSegment.content))
      case .inProgress:
        decodedContent = try .inProgress(resolvableType.Base.Schema.PartiallyGenerated(structuredSegment.content))
      default:
        decodedContent = .failed(structuredSegment.content)
      }
    } catch {
      decodedContent = .failed(structuredSegment.content)
    }

    let structuredOutput = ContentGeneration<DecodableType>(
      id: structuredSegment.id,
      state: decodedContent,
      raw: structuredSegment.content,
    )

    return DecodableType.decode(structuredOutput)
  }
}
