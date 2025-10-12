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

  /// The provider that is used to decode the transcript.
  private let provider: Provider

  /// Creates a new tool decoder for the given tools and transcript.
  ///
  /// - Parameters:
  ///   - tools: The tools that can be decoded, all sharing the same `Resolution` type
  ///   - transcript: The conversation transcript containing tool calls and outputs
  public init(for provider: Provider) {
    self.provider = provider
    toolsByName = Dictionary(uniqueKeysWithValues: provider.decodableTools.map { ($0.name, $0) })
  }

  public func decode(_ transcript: Transcript) throws -> Provider.DecodedTranscript {
    var decodedTranscript = Provider.DecodedTranscript()

    for (index, entry) in transcript.entries.enumerated() {
      switch entry {
      case let .prompt(prompt):
        var decodedSources: [Provider.DecodedGrounding] = []
        var errorContext: TranscriptDecodingError.PromptResolution?

        do {
          decodedSources = try decodeGrounding(from: prompt.sources)
        } catch {
          errorContext = .groundingDecodingFailed(description: error.localizedDescription)
        }

        decodedTranscript.append(.prompt(Provider.DecodedTranscript.Prompt(
          id: prompt.id,
          input: prompt.input,
          sources: decodedSources,
          prompt: prompt.prompt,
          error: errorContext,
        )))
      case let .reasoning(reasoning):
        decodedTranscript.append(.reasoning(Provider.DecodedTranscript.Reasoning(
          id: reasoning.id,
          summary: reasoning.summary,
        )))
      case let .response(response):
        var segments: [Provider.DecodedTranscript.Segment] = []

        for segment in response.segments {
          switch segment {
          case let .text(text):
            segments.append(.text(Provider.DecodedTranscript.TextSegment(
              id: text.id,
              content: text.content,
            )))
          case let .structure(structure):
            let content = decode(structure, status: response.status)
            segments.append(.structure(Provider.DecodedTranscript.StructuredSegment(
              id: structure.id,
              typeName: structure.typeName,
              content: content,
            )))
          }
        }

        decodedTranscript.append(.response(Provider.DecodedTranscript.Response(
          id: response.id,
          segments: segments,
          status: response.status,
        )))
      case let .toolCalls(toolCalls):
        for call in toolCalls {
          let rawOutput = findOutput(for: call, startingAt: index + 1, in: transcript.entries)
          let decodedToolRun = decode(call, rawOutput: rawOutput)
          decodedTranscript.append(.toolRun(decodedToolRun))
        }
      case .toolOutput:
        // Handled already by the .toolCalls cases
        break
      }
    }

    return decodedTranscript
  }

  public func decode(_ call: ToolCall, rawOutput: GeneratedContent?) -> Provider.DecodedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
      let error = TranscriptDecodingError.ToolRunResolution.unknownTool(name: call.toolName)
      AgentLog.error(
        error,
        context: "Tool resolution failed. Available tools: \(availableTools)",
      )
      return Provider.DecodedToolRun.makeUnknown(toolCall: call)
    }

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

  /// Finds the tool output for a given tool call by searching forward from the current index.
  /// Tool outputs typically appear shortly after their corresponding tool calls in the transcript.
  ///
  /// - Parameters:
  ///   - call: The tool call to find output for
  ///   - startIndex: The index to start searching from (typically the index after the tool call entry)
  ///   - entries: The transcript entries to search through
  /// - Returns: The generated content from the tool output, or nil if not found
  private func findOutput(
    for call: ToolCall,
    startingAt startIndex: Int,
    in entries: [Transcript.Entry],
  ) -> GeneratedContent? {
    // Search forward from the current position for the matching tool output
    // Tool outputs are typically close to their calls, so this is efficient
    for index in startIndex..<entries.count {
      if case let .toolOutput(toolOutput) = entries[index],
         toolOutput.callId == call.callId {
        switch toolOutput.segment {
        case let .text(text):
          return GeneratedContent(text.content)
        case let .structure(structure):
          return structure.content
        }
      }
    }

    return nil
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
    var decodedContent: DecodedGeneratedContent<DecodableType>.State

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

    let structuredOutput = DecodedGeneratedContent<DecodableType>(
      id: structuredSegment.id,
      state: decodedContent,
      raw: structuredSegment.content,
    )

    return DecodableType.decode(structuredOutput)
  }

  // MARK: Groundings

  public func decodeGrounding(from data: Data) throws -> [Provider.DecodedGrounding] {
    try JSONDecoder().decode([Provider.DecodedGrounding].self, from: data)
  }
}
