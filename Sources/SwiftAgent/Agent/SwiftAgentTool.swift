// By Dennis Müller

import Foundation
import FoundationModels
import Internal

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
public protocol SwiftAgentTool<ResolutionType>: FoundationModels.Tool,
	Encodable where Output: ConvertibleToGeneratedContent,
	Output: ConvertibleFromGeneratedContent {
	/// The type returned when this tool is resolved.
	///
	/// Defaults to `Void` for tools that don't need custom resolution logic.
	/// Override to return domain-specific types that represent the resolved tool execution.
	associatedtype ResolutionType = Void

	/// Resolves a tool run into a domain-specific result.
	///
	/// This method is called after the tool's arguments have been parsed and any output
	/// has been matched from the conversation transcript. Use this to transform the
	/// raw tool call data into meaningful domain objects.
	///
	/// - Parameter run: The tool run containing typed arguments and optional output
	/// - Returns: A resolved representation of the tool execution
	func resolve(_ run: AgentToolRun<Self>) -> ResolutionType
}

// MARK: - Default Resolution

public extension SwiftAgentTool where ResolutionType == Void {
	/// Default implementation for tools that don't need custom resolution logic.
	///
	/// This implementation is automatically provided for tools where `Resolution`
	/// is `Void`, making the `resolve(_:)` method optional for simple tools.
	///
	/// - Parameter run: The tool run (unused in default implementation)
	func resolve(_ run: AgentToolRun<Self>) {
		()
	}
}

// MARK: - Tool Implementation

package extension SwiftAgentTool {
	var toolType: Self.Type { Self.self }

	/// Resolves a tool with raw GeneratedContent arguments and output.
	///
	/// This is the internal bridge method that converts between Apple's FoundationModels
	/// content representation and SwiftAgent's strongly typed tool system.
	///
	/// - Parameters:
	///   - arguments: The raw arguments from the AI model
	///   - output: The raw output content, if available
	/// - Returns: The resolved tool result
	/// - Throws: Conversion or resolution errors
	func resolve(arguments: GeneratedContent, output: GeneratedContent?) throws -> ResolutionType {
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
		let parsedArguments = try self.arguments(from: arguments)

		guard let output else {
			return AgentToolRun(arguments: parsedArguments)
		}

		do {
			return try AgentToolRun(arguments: parsedArguments, output: self.output(from: output))
		} catch {
			guard let problem = problem(from: output) else {
				throw error
			}

			return AgentToolRun(arguments: parsedArguments, problem: problem)
		}
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

	private func problem(from generatedContent: GeneratedContent) -> AgentToolRun<Self>.Problem? {
		guard
			let problemReport = try? ProblemReport(generatedContent),
			problemReport.error else {
			return nil
		}

		return AgentToolRun<Self>.Problem(
			reason: problemReport.reason,
			json: generatedContent.jsonString,
			details: ProblemReportDetailsExtractor.values(from: generatedContent),
		)
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
/// ``Tool/resolve(_:)->_`` method:
///
/// ```swift
/// func resolve(_ run: AgentToolRun<Self>) -> MyToolResolution {
///   .mySpecificTool(run)
/// }
/// ```
public struct AgentToolRun<Tool: SwiftAgentTool> {
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
	package init(
		arguments: Tool.Arguments,
		output: Tool.Output? = nil,
		problem: Problem? = nil,
	) {
		self.arguments = arguments
		self.output = output
		self.problem = problem
	}
}

public extension AgentToolRun {
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

extension AgentToolRun: Sendable where Tool.Arguments: Sendable, Tool.Output: Sendable {}
extension AgentToolRun: Equatable where Tool.Arguments: Equatable, Tool.Output: Equatable {}
extension AgentToolRun: Hashable where Tool.Arguments: Hashable, Tool.Output: Hashable {}
