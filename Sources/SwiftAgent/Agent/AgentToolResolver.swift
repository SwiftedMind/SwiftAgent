// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

// MARK: - Tool Resolver

public extension AgentTranscript {
  /// Creates a tool resolver for type-safe tool call resolution.
  ///
  /// The tool resolver provides a bridge between raw tool calls in the conversation transcript
  /// and strongly typed tool runs that can be used in your application logic. It matches
  /// tool calls by name with their corresponding outputs and converts them into domain-specific
  /// resolved tool runs.
  ///
  /// - Parameter tools: An array of tools that share the same `ResolvedToolRun` type
  /// - Returns: A configured tool resolver for this transcript
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Create tools with shared resolved type
  /// let tools: [any AgentTool<ResolvedToolRun>] = [WeatherTool(), CalculatorTool()]
  ///
  /// // Get resolver from transcript
  /// let resolver = session.transcript.toolResolver(for: tools)
  ///
  /// // Resolve individual tool calls
  /// for entry in session.transcript {
  ///   if case let .toolCalls(toolCalls) = entry {
  ///     for toolCall in toolCalls {
  ///       let resolved = try resolver.resolve(toolCall)
  ///       // Handle resolved tool...
  ///     }
  ///   }
  /// }
  /// ```
  func toolResolver<ResolvedToolRun>(for tools: [any AgentTool<ResolvedToolRun>]) -> AgentToolResolver<Context, ResolvedToolRun> {
    AgentToolResolver(tools: tools, in: self)
  }
}

/// A type-safe resolver for converting raw tool calls into strongly typed tool runs.
///
/// ``AgentToolResolver`` bridges the gap between AI model tool calls and your application's
/// domain logic by providing type-safe resolution of tool invocations. It matches tool calls
/// with their outputs from the conversation transcript and converts them into strongly typed
/// ``ResolvedToolRun`` instances.
///
/// ## Overview
///
/// The resolver works by:
/// 1. Indexing provided tools by their names for fast lookup
/// 2. Extracting all tool outputs from the conversation transcript
/// 3. Matching tool calls with their corresponding outputs by call ID
/// 4. Converting raw `GeneratedContent` into strongly typed tool runs
/// 5. Calling each tool's ``AgentTool/resolve(_:)->_`` method to produce the final result
///
/// ## Usage
///
/// Create a resolver from a transcript and use it to resolve tool calls:
///
/// ```swift
/// // Define your resolved tool run type
/// enum ResolvedToolRun {
///   case weather(AgentToolRun<WeatherTool>)
///   case calculator(AgentToolRun<CalculatorTool>)
/// }
///
/// // Create tools and resolver
/// let tools: [any AgentTool<ResolvedToolRun>] = [WeatherTool(), CalculatorTool()]
/// let resolver = session.transcript.toolResolver(for: tools)
///
/// // Resolve tool calls
/// for entry in session.transcript {
///   if case let .toolCalls(toolCalls) = entry {
///     for toolCall in toolCalls {
///       do {
///         let resolved = try resolver.resolve(toolCall)
///         handleResolvedTool(resolved)
///       } catch {
///         print("Failed to resolve tool: \(error)")
///       }
///     }
///   }
/// }
/// ```
///
/// ## Error Handling
///
/// The resolver throws ``AgentToolResolutionError`` when:
/// - A tool call references an unknown tool name
/// - Tool argument parsing fails
/// - Tool output conversion fails
///
/// ## Type Safety
///
/// By using a shared `ResolvedToolRun` type across all tools, the resolver ensures
/// compile-time safety when handling different tool types in a unified way.
public struct AgentToolResolver<Context: PromptContextSource, ResolvedToolRun> {
  /// The tool call type from the associated transcript.
  public typealias ToolCall = AgentTranscript<Context>.ToolCall

  /// Dictionary mapping tool names to their implementations for fast lookup.
  private let toolsByName: [String: any AgentTool<ResolvedToolRun>]

  /// All tool outputs extracted from the conversation transcript.
  private let transcriptToolOutputs: [AgentTranscript<Context>.ToolOutput]

  /// Creates a new tool resolver for the given tools and transcript.
  ///
  /// - Parameters:
  ///   - tools: The tools that can be resolved, all sharing the same `ResolvedToolRun` type
  ///   - transcript: The conversation transcript containing tool calls and outputs
  init(tools: [any AgentTool<ResolvedToolRun>], in transcript: AgentTranscript<Context>) {
    toolsByName = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
    transcriptToolOutputs = transcript.compactMap { entry in
      switch entry {
      case let .toolOutput(toolOutput):
        return toolOutput
      default:
        return nil
      }
    }
  }

  /// Resolves a tool call into a strongly typed resolved tool run.
  /// ## Example
  ///
  /// ```swift
  /// let resolver = session.transcript.toolResolver(for: tools)
  ///
  /// for entry in session.transcript {
  ///   if case let .toolCalls(toolCalls) = entry {
  ///     for toolCall in toolCalls {
  ///       do {
  ///         let resolved = try resolver.resolve(toolCall)
  ///         switch resolved {
  ///         case let .weather(run):
  ///           print("Weather request for: \(run.arguments.city)")
  ///         case let .calculator(run):
  ///           print("Calculation: \(run.arguments.expression)")
  ///         }
  ///       } catch AgentToolResolutionError.unknownTool(let name) {
  ///         print("Unknown tool: \(name)")
  ///       } catch {
  ///         print("Resolution failed: \(error)")
  ///       }
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter call: The tool call to resolve
  /// - Returns: A resolved tool run of the specified `ResolvedToolRun` type
  /// - Throws: ``AgentToolResolutionError/unknownTool(name:)`` if the tool is not found,
  ///           or conversion/resolution errors from the underlying tool
  ///
  public func resolve(_ call: ToolCall) throws -> ResolvedToolRun {
    guard let tool = toolsByName[call.toolName] else {
      let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
      AgentLog.error(
        AgentToolResolutionError.unknownTool(name: call.toolName),
        context: "Tool resolution failed. Available tools: \(availableTools)"
      )
      throw AgentToolResolutionError.unknownTool(name: call.toolName)
    }

    let output = findOutput(for: call)

    do {
      let resolvedTool = try tool.resolvedTool(arguments: call.arguments, output: output)
      return resolvedTool
    } catch {
      AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
      throw error
    }
  }

  /// Finds the corresponding output for a tool call in the transcript.
  ///
  /// This method searches the transcript's tool outputs for one that matches
  /// the given tool call's ID, then converts the output segment into `GeneratedContent`.
  ///
  /// - Parameter call: The tool call to find output for
  /// - Returns: The generated content from the tool's output, or `nil` if no output found
  private func findOutput(for call: ToolCall) -> GeneratedContent? {
    guard let toolOutput = transcriptToolOutputs.first(
      where: { $0.callId == call.callId }) else {
      return nil
    }

    switch toolOutput.segment {
    case let .text(text):
      return GeneratedContent(text.content)
    case let .structure(structure):
      return structure.content
    }
  }
}

/// Errors that can occur during tool resolution.
public enum AgentToolResolutionError: Error, Sendable, Equatable {
  /// The requested tool name was not found in the resolver's tool collection.
  ///
  /// This error occurs when a tool call references a tool that was not provided
  /// to the resolver during initialization.
  ///
  /// - Parameter name: The name of the unknown tool that was requested
  case unknownTool(name: String)
}
