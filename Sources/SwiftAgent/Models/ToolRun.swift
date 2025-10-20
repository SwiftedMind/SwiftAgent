// By Dennis Müller

import Foundation
import FoundationModels

/// Combines a tool call, its streaming arguments, and the resulting payload into one typed record.
///
/// Raw transcripts emit tool input and output as separate items. `ToolRun` stitches them back together so
/// your UI or analytics code can reason about a single, cohesive interaction, with safe access to both the
/// `Tool.Arguments` and `Tool.Output` types.
///
/// Because the generic parameter is your concrete tool, SwiftAgent guarantees type-safety all the way from
/// streaming arguments to the final output. Use `currentArguments` for UI-friendly projections that stay
/// stable while tokens arrive, and fall back to `finalArguments` once validation succeeds.
///
/// ## Example
///
/// ```swift
/// struct WeatherTool: Tool {
///   let name = "get_weather"
///   let description = "Fetch the latest weather report"
///
///   @Generable
///   struct Arguments {
///     let city: String
///     let unit: String
///   }
///
///   @Generable
///   struct Output {
///     let temperature: Double
///     let condition: String
///   }
///
///   // ...
/// }
///
/// @SessionSchema
/// struct SessionSchema {
///   @Tool var weatherTool = WeatherTool()
/// }
///
/// let sessionSchema = SessionSchema()
/// let session = OpenAISession(schema: sessionSchema, instructions: "You are a helpful assistant.", apiKey: "sk-...")
/// let response = try await session.respond(to: "Weather in Lisbon today?")
///
/// for entry in try sessionSchema.decode(session.transcript) {
///   if case let .toolRun(.weatherTool(run)) = entry, let arguments = run.currentArguments {
///     Text(arguments.city ?? "–")
///     if arguments.isFinal, let output = run.output {
///       Text(output.condition)
///     }
///   }
/// }
/// ```
public struct ToolRun<Tool: FoundationModels.Tool>: Identifiable where Tool.Arguments: Generable,
  Tool.Output: Generable {
  /// The arguments type for this tool.
  public typealias Arguments = Tool.Arguments

  /// The output type for this tool.
  public typealias Output = Tool.Output

  /// Tracks how far argument generation progressed for a tool call.
  ///
  /// While the provider streams tokens, SwiftAgent surfaces a `partial` projection backed by
  /// `Arguments.PartiallyGenerated`. Once validation succeeds the phase upgrades to `final` and
  /// carries the fully typed `Arguments` value. When decoding fails the phase stays `nil`.
  public enum ArgumentsPhase {
    /// Arguments are being streamed and may be incomplete.
    case partial(Arguments.PartiallyGenerated)
    /// Arguments are complete and fully validated.
    case final(Arguments)
  }

  /// Stable projection of arguments designed for SwiftUI updates during streaming.
  ///
  /// `CurrentArguments` always exposes the partially generated shape of the arguments, even when
  /// the underlying value is final. That keeps SwiftUI identity steady from the first token to the
  /// last, while the `isFinal` flag tells you when the agent finished deciding on its inputs.
  @dynamicMemberLookup
  public struct CurrentArguments {
    /// Whether the arguments are in their final, complete state.
    public var isFinal: Bool

    /// The partially generated representation backing this view.
    public var arguments: Arguments.PartiallyGenerated

    init(isFinal: Bool, arguments: Arguments.PartiallyGenerated) {
      self.isFinal = isFinal
      self.arguments = arguments
    }

    /// Forwards dynamic member lookups to the partially generated arguments.
    public subscript<Value>(dynamicMember keyPath: KeyPath<Arguments.PartiallyGenerated, Value>) -> Value {
      arguments[keyPath: keyPath]
    }
  }

  /// The unique identifier for this tool run.
  public var id: String

  /// The raw generated content containing the tool arguments.
  public var rawArguments: GeneratedContent

  /// The raw generated content containing the tool output, if available.
  public var rawOutput: GeneratedContent?

  /// The current phase of the tool arguments (partial or final).
  ///
  /// - `nil`: Arguments failed to decode or are not available
  /// - `.partial`: Arguments are being streamed and may be incomplete
  /// - `.final`: Arguments are complete and validated
  public var argumentsPhase: ArgumentsPhase?

  /// A UI-stable view of the tool arguments for SwiftUI.
  public var currentArguments: CurrentArguments?

  /// The validated arguments once the agent commits to a tool call.
  public var finalArguments: Arguments?

  /// The strongly-typed output from the tool execution.
  ///
  /// This will be `nil` when:
  /// - The tool run is still pending execution
  /// - The tool execution failed
  /// - No corresponding output was found in the transcript
  public var output: Output?

  /// Structured payload returned when the tool threw a `ToolRunRejection`.
  public var rejection: Rejection?

  /// An error that occurred while decoding or resolving the tool run.
  public var error: TranscriptResolvingError.ToolRunResolution?

  /// Whether the tool run has successfully produced a typed output.
  public var hasOutput: Bool {
    output != nil
  }

  /// Whether the tool run contains recoverable rejection information.
  public var hasRejection: Bool {
    rejection != nil
  }

  /// Whether the tool run encountered a decoding or resolution error.
  public var hasError: Bool {
    error != nil
  }

  /// Whether the tool was called but has not yet produced any terminal payload.
  public var isPending: Bool {
    output == nil && rejection == nil && error == nil
  }

  public init(
    id: String,
    argumentsPhase: ArgumentsPhase,
    output: Output? = nil,
    rejection: Rejection? = nil,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.argumentsPhase = argumentsPhase
    self.output = output
    self.rejection = rejection
    self.rawArguments = rawArguments
    self.rawOutput = rawOutput
    currentArguments = Self.makeCurrentArguments(from: argumentsPhase, rawArguments: rawArguments)

    switch argumentsPhase {
    case let .final(final):
      finalArguments = final
    default:
      break
    }
  }

  public init(
    id: String,
    output: Output? = nil,
    rejection: Rejection? = nil,
    error: TranscriptResolvingError.ToolRunResolution,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.output = output
    self.rejection = rejection
    self.error = error
    self.rawArguments = rawArguments
    self.rawOutput = rawOutput
  }

  /// Creates a tool run in the middle of argument streaming.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let partialRun = try ToolRun<CalculatorTool>.partial(
  ///   id: "calc-123",
  ///   json: #"{ "firstNumber": 10, "operation": "+" }"#
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this tool run
  ///   - json: The JSON string containing the partial arguments
  /// - Returns: A tool run in partial state
  /// - Throws: If the JSON cannot be parsed or arguments cannot be decoded
  public static func partial(
    id: String,
    json: String,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments.PartiallyGenerated(rawArguments)
    return self.init(
      id: id,
      argumentsPhase: .partial(arguments),
      rawArguments: rawArguments,
    )
  }

  /// Creates a tool run that already completed with a typed output.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let completedRun = try ToolRun<CalculatorTool>.completed(
  ///   id: "calc-123",
  ///   json: #"{ "firstNumber": 10, "operation": "+", "secondNumber": 5 }"#,
  ///   output: CalculatorTool.Output(result: 15)
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this tool run
  ///   - json: The JSON string containing the complete arguments
  ///   - output: The successfully produced tool output
  /// - Returns: A completed tool run with output
  /// - Throws: If the JSON cannot be parsed or arguments cannot be decoded
  public static func completed(
    id: String,
    json: String,
    output: Output,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments(rawArguments)
    return self.init(
      id: id,
      argumentsPhase: .final(arguments),
      output: output,
      rawArguments: rawArguments,
    )
  }

  /// Creates a resolved tool run whose execution produced a recoverable rejection.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let rejectionRun = try ToolRun<CalculatorTool>.completed(
  ///   id: "calc-123",
  ///   json: #"{ "firstNumber": 10, "operation": "/", "secondNumber": 0 }"#,
  ///   rejection: ToolRun<CalculatorTool>.Rejection(
  ///     reason: "Division by zero",
  ///     json: #"{ "error": "Cannot divide by zero" }"#,
  ///     details: ["error": "Cannot divide by zero"]
  ///   )
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this tool run
  ///   - json: The JSON string containing the complete arguments
  ///   - rejection: The structured rejection information
  /// - Returns: A completed tool run with rejection information
  /// - Throws: If the JSON cannot be parsed or arguments cannot be decoded
  public static func completed(
    id: String,
    json: String,
    rejection: Rejection,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments(rawArguments)
    return self.init(
      id: id,
      argumentsPhase: .final(arguments),
      rejection: rejection,
      rawArguments: rawArguments,
    )
  }

  /// Creates a run that failed before argument decoding could succeed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let errorRun = try ToolRun<CalculatorTool>.error(
  ///   id: "calc-123",
  ///   error: .unknownTool(name: "unknown_calculator")
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this tool run
  ///   - error: The resolution or decoding error that occurred
  /// - Returns: A tool run in error state
  public static func error(
    id: String,
    error: TranscriptResolvingError.ToolRunResolution,
  ) throws -> ToolRun<Tool> {
    self.init(id: id, error: error, rawArguments: GeneratedContent(kind: .null))
  }
}

