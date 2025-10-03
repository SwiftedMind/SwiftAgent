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
	/// The request to the provider could not be completed before reaching the model.
	case requestFailed(RequestFailureContext)
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
		case let .requestFailed(context):
			switch context.reason {
			case .invalidRequestConfiguration:
				return "Failed to create provider request: \(context.detail)"
			case .networkFailure:
				return "Could not contact provider: \(context.detail)"
			case .invalidResponse:
				return "Provider response was not valid: \(context.detail)"
			case .decodingFailure:
				return "Could not decode provider response: \(context.detail)"
			}
		case let .providerError(context):
			switch context.category {
			case .authentication:
				return "Provider authentication failed: \(context.message)"
			case .permissionDenied:
				return "Provider denied the request: \(context.message)"
			case .requestInvalid:
				return "Provider rejected the request: \(context.message)"
			case .resourceMissing:
				return "Requested provider resource was not found: \(context.message)"
			case .server:
				return "Provider is temporarily unavailable: \(context.message)"
			case .unknown:
				return "Provider error: \(context.message)"
			}
		case let .streamingFailure(context):
			if let detail = context.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
				return "Streaming failed: \(detail)"
			}
			switch context.reason {
			case .responseFailed:
				return "Streaming failed: provider response failed"
			case .responseIncomplete:
				return "Streaming failed: provider response incomplete"
			case .errorEvent:
				return "Streaming failed due to provider error event"
			case .transportFailure:
				return "Streaming failed due to transport failure"
			case .decodingFailure:
				return "Streaming failed: could not decode provider updates"
			case .cancelled:
				return "Streaming cancelled"
			}
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
	/// Context information for request failures that occur before reaching the provider model.
	struct RequestFailureContext: Sendable {
		/// Categorises the nature of the request failure.
		public enum Reason: Sendable {
			case invalidRequestConfiguration
			case networkFailure
			case invalidResponse
			case decodingFailure
		}

		/// Why the request failed.
		public var reason: Reason
		/// Additional human readable context about the failure.
		public var detail: String
		/// The underlying error if the system reported one.
		public var underlyingError: (any Error)?

		public init(
			reason: Reason,
			detail: String,
			underlyingError: (any Error)? = nil
		) {
			self.reason = reason
			self.detail = detail
			self.underlyingError = underlyingError
		}
	}
}

// (Removed) ServiceQuotaExceededContext: quota and rate limit issues are represented via `providerError`.

public extension GenerationError {
	/// Context information for provider errors reported by the backend.
	struct ProviderErrorContext: Sendable {
		/// High-level categories for provider originated errors.
		public enum Category: Sendable {
			case authentication
			case permissionDenied
			case requestInvalid
			case resourceMissing
			case server
			case unknown
		}

		/// The classified category for the error.
		public var category: Category
		/// The human-readable message provided by the backend.
		public var message: String
		/// The HTTP status code if the backend provided one.
		public var statusCode: Int?
		/// The provider supplied error code, if any.
		public var code: String?
		/// The provider supplied error type, if any.
		public var type: String?
		/// The provider supplied parameter hint, if any.
		public var parameter: String?
		/// An underlying system error if one is available (for instance, decoding errors).
		public var underlyingError: (any Error)?

		public init(
			message: String,
			code: String? = nil,
			category: Category = .unknown,
			statusCode: Int? = nil,
			type: String? = nil,
			parameter: String? = nil,
			underlyingError: (any Error)? = nil
		) {
			self.category = category
			self.message = message
			self.statusCode = statusCode
			self.code = code
			self.type = type
			self.parameter = parameter
			self.underlyingError = underlyingError
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
