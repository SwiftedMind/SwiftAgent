// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(for: .openAI)
private final class ExampleSession {}

@Suite("OpenAIAdapter - Streaming - Error Handling")
struct OpenAIAdapterStreamingErrorTests {
	typealias Transcript = SwiftAgent.Transcript

	// MARK: - Properties

	private let session: ExampleSession
	private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

	// MARK: - Initialization

	init() async {
		mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(recordedResponse: insufficientQuotaErrorResponse)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		session = ExampleSession(instructions: "", configuration: configuration)
	}

	@Test("Error event surfaces a failure")
	func errorEventSurfacesFailure() async throws {
		let stream = try session.streamResponse(
			to: "prompt",
			using: .gpt5,
			options: .init(include: [.reasoning_encryptedContent]),
		)

		do {
			for try await _ in stream {}
			Issue.record("Expected streamResponse to throw when an error event is received")
			return
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
}

// MARK: - Mock Responses

private let insufficientQuotaErrorResponse: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: error
data: {"type":"error","sequence_number":2,"error":{"type":"insufficient_quota","code":"insufficient_quota","message":"You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors.","param":null}}

event: response.failed
data: {"type":"response.failed","sequence_number":3,"response":{"id":"resp_0265b28bea036ff60068df845920648196938b4f36acdcee37","object":"response","created_at":1759478873,"status":"failed","background":false,"error":{"code":"insufficient_quota","message":"You exceeded your current quota, please check your plan and billing details. For more information on this error, read the docs: https://platform.openai.com/docs/guides/error-codes/api-errors."},"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}
"""#
