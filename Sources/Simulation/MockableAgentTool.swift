// By Dennis Müller

import Foundation
import FoundationModels
import SwiftAgent

/// A protocol that defines the interface for creating mockable versions of agent tools
/// in the SwiftAgent simulation system.
///
/// This protocol enables the creation of mock implementations of `AgentTool` instances
/// for testing and simulation purposes. It provides a way to generate predictable
/// arguments and outputs without making actual tool calls during testing.
///
/// ## Requirements
///
/// The `Tool.Arguments` type must conform to `Encodable` because the simulation
/// adapter needs to serialize arguments to JSON format for proper and realistic mocking
/// behavior.
///
/// ## Example
///
/// ```swift
/// struct MockWeatherTool: MockableAgentTool {
///   let tool = WeatherTool()
///
///   func mockArguments() -> WeatherTool.Arguments {
///     WeatherTool.Arguments(location: "San Francisco")
///   }
///
///   func mockOutput() async throws -> WeatherTool.Output {
///     WeatherData(temperature: 72, condition: "sunny")
///   }
/// }
/// ```
public protocol MockableAgentTool<Tool>: Sendable where Tool.Arguments: Encodable {
  /// The associated agent tool type that this mock represents.
  ///
  /// This type must conform to `AgentTool` and its `Arguments` type must be `Encodable`
  /// to support JSON serialization in the simulation system.
  associatedtype Tool: AgentTool

  /// The actual tool instance that this mock wraps.
  ///
  /// This property provides access to the underlying tool for metadata like
  /// name, description, and schema information.
  var tool: Tool { get }

  /// Generates mock arguments for the associated tool.
  ///
  /// This method should return valid arguments that the tool would accept
  /// during normal operation. The returned arguments will be used by the
  /// simulation system to test tool calling behavior.
  ///
  /// - Returns: Mock arguments of type `Tool.Arguments` that are valid for the tool.
  ///
  /// - Note: The arguments must be serializable to JSON, which is ensured by the
  ///   `Encodable` constraint on `Tool.Arguments`.
  func mockArguments() -> Tool.Arguments

  /// Generates mock output for the associated tool.
  ///
  /// This method should return the expected output that the tool would produce
  /// when called with valid arguments. This allows testing of tool output handling
  /// without executing the actual tool logic.
  ///
  /// - Returns: Mock output of type `Tool.Output` representing a successful tool execution.
  /// - Throws: Any errors that the real tool might throw during execution, allowing
  ///   testing of error handling scenarios.
  func mockOutput() async throws -> Tool.Output
}

/// A protocol that extends `@Generable` types with the ability to provide mock content
/// for structured output generation in simulated sessions.
///
/// This protocol is used by the SwiftAgent simulation system when using
/// `SimulatedGeneration.response(content:)` with structured output types. Instead of
/// returning string responses, the simulation adapter uses this protocol to create
/// mock instances of `@Generable` structs for predictable structured output testing.
///
/// ## Requirements
///
/// Any `@Generable` struct used with `SimulatedGeneration.response(content:)`
/// must conform to `MockableGenerable` to enable proper mock generation.
///
/// ## Usage
///
/// Implement this protocol for custom `@Generable` types that will be used with
/// `SimulatedGeneration.response(content:)`:
///
/// ```swift
/// @Generable
/// struct TaskList: MockableGenerable {
///   let tasks: [Task]
///   let priority: String
///
///   static func mockContent() -> TaskList {
///     TaskList(
///       tasks: [Task(title: "Mock task", completed: false)],
///       priority: "high"
///     )
///   }
/// }
/// ```
public protocol MockableGenerable where Self: Generable {
  /// The associated content type that can be generated.
  ///
  /// This type must conform to `Generable` to be compatible with the
  /// SwiftAgent generation system.
  associatedtype Content: Generable

  /// Provides mock content for testing and simulation.
  ///
  /// This method should return a representative instance of the content type
  /// that can be used in place of actual AI-generated content during testing.
  ///
  /// - Returns: A mock instance of `Content` for testing purposes.
  static func mockContent() -> Content
}

/// Provides a default `MockableGenerable` implementation for `String`.
///
/// This extension allows `String` to be used in mock scenarios within the
/// simulation system, though the actual implementation returns an empty string
/// as it's not actively used by the current simulation adapter.
extension String: MockableGenerable {
  /// Returns mock content for `String` type.
  ///
  /// - Returns: An empty string as mock content.
  ///
  /// - Note: This implementation returns an empty string because it's not
  ///   currently utilized by the simulation adapter, but is provided for
  ///   protocol conformance completeness.
  public static func mockContent() -> String {
    // Is not used by the simulation adapter
    ""
  }
}
