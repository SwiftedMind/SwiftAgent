// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

public struct TranscriptResolver<Provider: LanguageModelProvider> {
  /// The tool call type from the associated transcript.
  public typealias ToolCall = Transcript.ToolCall

  /// Dictionary mapping tool names to their implementations for fast lookup.
  private let toolsByName: [String: any ResolvableTool<Provider>]

  /// All tool outputs extracted from the conversation transcript.
  private let transcriptToolOutputs: [Transcript.ToolOutput]

  /// Creates a new tool resolver for the given tools and transcript.
  ///
  /// - Parameters:
  ///   - tools: The tools that can be resolved, all sharing the same `Resolution` type
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

  public func resolve(_ call: ToolCall) -> Provider.ResolvedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
      let error = TranscriptResolutionError.ToolRunResolution.unknownTool(name: call.toolName)
      AgentLog.error(
        error,
        context: "Tool resolution failed. Available tools: \(availableTools)",
      )
      return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
    }

    let rawOutput = findOutput(for: call)

    do {
      switch call.status {
      case .inProgress:
        return try tool.resolveInProgress(id: call.id, rawContent: call.arguments, rawOutput: rawOutput)
      case .completed:
        return try tool.resolveCompleted(id: call.id, rawContent: call.arguments, rawOutput: rawOutput)
      default:
        return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
      }
    } catch {
      AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
      return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
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

  public func resolve(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
  ) -> Provider.ResolvedStructuredOutput {
    let structuredOutputs = Provider.structuredOutputs

    guard let structuredOutput = structuredOutputs.first(where: { $0.name == structuredSegment.typeName }) else {
      return Provider.ResolvedStructuredOutput.makeUnknown(segment: structuredSegment)
    }

    return resolve(structuredSegment, status: status, with: structuredOutput)
  }

  private func resolve<ResolvableType: ResolvableStructuredOutput>(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
    with resolvableType: ResolvableType.Type,
  ) -> Provider.ResolvedStructuredOutput where ResolvableType.Provider == Provider {
    var resolvedContent: ContentGeneration<ResolvableType>.State

    do {
      switch status {
      case .completed:
        resolvedContent = try .completed(resolvableType.Base.Schema(structuredSegment.content))
      case .inProgress:
        resolvedContent = try .inProgress(resolvableType.Base.Schema.PartiallyGenerated(structuredSegment.content))
      default:
        resolvedContent = .failed(structuredSegment.content)
      }
    } catch {
      resolvedContent = .failed(structuredSegment.content)
    }

    let structuredOutput = ContentGeneration<ResolvableType>(
      id: structuredSegment.id,
      state: resolvedContent,
      raw: structuredSegment.content,
    )

    return ResolvableType.resolve(structuredOutput)
  }
}
