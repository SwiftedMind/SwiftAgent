// By Dennis Müller

import Foundation
import Internal
import OpenAI
import SwiftAgent

public extension GenerationError {
	static func from(_ httpError: HTTPError) -> GenerationError {
		switch httpError {
		case .invalidURL:
			.requestFailed(
				GenerationError.RequestFailureContext(
					reason: .invalidRequestConfiguration,
					detail: "The configured provider endpoint URL is invalid.",
					underlyingError: nil
				)
			)
		case let .requestFailed(underlying):
			.requestFailed(
				GenerationError.RequestFailureContext(
					reason: .networkFailure,
					detail: underlying.localizedDescription
				)
			)
		case .invalidResponse:
			.requestFailed(
				GenerationError.RequestFailureContext(
					reason: .invalidResponse,
					detail: "The provider returned a response without HTTP information."
				)
			)
		case let .unacceptableStatus(code, data):
			mapStatusError(statusCode: code, data: data)
		case let .decodingFailed(underlying, _):
			.requestFailed(
				GenerationError.RequestFailureContext(
					reason: .decodingFailure,
					detail: underlying.localizedDescription,
					underlyingError: underlying
				)
			)
		}
	}
}

private extension GenerationError {
	static func mapStatusError(statusCode: Int, data: Data?) -> GenerationError {
		let apiError = decodeAPIError(from: data)
		let message = bestMessage(for: statusCode, apiError: apiError)

		switch statusCode {
		case 401:
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .authentication,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		case 403:
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .permissionDenied,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		case 404:
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .resourceMissing,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		case 400, 409, 422, 429:
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .requestInvalid,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		case 500...599:
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .server,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		case 408:
			return .requestFailed(
				GenerationError.RequestFailureContext(
					reason: .networkFailure,
					detail: message
				)
			)
		default:
			if (400...499).contains(statusCode) {
				return .providerError(
					ProviderErrorContext(
						message: message,
						code: apiError?.code,
						category: .requestInvalid,
						statusCode: statusCode,
						type: apiError?.type,
						parameter: apiError?.param
					)
				)
			}
			return .providerError(
				ProviderErrorContext(
					message: message,
					code: apiError?.code,
					category: .unknown,
					statusCode: statusCode,
					type: apiError?.type,
					parameter: apiError?.param
				)
			)
		}
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
