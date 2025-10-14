// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct ToolRun<Tool: FoundationModels.Tool>: Identifiable where Tool.Arguments: Generable,
  Tool.Output: Generable {
  public typealias Arguments = Tool.Arguments
  public typealias Output = Tool.Output

  private let rawContent: GeneratedContent
  private let rawOutput: GeneratedContent?

  public enum ArgumentsPhase {
    case partial(Arguments.PartiallyGenerated)
    case final(Arguments)
    case failed(TranscriptDecodingError.ToolRunResolution)
  }

  @dynamicMemberLookup
  public struct NormalizedArguments {
    public var isFinal: Bool
    public var arguments: Arguments.PartiallyGenerated

    init(isFinal: Bool, arguments: Arguments.PartiallyGenerated) {
      self.isFinal = isFinal
      self.arguments = arguments
    }

    public subscript<Value>(dynamicMember keyPath: KeyPath<Arguments.PartiallyGenerated, Value>) -> Value {
      arguments[keyPath: keyPath]
    }
  }

  public var id: String

  public var arguments: ArgumentsPhase

  /// Provides a UI-stable, partial-shaped view of the tool arguments.
  /// Even when the underlying arguments are final, this exposes them
  /// as `Arguments.PartiallyGenerated` so SwiftUI view identities do not change.
  /// Use `isFinal` to know whether the values represent a completed set.
  public let normalizedArguments: NormalizedArguments?

  /// The tool's output, if available.
  ///
  /// This will be `nil` when the tool run has not yet produced a result, or when
  /// no corresponding output is found in the conversation transcript.
  public var output: Output?

  /// Contains the recoverable problem information when decoding `Output` fails.
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
  ///   - problem: The problem payload provided when `Output` decoding fails
  public init(
    id: String,
    arguments: ArgumentsPhase,
    output: Output? = nil,
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
    normalizedArguments = Self.makeNormalizedArguments(from: arguments, rawContent: rawContent)
  }
}

public extension ToolRun {
  /// Recoverable problem information returned when the tool output cannot be decoded into `Output`.
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

private extension ToolRun {
  static func makeNormalizedArguments(
    from phase: ArgumentsPhase,
    rawContent: GeneratedContent,
  ) -> NormalizedArguments? {
    switch phase {
    case let .partial(arguments):
      NormalizedArguments(isFinal: false, arguments: arguments)
    case let .final(arguments):
      NormalizedArguments(isFinal: true, arguments: arguments.asPartiallyGenerated())
    case .failed:
      nil
    }
  }
}

extension ToolRun.ArgumentsPhase: Sendable
  where ToolRun.Arguments: Sendable, ToolRun.Arguments.PartiallyGenerated: Sendable {}
extension ToolRun.NormalizedArguments: Sendable
  where ToolRun.Arguments.PartiallyGenerated: Sendable {}
extension ToolRun: Sendable
  where ToolRun.Arguments: Sendable, ToolRun.Arguments.PartiallyGenerated: Sendable, ToolRun.Output: Sendable {}
extension ToolRun: Equatable {
  public static func == (lhs: ToolRun, rhs: ToolRun) -> Bool {
    lhs.rawContent == rhs.rawContent && lhs.rawOutput == rhs.rawOutput
  }
}
