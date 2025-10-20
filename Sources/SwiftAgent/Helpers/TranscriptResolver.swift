// By Dennis Müller

import Foundation
import FoundationModels
import OSLog

/// Resolves raw transcript entries into your app's domain types.
///
/// This utility reads a ``Transcript`` and produces the `SessionSchema.Transcript`
/// by resolving tool runs, structured outputs, and groundings using the
/// automatically generated `decodableTools` and `structuredOutputs` from your
/// `@LanguageModelProvider` session.
///
/// - Note: You typically create this via `session.resolver()`; the macro wires
///   up everything needed. You rarely construct it manually.
public struct TranscriptResolver<SessionSchema: LanguageModelSessionSchema> {
  /// The tool call type from the associated transcript.
  public typealias ToolCall = Transcript.ToolCall

  /// Dictionary mapping tool names to their implementations for fast lookup.
  private let toolsByName: [String: any DecodableTool<SessionSchema.DecodedToolRun>]

  /// The provider that is used to resolve the transcript.
  private let provider: SessionSchema

  /// Creates a new resolver for the given provider instance.
  ///
  /// - Parameter provider: The session whose tools and structured outputs are used
  ///   to resolve transcript entries.
  public init(for provider: SessionSchema) {
    self.provider = provider
    toolsByName = Dictionary(uniqueKeysWithValues: provider.decodableTools.map { ($0.name, $0) })
  }

  /// Resolves a full transcript into the provider's resolved representation.
  ///
  /// This walks the transcript in order and resolves prompts, responses,
  /// tool calls and outputs, and structured segments.
  public func resolve(_ transcript: Transcript) throws -> SessionSchema.Transcript {
    var resolvedTranscript = SessionSchema.Transcript()

    for (index, entry) in transcript.entries.enumerated() {
      switch entry {
      case let .prompt(prompt):
        var resolvedSources: [SessionSchema.DecodedGrounding] = []
        var errorContext: TranscriptResolvingError.PromptResolution?

        do {
          resolvedSources = try resolveGroundings(from: prompt.sources)
        } catch {
          errorContext = .groundingResolutionFailed(description: error.localizedDescription)
        }

        resolvedTranscript.append(.prompt(SessionSchema.Transcript.Prompt(
          id: prompt.id,
          input: prompt.input,
          sources: resolvedSources,
          prompt: prompt.prompt,
          error: errorContext,
        )))
      case let .reasoning(reasoning):
        resolvedTranscript.append(.reasoning(SessionSchema.Transcript.Reasoning(
          id: reasoning.id,
          summary: reasoning.summary,
        )))
      case let .response(response):
        var segments: [SessionSchema.Transcript.Segment] = []

        for segment in response.segments {
          switch segment {
          case let .text(text):
            segments.append(.text(SessionSchema.Transcript.TextSegment(
              id: text.id,
              content: text.content,
            )))
          case let .structure(structure):
            let content = resolve(structure, status: response.status)
            segments.append(.structure(SessionSchema.Transcript.StructuredSegment(
              id: structure.id,
              typeName: structure.typeName,
              content: content,
            )))
          }
        }

        resolvedTranscript.append(.response(SessionSchema.Transcript.Response(
          id: response.id,
          segments: segments,
          status: response.status,
        )))
      case let .toolCalls(toolCalls):
        for call in toolCalls {
          let rawOutput = findOutput(for: call, startingAt: index + 1, in: transcript.entries)
          let resolvedToolRun = resolve(call, rawOutput: rawOutput)
          resolvedTranscript.append(.toolRun(resolvedToolRun))
        }
      case .toolOutput:
        // Handled already by the .toolCalls cases
        break
      }
    }

    return resolvedTranscript
  }

  /// Resolves a single tool call (optionally with its raw output) into your app's type.
  ///
  /// - Parameters:
  ///   - call: The tool call entry to resolve
  ///   - rawOutput: The raw generated content produced by the tool, if found
  /// - Returns: A resolved tool run. Unknown tools are mapped to `Provider.DecodedToolRun.makeUnknown`.
  public func resolve(_ call: ToolCall, rawOutput: GeneratedContent?) -> SessionSchema.DecodedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let error = TranscriptResolvingError.ToolRunResolution.unknownTool(name: call.toolName)
      AgentLog.error(error, context: "Tool resolution failed")
      return SessionSchema.DecodedToolRun.makeUnknown(toolCall: call)
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
      return SessionSchema.DecodedToolRun.makeUnknown(toolCall: call)
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

  /// Resolves a structured segment into the provider's `DecodedStructuredOutput` type.
  public func resolve(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
  ) -> SessionSchema.DecodedStructuredOutput {
    let structuredOutputs = SessionSchema.structuredOutputs()

    guard let structuredOutput = structuredOutputs.first(where: { $0.name == structuredSegment.typeName }) else {
      return SessionSchema.DecodedStructuredOutput.makeUnknown(segment: structuredSegment)
    }

    return resolve(structuredSegment, status: status, with: structuredOutput)
  }

  /// Resolves a structured segment using a specific decodable structured output type.
  private func resolve<DecodableType: DecodableStructuredOutput>(
    _ structuredSegment: Transcript.StructuredSegment,
    status: Transcript.Status,
    with resolvableType: DecodableType.Type,
  ) -> SessionSchema.DecodedStructuredOutput
    where DecodableType.DecodedStructuredOutput == SessionSchema.DecodedStructuredOutput {
    var contentPhase: StructuredOutputSnapshot<DecodableType.Base>.ContentPhase?
    var structuredOutputSnapshot: StructuredOutputSnapshot<DecodableType.Base>

    do {
      switch status {
      case .completed:
        contentPhase = try .final(resolvableType.Base.Schema(structuredSegment.content))
      case .inProgress:
        contentPhase = try .partial(resolvableType.Base.Schema.PartiallyGenerated(structuredSegment.content))
      default:
        contentPhase = nil
      }
    } catch {
      contentPhase = nil
    }

    if let contentPhase {
      structuredOutputSnapshot = StructuredOutputSnapshot<DecodableType.Base>(
        id: structuredSegment.id,
        contentPhase: contentPhase,
        rawContent: structuredSegment.content,
      )
    } else {
      structuredOutputSnapshot = StructuredOutputSnapshot<DecodableType.Base>(
        id: structuredSegment.id,
        error: structuredSegment.content,
        rawContent: structuredSegment.content,
      )
    }

    return DecodableType.decode(structuredOutputSnapshot)
  }

  // MARK: Groundings

  /// Resolves grounding data previously encoded via `LanguageModelProvider.encodeGrounding`.
  public func resolveGroundings(from data: Data) throws -> [SessionSchema.DecodedGrounding] {
    try JSONDecoder().decode([SessionSchema.DecodedGrounding].self, from: data)
  }
}
