// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@Suite("OpenAIAdapter Streaming Tools Tests")
struct OpenAIStreamingToolsTests {
	typealias Transcript = SwiftAgent.Transcript

	@Test
	func streamToolResponse() async throws {
		let mockHTTPClient = ReplayHTTPClient(recordedResponse: response1)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let adapter = await OpenAIAdapter(tools: [], instructions: "", configuration: configuration)

		let inputPrompt = Transcript<NoContext>.Prompt(input: "input?", embeddedPrompt: "embeddedPrompt")
		let initialTranscript = Transcript<NoContext>(entries: [.prompt(inputPrompt)])

		let stream = await adapter.streamResponse(
			to: inputPrompt,
			generating: String.self,
			including: initialTranscript,
			options: .init(include: [.reasoning_encryptedContent])
		)

		var generatedTranscript = Transcript<NoContext>()

		for try await event in stream {
			switch event {
			case let .transcript(entry):
				generatedTranscript.upsert(entry)
			default:
				break
			}
		}
		
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

// MARK: - Tools

#tools(accessLevel: .private) {
	WeatherTool()
}

private struct WeatherTool: SwiftAgentTool {
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

// MARK: - Mock Responses

private let response1: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d835172d4481a3adc02a0a27d80dad05b5406cc515b605","object":"response","created_at":1758999831,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get the weather for a specified location","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"Name of the location to get the weather for"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d835172d4481a3adc02a0a27d80dad05b5406cc515b605","object":"response","created_at":1758999831,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get the weather for a specified location","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"Name of the location to get the weather for"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_68d83517d32481a3a885d6180985b19505b5406cc515b605","type":"reasoning","encrypted_content":"gAAAAABo2DUXb6CqT9OpUnYfUfIFdzETHDyQLdIt6VK_KnmwJ8rxL0TTvf-Js1xn-FqUhWqh5f0X2RlFlhGb13DS-5OGpSLkbaAl9-g7KALZJVgYqu2hsJOAIh9U0QLgcnKs02rdmr3yGmk7saYnDn0fflOgLVbYv8k2-9lU12hoX43cj74GZEm8S_Qo_nRXN-hwatG7JA8-eM-PTOiou9iPXzM20M103SHTMwP2UrkzTreGiMrukEBx2xyyIIzQRzybNdEqbFPE_vYPEDsQM-VKHst37M1eAo4xwoB37sh0cjBOAg6TzmzTYgi2u7_9hl_s8Q-OIr1aM4fYjzwc7WdfNI-0A-tPFIzb4jx3p1I69eczjCgsKoHd9EdXfZucqcPqBghsstq4mC5Jfx369G_tNW4hRanhv0tSk1F7osaSXybUIfMXEzo0TSI41T4hDEJ28qmgU3t_4u6c5qPUuWCGvzbhn-lQ2-N4FR-yqN8M4IuMOKOPqLybOoh9JA8oQuQoZW6EtJDvmbR39MNhg3OTjkXktBQQtwqSTnpyeouGSXsxgV9px8dlQg2DzdkU41xRbGZgrMEW-vYw30p4QSM7zonno8skeEYoqpw-Iu-07X66r53_7pGGgBaenUhVibuVhRZ0dHoMsB3oy4Z2mnddUg-Akjix8w-RH_gaG9f98AfZQrVUqUDwhkKUyofKSlfg5sklp-TAcfz4SJ0OLVPs4y1jztenAJawtoWKFS5JkU72j6LT4LKmss8HS2WsEUuOf6-gWgkmPiEAV9nU5jOa04nYIdFdbhXlYDygBDerypEaw7tM__I=","summary":[]}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_68d83517d32481a3a885d6180985b19505b5406cc515b605","type":"reasoning","encrypted_content":"gAAAAABo2DUYOAYuP7p03SU0PjHLxwh8ia5DyWu_IYV-Kh-i2msszJsPc6t1agpIGrdvx0IQNNtKmWPAkejXb3z89VWRqM6I_80e44oh_rRDoRxP7A2ChZUgmoYHHZptP0VjfM_M7Dlabq6k5AE-JEjuxDgOQab3OsKBkPCMfH9shy2UXPYlThDanY_rPBT5MGc3AO7AGsKbXPQBtETRU5oBTVDr_sTkHV2pG1LzwPjhx3TwnneArR3YRs0DXTLo1KvOuRonlSvP5apVyIq8OxMOSf-35h3usfdIhy_dy8HWBRqAQe26FtcpiZUNm7QxAPVn5tgUlnu7MBZccVbJ-yg3qeubLatqZ0U8BbbQ8WO4zyGXwGS3qwKGkJ5AtLiyrzFTz3FFb14dpZkQjkVnvuld8LKYuzTFNtKbI3HClUcO9NSIivtqPMWP7QVhGzNI0WEvZ8OlWazan-7cH0ju60Fw2pu0Tq9UvJ9IPsZsvbKgFTVS631PTO-AZIyTTjVcYAK0kyHhkfNJnVq95GG8MVTpFo5_WQlQ5c7JsDY9WlgE7WlYr9OxeSK28DfV0BRuiREQVXpjbIyL71OvLZfZNxllRJDRTO1evVNtEn42o--Pn-dGFzrj7a8mKkQ1FJaDW9MmVDP3QkfPhwcAd5X4dOAURq4rnmk_3AwX5YJk4KGG0huPQ2YDwiW6sJx59qiJmkfKfOobQ5gA1vPmntiLW09Nk693V6Rv9SruLjZLgtvpJSDeyu-5M-7k0DarYGlxgxKmDQoUQcNRDHeZhAXb2Iol4EsHTYlsN6I1FceLJhY0I-Om1PIoDjlgieYmQwLGFi3quEKH4-MXrXlI3qI6p6aiHXWUkDqJKe7AY4Z8bLt5puzCkfaZWXo=","summary":[]}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":4,"output_index":1,"item":{"id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","type":"function_call","status":"in_progress","arguments":"","call_id":"call_zmgkl7rFpA4eOyUO0SamopGI","name":"get_weather"}}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":5,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":"{\"","obfuscation":"6f4CRyWzgLMnbZ"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":6,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":"location","obfuscation":"nOpGcH0N"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":7,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":"\":\"","obfuscation":"LTtDeKkAZt7mO"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":8,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":"New","obfuscation":"jJkEhAM9UjcLn"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":9,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":" York","obfuscation":"8cdbJpkcFBE"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":10,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":" City","obfuscation":"Lvljd9m7apQ"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":11,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":",","obfuscation":"n5nV2EjcJtJifi1"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":12,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":" USA","obfuscation":"gEAnVt7tvZlv"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":13,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"delta":"\"}","obfuscation":"dHSW0Muy6Y4MOW"}

event: response.function_call_arguments.done
data: {"type":"response.function_call_arguments.done","sequence_number":14,"item_id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","output_index":1,"arguments":"{\"location\":\"New York City, USA\"}"}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":15,"output_index":1,"item":{"id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","type":"function_call","status":"completed","arguments":"{\"location\":\"New York City, USA\"}","call_id":"call_zmgkl7rFpA4eOyUO0SamopGI","name":"get_weather"}}

