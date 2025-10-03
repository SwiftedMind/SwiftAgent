// By Dennis Müller

import Foundation

public extension GenerationError {
	/// Maps a generic `HTTPError` produced by the networking layer to a `GenerationError`.
	///
	/// - Parameters:
	///   - httpError: The error produced by the HTTP client.
	///   - override: Optional provider-specific override. Return a value to override
	///     the default mapping for the given `httpError`, or return `nil` to fall back
	///     to the default mapping. Keep this focused and only override what truly needs
	///     provider context (for example, decoding a provider error payload for status codes).
	static func fromHTTP(
		_ httpError: HTTPError,
		override: ((HTTPError) -> GenerationError?)? = nil,
	) -> GenerationError {
		if let override, let mapped = override(httpError) {
			return mapped
		}

		switch httpError {
		case .invalidURL:
			return .requestFailed(
				reason: .invalidRequestConfiguration,
				detail: "The configured provider endpoint URL is invalid.",
			)
		case let .requestFailed(underlying):
			return .requestFailed(
				reason: .networkFailure,
				detail: underlying.localizedDescription,
				underlyingError: underlying,
			)
		case .invalidResponse:
			return .requestFailed(
				reason: .invalidResponse,
				detail: "The provider returned a response without HTTP information.",
			)
		case let .decodingFailed(underlying, _):
			return .requestFailed(
				reason: .decodingFailure,
				detail: underlying.localizedDescription,
				underlyingError: underlying,
			)
		case let .unacceptableStatus(statusCode, data):
			let message = bestMessage(for: statusCode, data: data)
			if statusCode == 408 {
				return .requestFailed(
					reason: .networkFailure,
					detail: message,
				)
			}

			return .providerError(
				message: message,
				category: category(for: statusCode),
				statusCode: statusCode,
			)
		}
	}
}

private extension GenerationError {
	static func bestMessage(for statusCode: Int, data: Data?) -> String {
		if let data, let extracted = HTTPErrorMessageExtractor.extract(from: data) {
			let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmed.isEmpty {
				return trimmed
			}
		}

		return defaultMessage(forStatusCode: statusCode)
	}

	static func defaultMessage(forStatusCode statusCode: Int) -> String {
		let localized = HTTPURLResponse.localizedString(forStatusCode: statusCode)
		let trimmed = localized.trimmingCharacters(in: .whitespacesAndNewlines)
		if !trimmed.isEmpty { return trimmed.capitalized }
		return "HTTP status \(statusCode)"
	}

	static func category(for statusCode: Int) -> ProviderErrorContext.Category {
		switch statusCode {
		case 401:
			.authentication
		case 403:
			.permissionDenied
		case 404:
			.resourceMissing
		case 400, 409, 422, 429:
			.requestInvalid
		case 500...599:
			.server
		case 400...499:
			.requestInvalid
		default:
			.unknown
		}
	}
}
