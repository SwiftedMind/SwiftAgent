// By Dennis Müller

import Foundation
import FoundationModels
import OpenAI
@testable import OpenAISession
@testable import SwiftAgent
import Testing

@LanguageModelProvider(.openAI)
private final class ExampleSession {
  @StructuredOutput(WeatherForecast.self) var weatherForecast
}

@Suite("OpenAI - Streaming - Structured Output")
struct OpenAIStreamingStructuredOutputTests {
  typealias Transcript = SwiftAgent.Transcript

  // MARK: - Properties

  private let session: ExampleSession
  private let mockHTTPClient: ReplayHTTPClient<CreateModelResponseQuery>

  // MARK: - Initialization

  init() async {
    mockHTTPClient = ReplayHTTPClient<CreateModelResponseQuery>(
      recordedResponse: .init(body: structuredOutputResponse),
    )
    let configuration = OpenAIConfiguration(httpClient: mockHTTPClient)
    session = ExampleSession(instructions: "", configuration: configuration)
  }

  @Test("Single response")
  func singleResponse() async throws {
    try await processStreamResponse()
    try await validateRecordedHTTPRequests()
  }

  private func processStreamResponse() async throws {
    let stream = try session.weatherForecast.streamGeneration(
      from: "Provide the latest weather update.",
      using: .gpt5_mini,
      options: .init(include: [.reasoning_encryptedContent], minimumStreamingSnapshotInterval: .zero),
    )

    var generatedTranscript = Transcript()
    var generatedOutputSnapshots: [WeatherForecast.Schema.PartiallyGenerated] = []

    for try await snapshot in stream {
      generatedTranscript = snapshot.transcript

      if let content = snapshot.content {
        generatedOutputSnapshots.append(content)
      }
    }

    validateAgentResponse(generatedTranscript: generatedTranscript)
    validateGeneratedOutput(generatedOutputs: generatedOutputSnapshots)
  }

  private func validateRecordedHTTPRequests() async throws {
    let recordedRequests = await mockHTTPClient.recordedRequests()

    let request = try #require(recordedRequests.first)
    guard case let .inputItemList(items) = request.body.input else {
      Issue.record("Recorded request body input is not .inputItemList")
      return
    }

    #expect(items.count == 1)

    guard case let .inputMessage(message) = items[0] else {
      Issue.record("Recorded request item is not .inputMessage")
      return
    }
    guard case let .textInput(text) = message.content else {
      Issue.record("Expected message content to be text input")
      return
    }

    #expect(text == "Provide the latest weather update.")

    let expectedOutputConfig = CreateModelResponseQuery.TextResponseConfigurationOptions.OutputFormat
      .StructuredOutputsConfig(
        name: WeatherForecast.name,
        schema: .dynamicJsonSchema(WeatherForecast.Schema.generationSchema),
        description: nil,
        strict: false,
      )

    guard request.body.text == .jsonSchema(expectedOutputConfig) else {
      Issue.record("Expected text configuration format to be present")
      return
    }
  }

  private func validateGeneratedOutput(generatedOutputs: [WeatherForecast.Schema.PartiallyGenerated]) {
    // Test the streaming progression
    #expect(generatedOutputs.count == 19)

    // Initial values should be nil
    for index in 0...4 {
      #expect(generatedOutputs[index].temperatureCelsius == nil)
      #expect(generatedOutputs[index].condition == nil)
    }

    // Temperature starts getting set to 22.0
    for index in 5...7 {
      #expect(generatedOutputs[index].temperatureCelsius == 22.0)
      #expect(generatedOutputs[index].condition == nil)
    }

    // Condition starts getting set incrementally
    #expect(generatedOutputs[8].temperatureCelsius == 22.0)
    #expect(generatedOutputs[8].condition == "")

    #expect(generatedOutputs[9].temperatureCelsius == 22.0)
    #expect(generatedOutputs[9].condition == "Part")

    #expect(generatedOutputs[10].temperatureCelsius == 22.0)
    #expect(generatedOutputs[10].condition == "Partly")

    #expect(generatedOutputs[11].temperatureCelsius == 22.0)
    #expect(generatedOutputs[11].condition == "Partly Cloud")

    // Final output should have complete values
    for index in 12...18 {
      #expect(generatedOutputs[index].temperatureCelsius == 22.0)
      #expect(generatedOutputs[index].condition == "Partly Cloudy")
    }
  }

