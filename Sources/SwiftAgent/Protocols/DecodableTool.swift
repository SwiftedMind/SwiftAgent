// By Dennis Müller

import Foundation
import FoundationModels

/// Describes how a tool run is decoded into schema-backed values.
///
/// ``SessionSchema`` macros synthesize conformances for every `@Tool` property you declare. Those
/// generated types turn streaming `ToolRun<BaseTool>` snapshots into concrete `DecodedToolRun`
/// objects that feed decoded transcripts, UI views, and analytics.
public protocol DecodableTool<DecodedToolRun>: SwiftAgentTool where BaseTool.Arguments: Generable,
  BaseTool.Output: Generable {
  /// The tool implementation being decoded.
  associatedtype BaseTool: FoundationModels.Tool
  /// Schema-specific projection used in decoded transcripts and snapshots.
  associatedtype DecodedToolRun: SwiftAgent.DecodedToolRun
  /// Converts a typed `ToolRun` into the schema-defined decoded representation.
  func decode(_ run: ToolRun<BaseTool>) -> DecodedToolRun
}

package extension DecodableTool {
  /// Decodes a completed tool run from raw generated content.
  func decodeCompleted(
    id: String,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> DecodedToolRun {
    let arguments = try BaseTool.Arguments(rawArguments)
    let toolRun = try toolRun(
      id: id,
      argumentsPhase: .final(arguments),
      rawArguments: rawArguments,
      rawOutput: rawOutput,
    )
    return decode(toolRun)
  }

  /// Decodes an in‑progress tool run from raw generated content.
  func decodePartial(
    id: String,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> DecodedToolRun {
    let arguments = try BaseTool.Arguments.PartiallyGenerated(rawArguments)
    let toolRun = try toolRun(
      id: id,
      argumentsPhase: .partial(arguments),
      rawArguments: rawArguments,
      rawOutput: rawOutput,
    )
    return decode(toolRun)
  }

  /// Decodes a failed tool run with an associated resolution error.
  func decodeFailed(
    id: String,
    error: TranscriptDecodingError.ToolRunResolution,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> DecodedToolRun {
    let toolRun = ToolRun<BaseTool>(
      id: id,
      error: error,
      rawArguments: rawArguments,
      rawOutput: rawOutput,
    )
    return decode(toolRun)
  }
}

package extension DecodableTool {
  /// Builds a typed `ToolRun` value from raw arguments and optional output or rejection.
  func toolRun(
    id: String,
    argumentsPhase: ToolRun<BaseTool>.ArgumentsPhase,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> ToolRun<BaseTool> {
    guard let rawOutput else {
      return ToolRun(
        id: id,
        argumentsPhase: argumentsPhase,
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    }

    do {
      return try ToolRun(
        id: id,
        argumentsPhase: argumentsPhase,
        output: BaseTool.Output(rawOutput),
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    } catch {
      guard let rejection = rejection(from: rawOutput) else {
        throw error
      }

      return ToolRun(
        id: id,
        argumentsPhase: argumentsPhase,
        rejection: rejection,
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    }
  }

  /// Extracts a structured rejection description from generated content (if present).
  func rejection(from generatedContent: GeneratedContent) -> ToolRun<BaseTool>.Rejection? {
    guard
      let rejectionReport = try? RejectionReport(generatedContent),
      rejectionReport.error else {
      return nil
    }

    return ToolRun<BaseTool>.Rejection(
      reason: rejectionReport.reason,
      json: generatedContent.stableJsonString,
      details: RejectionReportDetailsExtractor.values(from: generatedContent),
    )
  }
}
