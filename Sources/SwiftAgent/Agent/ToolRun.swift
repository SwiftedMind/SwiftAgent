// By Dennis Müller

import Foundation
import FoundationModels
import Internal

/// Represents a single tool execution with strongly typed arguments and output.
///
/// `ToolRun` encapsulates a tool invocation by combining the parsed arguments
/// with any available output from the conversation transcript. This provides a
/// clean, type-safe interface for tool resolution logic.
///
/// ## Usage
///
/// Tool runs are created internally by the framework and passed to your tool's`
/// ``SwiftAgentTool/resolve(_:)->_`` method:
///
/// ```swift
/// enum ToolRunKind {
///  case mySpecificTool(ToolRun<MySpecificTool>)
/// }
///
/// struct MySpecificTool: AgentTool {
///   /* ... */
///
///   func resolve(_ run: ToolRun<Self>) -> ToolRunKind {
///     .mySpecificTool(run)
///   }
/// }
/// ```
public struct ToolRun<Tool: SwiftAgentTool> {
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
		arguments: Tool.Arguments,
		output: Tool.Output? = nil,
		problem: Problem? = nil
	) {
		self.arguments = arguments
		self.output = output
		self.problem = problem
	}
}

public struct PartialToolRun<Tool: SwiftAgentTool> where Tool.Arguments: Generable, Tool.Output: Generable {
	/// The strongly typed inputs for this invocation.
	///
	/// These arguments are automatically parsed from the AI model's JSON tool call
	/// into your tool's `Arguments` type.
	public let arguments: Tool.Arguments.PartiallyGenerated
	
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
	public var problem: ToolRun<Tool>.Problem?
	
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
	package init(
		arguments: Tool.Arguments.PartiallyGenerated,
		output: Tool.Output? = nil,
		problem: ToolRun<Tool>.Problem? = nil
	) {
		self.arguments = arguments
		self.output = output
		self.problem = problem
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

extension ToolRun: Sendable where Tool.Arguments: Sendable, Tool.Output: Sendable {}
extension ToolRun: Equatable where Tool.Arguments: Equatable, Tool.Output: Equatable {}
extension ToolRun: Hashable where Tool.Arguments: Hashable, Tool.Output: Hashable {}
