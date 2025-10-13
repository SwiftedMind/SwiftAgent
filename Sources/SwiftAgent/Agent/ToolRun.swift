// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct ToolRun<Tool: SwiftAgentTool>: Identifiable {
  private let rawContent: GeneratedContent
  private let rawOutput: GeneratedContent?

  public enum Arguments {
    case inProgress(Tool.Arguments.PartiallyGenerated)
    case completed(Tool.Arguments)
    case failed(TranscriptDecodingError.ToolRunResolution)
  }

  public var id: String

  public var arguments: Arguments

  /// The tool's output, if available.
  ///
  /// This will be `nil` when the tool run has not yet produced a result, or when
  /// no corresponding output is found in the conversation transcript.
  public var output: Tool.Output?

  /// Contains the recoverable problem information when decoding `Tool.Output` fails.
  ///
  /// This happens when a tool execution throws ``ToolRunProblem`` and the adapter forwards
  /// arbitrary ``GeneratedContent`` back to the agent. That content cannot be strongly typed
  /// and is different from the planned output of the tool. You can read the problem's payload
  /// via this property.
  public var problem: Problem?

  /// Indicates whether the tool run has produced a typed output.
  public var hasOutput: Bool {
    output != nil
  }

  /// Indicates whether a problem payload is available.
  public var hasProblem: Bool {
    problem != nil
  }

  /// Indicates that the tool run is still awaiting an output.
  public var isPending: Bool {
    output == nil && problem == nil
  }

  /// Creates a new tool run with the given arguments, optional output, and optional problem payload.
  ///
  /// - Parameters:
  ///   - arguments: The parsed tool arguments
  ///   - output: The tool's output, if available
  ///   - problem: The problem payload provided when `Tool.Output` decoding fails
  public init(
    id: String,
    arguments: Arguments,
    output: Tool.Output? = nil,
    problem: Problem? = nil,
    rawContent: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.arguments = arguments
    self.output = output
    self.problem = problem
    self.rawContent = rawContent
    self.rawOutput = rawOutput
  }
}

public extension ToolRun {
  /// Recoverable problem information returned when the tool output cannot be decoded into `Tool.Output`.
  struct Problem: Sendable, Equatable, Hashable {
    /// The human-readable reason describing the problem.
    public let reason: String

    /// The raw JSON string returned by the tool.
    public let json: String

    /// A flattened representation of the payload for quick inspection.
    public let details: [String: String]

    package init(reason: String, json: String, details: [String: String]) {
      self.reason = reason
      self.json = json
      self.details = details
    }

    /// Generates the original `GeneratedContent` value, when needed.
    public var generatedContent: GeneratedContent? {
      try? GeneratedContent(json: json)
    }
  }
}

extension ToolRun.Arguments: Sendable where Tool.Arguments: Sendable, Tool.Arguments.PartiallyGenerated: Sendable,
  Tool.Output: Sendable {}
extension ToolRun: Sendable where Tool.Arguments: Sendable, Tool.Arguments.PartiallyGenerated: Sendable,
  Tool.Output: Sendable {}
extension ToolRun: Equatable {
  public static func == (lhs: ToolRun<Tool>, rhs: ToolRun<Tool>) -> Bool {
    lhs.rawContent == rhs.rawContent && lhs.rawOutput == rhs.rawOutput
  }
}
