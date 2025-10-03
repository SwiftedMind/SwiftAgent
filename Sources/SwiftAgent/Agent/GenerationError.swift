// By Dennis Müller

import Foundation

/// Errors that can occur during AI model generation in SwiftAgent.
///
/// These errors represent various failure scenarios when a `LanguageModelProvider` attempts to generate content,
/// including tool calling failures, content parsing issues, and model refusals.
public enum GenerationError: Error, LocalizedError {
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
	/// The provider reported that the caller exceeded the available quota.
	case serviceQuotaExceeded(ServiceQuotaExceededContext)
	/// The provider reported an error that does not have a dedicated case yet.
	case providerError(ProviderErrorContext)
	/// The streaming pipeline failed while consuming incremental updates from the provider.
	case streamingFailure(StreamingFailureContext)
	/// An unknown or unspecified generation error occurred.
	case unknown

	/// A localized description of the error suitable for display to users.
	public var errorDescription: String? {
		switch self {
		case .unexpectedStructuredResponse:
			return "Received unexpected structured response from model"
		case let .unsupportedToolCalled(context):
			return "Model called unsupported tool: \(context.toolName)"
		case let .emptyMessageContent(context):
			return "Model returned empty content when expecting \(context.expectedType)"
		case let .structuredContentParsingFailed(context):
			return "Failed to parse structured content: \(context.underlyingError)"
		case let .contentRefusal(context):
			if let reason = context.reason, !reason.isEmpty {
				return "Model refused to generate content for \(context.expectedType): \(reason)"
			}
			return "Model refused to generate content for \(context.expectedType)"
		case let .serviceQuotaExceeded(context):
			return "Provider quota exceeded: \(context.message)"
		case let .providerError(context):
			return "Provider error: \(context.message)"
		case let .streamingFailure(context):
			return "Streaming failed: \(context.detail)"
		case .unknown:
			return "Unknown generation error"
		}
	}
}

public extension GenerationError {
	/// Context information for unsupported tool call errors.
	struct UnsupportedToolCalledContext: Sendable {
		/// The name of the tool that the model tried to call.
		var toolName: String

		public init(toolName: String) {
			self.toolName = toolName
		}
	}
}

public extension GenerationError {
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
		var underlyingError: any Error

		public init(rawContent: String, underlyingError: any Error) {
			self.rawContent = rawContent
			self.underlyingError = underlyingError
		}
	}

	/// Context information for content refusal errors.
	struct ContentRefusalContext: Sendable {
		/// The type that was being generated when content was refused.
		var expectedType: String
		/// The human-readable reason provided by the model, if available.
		var reason: String?

		public init(expectedType: String, reason: String? = nil) {
			self.expectedType = expectedType
			self.reason = reason
		}
	}
}

public extension GenerationError {
	/// Context information for provider errors reported by the backend.
	struct ServiceQuotaExceededContext: Sendable {
		/// The human-readable message provided by the backend.
		public var message: String

		public init(message: String) {
			self.message = message
		}
	}
}

public extension GenerationError {
	/// Context information for provider errors reported by the backend.
	struct ProviderErrorContext: Sendable {
		/// The human-readable message provided by the backend.
		public var message: String
		
		public var code: String?

		public init(message: String, code: String?) {
			self.message = message
			self.code = code
		}
	}
}

public extension GenerationError {
	/// Additional details about failures that occur while streaming provider updates.
	struct StreamingFailureContext: Sendable {
		/// A categorisation of the streaming failure.
		public enum Reason: Sendable {
			case responseFailed
			case responseIncomplete
			case errorEvent
			case transportFailure
			case decodingFailure
			case cancelled
		}

		/// The reason why streaming failed.
		public var reason: Reason
		/// A human-readable explanation of the failure.
		public var detail: String?

		public var code: String?
		/// Additional provider error details when the backend supplied them.
		public var providerError: ProviderErrorContext?

		public init(
			reason: Reason,
			detail: String?,
			code: String? = nil,
			providerError: ProviderErrorContext? = nil
		) {
			self.reason = reason
			self.detail = detail
			self.code = code
			self.providerError = providerError
		}
	}
}
