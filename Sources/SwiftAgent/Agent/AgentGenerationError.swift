// By Dennis Müller

import Foundation

/// Errors that can occur during AI model generation in SwiftAgent.
///
/// These errors represent various failure scenarios when a `ModelSession` attempts to generate content,
/// including tool calling failures, content parsing issues, and model refusals.
public enum AgentGenerationError: Error, LocalizedError {
	/// The model returned structured content when none was expected.
	case unexpectedStructuredResponse(UnexpectedStructuredResponseContext)
	/// The model attempted to call a tool that is not supported or registered.
	case unsupportedToolCalled(UnsupportedToolCalledContext)
	/// The model returned empty content when specific content was expected.
	case emptyMessageContent(EmptyMessageContentContext)
	/// Failed to parse structured content returned by the model.
	case structuredContentParsingFailed(StructuredContentParsingFailedContext)
	/// The model refused to generate the requested content type.
	case contentRefusal(ContentRefusalContext)
	/// An unknown or unspecified generation error occurred.
	case unknown

	/// A localized description of the error suitable for display to users.
	public var errorDescription: String? {
		switch self {
		case .unexpectedStructuredResponse:
			"Received unexpected structured response from model"
		case let .unsupportedToolCalled(context):
			"Model called unsupported tool: \(context.toolName)"
		case let .emptyMessageContent(context):
			"Model returned empty content when expecting \(context.expectedType)"
		case let .structuredContentParsingFailed(context):
			"Failed to parse structured content: \(context.underlyingError)"
		case let .contentRefusal(context):
			"Model refused to generate content for \(context.expectedType)"
		case .unknown:
			"Unknown generation error"
		}
	}
}

public extension AgentGenerationError {
	/// Context information for unsupported tool call errors.
	struct UnsupportedToolCalledContext: Sendable {
		/// The name of the tool that the model tried to call.
		var toolName: String

		public init(toolName: String) {
			self.toolName = toolName
		}
	}
}

public extension AgentGenerationError {
	/// Context information for unexpected structured response errors.
	struct UnexpectedStructuredResponseContext: Sendable {
		public init() {}
	}

	/// Context information for empty message content errors.
	struct EmptyMessageContentContext: Sendable {
		/// The type that was expected to be generated.
		var expectedType: String

		public init(expectedType: String) {
			self.expectedType = expectedType
		}
	}

	/// Context information for structured content parsing failures.
	struct StructuredContentParsingFailedContext: Sendable {
		/// The raw content that failed to parse.
		var rawContent: String
		/// The underlying parsing error.
		var underlyingError: String

		public init(rawContent: String, underlyingError: Error) {
			self.rawContent = rawContent
			self.underlyingError = underlyingError.localizedDescription
		}
	}

	/// Context information for content refusal errors.
	struct ContentRefusalContext: Sendable {
		/// The type that was being generated when content was refused.
		var expectedType: String

		public init(expectedType: String) {
			self.expectedType = expectedType
		}
	}
}
