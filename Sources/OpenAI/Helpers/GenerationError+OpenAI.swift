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

	/// Maps an OpenAI streaming error event to a GenerationError.
	static func fromStreamErrorEvent(
		code: String?,
		type: String,
		message: String,
		param: String?
	) -> GenerationError {
		let category = categorizeStreamError(code: code, type: type)
		let context = GenerationError.ProviderErrorContext(
			message: message,
			code: code,
			category: category,
			type: type,
			parameter: param
		)
		return .providerError(context)
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

		return .providerError(
			ProviderErrorContext(
				message: message,
				code: apiError?.code,
				category: GenerationError.categoryForHTTPStatus(statusCode),
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

	/// Maps streaming error events to a provider error category using string matching as fallback.
	/// Prefers structured error codes over fuzzy string matching when available.
	static func categorizeStreamError(code: String?, type: String?) -> GenerationError.ProviderErrorContext.Category {
		let normalizedValues = [code, type]
			.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
		guard !normalizedValues.isEmpty else { return .unknown }

		let contains: ([String]) -> Bool = { keywords in
			normalizedValues.contains { value in keywords.contains { value.contains($0) } }
		}

		if contains(["auth", "token", "key", "credential"]) {
			return .authentication
		}
		if contains(["permission", "forbidden", "denied", "unauthorized"]) {
			return .permissionDenied
		}
		if contains(["not_found", "missing", "unknown_model", "unknown_tool"]) {
			return .resourceMissing
		}
		if contains(["invalid", "unsupported", "conflict", "parameter", "limit", "quota", "rate"]) {
			return .requestInvalid
		}
		if contains(["server", "internal", "unavailable", "timeout", "overloaded"]) {
			return .server
		}
		return .unknown
	}
}
