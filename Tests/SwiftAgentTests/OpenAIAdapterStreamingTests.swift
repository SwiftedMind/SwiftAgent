// By Dennis Müller

import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

// TODO: Update HTTPClient to support multiple responses. Pass an array of responses and those are returned in turn

#tools {
	WeatherTool()
}

struct WeatherTool: SwiftAgentTool {
	var name: String = "get_weather"
	var description: String = "Get current temperature for a given location."

	@Generable
	struct Arguments {
		var location: String
	}
	
	func call(arguments: Arguments) async throws -> String {
		"Sunny"
	}
}

@Suite("OpenAIAdapter Streaming")
struct OpenAIAdapterStreamingTests {
	@Test("Streams text responses into transcript entries")
	func streamProducesResponseEntry() async throws {
		// Important: MUST be a raw string #""" """# to not mess up the escape symbols in there!
		let mockHTTPClient = MockHTTPClient(response: #"""
		event: response.created
		data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d7a3538cc48191841fb718106028930f91bcf2eb2355fd","object":"response","created_at":1758962515,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"City and country e.g. Bogotá, Colombia"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}
		
		event: response.in_progress
		data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d7a3538cc48191841fb718106028930f91bcf2eb2355fd","object":"response","created_at":1758962515,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"City and country e.g. Bogotá, Colombia"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}
		
		event: response.output_item.added
		data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_68d7a353ef008191815c6f969ee647cf0f91bcf2eb2355fd","type":"reasoning","summary":[]}}
		
		event: response.output_item.done
		data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_68d7a353ef008191815c6f969ee647cf0f91bcf2eb2355fd","type":"reasoning","summary":[]}}
		
		event: response.output_item.added
		data: {"type":"response.output_item.added","sequence_number":4,"output_index":1,"item":{"id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","type":"function_call","status":"in_progress","arguments":"","call_id":"call_D5cRqvTm9V47jb0OLVJJ4Lqm","name":"get_weather"}}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":5,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"{\"","obfuscation":"3a7Earsr2459fp"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":6,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"location","obfuscation":"JxuLp6kU"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":7,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"\":\"","obfuscation":"BJiZ1DOP12LUs"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":8,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"F","obfuscation":"jT8WAijVwl5AWv3"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":9,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"reib","obfuscation":"0tERgLo59JyQ"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":10,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"urg","obfuscation":"NrLPF9643Wh9U"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":11,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":" im","obfuscation":"7fHncFfhI2lsJ"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":12,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":" Bre","obfuscation":"xm9ig32UBcT6"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":13,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"is","obfuscation":"ESv8jvELfiIkkS"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":14,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"gau","obfuscation":"EaLkHJt5yZnrU"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":15,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":",","obfuscation":"yDaywu9WOb2yT8H"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":16,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":" Germany","obfuscation":"qrnVaUA3"}
		
		event: response.function_call_arguments.delta
		data: {"type":"response.function_call_arguments.delta","sequence_number":17,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"delta":"\"}","obfuscation":"24N2cTFc21N3cg"}
		
		event: response.function_call_arguments.done
		data: {"type":"response.function_call_arguments.done","sequence_number":18,"item_id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","output_index":1,"arguments":"{\"location\":\"Freiburg im Breisgau, Germany\"}"}
		
		event: response.output_item.done
		data: {"type":"response.output_item.done","sequence_number":19,"output_index":1,"item":{"id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","type":"function_call","status":"completed","arguments":"{\"location\":\"Freiburg im Breisgau, Germany\"}","call_id":"call_D5cRqvTm9V47jb0OLVJJ4Lqm","name":"get_weather"}}
		
		event: response.completed
		data: {"type":"response.completed","sequence_number":20,"response":{"id":"resp_68d7a3538cc48191841fb718106028930f91bcf2eb2355fd","object":"response","created_at":1758962515,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"rs_68d7a353ef008191815c6f969ee647cf0f91bcf2eb2355fd","type":"reasoning","summary":[]},{"id":"fc_68d7a355c9688191979704b9b2be9bc80f91bcf2eb2355fd","type":"function_call","status":"completed","arguments":"{\"location\":\"Freiburg im Breisgau, Germany\"}","call_id":"call_D5cRqvTm9V47jb0OLVJJ4Lqm","name":"get_weather"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"City and country e.g. Bogotá, Colombia"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":68,"input_tokens_details":{"cached_tokens":0},"output_tokens":156,"output_tokens_details":{"reasoning_tokens":128},"total_tokens":224},"user":null,"metadata":{}}}
		"""#)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let adapter = await OpenAIAdapter(tools: Tools.all, instructions: "", configuration: configuration)

//		let stream = mockHTTPClient.stream(path: "", body: 5.self)
		let stream = await adapter.streamResponse(
			to: Transcript<NoContext>.Prompt(input: "", embeddedPrompt: ""),
			generating: String.self,
			including: Transcript<NoContext>(),
			options: .init(include: [.reasoning_encryptedContent])
		)
		for try await event in stream {
			switch event {
			case .transcript(let entry):
				switch entry {
				case .toolCalls(let toolCalls):
					for toolCall in toolCalls {
						print("Arguments", toolCall.arguments.jsonString)
					}
				case .response(let response):
					if let segment = response.segments.first {
						switch segment {
						case .text(let textSegment):
							print(textSegment.content)
						case .structure:
							break
						}
					}
				default:
					break
				}
			default:
				break
			}
		}
	}
}

private func collectUpdates(
	from stream: AsyncThrowingStream<AdapterUpdate<NoContext>, any Error>
) async throws -> [AdapterUpdate<NoContext>] {
	var updates: [AdapterUpdate<NoContext>] = []
	for try await update in stream {
		updates.append(update)
	}
	return updates
}
