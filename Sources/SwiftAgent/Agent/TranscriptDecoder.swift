// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

/// Decodes raw transcript entries into your app's domain types.
///
/// This utility reads a ``Transcript`` and produces the `Provider.DecodedTranscript`
/// by resolving tool runs, structured outputs, and groundings using the
/// automatically generated `decodableTools` and `structuredOutputs` from your
/// `@LanguageModelProvider` session.
///
/// - Note: You typically create this via `session.decoder()`; the macro wires
///   up everything needed. You rarely construct it manually.
public struct TranscriptDecoder<Provider: LanguageModelProvider> {
  /// The tool call type from the associated transcript.
  public typealias ToolCall = Transcript.ToolCall

  /// Dictionary mapping tool names to their implementations for fast lookup.
  private let toolsByName: [String: any DecodableTool<Provider>]

  /// The provider that is used to decode the transcript.
  private let provider: Provider

  /// Creates a new decoder for the given provider instance.
  ///
  /// - Parameter provider: The session whose tools and structured outputs are used
  ///   to resolve transcript entries.
  public init(for provider: Provider) {
    self.provider = provider
    toolsByName = Dictionary(uniqueKeysWithValues: provider.decodableTools.map { ($0.name, $0) })
  }

  /// Decodes a full transcript into the provider's decoded representation.
  ///
  /// This walks the transcript in order and resolves prompts, responses,
  /// tool calls and outputs, and structured segments.
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

  /// Decodes a single tool call (optionally with its raw output) into your app's type.
  ///
  /// - Parameters:
  ///   - call: The tool call entry to resolve
  ///   - rawOutput: The raw generated content produced by the tool, if found
  /// - Returns: A decoded tool run. Unknown tools are mapped to `Provider.DecodedToolRun.makeUnknown`.
  public func decode(_ call: ToolCall, rawOutput: GeneratedContent?) -> Provider.DecodedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let error = TranscriptDecodingError.ToolRunResolution.unknownTool(name: call.toolName)
      AgentLog.error(error, context: "Tool resolution failed")
      return Provider.DecodedToolRun.makeUnknown(toolCall: call)
    }

    do {
      switch call.status {
      case .inProgress:
        return try tool.decodePartial(id: call.id, rawArguments: call.arguments, rawOutput: rawOutput)
      case .completed:
        return try tool.decodeCompleted(id: call.id, rawArguments: call.arguments, rawOutput: rawOutput)
      default:
        return try tool.decodeFailed(
          id: call.id,
          error: .resolutionFailed(description: "Tool run failed"),
          rawArguments: call.arguments,
          rawOutput: rawOutput,
        )
      }
    } catch {
      AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
      return Provider.DecodedToolRun.makeUnknown(toolCall: call)
    }
  }

  /// Finds the matching tool output for a given call by scanning forward.
  ///
  /// Tool outputs usually appear immediately after their calls.
  /// - Returns: The generated content from the tool output, or `nil` if not found.
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

  /// Decodes a structured segment into the provider's `DecodedStructuredOutput` type.
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

  /// Decodes a structured segment using a specific decodable structured output type.
  private func decode<DecodableType: DecodableStructuredOutput>(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
    with resolvableType: DecodableType.Type,
  ) -> Provider.DecodedStructuredOutput where DecodableType.Provider == Provider {
    var content: StructuredOutputUpdate<DecodableType.Base>.Content?
    var structuredOutput: StructuredOutputUpdate<DecodableType.Base>

    do {
      switch status {
      case .completed:
        content = try .final(resolvableType.Base.Schema(structuredSegment.content))
      case .inProgress:
        content = try .partial(resolvableType.Base.Schema.PartiallyGenerated(structuredSegment.content))
      default:
        content = nil
      }
    } catch {
      content = nil
    }

    if let content {
      structuredOutput = StructuredOutputUpdate<DecodableType.Base>(
        id: structuredSegment.id,
        content: content,
        rawContent: structuredSegment.content,
      )
    } else {
      structuredOutput = StructuredOutputUpdate<DecodableType.Base>(
        id: structuredSegment.id,
        error: structuredSegment.content,
        rawContent: structuredSegment.content,
      )
    }

    return DecodableType.decode(structuredOutput)
  }

  // MARK: Groundings

  /// Decodes grounding data previously encoded via `LanguageModelProvider.encodeGrounding`.
  public func decodeGrounding(from data: Data) throws -> [Provider.DecodedGrounding] {
    try JSONDecoder().decode([Provider.DecodedGrounding].self, from: data)
  }
}
