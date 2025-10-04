// By Dennis Müller

import Dependencies
import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(for: .openAI)
private final class ExampleSession {
	@Tool var weather = WeatherTool()
}

@Suite("OpenAIAdapter - Streaming - Tool Calls")
struct OpenAIAdapterStreamingToolCallsTests {
	typealias Transcript = SwiftAgent.Transcript

	// MARK: - Properties

	private let session: ExampleSession
	private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

	// MARK: - Initialization

	init() async {
		mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
			recordedResponses: [
				.init(body: response1),
				.init(body: response2),
			],
		)
		let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
		session = ExampleSession(instructions: "", configuration: configuration)
	}

	@Test("Single Tool Call (2 responses)")
	func singleToolCall() async throws {
		let generatedTranscript = try await processStreamResponse()

		await validateHTTPRequests()
		try validateTranscript(generatedTranscript: generatedTranscript)
	}

	// MARK: - Private Test Helper Methods

	private func processStreamResponse() async throws -> Transcript {
		let userPrompt = "What is the weather in New York City, USA?"

		let stream = try session.streamResponse(
			to: userPrompt,
			generating: String.self,
			options: .init(include: [.reasoning_encryptedContent]),
		)

		var generatedTranscript = Transcript()

		for try await snapshot in stream {
			generatedTranscript = snapshot.transcript
		}

		return generatedTranscript
	}

	private func validateHTTPRequests() async {
		let recordedRequests = await mockHTTPClient.recordedRequests()
		#expect(recordedRequests.count == 2)

		// Validate first request
		guard case let .inputItemList(items) = recordedRequests[0].body.input else {
			Issue.record("Recorded request body input is not .inputItemList")
			return
		}

		#expect(items.count == 1)

		guard case let .inputMessage(message) = items[0] else {
			Issue.record("Recorded request body input item is not .inputMessage")
			return
		}
		guard case let .textInput(text) = message.content else {
			Issue.record("Expected message content to be text input")
			return
		}

		#expect(text == "What is the weather in New York City, USA?")

		// Validate second request
		guard case let .inputItemList(secondItems) = recordedRequests[1].body.input else {
			Issue.record("Second recorded request body input is not .inputItemList")
			return
		}

		#expect(secondItems.count == 4)

		// Validate first item (input message)
		guard case let .inputMessage(secondMessage) = secondItems[0] else {
			Issue.record("Second request first item is not .inputMessage")
			return
		}
		guard case let .textInput(secondText) = secondMessage.content else {
			Issue.record("Expected second message content to be text input")
			return
		}

		#expect(secondText == "What is the weather in New York City, USA?")

		// Validate second item (reasoning item)
		guard case let .item(.reasoningItem(reasoningItem)) = secondItems[1] else {
			Issue.record("Second request second item is not .reasoningItem")
			return
		}

		#expect(reasoningItem.id == "rs_68d9303e94ac819ead3d9e066f405eae03aa6e5a972b3b23")
		#expect(reasoningItem.summary == [])

		// Validate third item (function tool call)
		guard case let .item(.functionToolCall(functionCall)) = secondItems[2] else {
			Issue.record("Second request third item is not .functionToolCall")
			return
		}

		#expect(functionCall.id == "fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23")
		#expect(functionCall.callId == "call_5dp5Uj0Loqn1YcyIpqSq6sLX")
		#expect(functionCall.name == "get_weather")
		#expect(functionCall.arguments == #"{"location": "New York City, USA"}"#)

		// Validate fourth item (function call output)
		guard case let .item(.functionCallOutputItemParam(functionOutput)) = secondItems[3] else {
			Issue.record("Second request fourth item is not .functionCallOutputItemParam")
			return
		}

		#expect(functionOutput.callId == "call_5dp5Uj0Loqn1YcyIpqSq6sLX")
		#expect(functionOutput.output == "\"Sunny\"")
	}

	private func validateTranscript(generatedTranscript: Transcript) throws {
		#expect(generatedTranscript.count == 4)

		guard case let .reasoning(reasoning) = generatedTranscript[0] else {
			Issue.record("First transcript entry is not .reasoning")
			return
		}

		#expect(reasoning.id == "rs_68d9303e94ac819ead3d9e066f405eae03aa6e5a972b3b23")
		#expect(reasoning.summary == [])

		guard case let .toolCalls(toolCalls) = generatedTranscript[1] else {
			Issue.record("Second transcript entry is not .toolCalls")
			return
		}

		#expect(toolCalls.calls.count == 1)
		#expect(toolCalls.calls[0].id == "fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23")
		#expect(toolCalls.calls[0].callId == "call_5dp5Uj0Loqn1YcyIpqSq6sLX")
		#expect(toolCalls.calls[0].toolName == "get_weather")
		let expectedArguments = try GeneratedContent(json: #"{ "location": "New York City, USA" }"#)
		#expect(toolCalls.calls[0].arguments.jsonString == expectedArguments.jsonString)

		guard case let .toolOutput(toolOutput) = generatedTranscript[2] else {
			Issue.record("Third transcript entry is not .toolOutput")
			return
		}

		#expect(toolOutput.id == "fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23")
		#expect(toolOutput.callId == "call_5dp5Uj0Loqn1YcyIpqSq6sLX")
		#expect(toolOutput.toolName == "get_weather")

		guard case let .structure(structuredSegment) = toolOutput.segment else {
			Issue.record("Tool output segment is not .text")
			return
		}

		#expect(structuredSegment.content.generatedContent.kind == .string("Sunny"))

		guard case let .response(response) = generatedTranscript[3] else {
			Issue.record("Fourth transcript entry is not .response")
			return
		}

		#expect(response.id == "msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23")
		#expect(response.segments.count == 1)

		guard case let .text(textSegment) = response.segments[0] else {
			Issue.record("Response segment is not .text")
			return
		}

		#expect(textSegment.content == "Current weather in New York City, USA: Sunny.")
	}
}

