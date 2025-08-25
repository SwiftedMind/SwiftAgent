// By Dennis Müller

import Foundation
import FoundationModels

/// A thin wrapper around Apple's `FoundationModels.Tool` protocol that provides essential functionality
/// for SwiftAgent's tool calling system.
///
/// `AgentTool` extends Apple's native tool protocol with type-safe argument and output handling,
/// custom resolution logic, and seamless integration with SwiftAgent's agent execution loop.
///
/// ## Overview
///
/// The SwiftAgent framework builds on Apple's FoundationModels design philosophy by providing a
/// clean, declarative API for AI tool development. `AgentTool` serves as the bridge between
/// Apple's tool protocol and SwiftAgent's enhanced capabilities.
///
/// ## Usage
///
/// ```swift
/// struct WeatherTool: AgentTool {
///
///   let name = "get_weather"
///   let description = "Get current weather for a location"
///
///   @Generable
///   struct Arguments {
///     let location: String
///   }
///
///   @Generable
///   struct Output {
///     let temperature: Double
///     let conditions: String
///   }
/// }
/// ```
///
/// ## Tool Resolution
///
/// Tools are resolved through the ``AgentToolResolver`` which:
/// 1. Matches tool calls by name
/// 2. Converts `GeneratedContent` to strongly typed arguments
/// 3. Finds corresponding outputs from the conversation transcript
/// 4. Calls the tool's `resolve(_:)` method to produce the final result
///
/// For more information, see ``AgentToolResolver``.
///
/// - Note: The ``ResolvedToolRun`` associated type allows you to return any type that represents
///   the resolved tool execution, enabling seamless integration with your application's domain models.
public protocol AgentTool<ResolvedToolRun>: FoundationModels.Tool, Encodable where Output: ConvertibleToGeneratedContent, Output: ConvertibleFromGeneratedContent {
  /// The type returned when this tool is resolved.
  ///
  /// Defaults to `Void` for tools that don't need custom resolution logic.
  /// Override to return domain-specific types that represent the resolved tool execution.
  associatedtype ResolvedToolRun = Void

  /// Resolves a tool run into a domain-specific result.
  ///
  /// This method is called after the tool's arguments have been parsed and any output
  /// has been matched from the conversation transcript. Use this to transform the
  /// raw tool call data into meaningful domain objects.
  ///
  /// - Parameter run: The tool run containing typed arguments and optional output
  /// - Returns: A resolved representation of the tool execution
  func resolve(_ run: AgentToolRun<Self>) -> ResolvedToolRun
}

// MARK: - AgentTool Implementation

public extension AgentTool {
  package var toolType: Self.Type { Self.self }

  /// Resolves a tool with raw GeneratedContent arguments and output.
  ///
  /// This is the internal bridge method that converts between Apple's FoundationModels
  /// content representation and SwiftAgent's strongly typed tool system.
  ///
  /// - Note: You typically do not implement or interact with this method overload directly.
  /// This is handled by the SDK.
  ///
  /// - Parameters:
  ///   - arguments: The raw arguments from the AI model
  ///   - output: The raw output content, if available
  /// - Returns: The resolved tool result
  /// - Throws: Conversion or resolution errors
  func resolvedTool(arguments: GeneratedContent, output: GeneratedContent?) throws -> ResolvedToolRun {
    try resolve(run(for: arguments, output: output))
  }

  /// Creates a strongly typed tool run from raw content.
  ///
  /// - Parameters:
  ///   - arguments: Raw argument content from the AI model
  ///   - output: Optional raw output content
  /// - Returns: A typed AgentToolRun instance
  /// - Throws: Conversion errors if content cannot be parsed
  private func run(for arguments: GeneratedContent, output: GeneratedContent?) throws -> AgentToolRun<Self> {
    try AgentToolRun(arguments: self.arguments(from: arguments), output: self.output(from: output))
  }

  /// Converts raw GeneratedContent to strongly typed Arguments.
  ///
  /// - Parameter generatedContent: The raw content to convert
  /// - Returns: Typed arguments instance
  /// - Throws: Conversion errors
  private func arguments(from generatedContent: GeneratedContent) throws -> Arguments {
    try toolType.Arguments(generatedContent)
  }

  /// Converts optional raw GeneratedContent to strongly typed Output.
  ///
  /// - Parameter generatedContent: The optional raw content to convert
  /// - Returns: Typed output instance, or nil if no content provided
  /// - Throws: Conversion errors
  private func output(from generatedContent: GeneratedContent?) throws -> Output? {
    guard let generatedContent else {
      return nil
    }

    return try toolType.Output(generatedContent)
  }
}

// MARK: - Default Resolution

public extension AgentTool where ResolvedToolRun == Void {
  /// Default implementation for tools that don't need custom resolution logic.
  ///
  /// This implementation is automatically provided for tools where `ResolvedToolRun`
  /// is `Void`, making the `resolve(_:)` method optional for simple tools.
  ///
  /// - Parameter run: The tool run (unused in default implementation)
  func resolve(_ run: AgentToolRun<Self>) {
    ()
  }
}

// MARK: - AgentToolRun

/// Represents a single tool execution with strongly typed arguments and output.
///
/// `AgentToolRun` encapsulates a tool invocation by combining the parsed arguments
/// with any available output from the conversation transcript. This provides a
/// clean, type-safe interface for tool resolution logic.
///
/// ## Usage
///
/// Tool runs are created internally by the framework and passed to your tool's
/// `resolve(_:)` method:
///
/// ```swift
/// func resolve(_ run: AgentToolRun<Self>) -> MyResolvedAgentTool {
///   .mySpecificTool(run)
/// }
/// ```
public struct AgentToolRun<Tool: AgentTool> {
  /// The strongly typed inputs for this invocation.
  ///
  /// These arguments are automatically parsed from the AI model's JSON tool call
  /// into your tool's `Arguments` type.
  public let arguments: Tool.Arguments

  /// The tool's output, if available.
  ///
  /// This will be `nil` when the tool run has not yet produced a result, or when
  /// no corresponding output is found in the conversation transcript.
  public var output: Tool.Output?

  /// Creates a new tool run with the given arguments and optional output.
  ///
  /// - Parameters:
  ///   - arguments: The parsed tool arguments
  ///   - output: The tool's output, if available
  public init(arguments: Tool.Arguments, output: Tool.Output? = nil) {
    self.arguments = arguments
    self.output = output
  }
}

extension AgentToolRun: Sendable where Tool.Arguments: Sendable, Tool.Output: Sendable {}
extension AgentToolRun: Equatable where Tool.Arguments: Equatable, Tool.Output: Equatable {}
extension AgentToolRun: Hashable where Tool.Arguments: Hashable, Tool.Output: Hashable {}

// MARK: - Encoding

private enum AgentToolCodingKeys: String, CodingKey {
  case name
  case description
  case parameters
}

public extension AgentTool {
  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: AgentToolCodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(parameters, forKey: .parameters)
  }
}
