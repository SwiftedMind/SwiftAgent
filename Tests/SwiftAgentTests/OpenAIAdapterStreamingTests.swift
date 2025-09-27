// By Dennis Müller

import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@Suite("OpenAIAdapter Simple Text Streaming")
struct OpenAIAdapterSimpleTextStreamingTests {
	typealias Transcript = SwiftAgent.Transcript
	
	@Test(#"Stream a simple "Hello, World" text response"#)
	func streamSimpleTextResponse() async throws {
		let mockHTTPClient = ReplayHTTPClient(recordedResponse: helloWorldResponse)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		let adapter = await OpenAIAdapter(tools: [], instructions: "", configuration: configuration)

		let inputPrompt = Transcript<NoContext>.Prompt(input: "", embeddedPrompt: "")
		
		let stream = await adapter.streamResponse(
			to: Transcript<NoContext>.Prompt(input: "", embeddedPrompt: ""),
			generating: String.self,
			including: Transcript<NoContext>(),
			options: .init(include: [.reasoning_encryptedContent])
		)
		
		// TODO: Add Mechanism to the Transcript to upsert an entry
		// TODO: Then build the transcript from the stream below
		// TODO: Find a way to structurally compare it with expected values
		// -> simply equality check with a prebuilt transcript object is not possible because of random ids and stuff. So we can only compare the actual content
		// TODO: Use swift-dependencies for this!
		var transcript = Transcript<NoContext>()
		
		for try await event in stream {
			switch event {
			case let .transcript(entry):
				transcript.upsert(entry)
//				switch entry {
//				case let .toolCalls(toolCalls):
//					for toolCall in toolCalls {
//						print("Arguments", toolCall.arguments.jsonString)
//					}
//				case let .response(response):
//					if let segment = response.segments.first {
//						switch segment {
//						case let .text(textSegment):
//							print(textSegment.content)
//						case .structure:
//							break
//						}
//					}
//				default:
//					break
//				}
			default:
				break
			}
		}
		
		print(transcript)
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

private let helloWorldResponse: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"gAAAAABo1-_5IhSbO53CvEcj-V_xa9617xqMxLP3sRjhctNYktOWq0UprWDZJm8thyX0o-6a4RAI68hKD39xui5I4Z9KoewuGzwWjsSOuYj7zM2CNTqv8yLixei5ANsg_H0ouzpw_6o66n3GIjyF2_6yyIzgbEYDfDJP494bHDrq4OrwPOZyzMb-xDaLyKGVijnKXiK39XM9tyzWY77ltUc1hZUWdI8buDZggj3SkEaFTSUcV0GmRQrO6eTYd1Zucnd_mWdTLfQPD1DOsITC7qeKPuu4kzCH61pE6VEtbVh-TFsDAPsEtbieryZNSK7HjU-l3d8yzZzlL_jeL-ZRJyTBXm72FYNOzBXamR4cgTmZqLp0iYzcpoGAfTITMig-1uQbQleGT78_2huxk9_txu6vq3vQCqUxXgdJ08E776ZNCmW6wBdG3vk1KV7goDHTwS-f6PWyjsduAu2NFD4NxHt1-IjzOzKGRe-YFjdCCQmel-SlB5n8YVWjAH0Tizaa8CoAifwZkA190mx404ngBeGU--CwkHxOyGHlSlIXVhpLTEEgmfrg-ldea10OSEsy6EaMMNSSaAQPXagtwrOJQDWpazDwQ35ckKe1c5OSSHahlJr4nPLZ_rxeEZlWv5ESyCMPxanWOD1akHjBTV0nPA2Mgk7GeaARmmM9y6T2VKRVSVMDRctlbBx9gaLPfMnfwbJ7v9GZsoE5nqtjfyRCYLLKYxlOV3reVGca1kHn2nS17O7XdTZRiq2FmV-T4ZEeyByrLK7CxYCbJhUJa2bfTcqoJOiXatImysgrjtog7G8Oht1w6TEfxkM=","summary":[]}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"gAAAAABo1-_5iw2FsyprY54qyWoNzJx8LM8iefsU9gpapgIPvUbzFPxfD3fdhpki8bGjAeVBCgI_CvBMaguqoTPnYIINykaV0clK0tswFSI0D4R-7fPumYUtHuZ0Zah0FNHrkjsbhfUwi8nuyTWTKlYVn6K1aRe8NkgYe4OciUkWauXVhATJdw9mr3S0pJmO0Gq02uEoXKvo9qLShvc3SJYsD7R8D0BMAMCt7oheTpOUqppGz_Fybdr41cEBLCosFnbP5y_YD7acN1cQ0LJGXU0uD0jBtvWnzAaaMdEheRhZAkxTz9tfh6n5nqMFWrwOwyvK8dfAoBLY0mGYg02_uYB4IYmjkQ_tQXAnekPem8Q686Oport6nTMIoaIb-8HwZoKASCfQxZOiTkY7MAZ1G97r67uhDQD_Ji_YSuDLF0QYGTz02-Z2Z7DmdVis82CGyA5tU6qfy8p4yqiJuW3bpwvUOSPLWjiq9cvlweARv1tohpo20S5ZeFEaUsX2ekK7z324lmtLbhQIVW6EEuzS6sDEFxdiSCoUdoXPMRMNWk6xdNCH42mCqiyfP3nmiDiaU-hbI5opHiJFZBce0aG7CnOSULFpR37Y97w3ErpDEVwcepXjHjH9rBPmqf3XlKYRqfKiasIKE7mjHcPTNt-abrEDvyW7BRF93EzzED7-y_5tQHb6kjMe1-iaka9ko26ECL0XyACkEFPisswhnXf2FiL0NyGppHYzCAgoELcgJLsk4bffmXaxOL_cqkczhzATiUrWaUgRgX65jOYQasyDHTx2mAP-zOB0TLtstEZ4P6zlWOcvMpV3GyOg5WUYGFTrwKEbuO0VoJEMGYP_3dfP8Od0rWPNzrDQEwmPwb7-NMX9xDpmM_0XtBw=","summary":[]}}

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
data: {"type":"response.completed","sequence_number":13,"response":{"id":"resp_68d7eff889908196bde536de7b601b7d07152cb8c6ac9072","object":"response","created_at":1758982136,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"rs_68d7eff985648196883d78673232885e07152cb8c6ac9072","type":"reasoning","encrypted_content":"gAAAAABo1-_5YEd2Y0hgHD1gwMujoiAAzLd0T5A5hnzqifIviLB8ktFj31hrZNF0dRmwhuM7gOQzD2q8YQoXfuKKu_kucRNugOInzaQaCbt2_Jk10pGLq85Rpf2CjgffK5kQR6fZ6gQ5ldU-evBI_qinlMe25NJdDejo2D_XEjO7VGEzRUaoH1dE5Xv_S1ToH2sOGAVCEXuiSKUsbFJzCh6pAw40UAvqcsRh511qP-_FJaDV4pwnYhipXAxjqFrtKWUq618gZ9aTYXShftJWFULO06Q4CO_EGUAVZNuqMy9kwhLINBTpEDodzlkwH17xI5faqZPe2KTAwVg5WhIPd_GEK3cgk4m_LymJn11dQL2KObXYCFa25TeyIjeT9acVUHjTpShBSGKZULFleiCE8B9lOouD7dg52TEmEkllOy1EE401NY6QOrLZt9FwPBqCaEfwe_Sas0mR1DXfI5ONi43V5Vm_xuWhFD4hZdn9MBondE-T3tvhm5hajA9pSF8XGU_W6hNYSBeU_UCzP16kOw3soG2WeON3ENfCt-9RFqbua_jpUKXULpYqBDWHqGel0Zl_kRWGzAGo2L0osRqsLXjCZYpDj9hS25ZtBauv8gWvGBAPp6K2iawrKob3no0ekzfqriwlxvqXz2MGpMRYWImR89LMgnqWu2wc1kIS_JNadMpW2X5-aBGsxcHuxOJvwLFPfBxU2NzdKQk6gJtsC6tJLfxXmHEZjJV-q7-02nf5GX6jFKXDEPfpXqkfhRTbdkLUmUnoENeQ3m6tQu-28RbqTMn65cITmyxIP7xmjEPoCmysZ9qmtcdycK0YIlV_z1rszCqCZ6wUQIkBtV5SCeEfLeXcNjv3X32m2um0N1ZqOmU-PK6wrZY=","summary":[]},{"id":"msg_68d7eff9c3b8819683eb04cbeb3775d507152cb8c6ac9072","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"Hello, World!"}],"role":"assistant"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"default","store":true,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":12,"input_tokens_details":{"cached_tokens":0},"output_tokens":10,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":22},"user":null,"metadata":{}}}
"""#