public extension ToolRun {
  /// Structured payload returned when a tool call throws a `ToolRunRejection`.
  struct Rejection: Sendable, Equatable, Hashable {
    /// Human-readable explanation surfaced to the agent loop.
    public let reason: String

    /// Original JSON envelope returned by the tool.
    public let json: String

    /// Flattened convenience view over the rejection content.
    public let details: [String: String]

    package init(reason: String, json: String, details: [String: String]) {
      self.reason = reason
      self.json = json
      self.details = details
    }

    /// Converts the JSON back into `GeneratedContent` when you need structured access.
    public var generatedContent: GeneratedContent? {
      try? GeneratedContent(json: json)
    }
  }
}

private extension ToolRun {
  static func makeCurrentArguments(
    from phase: ArgumentsPhase,
    rawArguments: GeneratedContent,
  ) -> CurrentArguments? {
    switch phase {
    case let .partial(arguments):
      CurrentArguments(isFinal: false, arguments: arguments)
    case let .final(arguments):
      CurrentArguments(isFinal: true, arguments: arguments.asPartiallyGenerated())
    }
  }
}

extension ToolRun.ArgumentsPhase: Sendable
  where ToolRun.Arguments: Sendable, ToolRun.Arguments.PartiallyGenerated: Sendable {}
extension ToolRun.CurrentArguments: Sendable
  where ToolRun.Arguments.PartiallyGenerated: Sendable {}
extension ToolRun: Sendable
  where ToolRun.Arguments: Sendable, ToolRun.Arguments.PartiallyGenerated: Sendable, ToolRun.Output: Sendable {}
extension ToolRun: Equatable {
  public static func == (lhs: ToolRun, rhs: ToolRun) -> Bool {
    lhs.rawArguments == rhs.rawArguments && lhs.rawOutput == rhs.rawOutput
  }
}
