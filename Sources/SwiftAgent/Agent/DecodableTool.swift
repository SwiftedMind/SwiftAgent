// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A helper protocol that turns a `Tool` into a decodable form for transcripts.
///
/// - Note: You do not conform to this directly in typical apps. The
///   `@LanguageModelProvider` macro synthesizes these wrappers from your
///   `@Tool` properties so that tool calls in a transcript can be resolved.
public protocol DecodableTool<DecodedToolRun>: SwiftAgentTool where BaseTool.Arguments: Generable,
  BaseTool.Output: Generable {
  associatedtype BaseTool: FoundationModels.Tool
  associatedtype DecodedToolRun: SwiftAgent.DecodedToolRun
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
  /// Builds a typed `ToolRun` value from raw arguments and optional output/problem.
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
      guard let problem = problem(from: rawOutput) else {
        throw error
      }

      return ToolRun(
        id: id,
        argumentsPhase: argumentsPhase,
        problem: problem,
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    }
  }

  /// Extracts a structured problem description from generated content (if present).
  func problem(from generatedContent: GeneratedContent) -> ToolRun<BaseTool>.Problem? {
    guard
      let problemReport = try? ProblemReport(generatedContent),
      problemReport.error else {
      return nil
    }

    return ToolRun<BaseTool>.Problem(
      reason: problemReport.reason,
      json: generatedContent.jsonString,
      details: ProblemReportDetailsExtractor.values(from: generatedContent),
    )
  }
}
