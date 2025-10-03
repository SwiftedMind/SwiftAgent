// By Dennis Müller

import Foundation
import Internal
import OpenAI
import SwiftAgent

public extension GenerationError {
	/// OpenAI-specific HTTP error mapping that delegates to the generic mapper
	/// and only overrides cases where the OpenAI error payload provides richer context.
	static func from(_ httpError: HTTPError) -> GenerationError {
		fromHTTP(httpError, override: openAIHTTPOverride)
	}
}

private extension GenerationError {
	/// Provider-specific override used by `fromHTTP(_:override:)`.
	/// Returns `nil` for cases where the generic mapping is sufficient.
	static func openAIHTTPOverride(_ httpError: HTTPError) -> GenerationError? {
		guard case let .unacceptableStatus(statusCode, data) = httpError else {
			return nil
		}

		// For request timeout, let the generic mapper apply its standard behavior.
		if statusCode == 408 { return nil }

		let apiError = decodeAPIError(from: data)
		let message = bestMessage(for: statusCode, apiError: apiError)

		let category: ProviderErrorContext.Category = switch statusCode {
		case 401: .authentication
		case 403: .permissionDenied
		case 404: .resourceMissing
		case 400, 409, 422, 429: .requestInvalid
		case 500...599: .server
		case 400...499: .requestInvalid
		default: .unknown
		}

		return .providerError(
			ProviderErrorContext(
				message: message,
				code: apiError?.code,
				category: category,
				statusCode: statusCode,
				type: apiError?.type,
				parameter: apiError?.param,
			),
		)
	}

	static func decodeAPIError(from data: Data?) -> APIError? {
		guard let data else { return nil }

		let decoder = JSONDecoder()
		do {
			return try decoder.decode(APIErrorResponse.self, from: data).error
		} catch {
			return nil
		}
	}

	static func bestMessage(for statusCode: Int, apiError: APIError?) -> String {
		if let message = apiError?.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			return message
		}
		let defaultMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
		let trimmed = defaultMessage.trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? "HTTP status \(statusCode)" : trimmed
	}
}
