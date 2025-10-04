// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(.openAI)
private final class ExampleSession {}

@Suite("OpenAIAdapter - Error Handling")
struct OpenAIErrorHandling {
	typealias Transcript = SwiftAgent.Transcript

	@Test("'CancellationError' is thrown")
	func cancellationError() async throws {
		let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
			recordedResponse: .init(body: "", statusCode: 200, delay: .milliseconds(10)),
		)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let session = ExampleSession(instructions: "", configuration: configuration)

		do {
			let task = Task {
				try await session.respond(
					to: "prompt",
					using: .gpt5,
					options: .init(include: [.reasoning_encryptedContent]),
				)
			}
			task.cancel()
			try await print(task.value)

			Issue.record("Expected respond to throw")
		} catch is CancellationError {
		} catch {
			Issue.record("Expected CancellationError but received \(error)")
		}
	}

	@Test("'insufficient_quote' is thrown")
	func errorEventSurfacesFailure() async throws {
		let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
			recordedResponse: .init(body: insufficientQuotaErrorResponse, statusCode: 429),
		)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let session = ExampleSession(instructions: "", configuration: configuration)

		do {
			_ = try await session.respond(
				to: "prompt",
				using: .gpt5,
				options: .init(include: [.reasoning_encryptedContent]),
			)
			Issue.record("Expected respond to throw")
		} catch {
			guard let generationError = error as? GenerationError else {
				Issue.record("Expected GenerationError but received \(error)")
				return
			}

			switch generationError {
			case let .providerError(context):
				#expect(context.code == "insufficient_quota")
			default:
				Issue.record("Unexpected error thrown: \(generationError)")
			}
		}
	}

	@Test("'invalid_api_key' is thrown")
	func invalidAPIKeyError() async throws {
		let mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
			recordedResponse: .init(body: missingAPIKeyErrorResponse, statusCode: 401),
		)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let session = ExampleSession(instructions: "", configuration: configuration)

		do {
			_ = try await session.respond(
				to: "prompt",
				using: .gpt5,
				options: .init(include: [.reasoning_encryptedContent]),
			)
			Issue.record("Expected respond to throw")
		} catch {
			guard let generationError = error as? GenerationError else {
				Issue.record("Expected GenerationError but received \(error)")
				return
			}

			switch generationError {
			case let .providerError(context):
				#expect(context.code == "invalid_api_key")
			default:
				Issue.record("Unexpected error thrown: \(generationError)")
			}
		}
	}
}

// MARK: - Mock Responses

private let insufficientQuotaErrorResponse: String = #"""
{
	"error": {
		"message": "You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors.",
		"type": "insufficient_quota",
		"param": null,
		"code": "insufficient_quota"
	}
}
"""#

private let missingAPIKeyErrorResponse: String = #"""
{
  "error": {
    "message": "Incorrect API key provided: ''. You can find your API key at https://platform.openai.com/account/api-keys.",
    "type": "invalid_request_error",
    "param": null,
    "code": "invalid_api_key"
  }
}
"""#
