// By Dennis Müller

import Foundation

public extension GenerationError {
	/// Maps any error thrown while preparing or performing a request into `GenerationError`.
	static func fromRequest(
		_ error: any Error,
		httpErrorMapper: (HTTPError) -> GenerationError = { Self.fromHTTP($0) },
	) -> GenerationError {
		if let generationError = error as? GenerationError {
			return generationError
		}

		if let httpError = error as? HTTPError {
			return httpErrorMapper(httpError)
		}

		if let urlError = error as? URLError {
			return .requestFailed(
				reason: .networkFailure,
				detail: urlError.localizedDescription,
				underlyingError: urlError,
			)
		}

		if let decodingError = error as? DecodingError {
			return .requestFailed(
				reason: .decodingFailure,
				detail: decodingError.localizedDescription,
				underlyingError: decodingError,
			)
		}

		return .unknown
	}

	/// Maps streaming pipeline errors into `GenerationError`.
	static func fromStream(
		_ error: any Error,
		httpErrorMapper: (HTTPError) -> GenerationError = { Self.fromHTTP($0) },
	) -> GenerationError {
		if let generationError = error as? GenerationError {
			return generationError
		}

		if let httpError = error as? HTTPError {
			return httpErrorMapper(httpError)
		}

		if let sseError = error as? SSEError {
			switch sseError {
			case .invalidResponse:
				return .streamingFailure(
					reason: .transportFailure,
					detail: "The provider returned a response without HTTP information.",
				)
			case let .notEventStream(contentType):
				return .streamingFailure(
					reason: .transportFailure,
					detail: "Expected text/event-stream but received \(contentType ?? "unknown").",
				)
			case let .decodingFailed(underlying, _):
				return .streamingFailure(
					reason: .decodingFailure,
					detail: underlying.localizedDescription,
					providerError: nil,
				)
			}
		}

		if let urlError = error as? URLError {
			return .streamingFailure(
				reason: .transportFailure,
				detail: urlError.localizedDescription,
				providerError: nil,
			)
		}

		return .streamingFailure(
			reason: .transportFailure,
			detail: error.localizedDescription,
		)
	}

	/// Maps parsing errors from structured content into `GenerationError`.
	static func fromParsing(
		_ error: any Error,
		rawContent: String? = nil,
	) -> GenerationError {
		if let generationError = error as? GenerationError {
			return generationError
		}

		if let rawContent {
			return .structuredContentParsingFailed(
				StructuredContentParsingFailedContext(
					rawContent: rawContent,
					underlyingError: error,
				),
			)
		}

		if let decodingError = error as? DecodingError {
			return .requestFailed(
				reason: .decodingFailure,
				detail: decodingError.localizedDescription,
				underlyingError: decodingError,
			)
		}

		return .unknown
	}
}
