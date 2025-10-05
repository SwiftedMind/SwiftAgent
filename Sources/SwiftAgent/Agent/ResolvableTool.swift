// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol ResolvableTool<Session>: Equatable where Self: SwiftAgentTool {
	/// The type returned when this tool is resolved.
	///
	/// Defaults to `Void` for tools that don't need custom resolution logic.
	/// Override to return domain-specific types that represent the resolved tool execution.
	associatedtype Session: LanguageModelProvider

	/// Resolves a tool run into a domain-specific result.
	///
	/// This method is called after the tool's arguments have been parsed and any output
	/// has been matched from the conversation transcript. Use this to transform the
	/// raw tool call data into meaningful domain objects.
	///
	/// - Parameter run: The tool run containing typed arguments and optional output
	/// - Returns: A resolved representation of the tool execution
	func resolve(_ run: ToolRun<Self>) -> Session.ResolvedToolRun

	func resolvePartially(_ run: PartialToolRun<Self>) -> Session.PartiallyResolvedToolRun
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
	) throws -> Session.ResolvedToolRun {
		try resolve(run(for: arguments, output: output))
	}

	func resolvePartially(
		arguments: GeneratedContent,
		output: GeneratedContent?,
	) throws -> Session.PartiallyResolvedToolRun {
		let partialRun = try partialRun(for: arguments, output: output)
		return resolvePartially(partialRun)
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
	private func run(for arguments: GeneratedContent, output: GeneratedContent?) throws -> ToolRun<Self> {
		let parsedArguments = try self.arguments(from: arguments)

		guard let output else {
			return ToolRun(
				arguments: parsedArguments,
				_arguments: arguments,
				_output: output,
			)
		}

		do {
			return try ToolRun(
				arguments: parsedArguments,
				output: self.output(from: output),
				_arguments: arguments,
				_output: output,
			)
		} catch {
			guard let problem = problem(from: output) else {
				throw error
			}

			return ToolRun(
				arguments: parsedArguments,
				problem: problem,
				_arguments: arguments,
				_output: output,
			)
		}
	}

	/// Converts raw GeneratedContent to strongly typed Arguments.
	///
	/// - Parameter generatedContent: The raw content to convert
	/// - Returns: Typed arguments instance
	/// - Throws: Conversion errors
	private func arguments(from generatedContent: GeneratedContent) throws -> Arguments {
		try Arguments(generatedContent)
	}

	private func partialRun(for arguments: GeneratedContent, output: GeneratedContent?) throws -> PartialToolRun<Self> {
		let parsedArguments = try partialArguments(from: arguments)

		guard let output else {
			return PartialToolRun(
				arguments: parsedArguments,
				_arguments: arguments,
				_output: output,
			)
		}

		do {
			return try PartialToolRun(
				arguments: parsedArguments,
				output: self.output(from: output),
				_arguments: arguments,
				_output: output,
			)
		} catch {
			guard let problem = problem(from: output) else { throw error }

			return PartialToolRun(
				arguments: parsedArguments,
				problem: problem,
				_arguments: arguments,
				_output: output,
			)
		}
	}

	private func partialArguments(from generatedContent: GeneratedContent) throws -> Arguments.PartiallyGenerated {
		try Arguments.PartiallyGenerated(generatedContent)
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

		return try Output(generatedContent)
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