event: response.completed
data: {"type":"response.completed","sequence_number":16,"response":{"id":"resp_68d835172d4481a3adc02a0a27d80dad05b5406cc515b605","object":"response","created_at":1758999831,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"rs_68d83517d32481a3a885d6180985b19505b5406cc515b605","type":"reasoning","encrypted_content":"gAAAAABo2DUYx-Tdv1e4DyGGOCvN4Ro-gyAmgJkQWj1kyGJ2XvUgjJJzIUU3xrN5ns6e92YWacKCZdhXycRvr0OBcOTvMvKqRUFHSZYDD1YKx32D153pDvlCp2zZc6tkPWmZHd0FKaxR5zDHRXLDnyD1Z7rcX1Ye-ysH7_LSC-4kee6F6QjXAtN847MqwyLwOgpwoUbgH4uIS_EzJiWx9QF9m0aGmwogdYXYKZZkOgdolCuoOa9JxlMp9B-NmaG-sWtMNZ7uDA4hBwt5EDXGohYA1ZatfVhqsBWHn61xP5MEsblR7g63Ghg6eBNvM1ov4bo9sYK-WFHh5i0EIJvs8POa6X9wTyvMsqWfaYeOaylX-t4dOmPGThNWu8ChmdtHJCKd47iwa5z7CYqjLuBVykl8_QVqnfrOVYuy53qFEzJuw4Xdt34-lw2Zg-8CfbzcvlpdhJzbq5K9Bfi20O6y7O-cn9xJfy91Fw81iFpLwYMh0lnndWR8E69y-4q4VGwyPn8JqycLh2pieX938NLsNrZymRv2D4RVD3r_mjEUdSwm6j3jIXUGB4Tuf_t7pBHJB3WqSVbAhLCuqNBWpJ-g0dym7gxKrrjE8lpvoDmOqfCCfFtoXXgKoCOJo_8oFG3d59c0w83m-WkKEwRCVjhi7D1hEkUxmvNQ33iPRBz6y6rRiuM-caEz-y_Eux5Pta-lcDnxSEyeoTiiCaLYlhgY28RCVcWjJXIgCUkrqis-y3AgMHPSSluq24QTKtpIsXrbsMEr8qFzB_KChCSyyAHI8R_392SvMKcwzuf8vCLU8_mSyKjQJPBNil2eH3lJFaZDdP2cKgZEYPMHOVHwa_-k6v2LfOYcfP4eqtfCKI_UU06ReZPOtcv-2wI=","summary":[]},{"id":"fc_68d8351802e881a3aeaf0e594cbdc6d505b5406cc515b605","type":"function_call","status":"completed","arguments":"{\"location\":\"New York City, USA\"}","call_id":"call_zmgkl7rFpA4eOyUO0SamopGI","name":"get_weather"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get the weather for a specified location","name":"get_weather","parameters":{"type":"object","properties":{"location":{"type":"string","description":"Name of the location to get the weather for"}},"required":["location"],"additionalProperties":false},"strict":true}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":69,"input_tokens_details":{"cached_tokens":0},"output_tokens":24,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":93},"user":null,"metadata":{}}}
"""#