  private func validateAgentResponse(generatedTranscript: Transcript) {
    #expect(generatedTranscript.count == 3)

    guard case let .prompt(promptEntry) = generatedTranscript[0] else {
      Issue.record("Expected first transcript entry to be .prompt")
      return
    }

    #expect(promptEntry.input == "Provide the latest weather update.")

    guard case let .reasoning(reasoningEntry) = generatedTranscript[1] else {
      Issue.record("Expected second transcript entry to be .reasoning")
      return
    }

    #expect(reasoningEntry.id == "rs_061272552eb6b10b0168eba2b65c048197bf2f05c29f6f361d")
    #expect(reasoningEntry.summary == [])

    guard case let .response(responseEntry) = generatedTranscript[2] else {
      Issue.record("Expected third transcript entry to be .response")
      return
    }

    #expect(responseEntry.segments.count == 1)
    guard case let .structure(structuredSegment) = responseEntry.segments.first else {
      Issue.record("Expected response segment to be .structure")
      return
    }

    #expect(structuredSegment.typeName == WeatherForecast.name)
  }
}

private struct WeatherForecast: StructuredOutput {
  static let name: String = "weather_forecast"

  @Generable
  struct Schema {
    var temperatureCelsius: Double
    var condition: String
  }
}

// MARK: - Mock Responses

