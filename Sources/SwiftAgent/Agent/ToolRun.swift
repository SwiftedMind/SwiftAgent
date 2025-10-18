// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// A unified representation of a tool call and its output, providing type-safe access to arguments and results.
///
/// `ToolRun` combines tool calls and tool outputs into a single entry, making it easier to work with
/// tool interactions in your app. Unlike raw transcripts where tool calls and outputs are separate entries,
/// `ToolRun` provides a cohesive view with fully typed arguments and outputs.
///
/// The type is generic over your tool implementation, ensuring compile-time type safety when accessing
/// arguments and outputs. This eliminates the need to manually match tool calls with their corresponding
/// outputs and provides a stable interface for SwiftUI views.
///
/// ## Example
///
/// ```swift
/// @LanguageModelProvider(.openAI)
/// final class MySession {
///   @Tool var calculator = CalculatorTool()
/// }
///
/// let session = MySession(instructions: "You are a helpful assistant.", apiKey: "sk-...")
///
/// // generate responses ...
///
/// let decodedTranscript = try session.transcript.decoded(in: session)
///
/// for case let .toolRun(toolRun) in decodedTranscript {
///   switch toolRun {
///   case let .calculator(toolRun):
///     // Access typed arguments
///     if let arguments = toolRun.currentArguments {
///       print("First number: \(arguments.firstNumber)")
///       print("Operation: \(arguments.operation)")
///       print("Second number: \(arguments.secondNumber)")
///     }
///
///     // Access typed output
///     if let output = toolRun.output {
///       print("Result: \(output.result)")
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

  /// Represents the current state of tool arguments during streaming.
  ///
  /// Tool arguments can be in two phases: `partial` during streaming when the language model
  /// is still generating the arguments, and `final` when the arguments are complete and validated.
  ///
  /// ## Example
  ///
  /// ```swift
  /// switch toolRun.argumentsPhase {
  /// case let .partial(partialArguments):
  ///   // Arguments are still being generated
  ///   print("First number: \(partialArguments.firstNumber ?? 0)")
  ///   print("Operation: \(partialArguments.operation ?? "?")")
  ///
  /// case let .final(finalArguments):
  ///   // Arguments are complete and validated
  ///   print("Complete: \(finalArguments.firstNumber) \(finalArguments.operation) \(finalArguments.secondNumber)")
  ///
  /// case .none:
  ///   // No arguments available (error state)
  ///   print("Failed to decode arguments")
  /// }
  /// ```
  public enum ArgumentsPhase {
    /// Arguments are being streamed and may be incomplete.
    case partial(Arguments.PartiallyGenerated)
    /// Arguments are complete and fully validated.
    case final(Arguments)
  }

  /// A UI-stable view of tool arguments that maintains consistent SwiftUI view identity.
  ///
  /// `CurrentArguments` provides a stable interface for SwiftUI views by always exposing
  /// arguments in their `PartiallyGenerated` form, even when the underlying arguments are final.
  /// This prevents view identity changes that occur when switching between partial and final
  /// argument states during streaming.
  ///
  /// Use `isFinal` to determine whether the arguments represent a completed set, while
  /// accessing individual argument values through dynamic member lookup for a consistent API.
  ///
  /// ## Example
  ///
  /// ```swift
  /// struct CalculatorView: View {
  ///   let toolRun: ToolRun<CalculatorTool>
  ///
  ///   var body: some View {
  ///     if let currentArguments = toolRun.currentArguments {
  ///       HStack {
  ///         Text("\(currentArguments.firstNumber ?? 0)")
  ///         Text(currentArguments.operation ?? "?")
  ///         Text("\(currentArguments.secondNumber ?? 0)")
  ///
  ///         if currentArguments.isFinal {
  ///           Text("✓")
  ///         }
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  @dynamicMemberLookup
  public struct CurrentArguments {
    /// Whether the arguments are in their final, complete state.
    public var isFinal: Bool
    /// The arguments in their partially generated form for UI stability.
    public var arguments: Arguments.PartiallyGenerated

    init(isFinal: Bool, arguments: Arguments.PartiallyGenerated) {
      self.isFinal = isFinal
      self.arguments = arguments
    }

    /// Provides direct access to argument properties through dynamic member lookup.
    ///
    /// This allows you to access argument values directly on the `CurrentArguments`
    /// instance, maintaining a clean API while ensuring UI stability.
    public subscript<Value>(dynamicMember keyPath: KeyPath<Arguments.PartiallyGenerated, Value>) -> Value {
      arguments[keyPath: keyPath]
    }
  }

  /// The unique identifier for this tool run.
  public var id: String

  /// The raw generated content containing the tool arguments.
  ///
  /// This provides access to the original JSON or text content that was generated
  /// by the language model for the tool arguments.
  public var rawArguments: GeneratedContent

  /// The raw generated content containing the tool output, if available.
  ///
  /// This provides access to the original JSON or text content returned by the tool.
  /// May be `nil` if the tool hasn't completed execution or if no output was found.
  public var rawOutput: GeneratedContent?

  /// The current phase of the tool arguments (partial or final).
  ///
  /// - `nil`: Arguments failed to decode or are not available
  /// - `.partial`: Arguments are being streamed and may be incomplete
  /// - `.final`: Arguments are complete and validated
  public var argumentsPhase: ArgumentsPhase?

  /// A UI-stable view of the tool arguments for SwiftUI.
  ///
  /// This property always provides arguments in their `PartiallyGenerated` form,
  /// even when the underlying arguments are final. This prevents SwiftUI view
  /// identity changes during the transition from partial to final state.
  ///
  /// Use `isFinal` to determine completion status while accessing argument values
  /// through dynamic member lookup for consistent UI behavior.
  public var currentArguments: CurrentArguments?

  public var finalArguments: Arguments?

  /// The strongly-typed output from the tool execution.
  ///
  /// This will be `nil` when:
  /// - The tool run is still pending execution
  /// - The tool execution failed
  /// - No corresponding output was found in the transcript
  public var output: Output?

  /// Information about recoverable problems during tool execution.
  ///
  /// This contains structured error information when a tool execution fails
  /// but returns recoverable data. This typically occurs when a tool throws
  /// a `ToolRunProblem` and the adapter forwards the error details back to
  /// the agent as structured content.
  public var problem: Problem?

  /// An error that occurred while decoding or resolving the tool run.
  ///
  /// This indicates a failure in the tool resolution process, such as:
  /// - Unknown tool name
  /// - Invalid argument format
  /// - Decoding failures
  public var error: TranscriptDecodingError.ToolRunResolution?

  /// Whether the tool run has successfully produced a typed output.
  public var hasOutput: Bool {
    output != nil
  }

  /// Whether the tool run contains recoverable problem information.
  public var hasProblem: Bool {
    problem != nil
  }

  /// Whether the tool run encountered a decoding or resolution error.
  public var hasError: Bool {
    error != nil
  }

  /// Whether the tool run is still awaiting completion.
  ///
  /// Returns `true` when the tool has been called but hasn't yet produced
  /// an output, problem, or error.
  public var isPending: Bool {
    output == nil && problem == nil && error == nil
  }

  public init(
    id: String,
    argumentsPhase: ArgumentsPhase,
    output: Output? = nil,
    problem: Problem? = nil,
    rawArguments: GeneratedContent,
    rawOutput: GeneratedContent? = nil,
  ) {
    self.id = id
    self.argumentsPhase = argumentsPhase
    self.output = output
    self.problem = problem
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

  /// Creates a tool run with partial arguments during streaming.
  ///
  /// Use this factory method when the language model is still generating tool arguments
  /// and you want to create a `ToolRun` that represents the in-progress state.
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

  /// Creates a completed tool run with successful output.
  ///
  /// Use this factory method when the tool has completed execution successfully
  /// and produced a typed output.
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

  /// Creates a completed tool run with a recoverable problem.
  ///
  /// Use this factory method when the tool execution failed but returned
  /// structured error information that can be recovered.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let problemRun = try ToolRun<CalculatorTool>.completed(
  ///   id: "calc-123",
  ///   json: #"{ "firstNumber": 10, "operation": "/", "secondNumber": 0 }"#,
  ///   problem: ToolRun<CalculatorTool>.Problem(
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
  ///   - problem: The structured problem information
  /// - Returns: A completed tool run with problem information
  /// - Throws: If the JSON cannot be parsed or arguments cannot be decoded
  public static func completed(
    id: String,
    json: String,
    problem: Problem,
  ) throws -> ToolRun<Tool> {
    let rawArguments = try GeneratedContent(json: json)
    let arguments = try Arguments(rawArguments)
    return self.init(
      id: id,
      argumentsPhase: .final(arguments),
      problem: problem,
      rawArguments: rawArguments,
    )
  }

  /// Creates a tool run that failed during resolution or decoding.
  ///
  /// Use this factory method when the tool run cannot be properly decoded
  /// due to resolution errors, unknown tools, or other decoding failures.
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
    error: TranscriptDecodingError.ToolRunResolution,
  ) throws -> ToolRun<Tool> {
    self.init(id: id, error: error, rawArguments: GeneratedContent(kind: .null))
  }
}

