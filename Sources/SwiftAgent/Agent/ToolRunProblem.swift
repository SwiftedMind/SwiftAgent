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

	/// Creates a recoverable tool problem from arbitrary generated content.
	///
	/// - Parameters:
	///   - reason: Optional description explaining the failure. Defaults to `nil`.
	///   - content: Any value that can be converted into ``GeneratedContent``.
	public init(reason: String? = nil, content: some ConvertibleToGeneratedContent) {
		generatedContent = content.generatedContent
		self.reason = reason
	}

	/// Creates a recoverable tool problem from pre-built generated content.
	///
	/// - Parameters:
	///   - reason: Optional description explaining the failure. Defaults to `nil`.
	///   - generatedContent: The payload to forward to the model.
	public init(reason: String? = nil, generatedContent: GeneratedContent) {
		self.generatedContent = generatedContent
		self.reason = reason
	}

	public var errorDescription: String? {
		reason ?? "Recoverable tool problem"
	}
}
