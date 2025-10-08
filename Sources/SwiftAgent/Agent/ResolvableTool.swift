// By Dennis Müller

import Foundation
import FoundationModels
import Internal

public protocol ResolvableTool<Provider>: SwiftAgentTool {
	associatedtype Provider: LanguageModelProvider
	func resolve(_ run: ToolRun<Self>) -> Provider.ResolvedToolRun
}

package extension ResolvableTool {
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
	func resolveCompleted(
		id: String,
		rawContent: GeneratedContent,
		rawOutput: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let arguments = try Arguments(rawContent)
		let toolRun = try toolRun(
			id: id,
			.completed(arguments),
			rawContent: rawContent,
			rawOutput: rawOutput,
		)
		return resolve(toolRun)
	}

	func resolveInProgress(
		id: String,
		rawContent: GeneratedContent,
		rawOutput: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let arguments = try Arguments.PartiallyGenerated(rawContent)
		let toolRun = try toolRun(
			id: id,
			.inProgress(arguments),
			rawContent: rawContent,
			rawOutput: rawOutput,
		)
		return resolve(toolRun)
	}

	func resolveFailed(
		id: String,
		error: TranscriptResolutionError.ToolRunResolution,
		rawContent: GeneratedContent,
		rawOutput: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let toolRun = try toolRun(
			id: id,
			.failed(error),
			rawContent: rawContent,
			rawOutput: rawOutput,
		)
		return resolve(toolRun)
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
	func toolRun(
		id: String,
		_ arguments: ToolRun<Self>.Arguments,
		rawContent: GeneratedContent,
		rawOutput: GeneratedContent?,
	) throws -> ToolRun<Self> {
		guard let rawOutput else {
			return ToolRun(
				id: id,
				arguments: arguments,
				rawContent: rawContent,
				rawOutput: rawOutput,
			)
		}

		do {
			return try ToolRun(
				id: id,
				arguments: arguments,
				output: Output(rawOutput),
				rawContent: rawContent,
				rawOutput: rawOutput,
			)
		} catch {
			guard let problem = problem(from: rawOutput) else {
				throw error
			}

			return ToolRun(
				id: id,
				arguments: arguments,
				problem: problem,
				rawContent: rawContent,
				rawOutput: rawOutput,
			)
		}
	}

	func problem(from generatedContent: GeneratedContent) -> ToolRun<Self>.Problem? {
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
