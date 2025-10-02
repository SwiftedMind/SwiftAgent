// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

/// A type-safe resolver for converting raw tool calls into strongly typed tool runs.
///
/// ``ToolResolver`` bridges the gap between AI model tool calls and your application's
/// domain logic by providing type-safe resolution of tool invocations. It matches tool calls
/// with their outputs from the conversation transcript and converts them into strongly typed
/// instances of ``Tool/Resolution``.
///
/// ## Overview
///
/// The resolver works by:
/// 1. Indexing provided tools by their names for fast lookup
/// 2. Extracting all tool outputs from the conversation transcript
/// 3. Matching tool calls with their corresponding outputs by call ID
/// 4. Converting raw `GeneratedContent` into strongly typed tool runs
/// 5. Calling each tool's ``Tool/resolve(_:)->_`` method to produce the final result
///
/// ## Usage
///
/// Create a resolver from a transcript and use it to resolve tool calls:
///
/// ```swift
/// // Define your resolved tool run type
/// enum ToolRunKind {
///   case weather(ToolRun<WeatherTool>)
///   case calculator(ToolRun<CalculatorTool>)
/// }
///
/// // Create tools and resolver
/// let tools: [any Tool<ToolRunKind>] = [WeatherTool(), CalculatorTool()]
/// let resolver = session.transcript.toolResolver(using: tools)
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
/// - Tip: You can also use ``Transcript/resolved(using:)`` to embed the tool runs directly into the transcript
/// entries.
///
/// ## Error Handling
///
/// The resolver throws ``AgentToolRunKindError`` when:
/// - A tool call references an unknown tool name
/// - Tool argument parsing fails
/// - Tool output conversion fails
///
/// ## Type Safety
///
/// By using a shared `ToolRunKind` type across all your tools, the resolver ensures
/// compile-time safety when handling different tool types in a unified way.
public struct ToolResolver<Session: LanguageModelProvider> {
	/// The tool call type from the associated transcript.
	public typealias ToolCall = Transcript.ToolCall

	/// Dictionary mapping tool names to their implementations for fast lookup.
	private let toolsByName: [String: any ResolvableTool<Session>]

	/// All tool outputs extracted from the conversation transcript.
	private let transcriptToolOutputs: [Transcript.ToolOutput]

	/// Creates a new tool resolver for the given tools and transcript.
	///
	/// - Parameters:
	///   - tools: The tools that can be resolved, all sharing the same `Resolution` type
	///   - transcript: The conversation transcript containing tool calls and outputs
	init(for session: Session, transcript: Transcript) {
		toolsByName = Dictionary(uniqueKeysWithValues: session.tools.map { ($0.name, $0) })
		transcriptToolOutputs = transcript.compactMap { entry in
			switch entry {
			case let .toolOutput(toolOutput):
				toolOutput
			default:
				nil
			}
		}
	}

	/// Resolves a tool call into a strongly typed resolved tool run.
	/// ## Example
	///
	/// ```swift
	/// let resolver = session.transcript.toolResolver(using: tools)
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
	///       } catch AgentToolRunKindError.unknownTool(let name) {
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
	/// - Returns: A resolved tool run of the specified `Resolution` type
	/// - Throws: ``AgentToolRunKindError/unknownTool(name:)`` if the tool is not found,
	///           or conversion/resolution errors from the underlying tool
	///
	public func resolve(_ call: ToolCall) throws -> Session.ResolvedToolRun {
		guard let tool = toolsByName[call.toolName] else {
			let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
			AgentLog.error(
				AgentToolRunKindError.unknownTool(name: call.toolName),
				context: "Tool resolution failed. Available tools: \(availableTools)",
			)
			throw AgentToolRunKindError.unknownTool(name: call.toolName)
		}

		let output = findOutput(for: call)

		do {
			let resolvedTool = try tool.resolve(arguments: call.arguments, output: output)
			return resolvedTool
		} catch {
			AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
			throw error
		}
	}

	public func resolvePartially(_ call: ToolCall) throws -> Session.PartiallyResolvedToolRun {
		guard let tool = toolsByName[call.toolName] else {
			let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
			AgentLog.error(
				AgentToolRunKindError.unknownTool(name: call.toolName),
				context: "Tool partial resolution failed. Available tools: \(availableTools)",
			)
			throw AgentToolRunKindError.unknownTool(name: call.toolName)
		}

		let output = findOutput(for: call)

		do {
			let resolvedTool = try tool.resolvePartially(arguments: call.arguments, output: output)
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
		guard let toolOutput = transcriptToolOutputs.first(where: { $0.callId == call.callId }) else {
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
package enum AgentToolRunKindError: Error, Sendable, Equatable {
	/// The requested tool name was not found in the resolver's tool collection.
	///
	/// This error occurs when a tool call references a tool that was not provided
	/// to the resolver during initialization.
	///
	/// - Parameter name: The name of the unknown tool that was requested
	case unknownTool(name: String)
}