// MARK: - Tools

private struct WeatherTool: SwiftAgentTool {
	var name: String = "get_weather"
	var description: String = "Get current temperature for a given location."

	@Generable
	struct Arguments: Equatable {
		var location: String
	}

	func call(arguments: Arguments) async throws -> String {
		"Sunny"
	}
}

// MARK: - Mock Responses

private let response1: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d9303e0ef4819e9abaed38fac5de4f03aa6e5a972b3b23","object":"response","created_at":1759064126,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d9303e0ef4819e9abaed38fac5de4f03aa6e5a972b3b23","object":"response","created_at":1759064126,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_68d9303e94ac819ead3d9e066f405eae03aa6e5a972b3b23","type":"reasoning","encrypted_content":"gAAAAABo2TA-uKo-Hbpl44DC2KmrqAUd7t6v0ZU30eFE9oHi5mLqqgfcv0L4Y6iDmb3WTr3F_DZPTRDGqnnhreDrnyZwFRYvMBSvHUJ5LSR8aGwQwxRMLiJA5Dq2gINeXgt9ftscLoSgMOmmru2PVTRgCBu5CoYfotDMtHeb8cz9bGoCVjS311VYvJxLHePGtA52CwtJRKs5_BXLIOiudrqwmyJ57pw0IIftP2c3yqtCKk3PIfsHjGEef-sxBUuIS42C6DH287MniwtWNj7eOCB6ysH0II6b0i78pOJayIwa8UsYbdLJh8nDaeDdVqG5y80IMfRrX7AhZORAN5qZoit9wV8K-v3rPgVD_kQg4O6G1fGZe1UAoPaKqvtieDYM_OVAjqnSvWR5mkKrWuoUyxXN6BKDZdTN01q1riThZ3egNpG_ndsosG_q1eGfoUdkTsyE7IZZ-vAqJMHF467kgTC4qOAlADYvnsWCinR5ws5qimoFbmJ3WQ8MXZet6R5Pmg3CWalv_wh82feYOQN8RDjZKjoLB6B_xFPKtnn432ZaY-aXpskWyLnS1YPe5Vcw037dyTdGmNtfdm5uDM-BB3lAOsJWfz1RNlCWu_2w0NoazZC0GXW89p1W-znAdLj6tOPb0VEzLZ4Nk4f6f0wCud2qpVC9W-BqWo1xN-_TCU2SCuyG63JuVOmdME_UDr2GJleFQSyq51btCpvZJt2VJpAN0o9l_EhOCXSZ65E3XGF9nfFlV16pNTjFSyzsKzrRhJ8GJrWgrMqeAHn3shoapD1z4s4GZk8HTcygEcM4dHNyL5B3mtlqhSU=","summary":[]}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_68d9303e94ac819ead3d9e066f405eae03aa6e5a972b3b23","type":"reasoning","encrypted_content":"gAAAAABo2TA_9aBcwzsKm0jKc1AOjWhLaOBwJbo7JTTTcQtPJiM2LT1n7o9DY7uzvoHpacD_cgKgT4AtgUfGd0djMovchNpcvDzKZcwKPrYvmR45Xuvc_7JyVjcVEtx-f_YomDvXTVnv7evt6w65F2kHA1Ov-A_FOHbcOhnVxo63YuYmrB4BRSMojyxN5tscwaiMaLX1BlEnEqX9zjijUaFFIQj0gkZaJKzgTfLlGC0hGD3lOHkcg8Bt-raAJsAcoQvnX6mLG60uU84fFSjD-V4a2BuZ8w9vqlk3xwx98-w-5lWuAbbLmreprlYAI1OHCTZMsqZxBLAUiJ28YYsFvUQjeq1Mm1j7xp1LNRxXi1Ln_RNMrZQw2CVwLGlCz4XTMDqXzvlyoD5UCVkcpiXO3XFBxnVCk03jtArFiH-vh7TnQlhWnyeGPJNhXa4LtIVAv748wrsRqeVMaqs8VLFdIu9db07PzrRCyYpv9cKDQ1yIh2s37pcxA0Gvxw8ZRsrZQ5zDf4OsmfHhhRO0bO2A4y44L6UUkHOG-WJqA5pWr9khsAtZRJcOewG4ULCUzhDfXIau_twaqzbUanMEBU4ZP252etcL4ceM5vacg5Bq4uslndO4zh0YOnbLqfQ3LF7UvTa0t1uiRS1NOuqBu18Yvpf3Y3X9oV85MNBSl98F5S6KobkcbVr679N9S6PWEu9GLpwFCbayX5YZos5lEncUexkynv3cG4NgWju7LjAJ9UPSsyISEuje8mp7Jocs6TZGDboI41HARPNTySu34IvUBh7wrJzsSJWIRqoNDVbrPcuZsGdwgllkUbu3YpxlmLPHjHLgGj0wDIPP20iWaL_uDWAuLEx-HiuzkQOkNLDvcewakFQCrQHvJu_1P41Uvn9NoPZFXQXMmMKwcSr8VIhkcULr8FgwywKSXeDKN8TeHuDUy_TglsM7lG7GIEJQ2vOlbzfQqb_RCDvZd-nfMoh5S2nkCWtRPt_8LfMFHPZXhFarbtRuZx_8X1W9YwblcJwYRDhE21VziPpiTCA13LY60NhzyoWxqqwjiqOYUVNQV6Wiz5emEgJXEzBVjtQNIXh5uk6VrmLSNOuvSdkift0ohMcko74upi04Ejg8V4vWJO9Q62cOislju4-a8KUrK9Xmpnjt4wpnyMC0u310gSBpEw4XXAS_ShuSFelYS4VoRybnT_sGciCLaboPxzsUaACGiB6J9o7avZCh1pkTm7I1HUFD1tBQzL-5rG3s3mA87lZFdw7Fh5lPgZl6uGEM6EJwgZbIBMlpjzutyvRQ819xTIF0SX19g5Di0ZwhzYahVWc-35uspcVXPUJAy2njv-fouy1mJyVsr4yhImdClEiGtrcLuiNRf5MXrnbp3AWiEhhXgGyistoL3bgueFlKJUvkYMiv2VYPBjd2zY_4Dkr6QWufDIIttsJWrjzswMiWHTATuLFXwslA76nPaCesILfcRPJTDCfB3RsZs0jlEVujgzNUgMNT91dTdWLVFiv5iQVs_5mV1JbmivqzSezx-tSmUV_ISCQYJk7LpIjh9hMKUGarT_MyJ2cPPJHrmdT3cp1pEdjV-trAvQl5hsWQZ2URTb1_Es40Hw6LIgOBl1PB2X4wSejfKMNoUUKhlK9bVeEVuis5jz7DdoHFtRSfXA0g7-iP7k1_eO9fqBEYfNriVeGZzD9sEeMiX9DwQ_9CW-pD7Iab14BPYONzFiYGWzV2ayW7dizz4g2s86d_9oTFCMtx-fKPQDR8Yw==","summary":[]}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":4,"output_index":1,"item":{"id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","type":"function_call","status":"in_progress","arguments":"","call_id":"call_5dp5Uj0Loqn1YcyIpqSq6sLX","name":"get_weather"}}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":5,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":"{","obfuscation":"4FZhoGBnjNsYATZ"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":6,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" \"","obfuscation":"QZLnDBWlE731se"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":7,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":"location","obfuscation":"fswZpBw0"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":8,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":"\":","obfuscation":"ZeEswbWpCjCitv"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":9,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" \"","obfuscation":"6DMVR6c4JeEWCw"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":10,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":"New","obfuscation":"nsKh2fZwodcmP"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":11,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" York","obfuscation":"tItfifLsvjX"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":12,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" City","obfuscation":"zdbZoDOtaIM"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":13,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":",","obfuscation":"Y8X4rhWqjtuKg7r"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":14,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" USA","obfuscation":"yLJffarhjIAo"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":15,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":"\"","obfuscation":"fNFmrnvEYXpbrs9"}

