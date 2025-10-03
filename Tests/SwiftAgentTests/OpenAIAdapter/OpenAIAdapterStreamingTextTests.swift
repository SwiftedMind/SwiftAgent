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

@Suite("OpenAIAdapter - Streaming - Text") @MainActor
struct OpenAIAdapterStreamingTextTests {
	typealias Transcript = SwiftAgent.Transcript

	// MARK: - Properties

	private let session: ExampleSession
	private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

	// MARK: - Initialization

	init() async {
		mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(recordedResponse: helloWorldResponse)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		session = ExampleSession(instructions: "", configuration: configuration)
	}

	@Test("Single response")
	func singleResponse() async throws {
		let generatedTranscript = try await processStreamResponse()

		await validateHTTPRequests()
		try validateTranscript(generatedTranscript: generatedTranscript)
	}

	// MARK: - Private Test Helper Methods

	private func processStreamResponse() async throws -> Transcript {
		let stream = try session.streamResponse(
			to: "input",
			using: .gpt5,
			options: .init(include: [.reasoning_encryptedContent]),
		)

		var generatedTranscript = Transcript()

		for try await snapshot in stream {
			generatedTranscript.append(contentsOf: snapshot.transcript.entries)
		}

		return generatedTranscript
	}

	private func validateHTTPRequests() async {
		let recordedRequests = await mockHTTPClient.recordedRequests()
		#expect(recordedRequests.count == 1)

		guard case let .inputItemList(items) = recordedRequests[0].body.input else {
			Issue.record("Recorded request body input is not .inputItemList")
			return
		}

		#expect(items.count == 1)

		guard case let .inputMessage(message)? = items.first else {
			Issue.record("Recorded request body input item is not .inputMessage")
			return
		}
		guard case let .textInput(text) = message.content else {
			Issue.record("Expected message content to be text input")
			return
		}

		#expect(text == "prompt")
	}

	private func validateTranscript(generatedTranscript: Transcript) throws {
		#expect(generatedTranscript.count == 2)

		guard case let .reasoning(reasoning) = generatedTranscript[0] else {
			Issue.record("First transcript entry is not .reasoning")
			return
		}

		#expect(reasoning.id == "rs_68d7eff985648196883d78673232885e07152cb8c6ac9072")
		#expect(reasoning.summary == [])

		guard case let .response(response) = generatedTranscript[1] else {
			Issue.record("Second transcript entry is not .response")
			return
		}

		#expect(response.id == "msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072")
		#expect(response.segments.count == 1)
		guard case let .text(textSegment) = response.segments.first else {
			Issue.record("Second transcript entry is not .text")
			return
		}

		#expect(textSegment.content == "Hello, World!")
	}
}

// MARK: - Mock Responses

private let helloWorldResponse: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"encrypted-1","summary":[]}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"encrypted-2","summary":[]}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":4,"output_index":1,"item":{"id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","type":"message","status":"in_progress","content":[],"role":"assistant"}}

event: response.content_part.added
data: {"type":"response.content_part.added","sequence_number":5,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":""}}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":6,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"delta":"Hello","logprobs":[],"obfuscation":"jWSe9qxZ10e"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":7,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"delta":",","logprobs":[],"obfuscation":"va6PVP8CfPATBqu"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":8,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"delta":" World","logprobs":[],"obfuscation":"MDmc2cWFSq"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":9,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"delta":"!","logprobs":[],"obfuscation":"Lp16bxK7EjYnEwq"}

event: response.output_text.done
data: {"type":"response.output_text.done","sequence_number":10,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"text":"Hello, World!","logprobs":[]}

event: response.content_part.done
data: {"type":"response.content_part.done","sequence_number":11,"item_id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","output_index":1,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":"Hello, World!"}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":12,"output_index":1,"item":{"id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"Hello, World!"}],"role":"assistant"}}

event: response.completed
data: {"type":"response.completed","sequence_number":13,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"encrypted-3","summary":[]},{"id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"Hello, World!"}],"role":"assistant"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":12,"input_tokens_details":{"cached_tokens":0},"output_tokens":10,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":22},"user":null,"metadata":{}}}
"""#
