// By Dennis Müller

import Foundation
import Internal
import OpenAI
import SwiftAgent

public extension GenerationError {
	static func from(_ httpError: HTTPError) -> GenerationError {
		switch httpError {
		case .invalidURL:
			<#code#>
		case let .requestFailed(underlying):
			<#code#>
		case .invalidResponse:
			<#code#>
		case let .unacceptableStatus(code, data):
			// TODO: Special case for 401 (maybe others as well?) since that is the same for every provider
			let openAIError = try JSONDecoder().decode(APIErrorResponse.self, from: data)
			return
		case let .decodingFailed(underlying, data):
			<#code#>
		}
	}
}