private let structuredOutputResponse: String = #"""
event: response.created
data: {"type":"response.created","sequence_number":0,"response":{"id":"resp_061272552eb6b10b0168eba2b548c08197bf9b82fed20460ad","object":"response","created_at":1760273077,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-mini-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"json_schema","description":null,"name":"weather_forecast","schema":{"type":"object","properties":{"temperatureCelsius":{"type":"number","description":"Forecast temperature in degrees Celsius."},"condition":{"type":"string","description":"Short weather condition description (e.g., Sunny, Rainy, Cloudy)."}},"required":["temperatureCelsius","condition"],"additionalProperties":false},"strict":true},"verbosity":"low"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.in_progress
data: {"type":"response.in_progress","sequence_number":1,"response":{"id":"resp_061272552eb6b10b0168eba2b548c08197bf9b82fed20460ad","object":"response","created_at":1760273077,"status":"in_progress","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-mini-2025-08-07","output":[],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"auto","store":false,"temperature":1.0,"text":{"format":{"type":"json_schema","description":null,"name":"weather_forecast","schema":{"type":"object","properties":{"temperatureCelsius":{"type":"number","description":"Forecast temperature in degrees Celsius."},"condition":{"type":"string","description":"Short weather condition description (e.g., Sunny, Rainy, Cloudy)."}},"required":["temperatureCelsius","condition"],"additionalProperties":false},"strict":true},"verbosity":"low"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":null,"user":null,"metadata":{}}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":2,"output_index":0,"item":{"id":"rs_061272552eb6b10b0168eba2b65c048197bf2f05c29f6f361d","type":"reasoning","encrypted_content":"gAAAAABo66K2uVWJNJKFHjumVWjLgbk3mfAENj1wa1sSKCrO7M98nGbmjO3rxvZWSPTK7dfwWM6pJTwK46rt3STNw3vsmhpV-zMwgFFlpN9mJEAC7P-TLcm0DKvw7xEVwNJZnUPrWCH9hn-SIwilqv3dhRgtmbLpoDjAmrPRkpx0bG038BAbHLBoV2wsg2USLJdlKt5SWuiuebT0qjhxOaV6_zmDJWD-nWx7MM8KOPRMnxJ5a3zhWPy_127mb294kILJJmn4cCHemEmuSwC1-p8KLzdPj-imaw-nJ9zi0kMBVOKqN3nFgFXW7-9gYxcKIanEcUhsVZmw7Al3PlQpSrfKrrOKbRjCsBnfMF1tvrvazJ3EQDPd_WPe6b-mmnnH4K_YfPb5q1DqS3pZQb2c585lj_JjyzNZcIotIG69iqUO3xICRQtmsWgt68e3bqkYQ_ARug3lsJGCEMFNuHOKeQrgwk1opURgSVOIWnbqCANIwntB0A5kON2xGXWtkszCSgFWe6X-Lr-d3Apxji4r_tRJBs_m_UrGB_4HH8TtWqY5MR4e1pP9eq_pBZme3C6vhNDjgJIz_baIzh6BgRj4FbY2vu6DNyTTJJ7SGUl5alGMNezgfJAw8G53zxc76__RHaX-OgSkZABCAHHvfqGqX7lDfUtAQD6gy9ZWYepIc9wc8mzqROyKPGyg8i9k_FxHI-0-WQ66cC85spAR_LqW8Ck4XfzGKbq0zr_sjjKfUrrppyY90R0TNqUp7ZGvZDmi8N0zRbSoCLp_un1IZF7W47NDXbvmEafTp0R-ttNp0NHvq8RU0EbUS7r8fGpN_oVNAm7tAsxSUrsy","summary":[]}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":3,"output_index":0,"item":{"id":"rs_061272552eb6b10b0168eba2b65c048197bf2f05c29f6f361d","type":"reasoning","encrypted_content":"gAAAAABo66K2YWs27dyexAowhpdjNet8XY7pRnT1SpL3gxycHVsA2kjoYOK4TrbF84yblFxY7AmNl9ok6Eju_zDAcwj_5rhk-viMuDqTzEuL39dKMHH9Wg2ztsQMkX8FA9bC8jTYVb68rknALZkAKos_ShOc9ZH4DUYKemybr877WFs8vzEFWH7PomuUfkpaOxgI5NBiUUECfdeFqacei9G2j2FtaHNv7w4T3Z7Rj-1Ug4e0_FrPT-cwV1Bp7qT6WqToV4hi-htQoNyAlbAvd3yBAj6ijvUuyi9-g18K7u5BbICbNr2ZtPk9bjgHfjKtmH8fQFUt4S0rosalV1xl2s-4jjCazRU5Z-H5tYuNYy7o0UNxGTEaKLYSF-nTZrKb8ddzBy3Xn5Vjysq44KPCxaeYHzTk_Sjy-n8-q_7mckohhSRHef0UckXM3aeqnvrdjTBc3aFeJkOOqqV5O33tC5yDY5A2ei58K0rZabNNOs6wEHn3Ill-VdCBrR85v-8nr3O-7uoX6TP0eJ1z4qrZbWMNXP1mZA1_AKjwYR2wZ_lTpUV5fn5D0EUc1XuiltE9OzR2u-7JpvzmBIIn6H-XzAeBuhW2OIKGBYigFW20-SjO0eckSogGIFhjwd5wHRLkxUB_z_rx3x7O-8oWO5aAqTUpahV7v1gnpFewUWLoNNW_UOVJiveIy9UBQvgZSEH1UJZfb7an7BAE4Veo0sVnFifyB6etS5T-47fUiRpefbAkHmIfNbRHN58FGdO2OafPHCPI43E15w1CNFkv_-FOO_FMb4cjnfpmZkILMlYDy1Hp84k7gmGQq_Od6Rno9XTm3u3B6NQO6C8p9-3L7DPwZmKLrd9Y_y0NSjjsoDDey6FuKakU7XyKc18kt8AwuJtC1ZPa2ijLXno2fWnFIHx6Km8tEN72MEbLBg==","summary":[]}}

event: response.output_item.added
data: {"type":"response.output_item.added","sequence_number":4,"output_index":1,"item":{"id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","type":"message","status":"in_progress","content":[],"role":"assistant"}}

event: response.content_part.added
data: {"type":"response.content_part.added","sequence_number":5,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":""}}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":6,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"{\"","logprobs":[],"obfuscation":"qigDskq32eaUUp"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":7,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"temperature","logprobs":[],"obfuscation":"CwM4A"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":8,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"C","logprobs":[],"obfuscation":"oMZxjH4f0Jh9RE1"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":9,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"elsius","logprobs":[],"obfuscation":"X3RbOOfuS0"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":10,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"\":","logprobs":[],"obfuscation":"X6n8rO2GjE71kT"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":11,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"22","logprobs":[],"obfuscation":"ASDbXcy9f5SZ2N"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":12,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":",\"","logprobs":[],"obfuscation":"zffH5gwygwwQIO"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":13,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"condition","logprobs":[],"obfuscation":"5yAk5JL"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":14,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"\":\"","logprobs":[],"obfuscation":"kOH6nEisCXZqA"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":15,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"Part","logprobs":[],"obfuscation":"urSOtCEallio"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":16,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"ly","logprobs":[],"obfuscation":"57RDFTTvSvno7z"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":17,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":" Cloud","logprobs":[],"obfuscation":"5rsUlyYzj5"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":18,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"y","logprobs":[],"obfuscation":"r47RkNBnSifkasZ"}

event: response.output_text.delta
data: {"type":"response.output_text.delta","sequence_number":19,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"delta":"\"}","logprobs":[],"obfuscation":"OLzH8rzojSu5NS"}

event: response.output_text.done
data: {"type":"response.output_text.done","sequence_number":20,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"text":"{\"temperatureCelsius\":22,\"condition\":\"Partly Cloudy\"}","logprobs":[]}

event: response.content_part.done
data: {"type":"response.content_part.done","sequence_number":21,"item_id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","output_index":1,"content_index":0,"part":{"type":"output_text","annotations":[],"logprobs":[],"text":"{\"temperatureCelsius\":22,\"condition\":\"Partly Cloudy\"}"}}

event: response.output_item.done
data: {"type":"response.output_item.done","sequence_number":22,"output_index":1,"item":{"id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"{\"temperatureCelsius\":22,\"condition\":\"Partly Cloudy\"}"}],"role":"assistant"}}

event: response.completed
data: {"type":"response.completed","sequence_number":23,"response":{"id":"resp_061272552eb6b10b0168eba2b548c08197bf9b82fed20460ad","object":"response","created_at":1760273077,"status":"completed","background":false,"error":null,"incomplete_details":null,"instructions":null,"max_output_tokens":null,"max_tool_calls":null,"model":"gpt-5-mini-2025-08-07","output":[{"id":"rs_061272552eb6b10b0168eba2b65c048197bf2f05c29f6f361d","type":"reasoning","encrypted_content":"gAAAAABo66K2Y4t6JB54to_iMjqXi4rKH2D7zQ1PQVhCE0zbWLdF5l1rxiWStnDvw-w8yVaMzzKWfVlw0TCOjLDzGDmOakkq4G9bcI-TZLAMJYXj5_oVt_64USVaMfbnrYnrr3933YtwUkTl63kwy70H4lJ5RaOsmNHJEaYVzyiRuF0hIMvKuQPMFDlcA2WrYNLlUUBhs1Gys1bC6dcFNtPCcRBH-IeukGlpZf_e-YVmMJD7ECDzRi95ESqGBTM_yKkMs99dEiagdH9CKWe5-dCKE3JZTBeu6vDcMnI4te9wcdK3yq2kSUS7ZT0HN26hxdUN9wYErGEJinKxQy2CREOMINAfc2P5ahKfzdTNJNXFD6wasxFbRA73bhMUilN4dUYWFtKTtYKFpUoiyZzAjHdiOWHC5xlOqoYYDDr058II1Aa9PSwBZZX9ra8i6TjexbIGgeYymIaXqHbCJs7qre1HRgBphQjHB0iLGMfDpv0ZaoEMfXvWGessiO42Xmed3Gua6ivLNbttjWZvfYIiUYiovUaF9em6yRyClutDD0pdFMpgen1A3AoYGRhQeKjsKXswxuqW53p087QwXcp69MjYXRUxFr8ShyWLVQDOrpO1Lz-ZxEjsj0VMs2eTAUfaSYZNwESCEKEjIgKEgkjBKfled8HgEHFwfOpAkLyX9asi-6Z_2TiNiSoPf7xy9MNLXsqpyjZbE2J5JgiChebbchyLoGNcvUF7XDz-ZN6AvW7vymIqHMdob3eBkSkXKxmoHEsHKi0UtZDY8mMt7pkNYzqMuu3g7w07JbYOfEO_HqmsmXzMDOzN0SkhBhOWIgGOoooM1u-UZdV1IXYq-2dUIB7QRIHAc7Z8LqubCaRdWpA65mXapYDS0P5ToEnO3ECxsXvYr_-4ZRM2rZCA-4poF54ezGNwZ5NUxQ==","summary":[]},{"id":"msg_061272552eb6b10b0168eba2b6a4688197a206a98751d5a624","type":"message","status":"completed","content":[{"type":"output_text","annotations":[],"logprobs":[],"text":"{\"temperatureCelsius\":22,\"condition\":\"Partly Cloudy\"}"}],"role":"assistant"}],"parallel_tool_calls":true,"previous_response_id":null,"prompt_cache_key":null,"reasoning":{"effort":"minimal","summary":"detailed"},"safety_identifier":null,"service_tier":"default","store":false,"temperature":1.0,"text":{"format":{"type":"json_schema","description":null,"name":"weather_forecast","schema":{"type":"object","properties":{"temperatureCelsius":{"type":"number","description":"Forecast temperature in degrees Celsius."},"condition":{"type":"string","description":"Short weather condition description (e.g., Sunny, Rainy, Cloudy)."}},"required":["temperatureCelsius","condition"],"additionalProperties":false},"strict":true},"verbosity":"low"},"tool_choice":"auto","tools":[],"top_logprobs":0,"top_p":1.0,"truncation":"disabled","usage":{"input_tokens":72,"input_tokens_details":{"cached_tokens":0},"output_tokens":25,"output_tokens_details":{"reasoning_tokens":0},"total_tokens":97},"user":null,"metadata":{}}}
"""#
