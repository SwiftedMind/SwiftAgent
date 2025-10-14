// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public struct ToolRun<Tool: FoundationModels.Tool>: Identifiable where Tool.Arguments: Generable,
  Tool.Output: Generable {
  public typealias Arguments = Tool.Arguments
  public typealias Output = Tool.Output

  /// The arguments phase of the tool run.
  public enum ArgumentsPhase {
    case partial(Arguments.PartiallyGenerated)
    case final(Arguments)
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

  /// The ID of the tool run.
  public var id: String

  /// The raw content of the tool run.
  public var rawArguments: GeneratedContent

  /// The raw output of the tool run.
  public var rawOutput: GeneratedContent?

  /// The arguments phase of the tool run.
  public var arguments: ArgumentsPhase?

  /// Provides a UI-stable, partial-shaped view of the tool arguments.
  /// Even when the underlying arguments are final, this exposes them
  /// as `Arguments.PartiallyGenerated` so SwiftUI view identities do not change.
  /// Use `isFinal` to know whether the values represent a completed set.
  public var normalizedArguments: NormalizedArguments?

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

  /// The error of the tool run.
  public var error: TranscriptDecodingError.ToolRunResolution?

  /// Indicates whether the tool run has produced a typed output.
  public var hasOutput: Bool {
    output != nil
  }

  /// Indicates whether a problem payload is available.
  public var hasProblem: Bool {
    problem != nil
  }

  /// Indicates whether a problem payload is available.
  public var hasError: Bool {
    error != nil
  }

  /// Indicates that the tool run is still awaiting an output.
  public var isPending: Bool {
    output == nil && problem == nil && error == nil
  }

  public init(
    id: String,
    arguments: ArgumentsPhase,
    output: Output? = nil,
    problem: Problem? = nil,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.arguments = arguments
    self.output = output
    self.problem = problem
    self.rawArguments = rawArguments
    self.rawOutput = rawOutput
    normalizedArguments = Self.makeNormalizedArguments(from: arguments, rawArguments: rawArguments)
  }

  public init(
    id: String,
    output: Output? = nil,
    problem: Problem? = nil,
    error: TranscriptDecodingError.ToolRunResolution,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.output = output
    self.problem = problem
    self.error = error
    self.rawArguments = rawArguments
    self.rawOutput = rawOutput
  }

  public static func partial(
    id: String,
    json: String,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments.PartiallyGenerated(rawArguments)
    return self.init(
      id: id,
      arguments: .partial(arguments),
      rawArguments: rawArguments,
    )
  }

  public static func completed(
    id: String,
    json: String,
    output: Output,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments(rawArguments)
    return self.init(
      id: id,
      arguments: .final(arguments),
      output: output,
      rawArguments: rawArguments,
    )
  }

  public static func completed(
    id: String,
    json: String,
    problem: Problem,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments(rawArguments)
    return self.init(
      id: id,
      arguments: .final(arguments),
      problem: problem,
      rawArguments: rawArguments,
    )
  }

  public static func error(
    id: String,
    error: TranscriptDecodingError.ToolRunResolution,
  ) throws -> ToolRun<Tool> {
    self.init(id: id, error: error, rawArguments: GeneratedContent(kind: .null))
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
    rawArguments: GeneratedContent,
  ) -> NormalizedArguments? {
    switch phase {
    case let .partial(arguments):
      NormalizedArguments(isFinal: false, arguments: arguments)
    case let .final(arguments):
      NormalizedArguments(isFinal: true, arguments: arguments.asPartiallyGenerated())
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
    lhs.rawArguments == rhs.rawArguments && lhs.rawOutput == rhs.rawOutput
  }
}
