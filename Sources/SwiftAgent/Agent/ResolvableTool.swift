// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol ResolvableTool<Provider>: SwiftAgentTool {
	/// The type returned when this tool is resolved.
	///
	/// Defaults to `Void` for tools that don't need custom resolution logic.
	/// Override to return domain-specific types that represent the resolved tool execution.
	associatedtype Provider: LanguageModelProvider

	/// Resolves a tool run into a domain-specific result.
	///
	/// This method is called after the tool's arguments have been parsed and any output
	/// has been matched from the conversation transcript. Use this to transform the
	/// raw tool call data into meaningful domain objects.
	///
	/// - Parameter run: The tool run containing typed arguments and optional output
	/// - Returns: A resolved representation of the tool execution
	func resolve(_ run: ToolRun<Self>) -> Provider.ResolvedToolRun

	func resolveStreaming(_ run: StreamingToolRun<Self>) -> Provider.ResolvedStreamingToolRun
}

public extension ResolvableTool {
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
	func resolve(
		arguments: GeneratedContent,
		output: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		try resolve(run(for: arguments, output: output))
	}

	func resolveStreaming(
		arguments: GeneratedContent,
		output: GeneratedContent?,
	) throws -> Provider.ResolvedStreamingToolRun {
		let streamingToolRun = try partialRun(for: arguments, output: output)
		return resolveStreaming(streamingToolRun)
	}
}

package extension ResolvableTool {
	/// Creates a strongly typed tool run from raw content.
	///
	/// - Parameters:
	///   - arguments: Raw argument content from the AI model
	///   - output: Optional raw output content
	/// - Returns: A typed ToolRun instance
	/// - Throws: Conversion errors if content cannot be parsed
	private func run(
		for argumentsContent: GeneratedContent,
		output outputContent: GeneratedContent?,
	) throws -> ToolRun<Self> {
		let arguments = try Arguments(argumentsContent)

		guard let outputContent else {
			return ToolRun(
				arguments: arguments,
				_arguments: argumentsContent,
				_output: outputContent,
			)
		}

		do {
			return try ToolRun(
				arguments: arguments,
				output: Output(outputContent),
				_arguments: argumentsContent,
				_output: outputContent,
			)
		} catch {
			guard let problem = problem(from: outputContent) else {
				throw error
			}

			return ToolRun(
				arguments: arguments,
				problem: problem,
				_arguments: argumentsContent,
				_output: outputContent,
			)
		}
	}

	private func partialRun(
		for argumentsContent: GeneratedContent,
		output outputContent: GeneratedContent?,
	) throws -> StreamingToolRun<Self> {
		let arguments = try Arguments.PartiallyGenerated(argumentsContent)

		guard let outputContent else {
			return StreamingToolRun(
				arguments: arguments,
				_arguments: argumentsContent,
				_output: outputContent,
			)
		}

		do {
			return try StreamingToolRun(
				arguments: arguments,
				output: Output(outputContent),
				_arguments: argumentsContent,
				_output: outputContent,
			)
		} catch {
			guard let problem = problem(from: outputContent) else { throw error }

			return StreamingToolRun(
				arguments: arguments,
				problem: problem,
				_arguments: argumentsContent,
				_output: outputContent,
			)
		}
	}

	private func problem(from generatedContent: GeneratedContent) -> ToolRun<Self>.Problem? {
		guard
			let problemReport = try? ProblemReport(generatedContent),
			problemReport.error else {
			return nil
		}

		return ToolRun<Self>.Problem(
			reason: problemReport.reason,
			json: generatedContent.jsonString,
			details: ProblemReportDetailsExtractor.values(from: generatedContent),
		)
	}
}
