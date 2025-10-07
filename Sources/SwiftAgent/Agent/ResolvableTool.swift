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
		argumentsContent: GeneratedContent,
		outputContent: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let arguments = try Arguments(argumentsContent)
		let toolRun = try toolRun(
			id: id,
			.completed(arguments),
			argumentsContent: argumentsContent,
			outputContent: outputContent,
		)
		return resolve(toolRun)
	}

	func resolveInProgress(
		id: String,
		argumentsContent: GeneratedContent,
		outputContent: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let arguments = try Arguments.PartiallyGenerated(argumentsContent)
		let toolRun = try toolRun(
			id: id,
			.inProgress(arguments),
			argumentsContent: argumentsContent,
			outputContent: outputContent,
		)
		return resolve(toolRun)
	}

	func resolveFailed(
		id: String,
		error: TranscriptResolutionError.ToolRunResolution,
		argumentsContent: GeneratedContent,
		outputContent: GeneratedContent?,
	) throws -> Provider.ResolvedToolRun {
		let toolRun = try toolRun(
			id: id,
			.failed(error),
			argumentsContent: argumentsContent,
			outputContent: outputContent,
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
		argumentsContent: GeneratedContent,
		outputContent: GeneratedContent?,
	) throws -> ToolRun<Self> {
		guard let outputContent else {
			return ToolRun(
				id: id,
				arguments: arguments,
				argumentsContent: argumentsContent,
				outputContent: outputContent,
			)
		}

		do {
			return try ToolRun(
				id: id,
				arguments: arguments,
				output: Output(outputContent),
				argumentsContent: argumentsContent,
				outputContent: outputContent,
			)
		} catch {
			guard let problem = problem(from: outputContent) else {
				throw error
			}

			return ToolRun(
				id: id,
				arguments: arguments,
				problem: problem,
				argumentsContent: argumentsContent,
				outputContent: outputContent,
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