event: response.function_call_arguments.delta
data: {"type":"response.function_call_arguments.delta","sequence_number":16,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"delta":" }","obfuscation":"WYlLsyZT4dUUXw"}

event: response.function_call_arguments.done
data: {"type":"response.function_call_arguments.done","sequence_number":17,"item_id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","output_index":1,"arguments":"{ \"location\": \"New York City, USA\" }"}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":18,"output_index":1,"item":{"id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","type":"function_call","status":"completed","arguments":"{ \"location\": \"New York City, USA\" }","call_id":"call_5dp5Uj0Loqn1YcyIpqSq6sLX","name":"get_weather"}}

event: response.completed
data: {"type":"response.completed","sequence_number":19,"response":{"id":"resp_68d9303e0ef4819e9abaed38fac5de4f03aa6e5a972b3b23","object":"response","created_at":1759064126,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"rs_68d9303e94ac819ead3d9e066f405eae03aa6e5a972b3b23","type":"reasoning","encrypted_content":"gAAAAABo2TBAHIAEhoF6BMeLdaTLFV8HVEe_XWvYaavDRXgA5GxGNAUXrueahZnjVjdmIj01tH0cbvfcOY_7Nr4CDjV-WJC8fCpPnqtxNFOl8VRRBlLBnrRkxTGszpUA1T0-5aSq-7QUNgc3cOGG4WlmeYPmHz3uRvkTZSoCzSdLdwy2nRZMz895tczs6TQRbAATht2AXOBEuJRzuaN-nsjfLZpFnbHFm7gavipc8J_4TgNiDpqc2ZGmv4PAyb36DfvQugthq9RAzTzi1G3vLCArNk9vtbJEKQG2PT4CN420zGq2e7U05ZY5FnwOGmjCW34eZuznHQnw9KchNBjnHBGuZDI5kheS_NrGvHrJxffZj7KEbsmkue6upyb1pezxTrMVb2myJUq564zuydWbdEXNY-pSBcMO7CK9U-6X41iR5GjS00Ijsp6wUQFJmSZc2RpnYNAucvQTxUf9182TOdDxqNM8rK-P9oUetMnMHJrs780OlU45255qV-6Lxa4fpSzF9DilmmU1fqSSnitEOgOgyA-XreojGcN2wirtuDhkwCLyHJHT4owRf1R226MDgZOCyA2KkpSMlYYEbratNbGN4I831PDYSDfA4or1DG94WtIxrF5dbxgMGXKxmJ_VKow0QrYNY8t0MLCXQWRsN9s4dwzr2ykWh24fJuxq64NoZXvKzsFZHbPEFvmafsditiAWqcJzBuaPrOcZKgnMcq08FGt3mDQnaouWj6vbrM5nqJCqnguAvf2Uq1kZmt0GgB03S1C9QG0d5eZ3Ji-GfNT_hyx17lWxU_7hsPYa0dn_sjEA3bfAc00WS6ot0kMpwV3vp1S4Z_mGwaOQI5yrulBm9EGPTbxoClZ776_2QOu0A8wll1ocUe8uvYqjPo0LFJJawFqhid-4JmhvkU2PELybxk6vS7hqEesjxD6a8hF-QMAg0JKErXuXRhR8ydgomwEZ1d4ADlS2rFUCqNVkzZnVtzlmvT4wDNoRkSmG3CV0bymyVTa6xfZrtZ-e5aqvG-F9XBIKPeaEYnaw3C8DPVDrmj8UHgkBAvySkMYuZC77JuQ5nA6ST9BwmpKxDv6XVKf1ibUBBypNAMQcv5a6WEbl_gjOP18QBSmeLjEszPXqVjDgu9ut6joCnaM25IYxYXH9uZjQtxzNZaEVn5EFJMR0c4Q9xPVZ1LEmtrAUdO1OV49mphtXfMfQj48JlkkAF7KsNTlviIMss_A-ixKGnK1b71balxY0k35c7YG4QuqLY-tgfM3UcA1hsZerckJjnwpRc2NcCcSE71cYuIPc6MsE4dBYUuZpf38vYq6aWi5M5u-qOI66_jxpn1rBN2LbR79fcJkKL61l1RIoU9i3dUMLNVfTjMPWvwlmOpFkABY2nyQRvQoi_iVr5fQfUapI-32IUjzquSGPOlyuOvxqr2-QE8PkPlX1zm17EVY4FXQ4om0Z5QXhau47sQOi2iIACsbf1Cvr-BgR-0G2c5H3bEtCVkKjtBXCYUmXpXCAN3FcmrZMjH5udYbgcG1uVMMxyjLWVnplwquL_4iYgchqTup6LbKybQ_mYjmBLwAjsjsjlA5yr3kPkL0N3dSVwwtFONqBBVMmiD4OE1wx2ss89TPbTfkSvjbNLHX4ZR1lH3kIqPd7xS1HD2DfmS7vW4KTX9ofmtQ46GPp14AIa-x2Q2vic6KRhSRipclS47h0bVZPF5kdcjNOCrU_io0_5sh0tHieb-9HAA2MhBOuMVMvP79TlPKjDVi-4w==","summary":[]},{"id":"fc_68d9303fe7fc819ea999bda43617404203aa6e5a972b3b23","type":"function_call","status":"completed","arguments":"{ \"location\": \"New York City, USA\" }","call_id":"call_5dp5Uj0Loqn1YcyIpqSq6sLX","name":"get_weather"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"default","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":75,"input_tokens_details":{"cached_tokens":0},"output_tokens":155,"output_tokens_details":{"reasoning_tokens":128},"total_tokens":230},"user":null,"metadata":{}}}
"""#

private let response2: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_68d93041848c819e90d610c34d125a8f03aa6e5a972b3b23","object":"response","created_at":1759064129,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_68d93041848c819e90d610c34d125a8f03aa6e5a972b3b23","object":"response","created_at":1759064129,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","type":"message","status":"in_progress","content":[],"role":"assistant"}}

event: response.content_part.added
data: {"type":"response.content_part.added","sequence_number":3,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":""}}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":4,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":"Current","logprobs":[],"obfuscation":"8LmeBsRtk"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":5,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" weather","logprobs":[],"obfuscation":"fl9SWXpF"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":6,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" in","logprobs":[],"obfuscation":"0uzkNlgTVuACI"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":7,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" New","logprobs":[],"obfuscation":"m6CUvXEzWfZv"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":8,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" York","logprobs":[],"obfuscation":"yW0YQNvlCcF"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":9,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" City","logprobs":[],"obfuscation":"alx43zz35m4"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":10,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":",","logprobs":[],"obfuscation":"upDHkp9MuPeysjI"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":11,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" USA","logprobs":[],"obfuscation":"1f5eJnDuVv47"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":12,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":":","logprobs":[],"obfuscation":"yfTPZO99UZVlx4I"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":13,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":" Sunny","logprobs":[],"obfuscation":"bP4DLMeMRN"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":14,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"delta":".","logprobs":[],"obfuscation":"oxtpMK8COHrCfpB"}

event: response.output_text.done
data: {"type":"response.output_text.done","sequence_number":15,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"text":"Current weather in New York City, USA: Sunny.","logprobs":[]}

event: response.content_part.done
data: {"type":"response.content_part.done","sequence_number":16,"item_id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","output_index":0,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":"Current weather in New York City, USA: Sunny."}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":17,"output_index":0,"item":{"id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"Current weather in New York City, USA: Sunny."}],"role":"assistant"}}

event: response.completed
data: {"type":"response.completed","sequence_number":18,"response":{"id":"resp_68d93041848c819e90d610c34d125a8f03aa6e5a972b3b23","object":"response","created_at":1759064129,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":"You are a helpful assistant that reports weather updates.","max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-2025-08-07","output":[{"id":"msg_68d930427844819ebda216a5dcfbec4603aa6e5a972b3b23","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"Current weather in New York City, USA: Sunny."}],"role":"assistant"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"medium","summary":null},"safety_identifier":null,"service_tier":"default","store":false,"temperature":1.0,"text":{"format":{"type":"text"},"verbosity":"medium"},"tool_choice":"auto","tools":[{"type":"function","description":"Get current temperature for a given location.","name":"get_weather","parameters":{"additionalProperties":false,"properties":{"location":{"type":"string"}},"required":["location"],"title":"Arguments","type":"object","x-order":["location"]},"strict":false}],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":114,"input_tokens_details":{"cached_tokens":0},"output_tokens":15,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":129},"user":null,"metadata":{}}}
"""#