public extension ToolRun {
  /// Structured information about recoverable problems during tool execution.
  ///
  /// `Problem` represents situations where a tool execution failed but returned
  /// structured error information that can be returned to the agent for another attempt.
  /// This typically occurs when a tool throws a `ToolRunProblem` and the adapter
  /// forwards the error details back to the agent as structured content.
  /// ```
  struct Problem: Sendable, Equatable, Hashable {
    /// A human-readable description of what went wrong.
    ///
    /// This provides a clear, agent-friendly explanation of the problem
    /// that occurred during tool execution.
    public let reason: String

    /// The raw JSON string containing the problem details.
    ///
    /// This contains the original structured data returned by the tool
    /// when the problem occurred. You can use this to access the full
    /// problem payload or reconstruct the original `GeneratedContent`.
    public let json: String

    /// A flattened key-value representation of the problem details.
    ///
    /// This provides easy access to specific problem attributes without
    /// needing to parse the JSON manually. Useful for displaying
    /// structured error information in UI components.
    public let details: [String: String]

    package init(reason: String, json: String, details: [String: String]) {
      self.reason = reason
      self.json = json
      self.details = details
    }

    /// Reconstructs the original `GeneratedContent` from the problem JSON.
    ///
    /// This allows you to access the full structured content that was
    /// returned when the problem occurred, useful for advanced error
    /// handling or debugging scenarios.
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
