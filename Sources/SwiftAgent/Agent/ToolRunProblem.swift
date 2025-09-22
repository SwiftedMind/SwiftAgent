// By Dennis Müller

import Foundation
import FoundationModels

/// An error that indicates a tool run produced a recoverable problem.
///
/// Throw this error from a tool's ``AgentTool/call(arguments:)`` implementation when the
/// invocation cannot be completed successfully but the agent should be able to recover by
/// inspecting the returned payload and taking another action. Instead of aborting the agent run,
/// SwiftAgent will forward the provided ``GeneratedContent`` back to the model as the tool output.
public struct ToolRunProblem: Error, LocalizedError, Sendable {
	/// A machine-readable payload describing the failure. This content is forwarded to the model
	/// exactly like a successful tool output, allowing the model to reason about the failure.
	public let generatedContent: GeneratedContent

	/// A human-readable description of the recoverable problem.
	public let reason: String?

	private static let fallbackReason = "Recoverable tool problem"

	/// Creates a recoverable tool problem from arbitrary generated content.
	///
	/// - Parameters:
	///   - reason: Optional description explaining the failure. Defaults to `nil`.
	///   - content: Any value that can be converted into ``GeneratedContent``.
	public init(reason: String? = nil, content: some ConvertibleToGeneratedContent) {
		let resolvedReason = reason ?? Self.fallbackReason
		let problemReport = ProblemReport(reason: resolvedReason, details: content.generatedContent)
		generatedContent = problemReport.generatedContent
		self.reason = resolvedReason
	}

	/// Creates a recoverable tool problem from pre-built generated content.
	///
	/// - Parameters:
	///   - reason: Optional description explaining the failure. Defaults to `nil`.
	///   - generatedContent: The payload to forward to the model.
	public init(reason: String? = nil, generatedContent: GeneratedContent) {
		let resolvedReason = reason ?? Self.fallbackReason
		let problemReport = ProblemReport(reason: resolvedReason, details: generatedContent)
		self.generatedContent = problemReport.generatedContent
		self.reason = resolvedReason
	}

	/// Convenience initializer that wraps string-keyed details into a structured payload.
	///
	/// - Parameters:
	///   - reason: Description of the failure that the agent can surface to the user.
	///   - details: Optional machine-readable information that helps the agent recover.
	public init(reason: String, details: [String: String]? = nil) {
		let detailsContent = details.flatMap(Self.generateDetailsContent)
		let problemReport = ProblemReport(reason: reason, details: detailsContent)
		generatedContent = problemReport.generatedContent
		self.reason = reason
	}

	public var errorDescription: String? {
		reason ?? Self.fallbackReason
	}
}

@Generable
private struct ProblemReport {
	var error: Bool = true
	var reason: String
	var details: GeneratedContent?
}

private extension ToolRunProblem {
	static func generateDetailsContent(from details: [String: String]) -> GeneratedContent? {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]

		guard let data = try? encoder.encode(details), let jsonString = String(data: data, encoding: .utf8) else {
			return nil
		}

		return try? GeneratedContent(json: jsonString)
	}
}
