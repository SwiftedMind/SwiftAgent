// By Dennis Müller

import Foundation
import FoundationModels
import Internal
import OSLog

/// A type-safe resolver for converting raw tool calls into strongly typed tool runs.
///
/// ``TranscriptResolver`` bridges the gap between AI model tool calls and your application's
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
public struct TranscriptResolver<Provider: LanguageModelProvider> {
	/// The tool call type from the associated transcript.
	public typealias ToolCall = Transcript.ToolCall

	/// Dictionary mapping tool names to their implementations for fast lookup.
	private let toolsByName: [String: any ResolvableTool<Provider>]

	/// All tool outputs extracted from the conversation transcript.
	private let transcriptToolOutputs: [Transcript.ToolOutput]

	/// Creates a new tool resolver for the given tools and transcript.
	///
	/// - Parameters:
	///   - tools: The tools that can be resolved, all sharing the same `Resolution` type
	///   - transcript: The conversation transcript containing tool calls and outputs
	init(for provider: Provider, transcript: Transcript) {
		toolsByName = Dictionary(uniqueKeysWithValues: provider.tools.map { ($0.name, $0) })
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
	public func resolve(_ call: ToolCall) -> Provider.ResolvedToolRun {
		guard let tool = toolsByName[call.toolName] else {
			let availableTools = toolsByName.keys.sorted().joined(separator: ", ")
			let error = TranscriptResolutionError.ToolRunResolution.unknownTool(name: call.toolName)
			AgentLog.error(
				error,
				context: "Tool resolution failed. Available tools: \(availableTools)",
			)
			return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
		}

		let outputContent = findOutput(for: call)

		do {
			switch call.status {
			case .inProgress:
				return try tool.resolveInProgress(id: call.id, argumentsContent: call.arguments, outputContent: outputContent)
			case .completed:
				return try tool.resolveCompleted(id: call.id, argumentsContent: call.arguments, outputContent: outputContent)
			default:
				return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
			}
		} catch {
			AgentLog.error(error, context: "Tool resolution for '\(call.toolName)'")
			return Provider.ResolvedToolRun.makeUnknown(toolCall: call)
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

	// MARK: - Structured Outputs

	public func resolve(
		_ structuredSegment: Transcript.StructuredSegment,
		status: Transcript.Status,
	) -> Provider
		.ResolvedStructuredOutput {
		let structuredOutputs = Provider.structuredOutputs
		guard let structuredOutput = structuredOutputs.first(where: { $0.name == structuredSegment.typeName }) else {
			return Provider.ResolvedStructuredOutput.makeUnknown(segment: structuredSegment)
		}

		return resolve(structuredSegment, status: status, with: structuredOutput)
	}

	private func resolve<ResolvableType: ResolvableStructuredOutput>(
		_ structuredSegment: Transcript.StructuredSegment,
		status: Transcript.Status,
		with resolvableType: ResolvableType.Type,
	) -> Provider.ResolvedStructuredOutput where ResolvableType.Provider == Provider {
		var resolvedContent: StructuredOutput<ResolvableType>.State

		do {
			switch status {
			case .completed:
				resolvedContent = try .completed(resolvableType.Schema(structuredSegment.content))
			case .inProgress:
				resolvedContent = try .inProgress(resolvableType.Schema.PartiallyGenerated(structuredSegment.content))
			default:
				resolvedContent = .failed(structuredSegment.content)
			}
		} catch {
			resolvedContent = .failed(structuredSegment.content)
		}

		let structuredOutput = StructuredOutput<ResolvableType>(
			id: structuredSegment.id,
			state: resolvedContent,
			raw: structuredSegment.content,
		)

		return ResolvableType.resolve(structuredOutput)
	}
}
