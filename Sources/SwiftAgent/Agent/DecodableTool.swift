// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol DecodableTool<Provider>: SwiftAgentTool where BaseTool.Arguments: Generable,
  BaseTool.Output: Generable {
  associatedtype BaseTool: FoundationModels.Tool
  associatedtype Provider: LanguageModelProvider
  func decode(_ run: ToolRun<BaseTool>) -> Provider.DecodedToolRun
}

package extension DecodableTool {
  /// Decodes a tool with raw GeneratedContent arguments and output.
  ///
  /// This is the internal bridge method that converts between Apple's FoundationModels
  /// content representation and SwiftAgent's strongly typed tool system.
  ///
  /// - Parameters:
  ///   - arguments: The raw arguments from the AI model
  ///   - output: The raw output content, if available
  /// - Returns: The decoded tool result
  /// - Throws: Conversion or resolution errors
  func decodeCompleted(
    id: String,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> Provider.DecodedToolRun {
    let arguments = try BaseTool.Arguments(rawArguments)
    let toolRun = try toolRun(
      id: id,
      arguments: .final(arguments),
      rawArguments: rawArguments,
      rawOutput: rawOutput,
    )
    return decode(toolRun)
  }

  func decodePartial(
    id: String,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> Provider.DecodedToolRun {
    let arguments = try BaseTool.Arguments.PartiallyGenerated(rawArguments)
    let toolRun = try toolRun(
      id: id,
      arguments: .partial(arguments),
      rawArguments: rawArguments,
      rawOutput: rawOutput,
    )
    return decode(toolRun)
  }

  func decodeFailed(
    id: String,
    error: TranscriptDecodingError.ToolRunResolution,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> Provider.DecodedToolRun {
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
  /// Creates a strongly typed tool run from raw content.
  ///
  /// - Parameters:
  ///   - arguments: Raw argument content from the AI model
  ///   - output: Optional raw output content
  /// - Returns: A typed ToolRun instance
  /// - Throws: Conversion errors if content cannot be parsed
  func toolRun(
    id: String,
    arguments: ToolRun<BaseTool>.ArgumentsPhase,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent?,
  ) throws -> ToolRun<BaseTool> {
    guard let rawOutput else {
      return ToolRun(
        id: id,
        arguments: arguments,
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    }

    do {
      return try ToolRun(
        id: id,
        arguments: arguments,
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
        arguments: arguments,
        problem: problem,
        rawArguments: rawArguments,
        rawOutput: rawOutput,
      )
    }
  }

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
